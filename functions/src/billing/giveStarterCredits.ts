import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from 'firebase-admin';

interface StarterCreditsData {
    deviceId: string;
}

export const giveStarterCredits = onCall<StarterCreditsData>(async (request) => {

    const { deviceId } = request.data;

    // NOTE: Starter bonus is device-based and must not require Google sign-in.
    // However, we still require Firebase Auth (anonymous is OK) to reduce abuse
    // and to keep behavior consistent across clients.
    const auth = request.auth;
    const userId = auth?.uid ?? null;
    if (!userId) {
        logger.warn('giveStarterCredits: unauthenticated call');
        throw new HttpsError('unauthenticated', 'Auth is required.');
    }

    // 1. Validasyon: Device ID zorunlu
    if (!deviceId) {
        logger.warn('giveStarterCredits: missing deviceId', { uid: userId });
        throw new HttpsError(
            'invalid-argument',
            'Device ID is required.'
        );
    }

    const deviceIdSuffix = deviceId.length >= 6 ? deviceId.slice(-6) : deviceId;
    logger.info('giveStarterCredits: called', {
        uid: userId,
        deviceIdLen: deviceId.length,
        deviceIdSuffix,
    });

    const db = admin.firestore();
    const deviceBonusRef = db.collection('device_bonuses').doc(deviceId);
    const userRef = db.collection('users').doc(userId);

    let deviceBonusExisted = false;
    let grantedNow = false;

    // Transaction kullanarak veri bütünlüğünü sağlıyoruz (Atomik işlem)
    try {
        const payload = await db.runTransaction(async (transaction) => {
                // IMPORTANT: In Firestore transactions, all reads must happen before any writes.
                const deviceBonusDoc = await transaction.get(deviceBonusRef);
                const userDoc = await transaction.get(userRef);

                deviceBonusExisted = deviceBonusDoc.exists;

                const bonusAmount = 5;

                // Existing schema variants:
                // - legacy: { deviceId, userId, timestamp }
                // - legacy v2: { bonusCredits: 5 }
                // - new: { deviceCredits: <remaining> }
                const existingData = deviceBonusDoc.exists ? (deviceBonusDoc.data() ?? {}) : {};
                const legacyBonus = Number(existingData.bonusCredits ?? 0);
                let deviceCredits = Number(existingData.deviceCredits ?? 0);

                                const hasTrackingFields =
                                    Object.prototype.hasOwnProperty.call(existingData, 'deviceCredits') ||
                                    Object.prototype.hasOwnProperty.call(existingData, 'bonusCredits') ||
                                    Object.prototype.hasOwnProperty.call(existingData, 'totalBonusConsumed');

                                // Legacy marker migration: old docs may exist without any tracking fields
                                // (only deviceId/userId/timestamp). Treat them as "bonus granted" but
                                // initialize remaining bonus to full amount once so users don't lose credits
                                // on schema change. Lifetime cap is still enforced by totalBonusConsumed.
                                if (deviceBonusDoc.exists && !hasTrackingFields) {
                                    deviceCredits = bonusAmount;
                                }

                // Track total bonus consumption per device to prevent any form of top-up.
                let totalBonusConsumed = Number(existingData.totalBonusConsumed ?? NaN);
                if (!Number.isFinite(totalBonusConsumed) || totalBonusConsumed < 0) {
                                    if (deviceBonusDoc.exists && !hasTrackingFields) {
                                        totalBonusConsumed = 0;
                                    } else {
                                        // Infer best-effort from remaining deviceCredits.
                                        const inferredRemaining = Number.isFinite(deviceCredits) ? deviceCredits : 0;
                                        const clampedRemaining = Math.max(0, Math.min(bonusAmount, inferredRemaining));
                                        totalBonusConsumed = Math.max(0, bonusAmount - clampedRemaining);
                                    }
                }

                // If we have an old doc but no deviceCredits field, seed it from legacy bonus.
                if (deviceBonusDoc.exists && (!Number.isFinite(deviceCredits) || deviceCredits <= 0)) {
                    if (Number.isFinite(legacyBonus) && legacyBonus > 0) {
                        deviceCredits = legacyBonus;
                    } else {
                        deviceCredits = 0;
                    }
                }

                // Clamp to remaining allowed bonus (bonusAmount - totalBonusConsumed)
                const remainingAllowed = Math.max(0, bonusAmount - totalBonusConsumed);
                if (!Number.isFinite(deviceCredits) || deviceCredits < 0) deviceCredits = 0;
                deviceCredits = Math.min(deviceCredits, remainingAllowed);

                const canGiveBonus = !deviceBonusDoc.exists;
                if (canGiveBonus) {
                    grantedNow = true;
                    deviceCredits = bonusAmount;
                    totalBonusConsumed = 0;
                }

                // Purchased credits read (done before any writes).
                let purchasedCredits: number | null = 0;
                if (userDoc.exists) {
                    const userData = userDoc.data() ?? {};
                    const raw = userData.purchasedCredits ?? userData.credits ?? 0;
                    purchasedCredits = Number.isFinite(Number(raw)) ? Number(raw) : 0;
                }

                // Write after all reads are complete.
                transaction.set(
                    deviceBonusRef,
                    {
                        deviceId,
                        deviceCredits,
                        bonusGranted: true,
                        bonusAmount,
                        totalBonusConsumed,
                        createdAt: deviceBonusDoc.exists
                            ? (existingData.createdAt ?? admin.firestore.FieldValue.serverTimestamp())
                            : admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        lastUserId: userId,
                    },
                    { merge: true },
                );

                // Unified credit history (preferred by UI)
                // Only write when starter credits are granted now.
                if (canGiveBonus) {
                    const suffix = deviceId.length >= 6 ? deviceId.slice(-6) : deviceId;
                    const txRef = userRef.collection('credit_transactions').doc(`starter_${deviceId}`);
                    transaction.set(txRef, {
                        type: 'add',
                        amount: bonusAmount,
                        timestamp: admin.firestore.FieldValue.serverTimestamp(),
                        source: 'starter',
                        deviceIdSuffix: suffix,
                    }, { merge: true });
                }

                const totalCredits = (purchasedCredits ?? 0) + deviceCredits;
                return {
                    success: true,
                    message: canGiveBonus
                        ? 'Başlangıç kredisi verildi.'
                        : 'Cihaz kredisi hazır.',
                    deviceCredits,
                    purchasedCredits,
                    totalCredits,
                    bonusAmount: canGiveBonus ? bonusAmount : 0,
                };
        });

        logger.info('giveStarterCredits: success', {
            uid: userId,
            deviceIdSuffix,
            deviceBonusExisted,
            grantedNow,
            deviceCredits: payload.deviceCredits,
            purchasedCredits: payload.purchasedCredits,
            totalCredits: payload.totalCredits,
            bonusAmount: payload.bonusAmount,
        });

        return payload;
    } catch (e) {
        logger.error('giveStarterCredits: failed', {
            uid: userId,
            deviceIdSuffix,
            deviceBonusExisted,
            grantedNow,
            error: e instanceof Error ? e.message : String(e),
        });
        throw e;
    }
});
