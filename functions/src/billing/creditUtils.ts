import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';

import {
    meetsMinimumVersion,
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
    resolveGoogleLoginTokenGrantBalance,
    shouldUseTokenWallet,
    spendableTokenBalance,
    tokenWalletDeviceFields,
    tokenWalletUserFields,
    googleLoginGrantSpendAmount,
    withGoogleLoginGrantSpend,
    type TokenChargeMode,
} from './tokenWallet';
import {
    ensureGrantLotsConsistentInTx,
    expireDueGrantLotsInTx,
    loadActiveGrantLots,
    loadGoogleLoginGrantLots,
    reconcileSubscriptionGrantRemainingFromLots,
    recordGrantLotInTx,
    spendGrantLotsFifoInTx,
    sumActiveLotRemainingBySources,
    type GrantLotDoc,
} from './tokenGrantLots';
import {
    translationContentHash,
    TRANSLATION_QUOTE_MIN_DESKTOP_VERSION,
    TRANSLATION_QUOTE_MIN_MOBILE_VERSION,
    TRANSLATION_QUOTE_PROTOCOL_VERSION,
} from '../ai/translationQuote';

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
    googleLoginTokenGrantBalance: number;
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
    quoteProtocolVersion?: number | null;
    quoteId?: string | null;
    contentHash?: string | null;
    sourceContent?: string | null;
};

export function normalizePlatform(platform?: string | null): string {
    const value = (platform ?? '').trim().toLowerCase();
    return value.length === 0 ? 'unknown' : value;
}

