import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { assertCreditsAvailable, getAuthEmail, normalizePlatform, requireDeviceId } from '../billing/creditUtils';

type CheckTranslationAccessData = {
    deviceId?: string;
    chargeKey?: string;
    fileName?: string;
    targetLanguage?: string;
    platform?: string;
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

    if (chargeKey.includes('/')) {
        throw new HttpsError('invalid-argument', 'Invalid chargeKey');
    }

    const db = admin.firestore();
    const summary = await assertCreditsAvailable({
        db,
        uid: request.auth.uid,
        deviceId,
        platform,
    });

    if (chargeKey) {
        const sessionRef = db
            .collection('device_bonuses')
            .doc(deviceId)
            .collection('translation_sessions')
            .doc(chargeKey);

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
            charged: false,
            lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
            preparedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }

    return {
        success: true,
        totalCredits: summary.totalCredits,
        purchasedCredits: summary.purchasedCredits,
        deviceCredits: summary.deviceCredits,
        accessActive: summary.accessActive,
        chargeKey: chargeKey || null,
    };
});