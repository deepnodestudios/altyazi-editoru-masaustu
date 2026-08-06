import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';

import {
    shouldUseV160ClientRules,
    shouldUseV163AdRewardRules,
    shouldUseV169DeviceAdRewardRules,
} from '../referral/referralUtils';

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
    adRewardCredits: number;
    freeCredits: number;
    googleLoginCredits: number;
    totalCredits: number;
    accessActive: boolean;
    isPaidUser: boolean;
    hasPaidCredits: boolean;
    platform: string;
    deviceId: string;
};

export type CreditUsagePlan = {
    fromPurchased: number;
    fromAdReward: number;
    fromFree: number;
    fromGoogleLogin: number;
    fromDevice: number;
};

type PredictCreditUsageArgs = {
    amount: number;
    purchasedCredits: number;
    adRewardCredits: number;
    freeCredits: number;
    googleLoginCredits: number;
    deviceCredits: number;
    isModernClient: boolean;
    preferFreeCreditsFirst?: boolean;
};

type CreditSummaryArgs = {
    db: admin.firestore.Firestore;
    uid?: string | null;
    deviceId?: string | null;
    platform?: string | null;
    appVersion?: string | null;
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
    preferFreeCreditsFirst?: boolean;
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

function clampNonNegativeInt(value: unknown): number {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed <= 0) {
        return 0;
    }
    return Math.floor(parsed);
}

export function predictCreditUsage({
    amount,
    purchasedCredits,
    adRewardCredits,
    freeCredits,
    googleLoginCredits,
    deviceCredits,
    isModernClient,
    preferFreeCreditsFirst,
}: PredictCreditUsageArgs): CreditUsagePlan {
    let remaining = clampNonNegativeInt(amount);
    let fromPurchased = 0;
    let fromAdReward = 0;
    let fromFree = 0;
    let fromGoogleLogin = 0;
    let fromDevice = 0;

    if (remaining <= 0) {
        return {
            fromPurchased,
            fromAdReward,
            fromFree,
            fromGoogleLogin,
            fromDevice,
        };
    }

    const safePurchasedCredits = clampNonNegativeInt(purchasedCredits);
    const safeAdRewardCredits = clampNonNegativeInt(adRewardCredits);
    const safeFreeCredits = clampNonNegativeInt(freeCredits);
    const safeGoogleLoginCredits = clampNonNegativeInt(googleLoginCredits);
    const safeDeviceCredits = clampNonNegativeInt(deviceCredits);

    if (!isModernClient) {
        fromDevice = Math.min(safeDeviceCredits, remaining);
        remaining -= fromDevice;
        fromPurchased = Math.min(safePurchasedCredits, remaining);
        return {
            fromPurchased,
            fromAdReward,
            fromFree,
            fromGoogleLogin,
            fromDevice,
        };
    }

    if (preferFreeCreditsFirst === true) {
        fromAdReward = Math.min(safeAdRewardCredits, remaining);
        remaining -= fromAdReward;
        fromFree = Math.min(safeFreeCredits, remaining);
        remaining -= fromFree;
        fromGoogleLogin = Math.min(safeGoogleLoginCredits, remaining);
        remaining -= fromGoogleLogin;
        fromDevice = Math.min(safeDeviceCredits, remaining);
        remaining -= fromDevice;
        fromPurchased = Math.min(safePurchasedCredits, remaining);
    } else {
        fromPurchased = Math.min(safePurchasedCredits, remaining);
        remaining -= fromPurchased;
        fromAdReward = Math.min(safeAdRewardCredits, remaining);
        remaining -= fromAdReward;
        fromFree = Math.min(safeFreeCredits, remaining);
        remaining -= fromFree;
        fromGoogleLogin = Math.min(safeGoogleLoginCredits, remaining);
        remaining -= fromGoogleLogin;
        fromDevice = Math.min(safeDeviceCredits, remaining);
    }

    return {
        fromPurchased,
        fromAdReward,
        fromFree,
        fromGoogleLogin,
        fromDevice,
    };
}

