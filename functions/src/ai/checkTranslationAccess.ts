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
    const useRewardedAd = request.data.useRewardedAd === true;
    const paidCreditsOnly = shouldEnforceDesktopPaidCreditsOnly({
        appVersion,
        platform,
    });
    const preferFreeCreditsFirst = paidCreditsOnly
        ? false
        : request.data.preferFreeCreditsFirst === true;

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

    if (summary.totalCredits <= 0 && !summary.accessActive) {
        throw new HttpsError('failed-precondition', 'INSUFFICIENT_CREDIT');
    }

    const isModernClient = shouldUseV160ClientRules({
        appVersion,
        platform,
    });
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

    const requiresRewardedAd = !paidCreditsOnly &&
        isModernClient &&
        !summary.accessActive &&
        (usagePlan.fromFree + usagePlan.fromGoogleLogin + usagePlan.fromDevice) > 0;
    const translationCreditType = meetsMinimumVersion(appVersion, '1.6.4')
        ? (usagePlan.fromPurchased > 0
            ? 'paid'
            : ((usagePlan.fromAdReward + usagePlan.fromFree + usagePlan.fromGoogleLogin + usagePlan.fromDevice) > 0
                ? 'free'
                : null))
        : null;

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
            usesAdRewardCredits: usagePlan.fromAdReward > 0,
            ...(translationCreditType ? { translationCreditType } : {}),
            preferFreeCreditsFirst,
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
    };
});
