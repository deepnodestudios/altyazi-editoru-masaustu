import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { shouldUseV160ClientRules } from '../referral/referralUtils';

const DAILY_AD_LIMIT = 5;

interface CheckAdLimitData {
  deviceId: string;
  appVersion?: string;
  platform?: string;
}

/**
 * Checks if a user has reached the daily ad-based translation limit.
 * Returns remaining ad translations for today.
 * Only active for v1.6.0+.
 */
export const checkDailyAdLimit = onCall<CheckAdLimitData>(
  { invoker: 'public', enforceAppCheck: false },
  async (request) => {
    const { auth, data } = request;

    if (!shouldUseV160ClientRules({
      appVersion: data.appVersion,
      platform: data.platform,
    })) {
      // Old versions don't have ad gates — no limit
      return { allowed: true, remaining: DAILY_AD_LIMIT, limit: DAILY_AD_LIMIT };
    }

    const uid = auth?.uid ?? null;
    const deviceId = (data.deviceId ?? '').trim();
    if (!deviceId) {
      throw new HttpsError('invalid-argument', 'DEVICE_ID_REQUIRED');
    }

    const db = admin.firestore();

    // Check if user is paid (subscribed) — no limit for paid users
    if (uid) {
      const userDoc = await db.collection('users').doc(uid).get();
      const userData = userDoc.data() ?? {};
      const purchasedCredits = Number(userData.purchasedCredits ?? userData.credits ?? 0);
      if (userData.isPaidUser || userData.subscriptionActive || purchasedCredits > 0) {
        return { allowed: true, remaining: DAILY_AD_LIMIT, limit: DAILY_AD_LIMIT, isPaid: true };
      }
    }

    // Check today's ad count
    const todayKey = new Date().toISOString().slice(0, 10); // "2026-04-09"
    const limitDocId = `${deviceId}_${todayKey}`;
    const limitRef = db.collection('daily_ad_usage').doc(limitDocId);
    const limitDoc = await limitRef.get();

    const currentCount = limitDoc.exists ? Number(limitDoc.data()?.count ?? 0) : 0;
    const remaining = Math.max(0, DAILY_AD_LIMIT - currentCount);

    return {
      allowed: remaining > 0,
      remaining,
      limit: DAILY_AD_LIMIT,
      isPaid: false,
    };
  }
);

interface RecordAdUsageData {
  deviceId: string;
  appVersion?: string;
  platform?: string;
}

/**
 * Records one ad-based translation usage. Called after the rewarded ad is watched.
 * Enforces the daily limit server-side.
 */
export const recordAdUsage = onCall<RecordAdUsageData>(
  { invoker: 'public', enforceAppCheck: false },
  async (request) => {
    const { auth, data } = request;

    if (!shouldUseV160ClientRules({
      appVersion: data.appVersion,
      platform: data.platform,
    })) {
      return { success: true, skipped: true };
    }

    const deviceId = (data.deviceId ?? '').trim();

    if (!deviceId) {
      throw new HttpsError('invalid-argument', 'DEVICE_ID_REQUIRED');
    }

    const db = admin.firestore();
    const todayKey = new Date().toISOString().slice(0, 10);
    const limitDocId = `${deviceId}_${todayKey}`;
    const limitRef = db.collection('daily_ad_usage').doc(limitDocId);

    await db.runTransaction(async (tx) => {
      const doc = await tx.get(limitRef);
      const currentCount = doc.exists ? Number(doc.data()?.count ?? 0) : 0;

      if (currentCount >= DAILY_AD_LIMIT) {
        throw new HttpsError('resource-exhausted', 'DAILY_AD_LIMIT_REACHED');
      }

      tx.set(limitRef, {
        deviceId,
        date: todayKey,
        uid: auth?.uid ?? null,
        count: currentCount + 1,
        lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });

    return { success: true };
  }
);

export { DAILY_AD_LIMIT };
