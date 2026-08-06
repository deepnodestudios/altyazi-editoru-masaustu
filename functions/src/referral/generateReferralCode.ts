import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { generateCode, isMobilePlatform, meetsMinimumVersion, meetsVersionRequirement } from './referralUtils';

const REFERRAL_SHARE_INTEGRITY_MIN_VERSION = '1.6.2';

interface GenerateReferralCodeData {
  appVersion?: string;
  platform?: string;
}

/**
 * Generates (or returns existing) referral code for a Google-signed-in user.
 * Requires v1.6.0+.
 */
export const generateReferralCode = onCall<GenerateReferralCodeData>(
  { invoker: 'public', enforceAppCheck: false },
  async (request) => {
    const { auth, data } = request;
    const resolvedPlatform = String(data.platform ?? '').trim().toLowerCase();

    if (!auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    if (!meetsVersionRequirement(data.appVersion)) {
      throw new HttpsError('failed-precondition', 'VERSION_TOO_OLD');
    }

    // Must be Google-signed-in (not anonymous)
    const user = await admin.auth().getUser(auth.uid);
    const isGoogle = user.providerData.some((p) => p.providerId === 'google.com');
    if (!isGoogle) {
      throw new HttpsError('permission-denied', 'GOOGLE_SIGN_IN_REQUIRED');
    }

    const shouldBlockReferralShare =
      isMobilePlatform(resolvedPlatform) &&
      meetsMinimumVersion(data.appVersion, REFERRAL_SHARE_INTEGRITY_MIN_VERSION) &&
      !request.app;
    if (shouldBlockReferralShare) {
      throw new HttpsError('failed-precondition', 'REFERRAL_SHARE_UNTRUSTED_DEVICE');
    }

    const db = admin.firestore();
    const userRef = db.collection('users').doc(auth.uid);

    // Check if user already has a referral code
    const userDoc = await userRef.get();
    const existingCode = userDoc.data()?.referralCode;
    if (existingCode) {
      return { referralCode: existingCode };
    }

    // Generate a unique code
    let code = generateCode(auth.uid);
    let attempts = 0;
    while (attempts < 5) {
      const existing = await db.collection('referral_codes').doc(code).get();
      if (!existing.exists) break;
      code = generateCode(auth.uid + attempts);
      attempts++;
    }

    // Save code
    const batch = db.batch();
    batch.set(db.collection('referral_codes').doc(code), {
      ownerUid: auth.uid,
      ownerEmail: user.email ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      totalClaims: 0,
    });
    batch.set(userRef, { referralCode: code }, { merge: true });
    await batch.commit();

    console.log(`✅ Referral code generated: ${code} for user ${auth.uid}`);
    return { referralCode: code };
  }
);
