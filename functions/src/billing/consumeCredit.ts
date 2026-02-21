import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from 'firebase-admin';

interface ConsumeCreditsData {
  amount: number;
  deviceId: string;
  reason?: string;
  chargeKey?: string;
  fileName?: string;
  targetLanguage?: string;
  platform?: string;
}

/**
 * Kredi düşme fonksiyonu (v2)
 */
export const consumeCredit = onCall<ConsumeCreditsData>(async (request) => {
  // v2'de data ve auth request objesinden gelir
  const { data, auth } = request;
  const { amount, reason, deviceId, chargeKey, fileName, targetLanguage, platform } = data;

  const trimmedDeviceId = (deviceId ?? '').trim();
  if (!trimmedDeviceId) {
    throw new HttpsError('invalid-argument', 'Device ID is required');
  }

  const trimmedChargeKey = (chargeKey ?? '').trim();
  const trimmedPlatform = (platform ?? '').trim().toLowerCase();

  if (!amount || amount <= 0) {
    throw new HttpsError('invalid-argument', 'Geçersiz kredi miktarı');
  }

  try {
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const db = admin.firestore();
      const deviceBonusRef = db.collection('device_bonuses').doc(trimmedDeviceId);
      const deviceBonusDoc = await transaction.get(deviceBonusRef);
      const normalizedReason = (reason ?? 'unknown').trim().toLowerCase();
      const requiresFirstChunkApproval = normalizedReason !== 'cache_hit';

      if (requiresFirstChunkApproval && trimmedChargeKey.length === 0) {
        throw new HttpsError('failed-precondition', 'First chunk approval is required');
      }

      if (requiresFirstChunkApproval) {
        const sessionRef = db.collection('translation_sessions').doc(trimmedChargeKey);
        const sessionDoc = await transaction.get(sessionRef);
        const approved = sessionDoc.exists && sessionDoc.data()?.approved === true;

        if (!approved) {
          throw new HttpsError('failed-precondition', 'First chunk not approved');
        }
      }

      const idempotencyRef = trimmedChargeKey.length > 0
        ? deviceBonusRef.collection('credit_usage').doc(trimmedChargeKey)
        : null;

      if (idempotencyRef != null) {
        const idempotencyDoc = await transaction.get(idempotencyRef);
        if (idempotencyDoc.exists) {
          const idempotencyData = idempotencyDoc.data() ?? {};
          const remainingDeviceCredits = Number(idempotencyData.remainingDeviceCredits ?? 0);
          const remainingPurchasedCredits = Number(idempotencyData.remainingPurchasedCredits ?? 0);
          return {
            success: true,
            idempotent: true,
            remainingDeviceCredits: Number.isFinite(remainingDeviceCredits) ? remainingDeviceCredits : 0,
            remainingPurchasedCredits: Number.isFinite(remainingPurchasedCredits) ? remainingPurchasedCredits : 0,
            remainingCredits:
              (Number.isFinite(remainingDeviceCredits) ? remainingDeviceCredits : 0) +
              (Number.isFinite(remainingPurchasedCredits) ? remainingPurchasedCredits : 0),
          };
        }
      }

      // Device credits are stored on the device doc (works even if user changes accounts).
      const existingDeviceData = deviceBonusDoc.exists ? (deviceBonusDoc.data() ?? {}) : {};
      const bonusAmount = 5;
      const hasTrackingFields =
        Object.prototype.hasOwnProperty.call(existingDeviceData, 'deviceCredits') ||
        Object.prototype.hasOwnProperty.call(existingDeviceData, 'bonusCredits') ||
        Object.prototype.hasOwnProperty.call(existingDeviceData, 'totalBonusConsumed');
      const legacyBonus = Number(existingDeviceData.bonusCredits ?? 0);
      let deviceCreditsRaw = Number(existingDeviceData.deviceCredits ?? 0);
      if (!Number.isFinite(deviceCreditsRaw) || deviceCreditsRaw < 0) deviceCreditsRaw = 0;
      if (deviceCreditsRaw === 0 && Number.isFinite(legacyBonus) && legacyBonus > 0) {
        deviceCreditsRaw = legacyBonus;
      }
      if (deviceBonusDoc.exists && !hasTrackingFields) {
        deviceCreditsRaw = bonusAmount;
      }

      // Lifetime cap: a deviceId can never consume more than 5 bonus credits.
      let totalBonusConsumed = Number(existingDeviceData.totalBonusConsumed ?? NaN);
      if (!Number.isFinite(totalBonusConsumed) || totalBonusConsumed < 0) {
        if (deviceBonusDoc.exists && !hasTrackingFields) {
          totalBonusConsumed = 0;
        } else {
          const clampedRemaining = Math.max(0, Math.min(bonusAmount, deviceCreditsRaw));
          totalBonusConsumed = Math.max(0, bonusAmount - clampedRemaining);
        }
      }

      const remainingBonusAllowed = Math.max(0, bonusAmount - totalBonusConsumed);
      // Effective remaining bonus is min(stored remaining, remaining allowed by counter).
      let deviceCredits = Math.min(Math.max(0, deviceCreditsRaw), remainingBonusAllowed);

      let purchasedCredits = 0;
      let userRef: FirebaseFirestore.DocumentReference | null = null;
      if (auth?.uid) {
        userRef = db.collection('users').doc(auth.uid);
        const userDoc = await transaction.get(userRef);
        if (userDoc.exists) {
          const userData = userDoc.data() ?? {};
          const rawPurchased = userData.purchasedCredits;
          const rawCredits = userData.credits;
          const purchasedA = Number.isFinite(Number(rawPurchased)) ? Number(rawPurchased) : 0;
          const purchasedB = Number.isFinite(Number(rawCredits)) ? Number(rawCredits) : 0;
          purchasedCredits = Math.max(purchasedA, purchasedB);
        }
      }

      const currentTotal = deviceCredits + purchasedCredits;
      if (currentTotal < amount) {
        throw new HttpsError(
          'failed-precondition',
          `Yetersiz kredi. Mevcut: ${currentTotal}, Gerekli: ${amount}`
        );
      }

      const fromDevice = Math.min(deviceCredits, amount);
      const fromPurchased = amount - fromDevice;

      deviceCredits -= fromDevice;
      totalBonusConsumed += fromDevice;
      purchasedCredits -= fromPurchased;
      if (purchasedCredits < 0) purchasedCredits = 0;

      // Persist device remaining credits.
      transaction.set(deviceBonusRef, {
        deviceId: trimmedDeviceId,
        deviceCredits,
        bonusAmount,
        totalBonusConsumed,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUserId: auth?.uid ?? null,
      }, { merge: true });

      // Persist purchased credits only if authenticated.
      if (userRef) {
        transaction.set(userRef, {
          purchasedCredits,
          credits: purchasedCredits,
          lastCreditConsumption: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      if (userRef) {
        const usageRef = userRef.collection('credit_usage').doc();
        transaction.set(usageRef, {
          amount,
          reason: reason || 'unknown',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          deviceId: trimmedDeviceId,
          platform: trimmedPlatform || null,
          chargeKey: trimmedChargeKey.length > 0 ? trimmedChargeKey : null,
          fileName: (fileName ?? '').trim() || null,
          targetLanguage: (targetLanguage ?? '').trim() || null,
          fromDevice,
          fromPurchased,
          remainingDeviceCredits: deviceCredits,
          remainingPurchasedCredits: purchasedCredits,
          remainingCredits: purchasedCredits + deviceCredits,
        });

        // Unified credit history (preferred by UI)
        // Use chargeKey as deterministic docId when available to avoid duplicates.
        const txDoc = trimmedChargeKey.length > 0
          ? userRef.collection('credit_transactions').doc(trimmedChargeKey)
          : userRef.collection('credit_transactions').doc();
        transaction.set(txDoc, {
          type: 'spend',
          amount,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          source: 'consume_credit',
          reason: reason || 'unknown',
          deviceId: trimmedDeviceId,
          platform: trimmedPlatform || null,
          chargeKey: trimmedChargeKey.length > 0 ? trimmedChargeKey : null,
          fileName: (fileName ?? '').trim() || null,
          targetLanguage: (targetLanguage ?? '').trim() || null,
          fromDevice,
          fromPurchased,
          remainingDeviceCredits: deviceCredits,
          remainingPurchasedCredits: purchasedCredits,
          remainingCredits: purchasedCredits + deviceCredits,
        }, { merge: true });
      }

      if (idempotencyRef != null) {
        transaction.set(idempotencyRef, {
          amount,
          reason: reason || 'unknown',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          deviceId: trimmedDeviceId,
          userId: auth?.uid ?? null,
          platform: trimmedPlatform || null,
          fromDevice,
          fromPurchased,
          remainingDeviceCredits: deviceCredits,
          remainingPurchasedCredits: purchasedCredits,
          remainingCredits: purchasedCredits + deviceCredits,
        });
      }

      return {
        success: true,
        remainingDeviceCredits: deviceCredits,
        remainingPurchasedCredits: purchasedCredits,
        remainingCredits: purchasedCredits + deviceCredits,
      };
    });

    console.log(`✅ Credits consumed: deviceId=${trimmedDeviceId}, amount=${amount}`);
    return result;

  } catch (error: any) {
    console.error('❌ Error consuming credits:', error);
    if (error instanceof HttpsError) { throw error; }
    throw new HttpsError('internal', 'Kredi düşülürken hata oluştu');
  }
});
