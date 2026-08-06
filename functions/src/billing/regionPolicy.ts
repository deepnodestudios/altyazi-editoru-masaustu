/**
 * Region policy for free-credit earning restrictions.
 * Uses geography only (country code OR timezone). Language is ignored so
 * diaspora users can use vernacular languages abroad without restriction.
 *
 * Iran: country IR OR UTC+3:30 (210 minutes)
 * India: country IN OR UTC+5:30 (330 minutes)
 */

import { HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

export const IRAN_OFFSET_MINUTES = 210;
export const INDIA_OFFSET_MINUTES = 330;

export const IRAN_COUNTRY_CODES = new Set(['IR']);
export const INDIA_COUNTRY_CODES = new Set(['IN']);

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

export function isGeoFreeRewardsRestricted(args: {
  countryCodes?: unknown;
  timeZoneOffsetMinutes?: unknown;
}): boolean {
  const countries = collectCountryCodes(args.countryCodes);
  const offsetRaw = Number(args.timeZoneOffsetMinutes);
  const offsetMinutes = Number.isFinite(offsetRaw) ? Math.trunc(offsetRaw) : NaN;

  const iranCountry = [...countries].some((code) => IRAN_COUNTRY_CODES.has(code));
  const indiaCountry = [...countries].some((code) => INDIA_COUNTRY_CODES.has(code));
  const iranTimezone = offsetMinutes === IRAN_OFFSET_MINUTES;
  const indiaTimezone = offsetMinutes === INDIA_OFFSET_MINUTES;

  return iranCountry || indiaCountry || iranTimezone || indiaTimezone;
}

/** Geography-only restriction check (language is intentionally ignored). */
export function isFreeRewardsRestricted(args: {
  countryCodes?: unknown;
  timeZoneOffsetMinutes?: unknown;
  languageCodes?: unknown;
}): boolean {
  return isGeoFreeRewardsRestricted(args);
}

export function restrictedReason(args: {
  countryCodes?: unknown;
  timeZoneOffsetMinutes?: unknown;
  languageCodes?: unknown;
}): string | null {
  if (!isGeoFreeRewardsRestricted(args)) return null;

  const countries = collectCountryCodes(args.countryCodes);
  const offsetRaw = Number(args.timeZoneOffsetMinutes);
  const offsetMinutes = Number.isFinite(offsetRaw) ? Math.trunc(offsetRaw) : NaN;

  if ([...countries].some((code) => IRAN_COUNTRY_CODES.has(code)) ||
      offsetMinutes === IRAN_OFFSET_MINUTES) {
    return 'IR';
  }
  if ([...countries].some((code) => INDIA_COUNTRY_CODES.has(code)) ||
      offsetMinutes === INDIA_OFFSET_MINUTES) {
    return 'IN';
  }
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
}): Promise<void> {
  const userDoc = await args.db.collection('users').doc(args.uid).get();
  const resolution = resolveFreeRewardsRestriction({
    userData: userDoc.data(),
    countryCodes: args.countryCodes,
    timeZoneOffsetMinutes: args.timeZoneOffsetMinutes,
  });
  if (resolution.restricted) {
    throw new HttpsError('permission-denied', 'FREE_REWARDS_RESTRICTED');
  }
}
