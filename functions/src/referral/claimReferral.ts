import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { meetsVersionRequirement, REFERRAL_REWARD } from './referralUtils';
import { assertFreeRewardsAllowed } from '../billing/regionPolicy';
import {
  REFERRAL_TOKENS,
  grantWalletTokensInTx,
  shouldUseTokenWallet,
} from '../billing/tokenWallet';
import {
  loadActiveGrantLots,
  type GrantLotDoc,
} from '../billing/tokenGrantLots';

interface ClaimReferralData {
  referralCode: string;
  deviceId: string;
  appVersion?: string;
  platform?: string;
  countryCodes?: string[];
  timeZoneOffsetMinutes?: number;
}

function grantReferralCreditsInTx(args: {
  tx: FirebaseFirestore.Transaction;
  userRef: FirebaseFirestore.DocumentReference;
  userData: FirebaseFirestore.DocumentData;
  amount: number;
  reason: string;
  metadata: Record<string, unknown>;
  auditId: string;
}): void {
  const currentFreeRaw = Number(args.userData.freeCredits ?? 0);
  const currentFree = Number.isFinite(currentFreeRaw)
    ? Math.max(0, Math.floor(currentFreeRaw))
    : 0;
  args.tx.set(args.userRef, {
    freeCredits: currentFree + args.amount,
  }, { merge: true });
  args.tx.set(args.userRef.collection('credit_transactions').doc(args.auditId), {
    type: 'add',
    amount: args.amount,
    reason: args.reason,
    source: 'referral',
    creditType: 'free',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    ...args.metadata,
  });
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
    const { referralCode, deviceId, appVersion, platform, countryCodes, timeZoneOffsetMinutes } = data;

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
      appVersion,
    });

    const codeRef = db.collection('referral_codes').doc(trimmedCode);
    const deviceClaimRef = db.collection('referral_device_claims').doc(trimmedDeviceId);
    const userClaimRef = db.collection('referral_claims_by_user').doc(auth.uid);
    const legacyUserClaimQuery = db.collection('referral_claims')
      .where('claimerUid', '==', auth.uid)
      .limit(1);
    const claimRef = db.collection('referral_claims').doc();
    const useWallet = shouldUseTokenWallet({ appVersion, platform });
    const result = await db.runTransaction(async (tx) => {
      // Read the code first because it identifies the second wallet owner.
      const codeDoc = await tx.get(codeRef);
      if (!codeDoc.exists) {
        throw new HttpsError('not-found', 'REFERRAL_CODE_NOT_FOUND');
      }
      const referrerUid = String(codeDoc.data()?.ownerUid ?? '').trim();
      if (!referrerUid) {
        throw new HttpsError('failed-precondition', 'REFERRER_NOT_FOUND');
      }
      if (referrerUid === auth.uid) {
        throw new HttpsError('failed-precondition', 'CANNOT_USE_OWN_CODE');
      }

      const claimerRef = db.collection('users').doc(auth.uid);
      const referrerRef = db.collection('users').doc(referrerUid);

      // Firestore transactions require every read before the first write.
      const deviceClaimDoc = await tx.get(deviceClaimRef);
      const userClaimDoc = await tx.get(userClaimRef);
      const legacyUserClaim = await tx.get(legacyUserClaimQuery);
      const claimerDoc = await tx.get(claimerRef);
      const referrerDoc = await tx.get(referrerRef);
      let claimerLots: GrantLotDoc[] = [];
      let referrerLots: GrantLotDoc[] = [];
      if (useWallet) {
        claimerLots = await loadActiveGrantLots(tx, claimerRef);
        referrerLots = await loadActiveGrantLots(tx, referrerRef);
      }

      if (deviceClaimDoc.exists) {
        throw new HttpsError('already-exists', 'DEVICE_ALREADY_CLAIMED');
      }
      if (userClaimDoc.exists || !legacyUserClaim.empty) {
        throw new HttpsError('already-exists', 'USER_ALREADY_CLAIMED');
      }

      const claimedAt = admin.firestore.FieldValue.serverTimestamp();
      const claimData = {
        claimId: claimRef.id,
        referralCode: trimmedCode,
        referrerUid,
        claimerUid: auth.uid,
        claimerEmail: user.email ?? null,
        deviceId: trimmedDeviceId,
        claimedAt,
      };
      tx.create(claimRef, claimData);
      tx.create(deviceClaimRef, {
        claimId: claimRef.id,
        claimerUid: auth.uid,
        referralCode: trimmedCode,
        claimedAt,
      });
      tx.create(userClaimRef, claimData);
      tx.update(codeRef, {
        totalClaims: admin.firestore.FieldValue.increment(1),
      });

      const claimerData = claimerDoc.exists ? (claimerDoc.data() ?? {}) : {};
      const referrerData = referrerDoc.exists ? (referrerDoc.data() ?? {}) : {};
      if (useWallet) {
        const now = new Date();
        const claimerOriginId = `referral_claim_${claimRef.id}`;
        const referrerOriginId = `referral_reward_${claimRef.id}`;
        grantWalletTokensInTx({
          tx,
          userRef: claimerRef,
          uid: auth.uid,
          userData: claimerData,
          tokens: REFERRAL_TOKENS,
          reason: 'referral_claim',
          source: 'referral',
          asGrant: true,
          grantOriginId: claimerOriginId,
          metadata: {
            referralCode: trimmedCode,
            role: 'claimer',
            originId: claimerOriginId,
          },
          activeGrantLots: claimerLots,
          now,
        });
        grantWalletTokensInTx({
          tx,
          userRef: referrerRef,
          uid: referrerUid,
          userData: referrerData,
          tokens: REFERRAL_TOKENS,
          reason: 'referral_reward',
          source: 'referral',
          asGrant: true,
          grantOriginId: referrerOriginId,
          metadata: {
            referralCode: trimmedCode,
            role: 'referrer',
            claimerUid: auth.uid,
            originId: referrerOriginId,
          },
          activeGrantLots: referrerLots,
          now,
        });
      } else {
        grantReferralCreditsInTx({
          tx,
          userRef: claimerRef,
          userData: claimerData,
          amount: REFERRAL_REWARD,
          reason: 'referral_claim',
          metadata: { referralCode: trimmedCode, role: 'claimer' },
          auditId: `referral_claim_${claimRef.id}`,
        });
        grantReferralCreditsInTx({
          tx,
          userRef: referrerRef,
          userData: referrerData,
          amount: REFERRAL_REWARD,
          reason: 'referral_reward',
          metadata: {
            referralCode: trimmedCode,
            role: 'referrer',
            claimerUid: auth.uid,
          },
          auditId: `referral_reward_${claimRef.id}`,
        });
      }

      return { referrerUid };
    });

    console.log(
      `✅ Referral claimed${useWallet ? ' (tokens)' : ''}: `
      + `code=${trimmedCode}, claimer=${auth.uid}, referrer=${result.referrerUid}`,
    );
    if (useWallet) {
      return {
        success: true,
        creditsAwarded: 0,
        tokensAwarded: REFERRAL_TOKENS,
      };
    }
    return { success: true, creditsAwarded: REFERRAL_REWARD, tokensAwarded: 0 };
  }
);
