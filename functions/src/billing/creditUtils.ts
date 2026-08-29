import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';

import {
    shouldEnforceDesktopPaidCreditsOnly,
    shouldUseV160ClientRules,
    shouldUseV163AdRewardRules,
    shouldUseV169DeviceAdRewardRules,
} from '../referral/referralUtils';
import {
    hydrateTokenWallet,
    maybeRebalancePackBonusGrant,
    maybeSplitCombinedPackHistory,
    planTokenWalletCharge,
    shouldUseTokenWallet,
    spendableTokenBalance,
    tokenWalletDeviceFields,
    tokenWalletUserFields,
    type TokenChargeMode,
} from './tokenWallet';

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
    usesTokenWallet: boolean;
    tokenBalance: number;
    tokenGrantBalance: number;
    legacyFlatRateRemaining: number;
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
    platform?: string | null;
    appVersion?: string | null;
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
    charCount?: number | null;
    estimatedTokens?: number | null;
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
    platform,
    appVersion,
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

    // Desktop paid-only spend from v1.7.4+ (older desktop builds keep legacy behavior).
    if (shouldEnforceDesktopPaidCreditsOnly({ platform, appVersion })) {
        fromPurchased = Math.min(safePurchasedCredits, remaining);
        return {
            fromPurchased,
            fromAdReward: 0,
            fromFree: 0,
            fromGoogleLogin: 0,
            fromDevice: 0,
        };
    }
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
    let userData: Record<string, unknown> = {};
    if (uid) {
        const userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) {
            userData = userDoc.data() ?? {};
            if (shouldUseTokenWallet({
                appVersion,
                platform: normalizedPlatform,
            })) {
                userData = await maybeRebalancePackBonusGrant({
                    db,
                    uid,
                    userData,
                });
                userData = await maybeSplitCombinedPackHistory({
                    db,
                    uid,
                    userData,
                });
            }
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
    const paidCreditsOnly = shouldEnforceDesktopPaidCreditsOnly({
        appVersion,
        platform: normalizedPlatform,
    });
    const effectiveDeviceCredits = paidCreditsOnly ? 0 : deviceCredits;
    const spendableFreeCredits = paidCreditsOnly ? 0 : effectiveFreeCredits;
    const spendableGoogleLoginCredits = paidCreditsOnly ? 0 : effectiveGoogleLoginCredits;
    const spendableAdRewardCredits = paidCreditsOnly ? 0 : effectiveAdRewardCredits;
    const usesTokenWallet = shouldUseTokenWallet({
        appVersion,
        platform: normalizedPlatform,
    });
    const wallet = usesTokenWallet
        ? hydrateTokenWallet({
            userData,
            deviceData: existingDeviceData,
        })
        : null;
    const tokenBalance = wallet?.tokenBalance ?? 0;
    const tokenGrantBalance = wallet?.tokenGrantBalance ?? 0;
    const legacyFlatRateRemaining = wallet?.legacyFlatRateRemaining ?? 0;
    const spendableTokens = wallet
        ? spendableTokenBalance({
            state: wallet,
            platform: normalizedPlatform,
            appVersion,
        })
        : 0;
    const walletFileCredits = usesTokenWallet ? legacyFlatRateRemaining : purchasedCredits;
    const bonusFileCredits = 0;
    const creditUnitTotal = paidCreditsOnly
        ? purchasedCredits
        : effectiveDeviceCredits + purchasedCredits + spendableAdRewardCredits + spendableFreeCredits + spendableGoogleLoginCredits;
    const totalCredits = usesTokenWallet
        ? (legacyFlatRateRemaining + bonusFileCredits + (spendableTokens > 0 ? 1 : 0))
        : creditUnitTotal;

    return {
        deviceCredits: usesTokenWallet ? 0 : (paidCreditsOnly ? 0 : effectiveDeviceCredits),
        purchasedCredits: usesTokenWallet ? walletFileCredits : purchasedCredits,
        adRewardCredits: usesTokenWallet ? 0 : spendableAdRewardCredits,
        freeCredits: usesTokenWallet ? 0 : spendableFreeCredits,
        googleLoginCredits: usesTokenWallet ? 0 : spendableGoogleLoginCredits,
        totalCredits,
        accessActive,
        isPaidUser,
        hasPaidCredits: isPaidUser
            || walletFileCredits > 0
            || (usesTokenWallet && tokenBalance > tokenGrantBalance),
        platform: normalizedPlatform,
        deviceId: trimmedDeviceId,
        usesTokenWallet,
        tokenBalance,
        tokenGrantBalance,
        legacyFlatRateRemaining,
    };
}

