import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import {
    getAuthEmail,
    loadCreditSummary,
    normalizePlatform,
    predictCreditUsage,
    requireDeviceId,
} from '../billing/creditUtils';
import {
    hydrateTokenWallet,
    planTokenWalletCharge,
    spendableTokenBalance,
    tokenChargeRequiresRewardedAd,
} from '../billing/tokenWallet';
import {
    isUnsupportedDesktopClient,
    meetsMinimumVersion,
    shouldEnforceDesktopPaidCreditsOnly,
    shouldUseV160ClientRules,
} from '../referral/referralUtils';
import {
    TRANSLATION_QUOTE_PROTOCOL_VERSION,
} from './translationQuote';

type CheckTranslationAccessData = {
    deviceId?: string;
    chargeKey?: string;
    fileName?: string;
    targetLanguage?: string;
    platform?: string;
    appVersion?: string;
    useRewardedAd?: boolean;
    preferFreeCreditsFirst?: boolean;
    charCount?: number;
    estimatedTokens?: number;
    quoteProtocolVersion?: number;
    quoteId?: string;
    contentHash?: string;
};

export const checkTranslationAccess = onCall({ invoker: 'public', enforceAppCheck: false }, async (request: CallableRequest<CheckTranslationAccessData>) => {
    if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
    }

    const deviceId = requireDeviceId(request.data.deviceId);
    const chargeKey = (request.data.chargeKey ?? '').trim();
    const fileName = (request.data.fileName ?? '').trim();
    const targetLanguage = (request.data.targetLanguage ?? '').trim();
    const platform = normalizePlatform(request.data.platform);
    const appVersion = (request.data.appVersion ?? '').trim() || '1.6.0';
    if (isUnsupportedDesktopClient({ appVersion, platform })) {
        throw new HttpsError('failed-precondition', 'DESKTOP_UPDATE_REQUIRED');
    }
    const useRewardedAd = request.data.useRewardedAd === true;
    const paidCreditsOnly = shouldEnforceDesktopPaidCreditsOnly({
        appVersion,
        platform,
    });
    const preferFreeCreditsFirst = paidCreditsOnly
        ? false
        : request.data.preferFreeCreditsFirst === true;
    const quoteProtocolVersion = Math.floor(
        Number(request.data.quoteProtocolVersion ?? 0),
    );
    const usesExactQuote =
        quoteProtocolVersion === TRANSLATION_QUOTE_PROTOCOL_VERSION;
    let charCount = request.data.charCount;
    let estimatedTokens = request.data.estimatedTokens;
    let quoteSessionData: FirebaseFirestore.DocumentData | null = null;

    if (chargeKey.includes('/')) {
        throw new HttpsError('invalid-argument', 'Invalid chargeKey');
    }

    const db = admin.firestore();
    if (usesExactQuote) {
        if (!chargeKey) {
            throw new HttpsError(
                'failed-precondition',
                'Translation quote is required.',
            );
        }
        const quoteSessionSnap = await db
            .collection('device_bonuses')
            .doc(deviceId)
            .collection('translation_sessions')
            .doc(chargeKey)
            .get();
        const data = quoteSessionSnap.data() ?? {};
        const requestedQuoteId = String(request.data.quoteId ?? '').trim();
        const requestedContentHash = String(
            request.data.contentHash ?? '',
        ).trim();
        if (
            !quoteSessionSnap.exists
            || data.uid !== request.auth.uid
            || !requestedQuoteId
            || data.quoteId !== requestedQuoteId
            || !requestedContentHash
            || data.contentHash !== requestedContentHash
        ) {
            throw new HttpsError(
                'permission-denied',
                'Translation quote mismatch.',
            );
        }
        const expiryMillis = data.quoteExpiresAt?.toMillis?.() ?? 0;
        if (
            data.charged !== true
            && (!expiryMillis || expiryMillis < Date.now())
        ) {
            throw new HttpsError(
                'failed-precondition',
                'TRANSLATION_QUOTE_EXPIRED',
            );
        }
        const quotedAppTokens = Math.max(
            0,
            Math.floor(Number(data.quotedAppTokens ?? 0)),
        );
        const quotedCharacterCount = Math.max(
            0,
            Math.floor(Number(data.quotedCharacterCount ?? 0)),
        );
        if (quotedAppTokens <= 0 || quotedCharacterCount <= 0) {
            throw new HttpsError(
                'failed-precondition',
                'Translation quote is invalid.',
            );
        }
        quoteSessionData = data;
        charCount = quotedCharacterCount;
        estimatedTokens = quotedAppTokens;
    }

    const summary = await loadCreditSummary({
        db,
        uid: request.auth.uid,
        deviceId,
        platform,
        appVersion,
    });

    if (summary.usesTokenWallet) {
        const bonusFiles = summary.adRewardCredits
            + summary.freeCredits
            + summary.googleLoginCredits
            + summary.deviceCredits;
        const spendableTokens = spendableTokenBalance({
            state: {
                tokenBalance: summary.tokenBalance,
                tokenGrantBalance: summary.tokenGrantBalance,
            },
            platform,
            appVersion,
            googleLoginTokenGrantBalance: summary.googleLoginTokenGrantBalance,
        });
        if (
            summary.legacyFlatRateRemaining <= 0
            && bonusFiles <= 0
            && spendableTokens <= 0
            && !(summary.accessActive && !usesExactQuote)
        ) {
            throw new HttpsError('failed-precondition', 'INSUFFICIENT_CREDIT');
        }
    } else if (summary.totalCredits <= 0 && !summary.accessActive) {
        throw new HttpsError('failed-precondition', 'INSUFFICIENT_CREDIT');
    }

    const isModernClient = shouldUseV160ClientRules({
        appVersion,
        platform,
    });
    const supportsRewardedAd =
        platform === 'android' || platform === 'ios';

    let requiresRewardedAd = false;
    let translationCreditType: 'paid' | 'free' | null = null;
    let usesAdRewardCredits = false;
    let chargeMode: string = 'credits';
    let plannedEstimatedTokens = 0;
    let plannedFromPaidTokens = 0;
    let plannedFromGrantTokens = 0;

    if (summary.usesTokenWallet) {
        const userSnap = await db.collection('users').doc(request.auth.uid).get();
        const chargePlan = planTokenWalletCharge({
            state: {
                ...hydrateTokenWallet({
                    userData: userSnap.data() ?? {},
                }),
                tokenBalance: summary.tokenBalance,
                tokenGrantBalance: summary.tokenGrantBalance,
                legacyFlatRateRemaining: summary.legacyFlatRateRemaining,
            },
            bonus: {
                adRewardCredits: 0,
                freeCredits: 0,
                googleLoginCredits: 0,
                deviceCredits: 0,
            },
            charCount,
            estimatedTokens,
            platform,
            appVersion,
            preferFreeCreditsFirst,
            googleLoginTokenGrantBalance: summary.googleLoginTokenGrantBalance,
        });
        chargeMode = chargePlan.mode;
        plannedEstimatedTokens = chargePlan.estimatedTokens;
        plannedFromPaidTokens = chargePlan.fromPaidTokens;
        plannedFromGrantTokens = chargePlan.fromGrantTokens;
        requiresRewardedAd = !paidCreditsOnly
            && supportsRewardedAd
            && isModernClient
            && tokenChargeRequiresRewardedAd(chargePlan);
        usesAdRewardCredits = chargePlan.fromAdReward > 0;
        translationCreditType = (usesExactQuote
            || meetsMinimumVersion(appVersion, '1.6.4'))
            ? (chargePlan.mode === 'paid_file' || chargePlan.fromPaidTokens > 0
                ? 'paid'
                : 'free')
            : null;
    } else {
        const usagePlan = predictCreditUsage({
            amount: 1,
            purchasedCredits: summary.purchasedCredits,
            adRewardCredits: summary.adRewardCredits,
            freeCredits: summary.freeCredits,
            googleLoginCredits: summary.googleLoginCredits,
            deviceCredits: summary.deviceCredits,
            isModernClient,
            preferFreeCreditsFirst,
            platform,
            appVersion,
        });

        requiresRewardedAd = !paidCreditsOnly &&
            supportsRewardedAd &&
            isModernClient &&
            !summary.accessActive &&
            (usagePlan.fromFree + usagePlan.fromGoogleLogin + usagePlan.fromDevice) > 0;
        usesAdRewardCredits = usagePlan.fromAdReward > 0;
        translationCreditType = (usesExactQuote
            || meetsMinimumVersion(appVersion, '1.6.4'))
            ? (usagePlan.fromPurchased > 0
                ? 'paid'
                : ((usagePlan.fromAdReward + usagePlan.fromFree + usagePlan.fromGoogleLogin + usagePlan.fromDevice) > 0
                    ? 'free'
                    : null))
            : null;
    }

    if (usesExactQuote && quoteSessionData != null) {
        const quotedChargeMode = String(
            quoteSessionData.quotedChargeMode ?? '',
        );
        const quotedFromPaidTokens = Math.max(
            0,
            Math.floor(Number(
                quoteSessionData.quotedFromPaidTokens ?? 0,
            )),
        );
        const quotedFromGrantTokens = Math.max(
            0,
            Math.floor(Number(
                quoteSessionData.quotedFromGrantTokens ?? 0,
            )),
        );
        const quotedCreditType =
            quoteSessionData.quotedTranslationCreditType ?? null;
        if (
            quoteSessionData.quotedSufficient !== true
            || quotedChargeMode !== chargeMode
            || quotedFromPaidTokens !== plannedFromPaidTokens
            || quotedFromGrantTokens !== plannedFromGrantTokens
            || quoteSessionData.quotedRequiresRewardedAd !==
                requiresRewardedAd
            || quotedCreditType !== translationCreditType
        ) {
            throw new HttpsError(
                'failed-precondition',
                'TRANSLATION_QUOTE_BALANCE_CHANGED',
            );
        }
    }

    if (requiresRewardedAd && !useRewardedAd) {
        throw new HttpsError('failed-precondition', 'REWARDED_AD_REQUIRED');
    }

    if (chargeKey) {
        const sessionRef = db
            .collection('device_bonuses')
            .doc(deviceId)
            .collection('translation_sessions')
            .doc(chargeKey);

        const existingSessionSnap = await sessionRef.get();
        const existingSessionData = existingSessionSnap.data()
            ?? quoteSessionData
            ?? {};
        const alreadyCharged = existingSessionSnap.exists && existingSessionData.charged === true;

        await sessionRef.set({
            chargeKey,
            uid: request.auth.uid,
            email: getAuthEmail(request.auth),
            deviceId,
            fileName: fileName || null,
            targetLanguage: targetLanguage || null,
            platform,
            prepared: true,
            approved: false,
            // Never reset 'charged' to false if the session was already charged.
            // This preserves idempotency integrity in translateText / batchTranslate.
            ...(!alreadyCharged && { charged: false }),
            requiresRewardedAd,
            rewardedAdConfirmed: !requiresRewardedAd || useRewardedAd,
            usesAdRewardCredits,
            ...(translationCreditType ? { translationCreditType } : {}),
            preferFreeCreditsFirst,
            charCount: charCount ?? existingSessionData.charCount ?? null,
            estimatedTokens: plannedEstimatedTokens || existingSessionData.estimatedTokens || null,
            chargeMode,
            fromPaidTokens: plannedFromPaidTokens,
            fromGrantTokens: plannedFromGrantTokens,
            ...(usesExactQuote
                ? {
                    quoteProtocolVersion,
                    quoteId: existingSessionData.quoteId,
                    contentHash: existingSessionData.contentHash,
                    quotedCharacterCount:
                        existingSessionData.quotedCharacterCount,
                    characterMultiplier:
                        existingSessionData.characterMultiplier,
                    quotedAppTokens: existingSessionData.quotedAppTokens,
                    quoteConfirmedAt:
                        admin.firestore.FieldValue.serverTimestamp(),
                }
                : {}),
            lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
            preparedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }

    return {
        success: true,
        totalCredits: summary.totalCredits,
        purchasedCredits: summary.purchasedCredits,
        adRewardCredits: summary.adRewardCredits,
        freeCredits: summary.freeCredits,
        googleLoginCredits: summary.googleLoginCredits,
        deviceCredits: summary.deviceCredits,
        hasPaidCredits: summary.hasPaidCredits,
        isPaidUser: summary.isPaidUser,
        accessActive: summary.accessActive,
        chargeKey: chargeKey || null,
        translationCreditType,
        usesTokenWallet: summary.usesTokenWallet,
        tokenBalance: summary.tokenBalance,
        tokenGrantBalance: summary.tokenGrantBalance,
        legacyFlatRateRemaining: summary.legacyFlatRateRemaining,
        chargeMode,
        estimatedTokens: plannedEstimatedTokens,
        requiresRewardedAd,
        fromPaidTokens: plannedFromPaidTokens,
        fromGrantTokens: plannedFromGrantTokens,
        ...(usesExactQuote
            ? {
                quoteProtocolVersion,
                quoteId: quoteSessionData?.quoteId ?? null,
                contentHash: quoteSessionData?.contentHash ?? null,
                quotedCharacterCount:
                    quoteSessionData?.quotedCharacterCount ?? null,
                characterMultiplier:
                    quoteSessionData?.characterMultiplier ?? null,
                quotedAppTokens:
                    quoteSessionData?.quotedAppTokens ?? plannedEstimatedTokens,
            }
            : {}),
    };
});