function normalizePurchasedCreditBuckets(userData: Record<string, unknown>): {
    purchasedCredits: number;
    subscriptionPurchasedCredits: number;
    extraPurchasedCredits: number;
} {
    const purchasedA = Number.isFinite(Number(userData.purchasedCredits)) ? Number(userData.purchasedCredits) : 0;
    const purchasedB = Number.isFinite(Number(userData.credits)) ? Number(userData.credits) : 0;
    const purchasedCredits = Math.max(purchasedA, purchasedB);

    const subscriptionRaw = Number(userData.subscriptionPurchasedCredits ?? Number.NaN);
    const subscriptionPurchasedCredits = Number.isFinite(subscriptionRaw) && subscriptionRaw >= 0
        ? Math.min(subscriptionRaw, purchasedCredits)
        : 0;

    const extraRaw = Number(userData.extraPurchasedCredits ?? Number.NaN);
    let extraPurchasedCredits = Number.isFinite(extraRaw) && extraRaw >= 0
        ? Math.min(extraRaw, Math.max(0, purchasedCredits - subscriptionPurchasedCredits))
        : 0;

    const assignedPurchasedCredits = subscriptionPurchasedCredits + extraPurchasedCredits;
    if (assignedPurchasedCredits < purchasedCredits) {
        extraPurchasedCredits += purchasedCredits - assignedPurchasedCredits;
    }

    return {
        purchasedCredits,
        subscriptionPurchasedCredits,
        extraPurchasedCredits,
    };
}

export function requireDeviceId(deviceId?: string | null): string {
    const trimmed = (deviceId ?? '').trim();
    if (!trimmed) {
        throw new HttpsError('permission-denied', 'Device verification failed.');
    }
    return trimmed;
}