export async function assertCreditsAvailable(args: CreditSummaryArgs): Promise<CreditSummary> {
    const summary = await loadCreditSummary(args);
    if (summary.usesTokenWallet) {
        const spendableTokens = spendableTokenBalance({
            state: {
                tokenBalance: summary.tokenBalance,
                tokenGrantBalance: summary.tokenGrantBalance,
            },
            platform: summary.platform,
            appVersion: args.appVersion,
        });
        const bonusFiles = summary.adRewardCredits
            + summary.freeCredits
            + summary.googleLoginCredits
            + summary.deviceCredits;
        if (
            summary.legacyFlatRateRemaining <= 0
            && bonusFiles <= 0
            && spendableTokens <= 0
            && !summary.accessActive
        ) {
            throw new HttpsError('failed-precondition', 'INSUFFICIENT_CREDIT');
        }
        return summary;
    }
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
    charCount,
    estimatedTokens,
}: ConsumeCreditArgs) {
    const reasonText = (reason ?? 'usage').trim();
    const fileNameText = (fileName ?? '').trim();
    const targetLanguageText = (targetLanguage ?? '').trim();
    const platformText = normalizePlatform(platform);
    const usesTokenWallet = shouldUseTokenWallet({
        appVersion,
        platform: platformText,
    });
    const paidCreditsOnly = shouldEnforceDesktopPaidCreditsOnly({
        appVersion,
        platform: platformText,
    });
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

    if (!usesTokenWallet && (!amount || amount <= 0)) {
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
        let subscriptionPurchasedCredits = 0;
        let extraPurchasedCredits = 0;
        let adRewardCredits = 0;
        let freeCredits = 0;
        let googleLoginCredits = 0;
        let userData: Record<string, unknown> = {};
        let userRef: FirebaseFirestore.DocumentReference | null = null;
        if (uid) {
            userRef = db.collection('users').doc(uid);
            const userDoc = await transaction.get(userRef);
            if (userDoc.exists) {
                userData = userDoc.data() ?? {};
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
                    remainingTokenBalance: Number.isFinite(Number(existing.remainingTokenBalance))
                        ? Math.max(0, Number(existing.remainingTokenBalance))
                        : 0,
                    remainingTokenGrantBalance: Number.isFinite(Number(existing.remainingTokenGrantBalance))
                        ? Math.max(0, Number(existing.remainingTokenGrantBalance))
                        : 0,
                    remainingLegacyFlatRateRemaining: Number.isFinite(Number(existing.remainingLegacyFlatRateRemaining))
                        ? Math.max(0, Number(existing.remainingLegacyFlatRateRemaining))
                        : remainingPurchasedCredits,
                    chargeMode: existing.chargeMode ?? 'credits',
                };
            }
        }

        const currentTotal = paidCreditsOnly
            ? purchasedCredits
            : deviceCredits + purchasedCredits + (isModernClient ? (adRewardCredits + freeCredits + googleLoginCredits) : 0);

        let fromPurchased = 0;
        let fromAdReward = 0;
        let fromFree = 0;
        let fromGoogleLogin = 0;
        let fromDevice = 0;
        let fromSubscriptionPurchased = 0;
        let fromExtraPurchased = 0;
        let chargedAmount = amount;
        let chargeMode: TokenChargeMode | 'credits' = 'credits';
        let fromPaidTokens = 0;
        let fromGrantTokens = 0;
        let remainingTokenBalance = 0;
        let remainingTokenGrantBalance = 0;
        let remainingLegacyFlatRateRemaining = 0;
        let walletUserPatch: Record<string, unknown> | null = null;
        let walletDevicePatch: Record<string, unknown> | null = null;
        let convertedBonusTokens = 0;
        let convertedAdCredits = 0;
        let convertedFreeCredits = 0;
        let convertedGoogleCredits = 0;
        let convertedDeviceCredits = 0;
        let conversionTokenBalance = 0;
        let conversionGrantBalance = 0;
        let conversionLegacyRemaining = 0;

        if (usesTokenWallet) {
            const walletState = hydrateTokenWallet({
                userData,
                deviceData: existingDeviceData,
            });
            convertedBonusTokens = walletState.convertedBonusTokens;
            convertedAdCredits = walletState.convertedAdCredits;
            convertedFreeCredits = walletState.convertedFreeCredits;
            convertedGoogleCredits = walletState.convertedGoogleCredits;
            convertedDeviceCredits = walletState.convertedDeviceCredits;
            conversionTokenBalance = walletState.tokenBalance;
            conversionGrantBalance = walletState.tokenGrantBalance;
            conversionLegacyRemaining = walletState.legacyFlatRateRemaining;
            if (walletState.convertedBonusTokens > 0 || walletState.snapshotPending) {
                adRewardCredits = 0;
                freeCredits = 0;
                googleLoginCredits = 0;
                deviceCredits = 0;
            }
            const chargePlan = planTokenWalletCharge({
                state: walletState,
                bonus: {
                    adRewardCredits: 0,
                    freeCredits: 0,
                    googleLoginCredits: 0,
                    deviceCredits: 0,
                },
                charCount,
                estimatedTokens,
                platform: platformText,
                appVersion,
                preferFreeCreditsFirst: paidCreditsOnly ? false : preferFreeCreditsFirst,
            });
            chargeMode = chargePlan.mode;
            chargedAmount = chargePlan.mode === 'tokens'
                ? chargePlan.estimatedTokens
                : 1;
            fromPaidTokens = chargePlan.fromPaidTokens;
            fromGrantTokens = chargePlan.fromGrantTokens;
            fromPurchased = chargePlan.fromLegacy;
            fromAdReward = chargePlan.fromAdReward;
            fromFree = chargePlan.fromFree;
            fromGoogleLogin = chargePlan.fromGoogleLogin;
            fromDevice = chargePlan.fromDevice;
            deviceCredits = chargePlan.bonusNext.deviceCredits;
            totalBonusConsumed += fromDevice;
            adRewardCredits = chargePlan.bonusNext.adRewardCredits;
            freeCredits = chargePlan.bonusNext.freeCredits;
            googleLoginCredits = chargePlan.bonusNext.googleLoginCredits;
            purchasedCredits = chargePlan.next.purchasedCredits;
            subscriptionPurchasedCredits = chargePlan.next.subscriptionPurchasedCredits;
            extraPurchasedCredits = chargePlan.next.extraPurchasedCredits;
            fromSubscriptionPurchased = Math.max(
                0,
                walletState.subscriptionPurchasedCredits - subscriptionPurchasedCredits,
            );
            fromExtraPurchased = Math.max(
                0,
                walletState.extraPurchasedCredits - extraPurchasedCredits,
            );
            remainingTokenBalance = chargePlan.next.tokenBalance;
            remainingTokenGrantBalance = chargePlan.next.tokenGrantBalance;
            remainingLegacyFlatRateRemaining = chargePlan.next.legacyFlatRateRemaining;
            walletUserPatch = tokenWalletUserFields(chargePlan.next);
            walletDevicePatch = tokenWalletDeviceFields(chargePlan.next);
        } else {
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
                preferFreeCreditsFirst: paidCreditsOnly ? false : preferFreeCreditsFirst,
                platform: platformText,
                appVersion,
            });
            fromPurchased = usagePlan.fromPurchased;
            fromAdReward = usagePlan.fromAdReward;
            fromFree = usagePlan.fromFree;
            fromGoogleLogin = usagePlan.fromGoogleLogin;
            fromDevice = usagePlan.fromDevice;

            deviceCredits -= fromDevice;
            totalBonusConsumed += fromDevice;
            fromSubscriptionPurchased = Math.min(subscriptionPurchasedCredits, fromPurchased);
            fromExtraPurchased = fromPurchased - fromSubscriptionPurchased;
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
        }

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
        if (walletDevicePatch) {
            Object.assign(deviceBonusUpdateData, walletDevicePatch);
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
            if (walletUserPatch) {
                Object.assign(userUpdateData, walletUserPatch);
            }
            transaction.set(userRef, userUpdateData, { merge: true });

            if (convertedBonusTokens > 0) {
                transaction.set(userRef.collection('credit_transactions').doc(), {
                    type: 'add',
                    amount: convertedBonusTokens,
                    unit: 'token',
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    source: 'legacy_bonus_conversion',
                    creditType: 'token_grant',
                    convertedAdCredits,
                    convertedFreeCredits,
                    convertedGoogleCredits,
                    convertedDeviceCredits,
                    remainingTokenBalance: conversionTokenBalance,
                    remainingTokenGrantBalance: conversionGrantBalance,
                    remainingLegacyFlatRateRemaining: conversionLegacyRemaining,
                });
            }

            transaction.set(db.collection('google_users').doc(uid), {
                purchasedCredits,
                credits: purchasedCredits,
                lastCreditConsumption: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });

            const usageRef = userRef.collection('credit_usage').doc();
            transaction.set(usageRef, {
                amount: chargedAmount,
                reason: reasonText || 'unknown',
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                deviceId: trimmedDeviceId,
                email: email ?? null,
                fromDevice,
                fromPurchased,
                fromPaidTokens,
                fromGrantTokens,
                fromAdReward,
                fromFree,
                fromGoogleLogin,
                remainingDeviceCredits: deviceCredits,
                remainingPurchasedCredits: purchasedCredits,
                remainingAdRewardCredits: adRewardCredits,
                remainingFreeCredits: freeCredits,
                remainingGoogleLoginCredits: googleLoginCredits,
                remainingCredits: purchasedCredits + deviceCredits + (isModernClient ? (adRewardCredits + freeCredits + googleLoginCredits) : 0),
                remainingTokenBalance,
                remainingTokenGrantBalance,
                remainingLegacyFlatRateRemaining,
                chargeMode,
            });

            transaction.set(userRef.collection('credit_transactions').doc(usageRef.id), {
                type: 'spend',
                amount: chargedAmount,
                unit: chargeMode === 'tokens' ? 'token' : 'credit',
                creditType: chargeMode === 'tokens'
                    ? (fromGrantTokens > 0 && fromPaidTokens > 0
                        ? 'token_mixed'
                        : (fromGrantTokens > 0 ? 'token_grant' : 'token_purchased'))
                    : chargeMode,
                reason: reasonText || 'unknown',
                chargeKey: trimmedChargeKey || null,
                fileName: fileNameText || null,
                targetLanguage: targetLanguageText || null,
                platform: platformText || null,
                email: email ?? null,
                creditBucket: fromPurchased > 0
                    ? 'paid'
                    : (chargeMode === 'tokens'
                        ? (fromGrantTokens > 0 && fromPaidTokens <= 0 ? 'token_grant' : 'token_purchased')
                        : (fromAdReward > 0 ? 'ad_reward' : 'free')),
                fromPaidTokens,
                fromGrantTokens,
                estimatedTokens: chargeMode === 'tokens' ? chargedAmount : 0,
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
                remainingTokenBalance,
                remainingTokenGrantBalance,
                remainingLegacyFlatRateRemaining,
                chargeMode,
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
                amount: chargedAmount,
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
                remainingTokenBalance,
                remainingTokenGrantBalance,
                remainingLegacyFlatRateRemaining,
                chargeMode,
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
            remainingTokenBalance,
            remainingTokenGrantBalance,
            remainingLegacyFlatRateRemaining,
            chargeMode,
            chargedAmount,
        };
    });
}
