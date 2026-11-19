import * as admin from 'firebase-admin';

/**
 * Ad reward knobs, read from the Remote Config *server* template
 * (Firebase console → Remote Config → Server). Missing parameters fall back to
 * the defaults below.
 *
 * - ad_reward_require_app_check  reject mobile ad rewards without an App Check
 *                                token. Off by default: calls are only logged,
 *                                so the share of real users without a token can
 *                                be measured before enforcing.
 */
export interface AdRewardRuntimeConfig {
    requireAppCheck: boolean;
}

export const AD_REWARD_CONFIG_DEFAULTS: AdRewardRuntimeConfig = {
    requireAppCheck: false,
};

const CACHE_TTL_MS = 5 * 60 * 1000;
const ERROR_RETRY_MS = 60 * 1000;

let cachedConfig: AdRewardRuntimeConfig | null = null;
let cachedAtMs = 0;
let inflight: Promise<AdRewardRuntimeConfig> | null = null;

async function loadAdRewardConfig(): Promise<AdRewardRuntimeConfig> {
    const template = await admin.remoteConfig().getServerTemplate({
        defaultConfig: {
            ad_reward_require_app_check: AD_REWARD_CONFIG_DEFAULTS.requireAppCheck,
        },
    });
    const config = template.evaluate();
    return {
        requireAppCheck: config.getBoolean('ad_reward_require_app_check'),
    };
}

export async function getAdRewardConfig(): Promise<AdRewardRuntimeConfig> {
    if (cachedConfig && Date.now() - cachedAtMs < CACHE_TTL_MS) {
        return cachedConfig;
    }
    if (!inflight) {
        inflight = loadAdRewardConfig()
            .then((config) => {
                cachedConfig = config;
                cachedAtMs = Date.now();
                return config;
            })
            .catch((error) => {
                console.warn('[adRewardConfig] Remote Config read failed; using last known or default values.', error);
                cachedConfig = cachedConfig ?? AD_REWARD_CONFIG_DEFAULTS;
                cachedAtMs = Date.now() - CACHE_TTL_MS + ERROR_RETRY_MS;
                return cachedConfig;
            })
            .finally(() => {
                inflight = null;
            });
    }
    return inflight;
}
