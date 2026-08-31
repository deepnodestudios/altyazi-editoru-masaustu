import * as admin from 'firebase-admin';
import { createHash, randomBytes } from 'crypto';

const REFERRAL_REWARD = 3; // Free credits per referral (both sides)
const MIN_APP_VERSION = '1.6.0';
const MIN_AD_REWARD_APP_VERSION = '1.6.3';
const MIN_DEVICE_AD_REWARD_APP_VERSION = '1.6.9';
const MIN_MOBILE_BONUS_POLICY_APP_VERSION = '1.7.5';
const MIN_DESKTOP_BONUS_POLICY_APP_VERSION = '1.7.4';
/** Desktop clients below this must update; translation APIs reject them. */
const MIN_DESKTOP_SUPPORTED_APP_VERSION = '1.7.6';

function parseVersion(value: string): { parts: number[]; build: number | null } {
  const trimmed = value.trim();
  const plusIndex = trimmed.indexOf('+');
  const versionPart = plusIndex >= 0 ? trimmed.slice(0, plusIndex) : trimmed;
  const buildPart = plusIndex >= 0 ? trimmed.slice(plusIndex + 1).trim() : '';
  const buildNumber = Number(buildPart);
  return {
    parts: versionPart.split('.').map((part) => Number(part) || 0),
    build: buildPart.length > 0 && Number.isFinite(buildNumber) ? buildNumber : null,
  };
}

function isVersionAtLeast(
  appVersion: string | null | undefined,
  minVersion: string,
): boolean {
  if (!appVersion) return false;
  const currentVersion = parseVersion(appVersion);
  const requiredVersion = parseVersion(minVersion);
  const maxLength = Math.max(currentVersion.parts.length, requiredVersion.parts.length, 3);
  for (let i = 0; i < maxLength; i++) {
    const current = currentVersion.parts[i] ?? 0;
    const required = requiredVersion.parts[i] ?? 0;
    if (current > required) return true;
    if (current < required) return false;
  }
  if (requiredVersion.build == null) {
    return true;
  }
  return (currentVersion.build ?? 0) >= requiredVersion.build;
}

export function isMobilePlatform(platform: string | null | undefined): boolean {
  const normalized = String(platform ?? '').trim().toLowerCase();
  return normalized === 'android' || normalized === 'ios';
}

/** Desktop clients cannot show rewarded ads, so bonus buckets must not be spent. */
export function isDesktopPlatform(platform: string | null | undefined): boolean {
  const normalized = String(platform ?? '').trim().toLowerCase();
  return (
    normalized === 'windows' ||
    normalized === 'mac' ||
    normalized === 'macos' ||
    normalized === 'linux'
  );
}

/**
 * Generates a unique 8-char referral code for a user.
 */
export function generateCode(uid: string): string {
  const hash = createHash('sha256').update(`${uid}_${Date.now()}_${randomBytes(8).toString('hex')}`).digest('hex');
  return hash.substring(0, 8).toUpperCase();
}

/**
 * Checks if the app version meets the minimum required version (>= 1.6.0).
 */
export function meetsVersionRequirement(appVersion: string | null | undefined): boolean {
  return isVersionAtLeast(appVersion, MIN_APP_VERSION);
}

export function meetsMinimumVersion(
  appVersion: string | null | undefined,
  minVersion: string,
): boolean {
  return isVersionAtLeast(appVersion, minVersion);
}

export function shouldUseV160ClientRules(args: {
  appVersion: string | null | undefined;
  platform: string | null | undefined;
}): boolean {
  return meetsVersionRequirement(args.appVersion) && isMobilePlatform(args.platform);
}

export function shouldUseV163AdRewardRules(args: {
  appVersion: string | null | undefined;
  platform: string | null | undefined;
}): boolean {
  return meetsMinimumVersion(args.appVersion, MIN_AD_REWARD_APP_VERSION) &&
    isMobilePlatform(args.platform);
}

export function shouldUseV169DeviceAdRewardRules(args: {
  appVersion: string | null | undefined;
  platform: string | null | undefined;
}): boolean {
  return meetsMinimumVersion(args.appVersion, MIN_DEVICE_AD_REWARD_APP_VERSION) &&
    isMobilePlatform(args.platform);
}

/** Purchase/subscription bonus grants (mobile Play clients). */
export function shouldGrantPurchaseBonus(
  appVersion: string | null | undefined,
): boolean {
  return meetsMinimumVersion(appVersion, MIN_MOBILE_BONUS_POLICY_APP_VERSION);
}

/** Desktop cannot show rewarded ads; enforce paid-only spend from v1.7.4+. */
export function shouldEnforceDesktopPaidCreditsOnly(args: {
  appVersion: string | null | undefined;
  platform: string | null | undefined;
}): boolean {
  return isDesktopPlatform(args.platform) &&
    meetsMinimumVersion(args.appVersion, MIN_DESKTOP_BONUS_POLICY_APP_VERSION);
}

/** True when a desktop client is older than the minimum supported release (1.7.6). */
export function isUnsupportedDesktopClient(args: {
  appVersion: string | null | undefined;
  platform: string | null | undefined;
}): boolean {
  return isDesktopPlatform(args.platform) &&
    !meetsMinimumVersion(args.appVersion, MIN_DESKTOP_SUPPORTED_APP_VERSION);
}

/**
 * Grants free credits to a user (referral bonus, monthly bonus, etc.).
 * Records the transaction in credit_transactions.
 */
export async function grantFreeCredits(args: {
  db: admin.firestore.Firestore;
  uid: string;
  amount: number;
  reason: string;
  source: string;
  metadata?: Record<string, any>;
}): Promise<void> {
  const { db, uid, amount, reason, source, metadata } = args;

  await db.runTransaction(async (tx) => {
    const userRef = db.collection('users').doc(uid);
    const userDoc = await tx.get(userRef);
    const userData = userDoc.exists ? (userDoc.data() ?? {}) : {};

    const currentFree = Number(userData.freeCredits ?? 0);
    const newFree = currentFree + amount;

    tx.set(userRef, { freeCredits: newFree }, { merge: true });

    const txRef = userRef.collection('credit_transactions').doc();
    tx.set(txRef, {
      type: 'add',
      amount,
      reason,
      source,
      creditType: 'free',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ...(metadata ?? {}),
    });
  });
}

export {
  REFERRAL_REWARD,
  MIN_APP_VERSION,
  MIN_AD_REWARD_APP_VERSION,
  MIN_DEVICE_AD_REWARD_APP_VERSION,
  MIN_MOBILE_BONUS_POLICY_APP_VERSION,
  MIN_DESKTOP_BONUS_POLICY_APP_VERSION,
  MIN_DESKTOP_SUPPORTED_APP_VERSION,
};
