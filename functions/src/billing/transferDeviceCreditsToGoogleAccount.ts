import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

interface TransferDeviceCreditsData {
  deviceId: string;
}

/**
 * Moves purchased credits from a legacy device-based user document (`users/{deviceId}`)
 * into the authenticated (Google) user document (`users/{uid}`), atomically.
 *
 * This prevents client-side tampering with credit amounts.
 */
export const transferDeviceCreditsToGoogleAccount = onCall<TransferDeviceCreditsData>({ invoker: 'public', enforceAppCheck: false }, async (request) => {
  const { data, auth } = request;

  if (!auth) {
    throw new HttpsError('unauthenticated', 'Kullanıcı girişi gerekli');
  }

  const provider = (auth.token as any)?.firebase?.sign_in_provider as string | undefined;
  if (provider === 'anonymous') {
    throw new HttpsError('failed-precondition', 'Kredi transferi için Google ile giriş yapmalısınız');
  }

  const targetUserId = auth.uid;
  const deviceId = (data?.deviceId ?? '').trim();
  if (!deviceId) {
    throw new HttpsError('invalid-argument', 'Device ID is required');
  }

  const db = admin.firestore();

  // If we have a prior server-side binding for this device, enforce it.
  // This blocks attempting to transfer credits from other devices.
  const deviceBonusRef = db.collection('device_bonuses').doc(deviceId);
  const deviceBonusDoc = await deviceBonusRef.get();
  if (deviceBonusDoc.exists) {
    const boundUserId = deviceBonusDoc.data()?.userId;
    if (boundUserId && boundUserId !== targetUserId) {
      throw new HttpsError('permission-denied', 'Bu cihaz başka bir hesaba bağlı');
    }
  }

  const sourceRef = db.collection('users').doc(deviceId); // legacy device-based doc
  const targetRef = db.collection('users').doc(targetUserId);

  return db.runTransaction(async (tx) => {
    const [sourceSnap, targetSnap] = await Promise.all([tx.get(sourceRef), tx.get(targetRef)]);

    if (!sourceSnap.exists) {
      return { success: false, transferred: 0, message: 'Transfer edilecek cihaz kaydı bulunamadı.' };
    }

    const source = sourceSnap.data() ?? {};

    if (source.deviceBased !== true) {
      return { success: false, transferred: 0, message: 'Bu cihaz hesabı device-based değil.' };
    }

    if (source.transferredTo) {
      return { success: false, transferred: 0, message: 'Bu cihaz kredileri daha önce transfer edilmiş.' };
    }

    const purchasedCredits = Number(source.purchasedCredits ?? 0);
    const bonusCredits = Number(source.bonusCredits ?? 0);

    if (!Number.isFinite(purchasedCredits) || purchasedCredits < 0) {
      throw new HttpsError('invalid-argument', 'Geçersiz purchasedCredits');
    }

    if (purchasedCredits <= 0) {
      if (bonusCredits > 0) {
        return { success: false, transferred: 0, message: 'Cihazda sadece bonus kredi var, transfer edilmemiştir.' };
      }
      return { success: false, transferred: 0, message: 'Transfer edilecek satın alınmış kredi yok.' };
    }

    const increment = admin.firestore.FieldValue.increment(purchasedCredits);

    tx.set(
      targetRef,
      {
        credits: increment,
        purchasedCredits: increment,
        transferredFrom: deviceId,
        transferredAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

      // google_users koleksiyonunu da eşzamanlı olarak güncelle
      const googleUserRef = db.collection('google_users').doc(targetUserId);
      tx.set(
        googleUserRef,
        {
          credits: increment,
          purchasedCredits: increment,
          transferredFrom: deviceId,
          transferredAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // Best-effort: decrement credits if present; always zero-out purchasedCredits.
      tx.set(
        sourceRef,
        {
          credits: admin.firestore.FieldValue.increment(-purchasedCredits),
          purchasedCredits: 0,
          transferredTo: targetUserId,
          transferredAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    // Optional audit record
    const auditRef = db.collection('credit_transfers').doc();
    tx.set(auditRef, {
      deviceId,
      fromUserDocId: deviceId,
      toUserId: targetUserId,
      purchasedCredits,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const targetCredits = targetSnap.exists ? Number(targetSnap.data()?.credits ?? 0) : 0;
    return { success: true, transferred: purchasedCredits, newCredits: targetCredits + purchasedCredits };
  });
});

// force redeploy
