import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

import { shouldUseV163AdRewardRules, shouldUseV169DeviceAdRewardRules } from '../referral/referralUtils';
import { assertFreeRewardsAllowed } from './regionPolicy';
import {
  AD_REWARD_TOKENS,
  addGrantTokens,
  hydrateTokenWallet,
  shouldUseTokenWallet,
  tokenWalletUserFields,
} from './tokenWallet';

const AD_REWARD_VIEWS_PER_CREDIT = 5;
const DAILY_AD_REWARD_VIEW_LIMIT = 5;
const WEEKLY_AD_REWARD_CREDIT_LIMIT = 2;
const DAILY_AD_REWARD_VIEW_LIMIT_TOKEN = 10;
const WEEKLY_AD_REWARD_VIEW_LIMIT_TOKEN = 40;

interface AdRewardData {
  deviceId?: string;
  appVersion?: string;
  platform?: string;
  countryCodes?: string[];
  timeZoneOffsetMinutes?: number;
}

type RewardLimits = {
  daily: number;
  weekly: number;
  viewsPerReward: number;
};

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

function adRewardLimits(useWallet: boolean): RewardLimits {
  if (useWallet) {
    return {
      daily: DAILY_AD_REWARD_VIEW_LIMIT_TOKEN,
      weekly: WEEKLY_AD_REWARD_VIEW_LIMIT_TOKEN,
      viewsPerReward: 1,
    };
  }
  return {
    daily: DAILY_AD_REWARD_VIEW_LIMIT,
    weekly: WEEKLY_AD_REWARD_CREDIT_LIMIT,
    viewsPerReward: AD_REWARD_VIEWS_PER_CREDIT,
  };
}

function emptyRewardState(now = new Date()): RewardState {
  return {
    adRewardCredits: 0,
    progressViews: 0,
    dailyViews: 0,
    weeklyCredits: 0,
    todayKey: utcDayKey(now),
    weekKey: utcWeekKey(now),
  };
}

function normalizeRewardState(
  userData: Record<string, unknown>,
  now: Date,
  limits: RewardLimits,
): RewardState {
  const todayKey = utcDayKey(now);
  const weekKey = utcWeekKey(now);

  const storedDailyKey = String(userData.adRewardDailyKey ?? '').trim();
  const storedWeekKey = String(userData.adRewardWeeklyKey ?? '').trim();

  const dailyViews = storedDailyKey === todayKey
    ? Math.min(limits.daily, clampNonNegativeInt(userData.adRewardDailyViews))
    : 0;
  const weeklyCredits = storedWeekKey === weekKey
    ? Math.min(limits.weekly, clampNonNegativeInt(userData.adRewardWeeklyCredits))
    : 0;

  return {
    adRewardCredits: clampNonNegativeInt(userData.adRewardCredits),
    progressViews: Math.min(
      Math.max(0, limits.viewsPerReward - 1),
      clampNonNegativeInt(userData.adRewardProgressViews),
    ),
    dailyViews,
    weeklyCredits,
    todayKey,
    weekKey,
  };
}

function buildStatus(
  state: RewardState,
  supported: boolean,
  limits: RewardLimits,
  useWallet: boolean,
): Record<string, unknown> {
  const allowed = supported &&
    state.dailyViews < limits.daily &&
    state.weeklyCredits < limits.weekly;

  return {
    supported,
    allowed,
    adRewardCredits: state.adRewardCredits,
    progressViews: state.progressViews,
    viewsPerCredit: limits.viewsPerReward,
    dailyViews: state.dailyViews,
    dailyViewLimit: limits.daily,
    weeklyCredits: state.weeklyCredits,
    weeklyCreditLimit: limits.weekly,
    remainingViewsToday: Math.max(0, limits.daily - state.dailyViews),
    remainingCreditsThisWeek: Math.max(0, limits.weekly - state.weeklyCredits),
    tokensPerReward: useWallet ? AD_REWARD_TOKENS : null,
  };
}

function resolveWalletMode(data: AdRewardData): { useWallet: boolean; limits: RewardLimits } {
  const platform = String(data.platform ?? '').trim().toLowerCase() || null;
  const useWallet = shouldUseTokenWallet({
    appVersion: data.appVersion,
    platform,
  });
  return { useWallet, limits: adRewardLimits(useWallet) };
}

