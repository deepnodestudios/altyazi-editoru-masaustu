import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

import { shouldUseV163AdRewardRules, shouldUseV169DeviceAdRewardRules } from '../referral/referralUtils';

const AD_REWARD_VIEWS_PER_CREDIT = 5;
const DAILY_AD_REWARD_VIEW_LIMIT = 5;
const WEEKLY_AD_REWARD_CREDIT_LIMIT = 2;

interface AdRewardData {
  deviceId?: string;
  appVersion?: string;
  platform?: string;
}

type RewardState = {
  adRewardCredits: number;
  progressViews: number;
  dailyViews: number;
  weeklyCredits: number;
  todayKey: string;
  weekKey: string;
};

function clampNonNegativeInt(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return 0;
  }
  return Math.floor(parsed);
}

function utcDayKey(date: Date): string {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function utcWeekKey(date: Date): string {
  const normalized = new Date(Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth(),
    date.getUTCDate(),
  ));
  const weekday = normalized.getUTCDay() || 7;
  normalized.setUTCDate(normalized.getUTCDate() + 4 - weekday);
  const yearStart = new Date(Date.UTC(normalized.getUTCFullYear(), 0, 1));
  const dayOfYear = Math.floor(
    (normalized.getTime() - yearStart.getTime()) / 86400000,
  ) + 1;
  const weekNumber = Math.ceil(dayOfYear / 7);
  return `${normalized.getUTCFullYear()}-W${String(weekNumber).padStart(2, '0')}`;
}

function normalizeRewardState(userData: Record<string, unknown>, now: Date): RewardState {
  const todayKey = utcDayKey(now);
  const weekKey = utcWeekKey(now);

  const storedDailyKey = String(userData.adRewardDailyKey ?? '').trim();
  const storedWeekKey = String(userData.adRewardWeeklyKey ?? '').trim();

  const dailyViews = storedDailyKey === todayKey
    ? Math.min(DAILY_AD_REWARD_VIEW_LIMIT, clampNonNegativeInt(userData.adRewardDailyViews))
    : 0;
  const weeklyCredits = storedWeekKey === weekKey
    ? Math.min(WEEKLY_AD_REWARD_CREDIT_LIMIT, clampNonNegativeInt(userData.adRewardWeeklyCredits))
    : 0;

  return {
    adRewardCredits: clampNonNegativeInt(userData.adRewardCredits),
    progressViews: Math.min(
      AD_REWARD_VIEWS_PER_CREDIT - 1,
      clampNonNegativeInt(userData.adRewardProgressViews),
    ),
    dailyViews,
    weeklyCredits,
    todayKey,
    weekKey,
  };
}

function buildStatus(state: RewardState, supported: boolean): Record<string, unknown> {
  const allowed = supported &&
    state.dailyViews < DAILY_AD_REWARD_VIEW_LIMIT &&
    state.weeklyCredits < WEEKLY_AD_REWARD_CREDIT_LIMIT;

  return {
    supported,
    allowed,
    adRewardCredits: state.adRewardCredits,
    progressViews: state.progressViews,
    viewsPerCredit: AD_REWARD_VIEWS_PER_CREDIT,
    dailyViews: state.dailyViews,
    dailyViewLimit: DAILY_AD_REWARD_VIEW_LIMIT,
    weeklyCredits: state.weeklyCredits,
    weeklyCreditLimit: WEEKLY_AD_REWARD_CREDIT_LIMIT,
    remainingViewsToday: Math.max(0, DAILY_AD_REWARD_VIEW_LIMIT - state.dailyViews),
    remainingCreditsThisWeek: Math.max(0, WEEKLY_AD_REWARD_CREDIT_LIMIT - state.weeklyCredits),
  };
}

