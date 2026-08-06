import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';

const STARTER_BONUS = 5;

export type AuthLike = {
    uid?: string | null;
    token?: {
        email?: unknown;
    };
} | null | undefined;

export type CreditSummary = {
    deviceCredits: number;
    purchasedCredits: number;
    totalCredits: number;
    accessActive: boolean;
    platform: string;
    deviceId: string;
};

type CreditSummaryArgs = {
    db: admin.firestore.Firestore;
    uid?: string | null;
    deviceId?: string | null;
    platform?: string | null;
};

type ConsumeCreditArgs = {
    db: admin.firestore.Firestore;
    amount: number;
    deviceId: string;
    uid?: string | null;
    email?: string | null;
    reason?: string;
    chargeKey?: string;
    fileName?: string;
    targetLanguage?: string;
    platform?: string;
    appVersion?: string | null;
    allowAutoApproveSession?: boolean;
};

export function normalizePlatform(platform?: string | null): string {
    const value = (platform ?? '').trim().toLowerCase();
    return value.length === 0 ? 'unknown' : value;
}

export function getAuthEmail(auth?: AuthLike): string | null {
    const raw = auth?.token?.email;
    if (typeof raw !== 'string') return null;
    const trimmed = raw.trim().toLowerCase();
    return trimmed.length === 0 ? null : trimmed;
}

export function requireDeviceId(deviceId?: string | null): string {
    const trimmed = (deviceId ?? '').trim();
    if (!trimmed) {
        throw new HttpsError('permission-denied', 'Device verification failed.');
    }
    return trimmed;
}

export async function loadCreditSummary({ db, uid, deviceId, platform }: CreditSummaryArgs): Promise<CreditSummary> {
    const normalizedPlatform = normalizePlatform(platform);
    const trimmedDeviceId = (deviceId ?? '').trim();
    const deviceBonusRef = trimmedDeviceId
        ? db.collection('device_bonuses').doc(trimmedDeviceId)
        : null;
    const deviceBonusDoc = deviceBonusRef ? await deviceBonusRef.get() : null;

    const existingDeviceData = deviceBonusDoc?.exists ? (deviceBonusDoc.data() ?? {}) : {};
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
    if (deviceBonusDoc?.exists && !hasTrackingFields) {
        deviceCreditsRaw = STARTER_BONUS;
    }

    let totalBonusConsumed = Number(existingDeviceData.totalBonusConsumed ?? Number.NaN);
    if (!Number.isFinite(totalBonusConsumed) || totalBonusConsumed < 0) {
        if (deviceBonusDoc?.exists && !hasTrackingFields) {
            totalBonusConsumed = 0;
        } else {
            const clampedRemaining = Math.max(0, Math.min(STARTER_BONUS, deviceCreditsRaw));
            totalBonusConsumed = Math.max(0, STARTER_BONUS - clampedRemaining);
        }
    }

    const remainingBonusAllowed = Math.max(0, STARTER_BONUS - totalBonusConsumed);
    const deviceCredits = Math.min(Math.max(0, deviceCreditsRaw), remainingBonusAllowed);

    let purchasedCredits = 0;
    if (uid) {
        const userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) {
            const userData = userDoc.data() ?? {};
            const purchasedA = Number.isFinite(Number(userData.purchasedCredits)) ? Number(userData.purchasedCredits) : 0;
            const purchasedB = Number.isFinite(Number(userData.credits)) ? Number(userData.credits) : 0;
            purchasedCredits = Math.max(purchasedA, purchasedB);
        }
    }

    const accessRaw = existingDeviceData.accessExpiresAt;
    const accessActive = accessRaw instanceof admin.firestore.Timestamp
        ? accessRaw.toMillis() > Date.now()
        : false;

    return {
        deviceCredits,
        purchasedCredits,
        totalCredits: deviceCredits + purchasedCredits,
        accessActive,
        platform: normalizedPlatform,
        deviceId: trimmedDeviceId,
    };
}

export async function assertCreditsAvailable(args: CreditSummaryArgs): Promise<CreditSummary> {
    const summary = await loadCreditSummary(args);
    if (summary.totalCredits <= 0 && !summary.accessActive) {
        throw new HttpsError('failed-precondition', 'INSUFFICIENT_CREDIT');
    }
    return summary;
}