export async function loadCreditSummary({ db, uid, deviceId, platform, appVersion }: CreditSummaryArgs): Promise<CreditSummary> {
    const normalizedPlatform = normalizePlatform(platform);
    const isModernClient = shouldUseV160ClientRules({
        appVersion,
        platform: normalizedPlatform,
    });
    const isAdRewardClient = shouldUseV163AdRewardRules({
        appVersion,
        platform: normalizedPlatform,
    });
    const useDeviceAdRewardRules = shouldUseV169DeviceAdRewardRules({
        appVersion,
        platform: normalizedPlatform,
    });
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
    let adRewardCredits = 0;
    let freeCredits = 0;
    let googleLoginCredits = 0;
    let isPaidUser = false;
    if (uid) {
        const userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) {
            const userData = userDoc.data() ?? {};
            const purchasedA = Number.isFinite(Number(userData.purchasedCredits)) ? Number(userData.purchasedCredits) : 0;
            const purchasedB = Number.isFinite(Number(userData.credits)) ? Number(userData.credits) : 0;
            purchasedCredits = Math.max(purchasedA, purchasedB);
            if (!useDeviceAdRewardRules) {
                adRewardCredits = isAdRewardClient ? clampNonNegativeInt(userData.adRewardCredits) : 0;
            }
            freeCredits = Number.isFinite(Number(userData.freeCredits)) ? Number(userData.freeCredits) : 0;
            googleLoginCredits = Number.isFinite(Number(userData.googleLoginCredits)) ? Number(userData.googleLoginCredits) : 0;
            isPaidUser = userData.subscriptionActive === true || userData.isPaidUser === true;
        }
    }

    if (useDeviceAdRewardRules) {
        adRewardCredits = clampNonNegativeInt(existingDeviceData.adRewardCredits);
    }

    const accessRaw = existingDeviceData.accessExpiresAt;
    const accessActive = accessRaw instanceof admin.firestore.Timestamp
        ? accessRaw.toMillis() > Date.now()
        : false;

    const effectiveFreeCredits = isModernClient ? freeCredits : 0;
    const effectiveGoogleLoginCredits = isModernClient ? googleLoginCredits : 0;
    const effectiveAdRewardCredits = isAdRewardClient ? adRewardCredits : 0;
    return {
        deviceCredits,
        purchasedCredits,
        adRewardCredits: effectiveAdRewardCredits,
        freeCredits: effectiveFreeCredits,
        googleLoginCredits: effectiveGoogleLoginCredits,
        totalCredits: deviceCredits + purchasedCredits + effectiveAdRewardCredits + effectiveFreeCredits + effectiveGoogleLoginCredits,
        accessActive,
        isPaidUser,
        hasPaidCredits: isPaidUser || purchasedCredits > 0,
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
    preferFreeCreditsFirst,
    allowAutoApproveSession = false,
}: ConsumeCreditArgs) {
    const reasonText = (reason ?? 'usage').trim();
    const fileNameText = (fileName ?? '').trim();
    const targetLanguageText = (targetLanguage ?? '').trim();
    const platformText = normalizePlatform(platform);
    const isModernClient = shouldUseV160ClientRules({
        appVersion,
        platform: platformText,
    });
    const isAdRewardClient = shouldUseV163AdRewardRules({
        appVersion,
        platform: platformText,
    });
    const useDeviceAdRewardRules = shouldUseV169DeviceAdRewardRules({
        appVersion,
        platform: platformText,
    });
    const trimmedDeviceId = requireDeviceId(deviceId);
    const trimmedChargeKey = (chargeKey ?? '').trim();

    if (!amount || amount <= 0) {
        throw new HttpsError('invalid-argument', 'Ge�ersiz kredi miktar�');
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
        let subscriptionPurchasedCredits = 0;
        let extraPurchasedCredits = 0;
        let adRewardCredits = 0;
        let freeCredits = 0;
        let googleLoginCredits = 0;
        let userRef: FirebaseFirestore.DocumentReference | null = null;
        if (uid) {
            userRef = db.collection('users').doc(uid);
            const userDoc = await transaction.get(userRef);
            if (userDoc.exists) {
                const userData = userDoc.data() ?? {};
                const normalizedBuckets = normalizePurchasedCreditBuckets(userData);
                purchasedCredits = normalizedBuckets.purchasedCredits;
                subscriptionPurchasedCredits = normalizedBuckets.subscriptionPurchasedCredits;
                extraPurchasedCredits = normalizedBuckets.extraPurchasedCredits;
                if (!useDeviceAdRewardRules) {
                    adRewardCredits = isAdRewardClient ? clampNonNegativeInt(userData.adRewardCredits) : 0;
                }
                freeCredits = Number.isFinite(Number(userData.freeCredits)) ? Number(userData.freeCredits) : 0;
                googleLoginCredits = Number.isFinite(Number(userData.googleLoginCredits)) ? Number(userData.googleLoginCredits) : 0;
            }
        }

        if (useDeviceAdRewardRules) {
            adRewardCredits = clampNonNegativeInt(existingDeviceData.adRewardCredits);
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
                const remainingFreeCreditsRaw = Number(existing.remainingFreeCredits);
                const remainingFreeCredits = Number.isFinite(remainingFreeCreditsRaw)
                    ? Math.max(0, remainingFreeCreditsRaw)
                    : freeCredits;
                const remainingAdRewardCreditsRaw = Number(existing.remainingAdRewardCredits);
                const remainingAdRewardCredits = Number.isFinite(remainingAdRewardCreditsRaw)
                    ? Math.max(0, remainingAdRewardCreditsRaw)
                    : adRewardCredits;
                const remainingGoogleLoginCreditsRaw = Number(existing.remainingGoogleLoginCredits);
                const remainingGoogleLoginCredits = Number.isFinite(remainingGoogleLoginCreditsRaw)
                    ? Math.max(0, remainingGoogleLoginCreditsRaw)
                    : googleLoginCredits;
                const remainingCredits = Number.isFinite(remainingCreditsRaw)
                    ? Math.max(0, remainingCreditsRaw)
                    : (remainingDeviceCredits + remainingPurchasedCredits + (isModernClient ? (remainingAdRewardCredits + remainingFreeCredits + remainingGoogleLoginCredits) : 0));

                return {
                    success: true,
                    idempotentReplay: true,
                    remainingDeviceCredits,
                    remainingPurchasedCredits,
                    remainingAdRewardCredits,
                    remainingFreeCredits,
                    remainingGoogleLoginCredits,
                    remainingCredits,
                };
            }
        }

        const currentTotal = deviceCredits + purchasedCredits + (isModernClient ? (adRewardCredits + freeCredits + googleLoginCredits) : 0);
        if (currentTotal < amount) {
            throw new HttpsError(
                'failed-precondition',
                `Yetersiz kredi. Mevcut: ${currentTotal}, Gerekli: ${amount}`
            );
        }

        const usagePlan = predictCreditUsage({
            amount,
            purchasedCredits,
            adRewardCredits,
            freeCredits,
            googleLoginCredits,
            deviceCredits,
            isModernClient,
            preferFreeCreditsFirst,
        });
        const {
            fromPurchased,
            fromAdReward,
            fromFree,
            fromGoogleLogin,
            fromDevice,
        } = usagePlan;

        deviceCredits -= fromDevice;
        totalBonusConsumed += fromDevice;
        const fromSubscriptionPurchased = Math.min(subscriptionPurchasedCredits, fromPurchased);
        const fromExtraPurchased = fromPurchased - fromSubscriptionPurchased;
        subscriptionPurchasedCredits -= fromSubscriptionPurchased;
        if (subscriptionPurchasedCredits < 0) subscriptionPurchasedCredits = 0;
        extraPurchasedCredits -= fromExtraPurchased;
        if (extraPurchasedCredits < 0) extraPurchasedCredits = 0;
        purchasedCredits = subscriptionPurchasedCredits + extraPurchasedCredits;
        adRewardCredits -= fromAdReward;
        if (adRewardCredits < 0) adRewardCredits = 0;
        freeCredits -= fromFree;
        if (freeCredits < 0) freeCredits = 0;
        googleLoginCredits -= fromGoogleLogin;
        if (googleLoginCredits < 0) googleLoginCredits = 0;

        const accessExpiry = admin.firestore.Timestamp.fromMillis(Date.now() + (3 * 60 * 60 * 1000));

        const deviceBonusUpdateData: Record<string, any> = {
            deviceId: trimmedDeviceId,
            deviceCredits,
            bonusAmount: STARTER_BONUS,
            totalBonusConsumed,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            accessExpiresAt: accessExpiry,
            lastUserId: uid ?? null,
            lastUserEmail: email ?? null,
        };
        if (useDeviceAdRewardRules) {
            deviceBonusUpdateData.adRewardCredits = adRewardCredits;
        }
        transaction.set(deviceBonusRef, deviceBonusUpdateData, { merge: true });

        if (userRef && uid) {
            const userUpdateData: Record<string, any> = {
                purchasedCredits,
                credits: purchasedCredits,
                subscriptionPurchasedCredits,
                extraPurchasedCredits,
                freeCredits,
                googleLoginCredits,
                lastCreditConsumption: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (!useDeviceAdRewardRules) {
                userUpdateData.adRewardCredits = adRewardCredits;
            }
            transaction.set(userRef, userUpdateData, { merge: true });

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
                fromAdReward,
                fromFree,
                fromGoogleLogin,
                remainingDeviceCredits: deviceCredits,
                remainingPurchasedCredits: purchasedCredits,
                remainingAdRewardCredits: adRewardCredits,
                remainingFreeCredits: freeCredits,
                remainingGoogleLoginCredits: googleLoginCredits,
                remainingCredits: purchasedCredits + deviceCredits + (isModernClient ? (adRewardCredits + freeCredits + googleLoginCredits) : 0),
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
                creditBucket: fromPurchased > 0 ? 'paid' : (fromAdReward > 0 ? 'ad_reward' : 'free'),
                fromSubscriptionPurchased,
                fromExtraPurchased,
                fromAdReward,
                fromFree,
                fromGoogleLogin,
                fromDevice,
                remainingAdRewardCredits: adRewardCredits,
                remainingFreeCredits: freeCredits,
                remainingGoogleLoginCredits: googleLoginCredits,
                remainingPurchasedCredits: purchasedCredits,
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
                remainingAdRewardCredits: adRewardCredits,
                remainingFreeCredits: freeCredits,
                remainingGoogleLoginCredits: googleLoginCredits,
                remainingCredits: purchasedCredits + deviceCredits + (isModernClient ? (adRewardCredits + freeCredits + googleLoginCredits) : 0),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }

        return {
            success: true,
            remainingDeviceCredits: deviceCredits,
            remainingPurchasedCredits: purchasedCredits,
            remainingAdRewardCredits: adRewardCredits,
            remainingFreeCredits: freeCredits,
            remainingGoogleLoginCredits: googleLoginCredits,
            remainingCredits: purchasedCredits + deviceCredits + (isModernClient ? (adRewardCredits + freeCredits + googleLoginCredits) : 0),
        };
    });
}
