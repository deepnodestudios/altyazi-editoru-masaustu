import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { meetsVersionRequirement, grantFreeCredits, REFERRAL_REWARD } from './referralUtils';
import { assertFreeRewardsAllowed } from '../billing/regionPolicy';

interface ClaimReferralData {
  referralCode: string;
  deviceId: string;
  appVersion?: string;
  countryCodes?: string[];
  timeZoneOffsetMinutes?: number;
}

/**
 * Claims a referral code. Awards REFERRAL_REWARD free credits to both
 * the referrer and the new user. Device-based fraud protection ensures
 * each device can only trigger one referral reward.
 *
 * Requires Google sign-in and v1.6.0+.
 */
export const claimReferral = onCall<ClaimReferralData>(
  { invoker: 'public', enforceAppCheck: false },
  async (request) => {
    const { auth, data } = request;
    const { referralCode, deviceId, appVersion, countryCodes, timeZoneOffsetMinutes } = data;

    if (!auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    if (!meetsVersionRequirement(appVersion)) {
      throw new HttpsError('failed-precondition', 'VERSION_TOO_OLD');
    }

    const trimmedCode = (referralCode ?? '').trim().toUpperCase();
    const trimmedDeviceId = (deviceId ?? '').trim();

    if (!trimmedCode || trimmedCode.length < 4) {
      throw new HttpsError('invalid-argument', 'INVALID_REFERRAL_CODE');
    }
    if (!trimmedDeviceId) {
      throw new HttpsError('invalid-argument', 'DEVICE_ID_REQUIRED');
    }

    // Must be Google-signed-in
    const user = await admin.auth().getUser(auth.uid);
    const isGoogle = user.providerData.some((p) => p.providerId === 'google.com');
    if (!isGoogle) {
      throw new HttpsError('permission-denied', 'GOOGLE_SIGN_IN_REQUIRED');
    }

    const db = admin.firestore();

    await assertFreeRewardsAllowed({
      db,
      uid: auth.uid,
      countryCodes,
      timeZoneOffsetMinutes,
    });

    // 1. Validate referral code exists
    const codeRef = db.collection('referral_codes').doc(trimmedCode);
    const codeDoc = await codeRef.get();
    if (!codeDoc.exists) {
      throw new HttpsError('not-found', 'REFERRAL_CODE_NOT_FOUND');
    }

    const codeData = codeDoc.data()!;
    const referrerUid = codeData.ownerUid;

    // Cannot use own code
    if (referrerUid === auth.uid) {
      throw new HttpsError('failed-precondition', 'CANNOT_USE_OWN_CODE');
    }

    // 2. Device fraud check: each device can only claim once
    const deviceClaimRef = db.collection('referral_device_claims').doc(trimmedDeviceId);
    const deviceClaimDoc = await deviceClaimRef.get();
    if (deviceClaimDoc.exists) {
      throw new HttpsError('already-exists', 'DEVICE_ALREADY_CLAIMED');
    }

    // 3. User can only claim one referral code ever
    const userClaimQuery = await db.collection('referral_claims')
      .where('claimerUid', '==', auth.uid)
      .limit(1)
      .get();
    if (!userClaimQuery.empty) {
      throw new HttpsError('already-exists', 'USER_ALREADY_CLAIMED');
    }

    // 4. All checks passed — grant rewards atomically
    const claimRef = db.collection('referral_claims').doc();
    const batch = db.batch();

    // Record the claim
    batch.set(claimRef, {
      referralCode: trimmedCode,
      referrerUid,
      claimerUid: auth.uid,
      claimerEmail: user.email ?? null,
      deviceId: trimmedDeviceId,
      claimedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Record device claim (fraud prevention)
    batch.set(deviceClaimRef, {
      claimerUid: auth.uid,
      referralCode: trimmedCode,
      claimedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Increment total claims on the code
    batch.update(codeRef, {
      totalClaims: admin.firestore.FieldValue.increment(1),
    });

    await batch.commit();

    // Grant free credits to both parties (non-transactional, idempotent via audit)
    await Promise.all([
      grantFreeCredits({
        db,
        uid: auth.uid,
        amount: REFERRAL_REWARD,
        reason: 'referral_claim',
        source: 'referral',
        metadata: { referralCode: trimmedCode, role: 'claimer' },
      }),
      grantFreeCredits({
        db,
        uid: referrerUid,
        amount: REFERRAL_REWARD,
        reason: 'referral_reward',
        source: 'referral',
        metadata: { referralCode: trimmedCode, role: 'referrer', claimerUid: auth.uid },
      }),
    ]);

    console.log(`✅ Referral claimed: code=${trimmedCode}, claimer=${auth.uid}, referrer=${referrerUid}`);
    return { success: true, creditsAwarded: REFERRAL_REWARD };
  }
);