export async function consumeCreditInternal({
    db,
    amount,
    deviceId,
    uid,
    email,
    reason,
    chargeKey,
    fileName,
    targetLanguage,
    platform,
    appVersion,
    allowAutoApproveSession = false,
}: ConsumeCreditArgs) {
    const reasonText = (reason ?? 'usage').trim();
    const fileNameText = (fileName ?? '').trim();
    const targetLanguageText = (targetLanguage ?? '').trim();
    const platformText = normalizePlatform(platform);
    const trimmedDeviceId = requireDeviceId(deviceId);
    const trimmedChargeKey = (chargeKey ?? '').trim();

    if (!amount || amount <= 0) {
        throw new HttpsError('invalid-argument', 'Geçersiz kredi miktarı');
    }
    if (trimmedChargeKey.includes('/')) {
        throw new HttpsError('invalid-argument', 'Invalid chargeKey');
    }

    return db.runTransaction(async (transaction) => {
        const deviceBonusRef = db.collection('device_bonuses').doc(trimmedDeviceId);
        const deviceBonusDoc = await transaction.get(deviceBonusRef);
        const chargeRef = trimmedChargeKey
            ? deviceBonusRef.collection('credit_charges').doc(trimmedChargeKey)
            : null;
        const sessionRef = trimmedChargeKey
            ? deviceBonusRef.collection('translation_sessions').doc(trimmedChargeKey)
            : null;

        const existingDeviceData = deviceBonusDoc.exists ? (deviceBonusDoc.data() ?? {}) : {};
        const legacyBonus = Number(existingDeviceData.bonusCredits ?? 0);
        const hasTrackingFields =
            Object.prototype.hasOwnProperty.call(existingDeviceData, 'deviceCredits') ||
            Object.prototype.hasOwnProperty.call(existingDeviceData, 'bonusCredits') ||
            Object.prototype.hasOwnProperty.call(existingDeviceData, 'totalBonusConsumed');
        let deviceCreditsRaw = Number(existingDeviceData.deviceCredits ?? 0);
        if (!Number.isFinite(deviceCreditsRaw) || deviceCreditsRaw < 0) deviceCreditsRaw = 0;
        if (deviceCreditsRaw === 0 && Number.isFinite(legacyBonus) && legacyBonus > 0) {
            deviceCreditsRaw = legacyBonus;
        }
        if (deviceBonusDoc.exists && !hasTrackingFields) {
            deviceCreditsRaw = STARTER_BONUS;
        }

        let totalBonusConsumed = Number(existingDeviceData.totalBonusConsumed ?? Number.NaN);
        if (!Number.isFinite(totalBonusConsumed) || totalBonusConsumed < 0) {
            if (deviceBonusDoc.exists && !hasTrackingFields) {
                totalBonusConsumed = 0;
            } else {
                const clampedRemaining = Math.max(0, Math.min(STARTER_BONUS, deviceCreditsRaw));
                totalBonusConsumed = Math.max(0, STARTER_BONUS - clampedRemaining);
            }
        }

        const remainingBonusAllowed = Math.max(0, STARTER_BONUS - totalBonusConsumed);
        let deviceCredits = Math.min(Math.max(0, deviceCreditsRaw), remainingBonusAllowed);

        let purchasedCredits = 0;
        let userRef: FirebaseFirestore.DocumentReference | null = null;
        if (uid) {
            userRef = db.collection('users').doc(uid);
            const userDoc = await transaction.get(userRef);
            if (userDoc.exists) {
                const userData = userDoc.data() ?? {};
                const purchasedA = Number.isFinite(Number(userData.purchasedCredits)) ? Number(userData.purchasedCredits) : 0;
                const purchasedB = Number.isFinite(Number(userData.credits)) ? Number(userData.credits) : 0;
                purchasedCredits = Math.max(purchasedA, purchasedB);
            }
        }

        if (sessionRef) {
            const sessionDoc = await transaction.get(sessionRef);
            const sessionData = sessionDoc.data() ?? {};

            if (allowAutoApproveSession) {
                if (!sessionDoc.exists) {
                    throw new HttpsError('failed-precondition', 'Translation session not prepared.');
                }
                if ((sessionData.uid ?? uid ?? null) !== (uid ?? null)) {
                    throw new HttpsError('permission-denied', 'Translation session mismatch.');
                }
            } else {
                const approved = sessionDoc.exists && sessionData.approved === true;
                const requiresFirstChunkApproval = reasonText !== 'cache_hit';
                if (requiresFirstChunkApproval && !approved) {
                    throw new HttpsError('failed-precondition', 'First chunk not approved by server yet.');
                }
            }
        }

        if (chargeRef) {
            const chargeDoc = await transaction.get(chargeRef);
            if (chargeDoc.exists) {
                const existing = chargeDoc.data() ?? {};
                const remainingDeviceCreditsRaw = Number(existing.remainingDeviceCredits);
                const remainingPurchasedCreditsRaw = Number(existing.remainingPurchasedCredits);
                const remainingCreditsRaw = Number(existing.remainingCredits);

                const remainingDeviceCredits = Number.isFinite(remainingDeviceCreditsRaw)
                    ? Math.max(0, remainingDeviceCreditsRaw)
                    : deviceCredits;
                const remainingPurchasedCredits = Number.isFinite(remainingPurchasedCreditsRaw)
                    ? Math.max(0, remainingPurchasedCreditsRaw)
                    : purchasedCredits;
                const remainingCredits = Number.isFinite(remainingCreditsRaw)
                    ? Math.max(0, remainingCreditsRaw)
                    : (remainingDeviceCredits + remainingPurchasedCredits);

                return {
                    success: true,
                    idempotentReplay: true,
                    remainingDeviceCredits,
                    remainingPurchasedCredits,
                    remainingCredits,
                };
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

        const accessExpiry = admin.firestore.Timestamp.fromMillis(Date.now() + (3 * 60 * 60 * 1000));

        transaction.set(deviceBonusRef, {
            deviceId: trimmedDeviceId,
            deviceCredits,
            bonusAmount: STARTER_BONUS,
            totalBonusConsumed,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            accessExpiresAt: accessExpiry,
            lastUserId: uid ?? null,
            lastUserEmail: email ?? null,
        }, { merge: true });

        if (userRef && uid) {
            transaction.set(userRef, {
                purchasedCredits,
                credits: purchasedCredits,
                lastCreditConsumption: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });

            transaction.set(db.collection('google_users').doc(uid), {
                purchasedCredits,
                credits: purchasedCredits,
                lastCreditConsumption: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });

            const usageRef = userRef.collection('credit_usage').doc();
            transaction.set(usageRef, {
                amount,
                reason: reasonText || 'unknown',
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                deviceId: trimmedDeviceId,
                email: email ?? null,
                fromDevice,
                fromPurchased,
                remainingDeviceCredits: deviceCredits,
                remainingPurchasedCredits: purchasedCredits,
                remainingCredits: purchasedCredits + deviceCredits,
            });

            transaction.set(userRef.collection('credit_transactions').doc(usageRef.id), {
                type: 'spend',
                amount,
                reason: reasonText || 'unknown',
                chargeKey: trimmedChargeKey || null,
                fileName: fileNameText || null,
                targetLanguage: targetLanguageText || null,
                platform: platformText || null,
                email: email ?? null,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        if (sessionRef) {
            const sessionPayload: Record<string, unknown> = {
                chargeKey: trimmedChargeKey,
                uid: uid ?? null,
                email: email ?? null,
                deviceId: trimmedDeviceId,
                fileName: fileNameText || null,
                targetLanguage: targetLanguageText || null,
                platform: platformText || null,
                charged: true,
                chargedAt: admin.firestore.FieldValue.serverTimestamp(),
                lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (allowAutoApproveSession) {
                sessionPayload.approved = true;
                sessionPayload.approvedAt = admin.firestore.FieldValue.serverTimestamp();
            }
            transaction.set(sessionRef, {
                ...sessionPayload,
            }, { merge: true });
        }

        if (chargeRef) {
            transaction.set(chargeRef, {
                chargeKey: trimmedChargeKey,
                amount,
                reason: reasonText || 'unknown',
                deviceId: trimmedDeviceId,
                uid: uid ?? null,
                email: email ?? null,
                remainingDeviceCredits: deviceCredits,
                remainingPurchasedCredits: purchasedCredits,
                remainingCredits: purchasedCredits + deviceCredits,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }

        return {
            success: true,
            remainingDeviceCredits: deviceCredits,
            remainingPurchasedCredits: purchasedCredits,
            remainingCredits: purchasedCredits + deviceCredits,
        };
    });
}