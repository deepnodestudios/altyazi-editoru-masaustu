const LEGACY_GEMINI_MODEL = 'gemini-2.5-flash-lite';
const MODERN_GEMINI_MODEL = 'gemini-2.5-flash-lite';
const MODEL_SWITCH_MIN_VERSION = '1.6.0';

function isAtLeastVersion(appVersion?: string | null): boolean {
  if (!appVersion) return false;

  const cleaned = appVersion.replace(/\+.*$/, '').trim();
  const currentParts = cleaned.split('.').map((part) => Number(part) || 0);
  const requiredParts = MODEL_SWITCH_MIN_VERSION.split('.').map((part) => Number(part) || 0);

  for (let index = 0; index < 3; index += 1) {
    const current = currentParts[index] ?? 0;
    const required = requiredParts[index] ?? 0;
    if (current > required) return true;
    if (current < required) return false;
  }

  return true;
}

export function resolveGeminiModel(appVersion?: string | null): string {
  return isAtLeastVersion(appVersion) ? MODERN_GEMINI_MODEL : LEGACY_GEMINI_MODEL;
}

export function shouldUseVertexAi(appVersion?: string | null): boolean {
  return isAtLeastVersion(appVersion);
}

export {
  LEGACY_GEMINI_MODEL,
  MODERN_GEMINI_MODEL,
  MODEL_SWITCH_MIN_VERSION,
};