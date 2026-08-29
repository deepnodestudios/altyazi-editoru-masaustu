/**
 * Region policy for free-credit earning restrictions.
 * Uses geography only (country code OR distinctive timezone). Language is
 * ignored so diaspora users can use vernacular languages abroad without
 * restriction.
 *
 * Legacy (all app versions): IR, IN + UTC+3:30 / UTC+5:30.
 * Wave 1.7.6+: first low-eCPM expansion (South Asia / SEA / core Africa / MENA).
 * Wave 1.7.7+: additional African low-eCPM countries.
 */

import { HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { meetsMinimumVersion } from '../referral/referralUtils';

export const IRAN_OFFSET_MINUTES = 210;
export const INDIA_OFFSET_MINUTES = 330;

/** First expanded country wave (after IR/IN). */
export const EXPANDED_GEO_V176_MIN_VERSION = '1.7.6';

/** Second wave: extra African countries. */
export const EXPANDED_GEO_V177_MIN_VERSION = '1.7.7';

/** @deprecated Use EXPANDED_GEO_V177_MIN_VERSION; kept for older imports. */
export const EXPANDED_GEO_RESTRICT_MIN_VERSION = EXPANDED_GEO_V177_MIN_VERSION;

/** Always restricted (Iran / India). */
export const LEGACY_RESTRICTED_COUNTRY_CODES = new Set(['IR', 'IN']);

/** Applied when appVersion >= 1.7.6. */
export const EXPANDED_RESTRICTED_COUNTRY_CODES_V176 = new Set([
  // South Asia
  'PK',
  'BD',
  'NP',
  'LK',
  'AF',
  // Southeast Asia (very low eCPM)
  'MM',
  'KH',
  'LA',
  // Africa (first wave)
  'NG',
  'ET',
  'KE',
  'GH',
  'TZ',
  'UG',
  'CD',
  'SD',
  // MENA (low demand)
  'IQ',
  'YE',
  'SY',
]);

/** Applied when appVersion >= 1.7.7. */
export const EXPANDED_RESTRICTED_COUNTRY_CODES_V177 = new Set([
  'CM',
  'CI',
  'SN',
  'ML',
  'BF',
  'NE',
  'TD',
  'MG',
  'MZ',
  'ZM',
  'ZW',
  'AO',
  'RW',
  'BI',
  'SO',
  'LR',
  'SL',
  'GN',
  'TG',
  'BJ',
  'MW',
  'SS',
]);

/** @deprecated Prefer V176 / V177 sets. Full union for docs. */
export const EXPANDED_RESTRICTED_COUNTRY_CODES = new Set([
  ...EXPANDED_RESTRICTED_COUNTRY_CODES_V176,
  ...EXPANDED_RESTRICTED_COUNTRY_CODES_V177,
]);

/** Full set for docs / clients on latest. */
export const RESTRICTED_COUNTRY_CODES = new Set([
  ...LEGACY_RESTRICTED_COUNTRY_CODES,
  ...EXPANDED_RESTRICTED_COUNTRY_CODES_V176,
  ...EXPANDED_RESTRICTED_COUNTRY_CODES_V177,
]);

export const RESTRICTED_STARTER_BONUS = 1;

function normalizeCountryCode(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim().toUpperCase();
  return trimmed.length === 2 ? trimmed : null;
}

function collectCountryCodes(countryCodes?: unknown): Set<string> {
  const codes = new Set<string>();
  if (Array.isArray(countryCodes)) {
    for (const item of countryCodes) {
      const normalized = normalizeCountryCode(item);
      if (normalized) codes.add(normalized);
    }
  } else {
    const single = normalizeCountryCode(countryCodes);
    if (single) codes.add(single);
  }
  return codes;
}

function activeRestrictedCountryCodes(appVersion?: unknown): Set<string> {
  const version = typeof appVersion === 'string' ? appVersion : null;
  const codes = new Set(LEGACY_RESTRICTED_COUNTRY_CODES);

  if (meetsMinimumVersion(version, EXPANDED_GEO_V176_MIN_VERSION)) {
    for (const code of EXPANDED_RESTRICTED_COUNTRY_CODES_V176) {
      codes.add(code);
    }
  }
  if (meetsMinimumVersion(version, EXPANDED_GEO_V177_MIN_VERSION)) {
    for (const code of EXPANDED_RESTRICTED_COUNTRY_CODES_V177) {
      codes.add(code);
    }
  }
  return codes;
}

function matchedRestrictedCountry(
  countries: Set<string>,
  restricted: Set<string>,
): string | null {
  for (const code of countries) {
    if (restricted.has(code)) return code;
  }
  return null;
}

export function isGeoFreeRewardsRestricted(args: {
  countryCodes?: unknown;
  timeZoneOffsetMinutes?: unknown;
  appVersion?: unknown;
}): boolean {
  const countries = collectCountryCodes(args.countryCodes);
  const offsetRaw = Number(args.timeZoneOffsetMinutes);
  const offsetMinutes = Number.isFinite(offsetRaw) ? Math.trunc(offsetRaw) : NaN;
  const restricted = activeRestrictedCountryCodes(args.appVersion);

  if (matchedRestrictedCountry(countries, restricted) != null) return true;
  // Distinctive half-hour offsets (Iran / India) — all app versions.
  if (offsetMinutes === IRAN_OFFSET_MINUTES) return true;
  if (offsetMinutes === INDIA_OFFSET_MINUTES) return true;
  return false;
}

/** Geography-only restriction check (language is intentionally ignored). */
export function isFreeRewardsRestricted(args: {
  countryCodes?: unknown;
  timeZoneOffsetMinutes?: unknown;
  languageCodes?: unknown;
  appVersion?: unknown;
}): boolean {
  return isGeoFreeRewardsRestricted(args);
}

export function restrictedReason(args: {
  countryCodes?: unknown;
  timeZoneOffsetMinutes?: unknown;
  languageCodes?: unknown;
  appVersion?: unknown;
}): string | null {
  if (!isGeoFreeRewardsRestricted(args)) return null;

  const countries = collectCountryCodes(args.countryCodes);
  const offsetRaw = Number(args.timeZoneOffsetMinutes);
  const offsetMinutes = Number.isFinite(offsetRaw) ? Math.trunc(offsetRaw) : NaN;
  const restricted = activeRestrictedCountryCodes(args.appVersion);

  const matched = matchedRestrictedCountry(countries, restricted);
  if (matched) return matched;

  if (offsetMinutes === IRAN_OFFSET_MINUTES) return 'IR';
  if (offsetMinutes === INDIA_OFFSET_MINUTES) return 'IN';
  return 'RESTRICTED';
}

export type FreeRewardsRestrictionResolution = {
  restricted: boolean;
  reason: string | null;
  geoLocked: boolean;
  clearLegacyRestrictedFlag: boolean;
};

export function resolveFreeRewardsRestriction(args: {
  userData?: FirebaseFirestore.DocumentData | null;
  countryCodes?: unknown;
  timeZoneOffsetMinutes?: unknown;
  appVersion?: unknown;
}): FreeRewardsRestrictionResolution {
  const userData = args.userData ?? {};
  const geoLocked = userData.freeRewardsGeoLocked === true;
  const geoRestricted = isGeoFreeRewardsRestricted(args);

  if (geoLocked) {
    return {
      restricted: true,
      reason: typeof userData.freeRewardsRestrictedReason === 'string'
        ? userData.freeRewardsRestrictedReason
        : 'RESTRICTED',
      geoLocked: true,
      clearLegacyRestrictedFlag: false,
    };
  }

  if (geoRestricted) {
    return {
      restricted: true,
      reason: restrictedReason(args),
      geoLocked: true,
      clearLegacyRestrictedFlag: false,
    };
  }

  const legacyFlag = userData.freeRewardsRestricted === true;
  if (legacyFlag) {
    return {
      restricted: false,
      reason: null,
      geoLocked: false,
      clearLegacyRestrictedFlag: true,
    };
  }

  return {
    restricted: false,
    reason: null,
    geoLocked: false,
    clearLegacyRestrictedFlag: false,
  };
}

export async function assertFreeRewardsAllowed(args: {
  db: admin.firestore.Firestore;
  uid: string;
  countryCodes?: unknown;
  timeZoneOffsetMinutes?: unknown;
  appVersion?: unknown;
}): Promise<void> {
  const userDoc = await args.db.collection('users').doc(args.uid).get();
  const resolution = resolveFreeRewardsRestriction({
    userData: userDoc.data(),
    countryCodes: args.countryCodes,
    timeZoneOffsetMinutes: args.timeZoneOffsetMinutes,
    appVersion: args.appVersion,
  });
  if (resolution.restricted) {
    throw new HttpsError('permission-denied', 'FREE_REWARDS_RESTRICTED');
  }
}
