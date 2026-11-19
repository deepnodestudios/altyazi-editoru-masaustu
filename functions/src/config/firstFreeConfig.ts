import * as admin from 'firebase-admin';
import { FIRST_FREE_MAX_TOKENS } from '../billing/tokenWallet';

/**
 * First-free translation knobs, read from the Remote Config *server* template
 * (Firebase console → Remote Config → Server). Missing parameters fall back to
 * the defaults below, which match the behaviour before these knobs existed.
 *
 * - first_free_enabled     kill switch; false stops granting NEW first-free quotes
 * - first_free_requires_ad mobile fully-free first job requires a rewarded ad
 * - first_free_max_tokens  fair-use cap for the free part of the first job
 *
 * Decisions are frozen into the quote session, so a change only affects new
 * quotes; in-flight quotes keep what the user was shown.
 */
export interface FirstFreeRuntimeConfig {
    enabled: boolean;
    requiresAd: boolean;
    maxTokens: number;
}

export const FIRST_FREE_CONFIG_DEFAULTS: FirstFreeRuntimeConfig = {
    enabled: true,
    requiresAd: true,
    maxTokens: FIRST_FREE_MAX_TOKENS,
};

/** Hard ceiling so a console typo cannot hand out unbounded free tokens. */
export const FIRST_FREE_MAX_TOKENS_CEILING = 500_000;

const CACHE_TTL_MS = 5 * 60 * 1000;
const ERROR_RETRY_MS = 60 * 1000;

let cachedConfig: FirstFreeRuntimeConfig | null = null;
let cachedAtMs = 0;
let inflight: Promise<FirstFreeRuntimeConfig> | null = null;

function sanitizeMaxTokens(value: number): number {
    if (!Number.isFinite(value) || value <= 0) {
        return FIRST_FREE_CONFIG_DEFAULTS.maxTokens;
    }
    return Math.min(FIRST_FREE_MAX_TOKENS_CEILING, Math.floor(value));
}

async function loadFirstFreeConfig(): Promise<FirstFreeRuntimeConfig> {
    const template = await admin.remoteConfig().getServerTemplate({
        defaultConfig: {
            first_free_enabled: FIRST_FREE_CONFIG_DEFAULTS.enabled,
            first_free_requires_ad: FIRST_FREE_CONFIG_DEFAULTS.requiresAd,
            first_free_max_tokens: FIRST_FREE_CONFIG_DEFAULTS.maxTokens,
        },
    });
    const config = template.evaluate();
    return {
        enabled: config.getBoolean('first_free_enabled'),
        requiresAd: config.getBoolean('first_free_requires_ad'),
        maxTokens: sanitizeMaxTokens(config.getNumber('first_free_max_tokens')),
    };
}

export async function getFirstFreeConfig(): Promise<FirstFreeRuntimeConfig> {
    if (cachedConfig && Date.now() - cachedAtMs < CACHE_TTL_MS) {
        return cachedConfig;
    }
    if (!inflight) {
        inflight = loadFirstFreeConfig()
            .then((config) => {
                cachedConfig = config;
                cachedAtMs = Date.now();
                return config;
            })
            .catch((error) => {
                console.warn('[firstFreeConfig] Remote Config read failed; using last known or default values.', error);
                // Keep serving the fallback briefly so a missing/broken template
                // does not add a Remote Config round trip to every quote.
                cachedConfig = cachedConfig ?? FIRST_FREE_CONFIG_DEFAULTS;
                cachedAtMs = Date.now() - CACHE_TTL_MS + ERROR_RETRY_MS;
                return cachedConfig;
            })
            .finally(() => {
                inflight = null;
            });
    }
    return inflight;
}