function exactTranslationQuoteRequired(
    platform: string,
    appVersion?: string | null,
): boolean {
    if (platform === 'android' || platform === 'ios') {
        return meetsMinimumVersion(
            appVersion,
            TRANSLATION_QUOTE_MIN_MOBILE_VERSION,
        );
    }
    if (
        platform === 'windows'
        || platform === 'macos'
        || platform === 'linux'
    ) {
        return meetsMinimumVersion(
            appVersion,
            TRANSLATION_QUOTE_MIN_DESKTOP_VERSION,
        );
    }
    return false;
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
    let googleLoginGrantLots: GrantLotDoc[] | undefined;
    if (uid) {
        const userRef = db.collection('users').doc(uid);
        const userDoc = await userRef.get();
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
                if (normalizedPlatform === 'web') {
                    googleLoginGrantLots =
                        await loadGoogleLoginGrantLots(userRef);
                }
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
    const googleLoginTokenGrantBalance = usesTokenWallet
        ? resolveGoogleLoginTokenGrantBalance(
            userData,
            googleLoginGrantLots,
        )
        : 0;
    const legacyFlatRateRemaining = wallet?.legacyFlatRateRemaining ?? 0;
    const spendableTokens = wallet
        ? spendableTokenBalance({
            state: wallet,
            platform: normalizedPlatform,
            appVersion,
            googleLoginTokenGrantBalance,
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
        googleLoginTokenGrantBalance,
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
            googleLoginTokenGrantBalance: summary.googleLoginTokenGrantBalance,
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
    quoteProtocolVersion,
    quoteId,
    contentHash,
    sourceContent,
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
    if (
        Math.floor(Number(quoteProtocolVersion ?? 0)) ===
            TRANSLATION_QUOTE_PROTOCOL_VERSION
        && !trimmedChargeKey
    ) {
        throw new HttpsError(
            'failed-precondition',
            'Translation quote is required.',
        );
    }
    if (
        usesTokenWallet
        && exactTranslationQuoteRequired(platformText, appVersion)
        && (
            !trimmedChargeKey
            || Math.floor(Number(quoteProtocolVersion ?? 0)) !==
                TRANSLATION_QUOTE_PROTOCOL_VERSION
        )
    ) {
        throw new HttpsError(
            'failed-precondition',
            'TRANSLATION_QUOTE_REQUIRED',
        );
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

        let authoritativeCharCount = charCount;
        let authoritativeEstimatedTokens = estimatedTokens;
        let appliedQuoteProtocolVersion = 0;
        let appliedQuoteId = '';
        let appliedContentHash = '';
        let appliedQuoteVersion = '';
        let appliedCharacterMultiplier = 0;
        let expectedQuoteChargeMode = '';
        let expectedQuoteFromPaidTokens = 0;
        let expectedQuoteFromGrantTokens = 0;
        let sessionData: any = {};

        if (sessionRef) {
            const sessionDoc = await transaction.get(sessionRef);
            sessionData = sessionDoc.data() ?? {};
            const sessionQuoteProtocolVersion = Math.floor(
                Number(sessionData.quoteProtocolVersion ?? 0),
            );
            const exactQuoteRequired = shouldUseTokenWallet({
                appVersion,
                platform: platformText,
            }) && exactTranslationQuoteRequired(platformText, appVersion);
            if (
                exactQuoteRequired
                && sessionQuoteProtocolVersion !==
                    TRANSLATION_QUOTE_PROTOCOL_VERSION
            ) {
                throw new HttpsError(
                    'failed-precondition',
                    'TRANSLATION_QUOTE_REQUIRED',
                );
            }

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

            if (
                sessionQuoteProtocolVersion ===
                TRANSLATION_QUOTE_PROTOCOL_VERSION
            ) {
                const requestedProtocolVersion = Math.floor(
                    Number(quoteProtocolVersion ?? 0),
                );
                const requestedQuoteId = String(quoteId ?? '').trim();
                const requestedContentHash = String(contentHash ?? '').trim();
                const quotedAppTokens = clampNonNegativeInt(
                    sessionData.quotedAppTokens,
                );
                const quotedCharacterCount = clampNonNegativeInt(
                    sessionData.quotedCharacterCount,
                );
                if (
                    requestedProtocolVersion !==
                        TRANSLATION_QUOTE_PROTOCOL_VERSION
                    || !requestedQuoteId
                    || requestedQuoteId !== sessionData.quoteId
                    || !requestedContentHash
                    || requestedContentHash !== sessionData.contentHash
                    || quotedAppTokens <= 0
                    || quotedCharacterCount <= 0
                ) {
                    throw new HttpsError(
                        'permission-denied',
                        'Translation quote mismatch.',
                    );
                }
                if (
                    typeof sourceContent !== 'string'
                    || !sourceContent
                    || translationContentHash(sourceContent) !==
                        requestedContentHash
                ) {
                    throw new HttpsError(
                        'failed-precondition',
                        'QUOTE_CONTENT_MISMATCH',
                    );
                }
                const quoteExpiresAtMillis =
                    sessionData.quoteExpiresAt?.toMillis?.() ?? 0;
                if (
                    sessionData.charged !== true
                    && (
                        !quoteExpiresAtMillis
                        || quoteExpiresAtMillis < Date.now()
                    )
                ) {
                    throw new HttpsError(
                        'failed-precondition',
                        'TRANSLATION_QUOTE_EXPIRED',
                    );
                }
                authoritativeCharCount = quotedCharacterCount;
                // First-free translation: only the amount above the fair-use
                // cap is charged; the free part is covered by the policy.
                authoritativeEstimatedTokens =
                    sessionData.firstFreeApplied === true
                        ? clampNonNegativeInt(sessionData.chargeAppTokens)
                        : quotedAppTokens;
                appliedQuoteProtocolVersion =
                    sessionQuoteProtocolVersion;
                appliedQuoteId = requestedQuoteId;
                appliedContentHash = requestedContentHash;
                appliedQuoteVersion = String(
                    sessionData.quoteVersion ?? '',
                );
                appliedCharacterMultiplier = Number(
                    sessionData.characterMultiplier ?? 0,
                );
                expectedQuoteChargeMode = String(
                    sessionData.chargeMode ?? '',
                );
                expectedQuoteFromPaidTokens = clampNonNegativeInt(
                    sessionData.fromPaidTokens,
                );
                expectedQuoteFromGrantTokens = clampNonNegativeInt(
                    sessionData.fromGrantTokens,
                );
            } else if (
                Math.floor(Number(quoteProtocolVersion ?? 0)) ===
                TRANSLATION_QUOTE_PROTOCOL_VERSION
            ) {
                throw new HttpsError(
                    'failed-precondition',
                    'Translation quote is required.',
                );
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
                    chargedAmount: clampNonNegativeInt(
                        existing.amount ?? existing.chargedAmount,
                    ),
                    fromPaidTokens: clampNonNegativeInt(
                        existing.fromPaidTokens,
                    ),
                    fromGrantTokens: clampNonNegativeInt(
                        existing.fromGrantTokens,
                    ),
                    translationCreditType:
                        existing.translationCreditType ?? null,
                    quoteProtocolVersion:
                        clampNonNegativeInt(existing.quoteProtocolVersion),
                    quoteVersion: existing.quoteVersion ?? null,
                    quoteId: existing.quoteId ?? null,
                    contentHash: existing.contentHash ?? null,
                    quotedCharacterCount: clampNonNegativeInt(
                        existing.quotedCharacterCount,
                    ),
                    characterMultiplier:
                        Number(existing.characterMultiplier ?? 0) || 0,
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
        let chargeMode: TokenChargeMode | 'credits' | 'first_free' = 'credits';
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
        let grantAllocations: Array<{ lotId: string; amount: number; source: string }> = [];
        let activeGrantLots: GrantLotDoc[] = [];
        let trackedGoogleLoginGrantLots: GrantLotDoc[] = [];

        if (usesTokenWallet) {
            // Lot query must run with other reads before any writes.
            if (userRef) {
                activeGrantLots = await loadActiveGrantLots(transaction, userRef);
                const shouldTrackGoogleLoginGrant =
                    platformText === 'web'
                    || userData.googleLoginTokenGrantBalance != null
                    || userData.googleLoginBonusGranted === true
                    || userData.loginBonusGranted === true;
                if (shouldTrackGoogleLoginGrant) {
                    trackedGoogleLoginGrantLots =
                        await loadGoogleLoginGrantLots(userRef, transaction);
                }
            }
            const grantNow = new Date();
            let walletState = hydrateTokenWallet({
                userData,
                deviceData: existingDeviceData,
            });
            if (userRef) {
                activeGrantLots = ensureGrantLotsConsistentInTx(
                    transaction,
                    userRef,
                    walletState,
                    activeGrantLots,
                    grantNow,
                );
                const expired = expireDueGrantLotsInTx(
                    transaction,
                    userRef,
                    walletState,
                    activeGrantLots,
                    grantNow,
                );
                walletState = expired.next;
                activeGrantLots = expired.lots;
            }
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
            if (userRef && walletState.convertedBonusTokens > 0) {
                const conversionLot = recordGrantLotInTx(transaction, userRef, {
                    amount: walletState.convertedBonusTokens,
                    source: 'legacy_conversion',
                    originId: `legacy_conversion_${uid}`,
                    grantedAt: grantNow,
                    existingLots: activeGrantLots,
                });
                if (conversionLot && !activeGrantLots.some((lot) => lot.id === conversionLot.id)) {
                    activeGrantLots = [...activeGrantLots, conversionLot];
                }
            }
            const isFirstFreeFullyFree = sessionData.firstFreeApplied === true
                && clampNonNegativeInt(sessionData.chargeAppTokens) <= 0;

            if (isFirstFreeFullyFree) {
                chargeMode = 'first_free';
                chargedAmount = 0;
                fromPaidTokens = 0;
                fromGrantTokens = 0;
                remainingTokenBalance = walletState.tokenBalance;
                remainingTokenGrantBalance = walletState.tokenGrantBalance;
                remainingLegacyFlatRateRemaining = walletState.legacyFlatRateRemaining;
                if (
                    appliedQuoteProtocolVersion > 0
                    && (
                        expectedQuoteChargeMode !== chargeMode
                        || expectedQuoteFromPaidTokens !== fromPaidTokens
                        || expectedQuoteFromGrantTokens !== fromGrantTokens
                    )
                ) {
                    throw new HttpsError(
                        'failed-precondition',
                        'TRANSLATION_QUOTE_BALANCE_CHANGED',
                    );
                }
            } else {
                const chargePlan = planTokenWalletCharge({
                    state: walletState,
                    bonus: {
                        adRewardCredits: 0,
                        freeCredits: 0,
                        googleLoginCredits: 0,
                        deviceCredits: 0,
                    },
                    charCount: sessionData.firstFreeApplied === true
                        ? undefined
                        : authoritativeCharCount,
                    estimatedTokens: authoritativeEstimatedTokens,
                    platform: platformText,
                    appVersion,
                    preferFreeCreditsFirst: paidCreditsOnly ? false : preferFreeCreditsFirst,
                    googleLoginTokenGrantBalance:
                        resolveGoogleLoginTokenGrantBalance(
                            userData,
                            activeGrantLots,
                            trackedGoogleLoginGrantLots.length > 0,
                        ),
                });
                chargeMode = chargePlan.mode;
                chargedAmount = chargePlan.mode === 'tokens'
                    ? chargePlan.estimatedTokens
                    : 1;
                fromPaidTokens = chargePlan.fromPaidTokens;
                fromGrantTokens = chargePlan.fromGrantTokens;
                if (
                    appliedQuoteProtocolVersion > 0
                    && (
                        expectedQuoteChargeMode !== chargePlan.mode
                        || expectedQuoteFromPaidTokens !== fromPaidTokens
                        || expectedQuoteFromGrantTokens !== fromGrantTokens
                    )
                ) {
                    throw new HttpsError(
                        'failed-precondition',
                        'TRANSLATION_QUOTE_BALANCE_CHANGED',
                    );
                }
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
                const trackedSubscriptionBeforeSpend =
                    sumActiveLotRemainingBySources(
                        activeGrantLots,
                        ['subscription_bonus'],
                    );
                const legacySubscriptionBeforeSpend = Math.max(
                    0,
                    walletState.subscriptionTokenGrantRemaining
                        - trackedSubscriptionBeforeSpend,
                );
                if (userRef && fromGrantTokens > 0) {
                    const spentLots = spendGrantLotsFifoInTx(
                        transaction,
                        userRef,
                        activeGrantLots,
                        fromGrantTokens,
                        grantNow,
                    );
                    activeGrantLots = spentLots.lots;
                    grantAllocations = spentLots.allocations;
                }
                const sourceAwareWalletState =
                    reconcileSubscriptionGrantRemainingFromLots(
                        {
                            ...chargePlan.next,
                            // applyTokenSpend cannot see FIFO lot sources. Preserve
                            // the pre-spend slice and rebuild it from updated lots.
                            subscriptionTokenGrantRemaining:
                                walletState.subscriptionTokenGrantRemaining,
                        },
                        activeGrantLots,
                        {
                            legacyUnattributedLimit:
                                legacySubscriptionBeforeSpend,
                        },
                    );
                remainingTokenBalance = sourceAwareWalletState.tokenBalance;
                remainingTokenGrantBalance = sourceAwareWalletState.tokenGrantBalance;
                remainingLegacyFlatRateRemaining =
                    sourceAwareWalletState.legacyFlatRateRemaining;
                const googleLoginLotTrackingKnown =
                    trackedGoogleLoginGrantLots.length > 0
                    || activeGrantLots.some(
                        (lot) => String(lot.source).trim().toLowerCase() ===
                            'google_login_bonus',
                    );
                const loginGrantSpent = googleLoginLotTrackingKnown
                    ? 0
                    : googleLoginGrantSpendAmount({
                        platform: platformText,
                        userData,
                        tokenGrantBalance: walletState.tokenGrantBalance,
                        fromGrantTokens,
                    });
                walletUserPatch = {
                    ...tokenWalletUserFields(sourceAwareWalletState),
                    googleLoginTokenGrantBalance: googleLoginLotTrackingKnown
                        ? resolveGoogleLoginTokenGrantBalance(
                            userData,
                            activeGrantLots,
                            true,
                        )
                        : withGoogleLoginGrantSpend(userData, loginGrantSpent),
                };
                walletDevicePatch = tokenWalletDeviceFields(sourceAwareWalletState);
            }
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

        const translationCreditType =
            chargeMode === 'paid_file'
            || fromPurchased > 0
            || fromPaidTokens > 0
                ? 'paid'
                : (
                    chargeMode === 'bonus_file'
                    || chargeMode === 'first_free'
                    || fromAdReward > 0
                    || fromFree > 0
                    || fromGoogleLogin > 0
                    || fromDevice > 0
                    || fromGrantTokens > 0
                        ? 'free'
                        : null
                );
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
                translationCreditType,
                quoteProtocolVersion: appliedQuoteProtocolVersion || null,
                quoteVersion: appliedQuoteVersion || null,
                quoteId: appliedQuoteId || null,
                contentHash: appliedContentHash || null,
                quotedCharacterCount:
                    appliedQuoteProtocolVersion > 0
                        ? clampNonNegativeInt(authoritativeCharCount)
                        : null,
                characterMultiplier:
                    appliedCharacterMultiplier || null,
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
                grantAllocations: grantAllocations.length > 0 ? grantAllocations : null,
                estimatedTokens: chargeMode === 'tokens' ? chargedAmount : 0,
                quotedCharacterCount:
                    appliedQuoteProtocolVersion > 0
                        ? clampNonNegativeInt(authoritativeCharCount)
                        : null,
                characterMultiplier:
                    appliedCharacterMultiplier || null,
                quoteProtocolVersion: appliedQuoteProtocolVersion || null,
                quoteVersion: appliedQuoteVersion || null,
                quoteId: appliedQuoteId || null,
                contentHash: appliedContentHash || null,
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
                chargedAmount,
                chargeMode,
                fromPaidTokens,
                fromGrantTokens,
                translationCreditType,
                quoteProtocolVersion: appliedQuoteProtocolVersion || null,
                quoteVersion: appliedQuoteVersion || null,
                quoteId: appliedQuoteId || null,
                contentHash: appliedContentHash || null,
                quotedCharacterCount:
                    appliedQuoteProtocolVersion > 0
                        ? clampNonNegativeInt(authoritativeCharCount)
                        : null,
                characterMultiplier:
                    appliedCharacterMultiplier || null,
                chargedAt: admin.firestore.FieldValue.serverTimestamp(),
                lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (sessionData.firstFreeApplied === true) {
                const now = admin.firestore.FieldValue.serverTimestamp();
                sessionPayload.firstFreeApplied = true;
                sessionPayload.firstFreeCoverageTokens =
                    clampNonNegativeInt(sessionData.firstFreeCoverageTokens);
                sessionPayload.regularAppTokens =
                    clampNonNegativeInt(sessionData.regularAppTokens ?? sessionData.quotedAppTokens);
                sessionPayload.firstFreeTranslationUsedAt =
                    sessionData.firstFreeTranslationUsedAt ?? now;
                transaction.set(deviceBonusRef, { firstFreeTranslationUsedAt: now }, { merge: true });
                if (userRef) {
                    transaction.set(userRef, { firstFreeTranslationUsedAt: now }, { merge: true });
                }
            }
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
                chargedAmount,
                fromPaidTokens,
                fromGrantTokens,
                translationCreditType,
                quoteProtocolVersion: appliedQuoteProtocolVersion || null,
                quoteVersion: appliedQuoteVersion || null,
                quoteId: appliedQuoteId || null,
                contentHash: appliedContentHash || null,
                quotedCharacterCount:
                    appliedQuoteProtocolVersion > 0
                        ? clampNonNegativeInt(authoritativeCharCount)
                        : null,
                characterMultiplier:
                    appliedCharacterMultiplier || null,
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
            fromPaidTokens,
            fromGrantTokens,
            translationCreditType,
            quoteProtocolVersion: appliedQuoteProtocolVersion,
            quoteVersion: appliedQuoteVersion || null,
            quoteId: appliedQuoteId || null,
            contentHash: appliedContentHash || null,
            quotedCharacterCount:
                appliedQuoteProtocolVersion > 0
                    ? clampNonNegativeInt(authoritativeCharCount)
                    : 0,
            characterMultiplier: appliedCharacterMultiplier,
        };
    });
}
