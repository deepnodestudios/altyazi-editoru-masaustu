/**
 * Region policy for free-credit earning restrictions.
 * Detection uses language codes OR timezone offset (no IP).
 *
 * Iran: fa OR UTC+3:30 (210 minutes)
 * India: Indian vernacular languages OR UTC+5:30 (330 minutes)
 * English alone never triggers restriction.
 */

export const IRAN_OFFSET_MINUTES = 210;
export const INDIA_OFFSET_MINUTES = 330;

export const IRAN_LANGUAGE_CODES = new Set(['fa']);

export const INDIA_LANGUAGE_CODES = new Set([
  'hi',
  'bn',
  'ta',
  'te',
  'mr',
  'gu',
  'kn',
  'ml',
  'pa',
  'or',
  'as',
  'ur',
  'in', // app Hindi locale mapped from device `hi`
]);

export const RESTRICTED_STARTER_BONUS = 1;

function normalizeLanguageCode(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim().toLowerCase();
  if (!trimmed) return null;
  if (trimmed.includes('-') || trimmed.includes('_')) {
    return trimmed.split(/[-_]/)[0] || null;
  }
  return trimmed;
}

export function isFreeRewardsRestricted(args: {
  languageCodes?: unknown;
  timeZoneOffsetMinutes?: unknown;
}): boolean {
  const codes = new Set<string>();
  if (Array.isArray(args.languageCodes)) {
    for (const item of args.languageCodes) {
      const normalized = normalizeLanguageCode(item);
      if (normalized) codes.add(normalized);
    }
  } else {
    const single = normalizeLanguageCode(args.languageCodes);
    if (single) codes.add(single);
  }

  const offsetRaw = Number(args.timeZoneOffsetMinutes);
  const offsetMinutes = Number.isFinite(offsetRaw) ? Math.trunc(offsetRaw) : NaN;

  const hasIranLanguage = [...codes].some((code) => IRAN_LANGUAGE_CODES.has(code));
  const hasIndiaLanguage = [...codes].some((code) => INDIA_LANGUAGE_CODES.has(code));
  const iranTimezone = offsetMinutes === IRAN_OFFSET_MINUTES;
  const indiaTimezone = offsetMinutes === INDIA_OFFSET_MINUTES;

  return hasIranLanguage || hasIndiaLanguage || iranTimezone || indiaTimezone;
}

export function restrictedReason(args: {
  languageCodes?: unknown;
  timeZoneOffsetMinutes?: unknown;
}): string | null {
  if (!isFreeRewardsRestricted(args)) return null;

  const codes = new Set<string>();
  if (Array.isArray(args.languageCodes)) {
    for (const item of args.languageCodes) {
      const normalized = normalizeLanguageCode(item);
      if (normalized) codes.add(normalized);
    }
  }

  const offsetRaw = Number(args.timeZoneOffsetMinutes);
  const offsetMinutes = Number.isFinite(offsetRaw) ? Math.trunc(offsetRaw) : NaN;

  if ([...codes].some((code) => IRAN_LANGUAGE_CODES.has(code)) ||
      offsetMinutes === IRAN_OFFSET_MINUTES) {
    return 'IR';
  }
  if ([...codes].some((code) => INDIA_LANGUAGE_CODES.has(code)) ||
      offsetMinutes === INDIA_OFFSET_MINUTES) {
    return 'IN';
  }
  return 'RESTRICTED';
}