export const getAdRewardStatus = onCall<AdRewardData>(
  { invoker: 'public', enforceAppCheck: false },
  async (request) => {
    const { auth, data } = request;
    const { useWallet, limits } = resolveWalletMode(data);
    const supported = shouldUseV163AdRewardRules({
      appVersion: data.appVersion,
      platform: data.platform,
    });

    if (!supported) {
      return buildStatus(emptyRewardState(), false, limits, useWallet);
    }

    const useDeviceRules = shouldUseV169DeviceAdRewardRules({
      appVersion: data.appVersion,
      platform: data.platform,
    });

    if (!auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const db = admin.firestore();
    await assertFreeRewardsAllowed({
      db,
      uid: auth.uid,
      countryCodes: data.countryCodes,
      timeZoneOffsetMinutes: data.timeZoneOffsetMinutes,
      appVersion: data.appVersion,
    });

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

    const state = normalizeRewardState(stateData, new Date(), limits);
    return buildStatus(state, true, limits, useWallet);
  },
);

export const recordAdRewardWatch = onCall<AdRewardData>(
  { invoker: 'public', enforceAppCheck: false },
  async (request) => {
    const { auth, data } = request;
    const { useWallet, limits } = resolveWalletMode(data);

    if (!shouldUseV163AdRewardRules({
      appVersion: data.appVersion,
      platform: data.platform,
    })) {
      return {
        success: true,
        skipped: true,
        ...buildStatus(emptyRewardState(), false, limits, useWallet),
      };
    }

    const useDeviceRules = shouldUseV169DeviceAdRewardRules({
      appVersion: data.appVersion,
      platform: data.platform,
    });

    if (!auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const db = admin.firestore();
    await assertFreeRewardsAllowed({
      db,
      uid: auth.uid,
      countryCodes: data.countryCodes,
      timeZoneOffsetMinutes: data.timeZoneOffsetMinutes,
      appVersion: data.appVersion,
    });

    const deviceId = (data.deviceId ?? '').trim();
    if (useDeviceRules && !deviceId) {
      throw new HttpsError('invalid-argument', 'DEVICE_ID_REQUIRED_FOR_V169');
    }

    const platform = String(data.platform ?? '').trim().toLowerCase() || null;
    const targetRef = useDeviceRules
      ? db.collection('device_bonuses').doc(deviceId)
      : db.collection('users').doc(auth.uid);
    const userRef = db.collection('users').doc(auth.uid);

    return db.runTransaction(async (tx) => {
      const targetDoc = await tx.get(targetRef);
      const userDoc = useWallet ? await tx.get(userRef) : null;
      const now = new Date();
      const targetData = targetDoc.data() ?? {};
      const state = normalizeRewardState(targetData, now, limits);

      if (state.dailyViews >= limits.daily ||
          state.weeklyCredits >= limits.weekly) {
        throw new HttpsError('resource-exhausted', 'AD_REWARD_LIMIT_REACHED');
      }

      const dailyViews = state.dailyViews + 1;
      let progressViews = state.progressViews;
      let weeklyCredits = state.weeklyCredits;
      let adRewardCredits = state.adRewardCredits;
      let earnedCredit = false;
      let tokensGranted = 0;
      let walletState = useWallet
        ? hydrateTokenWallet({
            userData: userDoc?.data() ?? {},
            deviceData: useDeviceRules ? targetData : undefined,
          })
        : null;

      if (useWallet && walletState) {
        weeklyCredits += 1;
        earnedCredit = true;
        tokensGranted = AD_REWARD_TOKENS;
        walletState = addGrantTokens(walletState, AD_REWARD_TOKENS);
        progressViews = 0;
      } else {
        progressViews = state.progressViews + 1;
        if (progressViews >= AD_REWARD_VIEWS_PER_CREDIT) {
          if (weeklyCredits >= limits.weekly) {
            throw new HttpsError('resource-exhausted', 'AD_REWARD_LIMIT_REACHED');
          }
          progressViews -= AD_REWARD_VIEWS_PER_CREDIT;
          weeklyCredits += 1;
          earnedCredit = true;
          adRewardCredits += 1;
        }
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
        lastAdRewardUserId: auth?.uid ?? null,
      };

      if (useWallet) {
        updateData.adRewardCredits = 0;
      }

      if (useDeviceRules && !targetDoc.exists) {
        updateData.deviceCredits = 0;
        updateData.totalBonusConsumed = 0;
        updateData.adRewardOnlyInit = true;
      }

      tx.set(targetRef, updateData, { merge: true });
      if (useWallet && walletState && (
        tokensGranted > 0
        || walletState.snapshotPending
        || walletState.convertedBonusTokens > 0
      )) {
        tx.set(userRef, tokenWalletUserFields(walletState), { merge: true });
      }

      if (earnedCredit) {
        const txRef = (useWallet ? userRef : targetRef).collection('credit_transactions').doc();
        tx.set(txRef, {
          type: 'add',
          amount: useWallet ? tokensGranted : 1,
          unit: useWallet ? 'token' : 'credit',
          reason: 'ad_reward',
          source: 'ad_reward',
          creditType: useWallet ? 'token_grant' : 'ad_reward',
          deviceId: deviceId.length === 0 ? null : deviceId,
          platform,
          progressViews,
          weeklyCredits,
          remainingTokenBalance: walletState?.tokenBalance ?? null,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      const nextState: RewardState = {
        adRewardCredits: useWallet ? 0 : adRewardCredits,
        progressViews,
        dailyViews,
        weeklyCredits,
        todayKey: state.todayKey,
        weekKey: state.weekKey,
      };

      return {
        success: true,
        earnedCredit,
        tokensGranted,
        tokenBalance: walletState?.tokenBalance ?? 0,
        ...buildStatus(nextState, true, limits, useWallet),
      };
    });
  },
);

export {
  AD_REWARD_VIEWS_PER_CREDIT,
  DAILY_AD_REWARD_VIEW_LIMIT,
  WEEKLY_AD_REWARD_CREDIT_LIMIT,
  DAILY_AD_REWARD_VIEW_LIMIT_TOKEN,
  WEEKLY_AD_REWARD_VIEW_LIMIT_TOKEN,
};
