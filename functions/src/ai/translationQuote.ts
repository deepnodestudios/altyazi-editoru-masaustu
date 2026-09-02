import { createHash } from 'crypto';

export const TRANSLATION_QUOTE_PROTOCOL_VERSION = 1;
export const TRANSLATION_QUOTE_MIN_MOBILE_VERSION = '1.8.2';
export const TRANSLATION_QUOTE_MIN_DESKTOP_VERSION = '1.7.9';
export const TRANSLATION_QUOTE_VERSION = 'char_utf16_v1_1_50';
export const TRANSLATION_QUOTE_MULTIPLIER = 1.50;
export const TRANSLATION_QUOTE_TTL_MS = 30 * 60 * 1000;

export function quoteTokensFromCharacterCount(characterCount: unknown): number {
    const parsed = Number(characterCount);
    if (!Number.isFinite(parsed) || parsed <= 0) return 0;
    const safeCount = Math.floor(parsed);
    // Exact 1.50 without floating-point drift.
    return Math.ceil((safeCount * 3) / 2);
}

export function translationContentHash(sourceContent: string): string {
    return createHash('sha256').update(sourceContent, 'utf8').digest('hex');
}