export const getAdRewardStatus = onCall<AdRewardData>(
  { invoker: 'public', enforceAppCheck: false },
  async (request) => {
    const { auth, data } = request;
    const supported = shouldUseV163AdRewardRules({
      appVersion: data.appVersion,
      platform: data.platform,
    });

    if (!supported) {
      return buildStatus({
        adRewardCredits: 0,
        progressViews: 0,
        dailyViews: 0,
        weeklyCredits: 0,
        todayKey: utcDayKey(new Date()),
        weekKey: utcWeekKey(new Date()),
      }, false);
    }

    const useDeviceRules = shouldUseV169DeviceAdRewardRules({
      appVersion: data.appVersion,
      platform: data.platform,
    });

    if (!auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const db = admin.firestore();
    let stateData: Record<string, unknown> = {};

    if (useDeviceRules) {
      const deviceId = (data.deviceId ?? '').trim();
      if (!deviceId) {
        throw new HttpsError('invalid-argument', 'DEVICE_ID_REQUIRED_FOR_V169');
      }
      const deviceDoc = await db.collection('device_bonuses').doc(deviceId).get();
      stateData = deviceDoc.data() ?? {};
    } else {
      const userDoc = await db.collection('users').doc(auth.uid).get();
      stateData = userDoc.data() ?? {};
    }

    const state = normalizeRewardState(stateData, new Date());
    return buildStatus(state, true);
  },
);

export const recordAdRewardWatch = onCall<AdRewardData>(
  { invoker: 'public', enforceAppCheck: false },
  async (request) => {
    const { auth, data } = request;

    if (!shouldUseV163AdRewardRules({
      appVersion: data.appVersion,
      platform: data.platform,
    })) {
      return { success: true, skipped: true, ...buildStatus({
        adRewardCredits: 0,
        progressViews: 0,
        dailyViews: 0,
        weeklyCredits: 0,
        todayKey: utcDayKey(new Date()),
        weekKey: utcWeekKey(new Date()),
      }, false) };
    }

    const useDeviceRules = shouldUseV169DeviceAdRewardRules({
      appVersion: data.appVersion,
      platform: data.platform,
    });

    if (!auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const db = admin.firestore();
    const deviceId = (data.deviceId ?? '').trim();
    if (useDeviceRules && !deviceId) {
      throw new HttpsError('invalid-argument', 'DEVICE_ID_REQUIRED_FOR_V169');
    }

    const platform = String(data.platform ?? '').trim().toLowerCase() || null;
    const targetRef = useDeviceRules
      ? db.collection('device_bonuses').doc(deviceId)
      : db.collection('users').doc(auth.uid);

    return db.runTransaction(async (tx) => {
      const targetDoc = await tx.get(targetRef);
      const now = new Date();
      const targetData = targetDoc.data() ?? {};
      const state = normalizeRewardState(targetData, now);

      if (state.dailyViews >= DAILY_AD_REWARD_VIEW_LIMIT ||
          state.weeklyCredits >= WEEKLY_AD_REWARD_CREDIT_LIMIT) {
        throw new HttpsError('resource-exhausted', 'AD_REWARD_LIMIT_REACHED');
      }

      let progressViews = state.progressViews + 1;
      const dailyViews = state.dailyViews + 1;
      let weeklyCredits = state.weeklyCredits;
      let adRewardCredits = state.adRewardCredits;
      let earnedCredit = false;

      if (progressViews >= AD_REWARD_VIEWS_PER_CREDIT) {
        if (weeklyCredits >= WEEKLY_AD_REWARD_CREDIT_LIMIT) {
          throw new HttpsError('resource-exhausted', 'AD_REWARD_LIMIT_REACHED');
        }

        progressViews -= AD_REWARD_VIEWS_PER_CREDIT;
        weeklyCredits += 1;
        adRewardCredits += 1;
        earnedCredit = true;
      }

      const updateData: Record<string, any> = {
        adRewardCredits,
        adRewardProgressViews: progressViews,
        adRewardDailyViews: dailyViews,
        adRewardDailyKey: state.todayKey,
        adRewardWeeklyCredits: weeklyCredits,
        adRewardWeeklyKey: state.weekKey,
        lastAdRewardAt: admin.firestore.FieldValue.serverTimestamp(),
        lastAdRewardDeviceId: deviceId.length === 0 ? null : deviceId,
        lastAdRewardUserId: auth?.uid ?? null, // track user id when bound to device
      };

      if (useDeviceRules && !targetDoc.exists) {
        updateData.deviceCredits = 0;
        updateData.totalBonusConsumed = 0;
        updateData.adRewardOnlyInit = true;
      }

      tx.set(targetRef, updateData, { merge: true });

      if (earnedCredit) {
        const txRef = targetRef.collection('credit_transactions').doc();
        tx.set(txRef, {
          type: 'add',
          amount: 1,
          reason: 'ad_reward',
          source: 'ad_reward',
          creditType: 'ad_reward',
          deviceId: deviceId.length === 0 ? null : deviceId,
          platform,
          progressViews,
          weeklyCredits,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      const nextState: RewardState = {
        adRewardCredits,
        progressViews,
        dailyViews,
        weeklyCredits,
        todayKey: state.todayKey,
        weekKey: state.weekKey,
      };

      return {
        success: true,
        earnedCredit,
        ...buildStatus(nextState, true),
      };
    });
  },
);

export {
  AD_REWARD_VIEWS_PER_CREDIT,
  DAILY_AD_REWARD_VIEW_LIMIT,
  WEEKLY_AD_REWARD_CREDIT_LIMIT,
};