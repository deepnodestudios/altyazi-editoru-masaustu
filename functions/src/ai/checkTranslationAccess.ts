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
    const charCount = request.data.charCount;
    const estimatedTokens = request.data.estimatedTokens;

    if (chargeKey.includes('/')) {
        throw new HttpsError('invalid-argument', 'Invalid chargeKey');
    }

    const db = admin.firestore();
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
        });
        if (
            summary.legacyFlatRateRemaining <= 0
            && bonusFiles <= 0
            && spendableTokens <= 0
            && !summary.accessActive
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

    let requiresRewardedAd = false;
    let translationCreditType: 'paid' | 'free' | null = null;
    let usesAdRewardCredits = false;
    let chargeMode: string = 'credits';
    let plannedEstimatedTokens = 0;

    if (summary.usesTokenWallet && !summary.accessActive) {
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
        });
        chargeMode = chargePlan.mode;
        plannedEstimatedTokens = chargePlan.estimatedTokens;
        requiresRewardedAd = !paidCreditsOnly
            && isModernClient
            && tokenChargeRequiresRewardedAd(chargePlan);
        usesAdRewardCredits = chargePlan.fromAdReward > 0;
        translationCreditType = meetsMinimumVersion(appVersion, '1.6.4')
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
            isModernClient &&
            !summary.accessActive &&
            (usagePlan.fromFree + usagePlan.fromGoogleLogin + usagePlan.fromDevice) > 0;
        usesAdRewardCredits = usagePlan.fromAdReward > 0;
        translationCreditType = meetsMinimumVersion(appVersion, '1.6.4')
            ? (usagePlan.fromPurchased > 0
                ? 'paid'
                : ((usagePlan.fromAdReward + usagePlan.fromFree + usagePlan.fromGoogleLogin + usagePlan.fromDevice) > 0
                    ? 'free'
                    : null))
            : null;
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
        const existingSessionData = existingSessionSnap.data() ?? {};
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
    };
});
