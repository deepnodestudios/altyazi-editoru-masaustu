import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';

import {
    isDesktopPlatform,
    meetsMinimumVersion,
    shouldEnforceDesktopPaidCreditsOnly,
} from '../referral/referralUtils';

/** First token-wallet app version on **mobile** (Android/iOS). Live 1.7.9 stays 1 credit = 1 file. */
export const MIN_TOKEN_WALLET_APP_VERSION = '1.8.0';

/**
 * First token-wallet app version on **desktop** (Windows/macOS/Linux).
 * Desktop is currently 1.7.5; 1.7.6+ can enter the wallet. Must not use the mobile 1.8.0 gate.
 */
export const MIN_TOKEN_WALLET_DESKTOP_APP_VERSION = '1.7.6';

/** 1 Sep 2026 00:00 Europe/Istanbul (UTC+3, no DST). */
export const TOKEN_WALLET_STARTS_AT_MS = Date.UTC(2026, 7, 31, 21, 0, 0);

export const CREDIT_POLICY_TOKEN_V1 = 'token_v1';

export const TOKENS_PER_LEGACY_CREDIT = 110_000;
export const STARTER_TOKENS = 150_000;
export const STARTER_TOKENS_RESTRICTED = 75_000;
export const GOOGLE_LOGIN_TOKENS = 150_000; // Legacy constant; new token-wallet clients no longer grant this.
export const REFERRAL_TOKENS = 150_000;
export const AD_REWARD_TOKENS = 5_000;
export const AD_REWARD_WEEKLY_TOKEN_LIMIT = 200_000;

const TOKEN_CHAR_MULTIPLIER = 1.30;

export const TOKEN_PACKS: Record<string, { base: number; bonus: number; tokens: number }> = {
    tokens_1m: { base: 1_000_000, bonus: 100_000, tokens: 1_100_000 },
    tokens_5m: { base: 5_000_000, bonus: 500_000, tokens: 5_500_000 },
    tokens_10m: { base: 10_000_000, bonus: 1_000_000, tokens: 11_000_000 },
};

/**
 * Monthly grants for Hobby / Cinema (same Play SKUs as the credit era).
 * Base is 2M / 3M plus 10% purchase bonus. That is more tokens than the
 * one-time Starter pack because the subscription also renews and is ad-free.
 */
export const SUBSCRIPTION_TOKEN_GRANTS: Record<string, { base: number; bonus: number; tokens: number }> = {
    sub_20_credits_monthly: { base: 2_000_000, bonus: 200_000, tokens: 2_200_000 },
    sub_30_credits_monthly: { base: 3_000_000, bonus: 300_000, tokens: 3_300_000 },
};

const SUBSCRIPTION_TOKEN_PRODUCT_ALIASES: Record<string, string> = {
    hobi_paket_monthly: 'sub_20_credits_monthly',
    sinema_paketi_monthly: 'sub_30_credits_monthly',
};

export type TokenChargeMode = 'paid_file' | 'bonus_file' | 'tokens';

export type BonusFileBuckets = {
    adRewardCredits: number;
    freeCredits: number;
    googleLoginCredits: number;
    deviceCredits: number;
};

export type TokenWalletState = {
    creditPolicy: typeof CREDIT_POLICY_TOKEN_V1;
    legacyFlatRateRemaining: number;
    tokenBalance: number;
    tokenGrantBalance: number;
    purchasedCredits: number;
    subscriptionPurchasedCredits: number;
    extraPurchasedCredits: number;
    snapshotPending: boolean;
    bonusCreditsConvertedToTokens: boolean;
    deviceBonusConvertedToTokens: boolean;
    convertedAdCredits: number;
    convertedFreeCredits: number;
    convertedGoogleCredits: number;
    convertedDeviceCredits: number;
    convertedBonusTokens: number;
    /** Leftover paid tokens from the current monthly subscription period. Packs are not in this bucket. */
    subscriptionTokenPaidRemaining: number;
    /** Leftover 10% purchase-bonus tokens from the current monthly subscription period. */
    subscriptionTokenGrantRemaining: number;
};

export type TokenChargePlan = {
    mode: TokenChargeMode;
    estimatedTokens: number;
    fromLegacy: number;
    fromBonusFile: number;
    fromPaidTokens: number;
    fromGrantTokens: number;
    fromAdReward: number;
    fromFree: number;
    fromGoogleLogin: number;
    fromDevice: number;
    next: TokenWalletState;
    bonusNext: BonusFileBuckets;
};

function clampNonNegativeInt(value: unknown): number {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed <= 0) {
        return 0;
    }
    return Math.floor(parsed);
}

export function shouldUseTokenWallet(args: {
    appVersion?: string | null;
    now?: Date | number | null;
    platform?: string | null;
}): boolean {
    const nowMs = args.now == null
        ? Date.now()
        : (args.now instanceof Date ? args.now.getTime() : Number(args.now));
    const platform = String(args.platform ?? '').trim().toLowerCase();
    // Web has no 1.8.0 store; it opens on the announced calendar day.
    if (platform === 'web') {
        return Number.isFinite(nowMs) && nowMs >= TOKEN_WALLET_STARTS_AT_MS;
    }
    if (isDesktopPlatform(platform)) {
        if (!Number.isFinite(nowMs) || nowMs < TOKEN_WALLET_STARTS_AT_MS) {
            return false;
        }
        return meetsMinimumVersion(args.appVersion, MIN_TOKEN_WALLET_DESKTOP_APP_VERSION);
    }
    // Mobile 1.8.0+ uses the wallet immediately so leftover bonus converts and
    // the shop/card match. Live 1.7.9 never enters (min version).
    return meetsMinimumVersion(args.appVersion, MIN_TOKEN_WALLET_APP_VERSION);
}

export function leftoverBonusCreditsToTokens(credits: unknown): number {
    return clampNonNegativeInt(credits) * TOKENS_PER_LEGACY_CREDIT;
}

const TOKEN_PURCHASE_CREDIT_DUMP_SIZES = [
    11_000_000,
    10_000_000,
    5_500_000,
    5_000_000,
    3_300_000,
    3_000_000,
    2_200_000,
    2_000_000,
    1_650_000,
    1_500_000,
    1_100_000,
    1_000_000,
] as const;

const TOKEN_PURCHASE_BONUS_CREDIT_DUMP_SIZES = [
    1_100_000,
    1_000_000,
    550_000,
    500_000,
    330_000,
    300_000,
    220_000,
    200_000,
    110_000,
    100_000,
] as const;

const MAX_PLAUSIBLE_LEFTOVER_FILE_CREDITS = 5_000;

export function recoverMisappliedTokenCredits(purchasedCredits: number): {
    fileCredits: number;
    dumpedTokens: number;
} {
    const raw = clampNonNegativeInt(purchasedCredits);
    if (raw < 1_000_000) {
        return { fileCredits: raw, dumpedTokens: 0 };
    }
    for (const size of TOKEN_PURCHASE_CREDIT_DUMP_SIZES) {
        if (raw >= size && raw - size < MAX_PLAUSIBLE_LEFTOVER_FILE_CREDITS) {
            return { fileCredits: raw - size, dumpedTokens: size };
        }
    }
    return { fileCredits: raw, dumpedTokens: 0 };
}

export function recoverMisappliedBonusCredits(bonusCredits: number): {
    leftoverCredits: number;
    dumpedTokens: number;
} {
    const raw = clampNonNegativeInt(bonusCredits);
    if (raw < 100_000) {
        return { leftoverCredits: raw, dumpedTokens: 0 };
    }
    for (const size of TOKEN_PURCHASE_BONUS_CREDIT_DUMP_SIZES) {
        if (raw >= size && raw - size < MAX_PLAUSIBLE_LEFTOVER_FILE_CREDITS) {
            return { leftoverCredits: raw - size, dumpedTokens: size };
        }
    }
    return { leftoverCredits: raw, dumpedTokens: 0 };
}

export function estimateTokens(charCount: unknown): number {
    const n = clampNonNegativeInt(charCount);
    if (n <= 0) {
        return 0;
    }
    return Math.ceil(n * TOKEN_CHAR_MULTIPLIER);
}

export function resolveTokenPack(productId?: string | null): {
    productId: string;
    base: number;
    bonus: number;
    tokens: number;
} | null {
    const key = (productId ?? '').trim();
    const pack = TOKEN_PACKS[key];
    if (!pack) {
        return null;
    }
    return { productId: key, ...pack };
}

export function resolveSubscriptionTokenGrant(productId?: string | null): {
    productId: string;
    base: number;
    bonus: number;
    tokens: number;
} | null {
    const raw = (productId ?? '').trim();
    const key = SUBSCRIPTION_TOKEN_PRODUCT_ALIASES[raw] ?? raw;
    const pack = SUBSCRIPTION_TOKEN_GRANTS[key];
    if (!pack) {
        return null;
    }
    return { productId: key, ...pack };
}

export function resolveTokenPackByTokens(tokens: number): {
    base: number;
    bonus: number;
    tokens: number;
} | null {
    const amount = clampNonNegativeInt(tokens);
    if (amount <= 0) {
        return null;
    }
    const packs = Object.values(TOKEN_PACKS);
    const exactTotal = packs.find((pack) => pack.tokens === amount);
    if (exactTotal) {
        return exactTotal;
    }
    const exactBase = packs.find((pack) => pack.base === amount);
    return exactBase ?? null;
}

export function starterTokenGrant(restricted: boolean): number {
    return restricted ? STARTER_TOKENS_RESTRICTED : STARTER_TOKENS;
}

export function paidTokenBalance(state: Pick<TokenWalletState, 'tokenBalance' | 'tokenGrantBalance'>): number {
    return Math.max(0, state.tokenBalance - state.tokenGrantBalance);
}

export function spendableTokenBalance(args: {
    state: Pick<TokenWalletState, 'tokenBalance' | 'tokenGrantBalance'>;
    platform?: string | null;
    appVersion?: string | null;
}): number {
    const paid = paidTokenBalance(args.state);
    if (shouldEnforceDesktopPaidCreditsOnly({
        platform: args.platform,
        appVersion: args.appVersion,
    }) || isDesktopPlatform(args.platform)) {
        return paid;
    }
    return Math.max(0, args.state.tokenBalance);
}

function normalizePurchasedBuckets(userData: Record<string, unknown>): {
    purchasedCredits: number;
    subscriptionPurchasedCredits: number;
    extraPurchasedCredits: number;
} {
    const purchasedA = clampNonNegativeInt(userData.purchasedCredits);
    const purchasedB = clampNonNegativeInt(userData.credits);
    const purchasedCredits = Math.max(purchasedA, purchasedB);

    const subscriptionRaw = Number(userData.subscriptionPurchasedCredits ?? Number.NaN);
    const subscriptionPurchasedCredits = Number.isFinite(subscriptionRaw) && subscriptionRaw >= 0
        ? Math.min(Math.floor(subscriptionRaw), purchasedCredits)
        : 0;

    const extraRaw = Number(userData.extraPurchasedCredits ?? Number.NaN);
    let extraPurchasedCredits = Number.isFinite(extraRaw) && extraRaw >= 0
        ? Math.min(Math.floor(extraRaw), Math.max(0, purchasedCredits - subscriptionPurchasedCredits))
        : 0;

    const assigned = subscriptionPurchasedCredits + extraPurchasedCredits;
    if (assigned < purchasedCredits) {
        extraPurchasedCredits += purchasedCredits - assigned;
    }

    return {
        purchasedCredits,
        subscriptionPurchasedCredits,
        extraPurchasedCredits,
    };
}

function emptyConvertedBonus(): Pick<
    TokenWalletState,
    | 'bonusCreditsConvertedToTokens'
    | 'deviceBonusConvertedToTokens'
    | 'convertedAdCredits'
    | 'convertedFreeCredits'
    | 'convertedGoogleCredits'
    | 'convertedDeviceCredits'
    | 'convertedBonusTokens'
    | 'subscriptionTokenPaidRemaining'
    | 'subscriptionTokenGrantRemaining'
> {
    return {
        bonusCreditsConvertedToTokens: false,
        deviceBonusConvertedToTokens: false,
        convertedAdCredits: 0,
        convertedFreeCredits: 0,
        convertedGoogleCredits: 0,
        convertedDeviceCredits: 0,
        convertedBonusTokens: 0,
        subscriptionTokenPaidRemaining: 0,
        subscriptionTokenGrantRemaining: 0,
    };
}

function readOptionalNonNegativeInt(
    data: Record<string, unknown>,
    key: string,
): number | null {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
        return null;
    }
    return clampNonNegativeInt(data[key]);
}

/**
 * Track leftover monthly subscription tokens separately from one-time packs.
 * Missing fields are seeded only when the paid/grant slices fit a single
 * subscription grant — mixed pack+sub wallets are left at 0 so packs are
 * never treated as subscription leftover.
 */
function attachSubscriptionTokenBuckets(
    state: TokenWalletState,
    userData: Record<string, unknown>,
): TokenWalletState {
    const paid = paidTokenBalance(state);
    const grant = Math.max(0, state.tokenGrantBalance);
    const storedPaid = readOptionalNonNegativeInt(userData, 'subscriptionTokenPaidRemaining');
    const storedGrant = readOptionalNonNegativeInt(userData, 'subscriptionTokenGrantRemaining');
    if (storedPaid != null || storedGrant != null) {
        return {
            ...state,
            subscriptionTokenPaidRemaining: Math.min(storedPaid ?? 0, paid),
            subscriptionTokenGrantRemaining: Math.min(storedGrant ?? 0, grant),
        };
    }

    const pack = resolveSubscriptionTokenGrant(
        typeof userData.subscriptionProductId === 'string'
            ? userData.subscriptionProductId
            : null,
    );
    if (
        pack != null &&
        userData.subscriptionActive === true &&
        paid <= pack.base &&
        grant <= pack.bonus
    ) {
        return {
            ...state,
            snapshotPending: true,
            subscriptionTokenPaidRemaining: paid,
            subscriptionTokenGrantRemaining: grant,
        };
    }

    return {
        ...state,
        subscriptionTokenPaidRemaining: 0,
        subscriptionTokenGrantRemaining: 0,
    };
}

function collectLeftoverBonusCredits(
    userData: Record<string, unknown>,
    deviceData: Record<string, unknown>,
    hasDeviceData: boolean,
): BonusFileBuckets {
    const userConverted = userData.bonusCreditsConvertedToTokens === true;
    const deviceConverted = deviceData.bonusCreditsConvertedToTokens === true;
    const freeCredits = userConverted ? 0 : clampNonNegativeInt(userData.freeCredits);
    const googleLoginCredits = userConverted
        ? 0
        : clampNonNegativeInt(userData.googleLoginCredits);
    const deviceCredits = !hasDeviceData || deviceConverted
        ? 0
        : Math.max(
            clampNonNegativeInt(deviceData.deviceCredits),
            clampNonNegativeInt(deviceData.bonusCredits),
        );
    const deviceHasAdField = Object.prototype.hasOwnProperty.call(
        deviceData,
        'adRewardCredits',
    );
    let adRewardCredits = 0;
    if (hasDeviceData && deviceHasAdField) {
        adRewardCredits = deviceConverted ? 0 : clampNonNegativeInt(deviceData.adRewardCredits);
    } else if (!userConverted) {
        adRewardCredits = clampNonNegativeInt(userData.adRewardCredits);
    }
    return {
        adRewardCredits,
        freeCredits,
        googleLoginCredits,
        deviceCredits,
    };
}

function subtractBonusDump(bonus: BonusFileBuckets, amount: number): BonusFileBuckets {
    let left = clampNonNegativeInt(amount);
    const take = (current: number): number => {
        const used = Math.min(current, left);
        left -= used;
        return current - used;
    };
    return {
        freeCredits: take(bonus.freeCredits),
        googleLoginCredits: take(bonus.googleLoginCredits),
        adRewardCredits: take(bonus.adRewardCredits),
        deviceCredits: take(bonus.deviceCredits),
    };
}

function applyLeftoverBonusConversion(
    state: TokenWalletState,
    userData: Record<string, unknown>,
    deviceData: Record<string, unknown>,
    hasDeviceData: boolean,
): TokenWalletState {
    if (state.bonusCreditsConvertedToTokens && (!hasDeviceData || state.deviceBonusConvertedToTokens)) {
        return state;
    }

    const leftover = collectLeftoverBonusCredits(userData, deviceData, hasDeviceData);
    const bonusSplit = recoverMisappliedBonusCredits(bonusFileTotal(leftover));
    let leftoverToConvert = subtractBonusDump(leftover, bonusSplit.dumpedTokens);
    let dumpedTokens = bonusSplit.dumpedTokens;
    let remaining = bonusFileTotal(leftoverToConvert);
    if (remaining >= MAX_PLAUSIBLE_LEFTOVER_FILE_CREDITS) {
        dumpedTokens += remaining;
        leftoverToConvert = {
            adRewardCredits: 0,
            freeCredits: 0,
            googleLoginCredits: 0,
            deviceCredits: 0,
        };
        remaining = 0;
    }
    const grantTokens = leftoverBonusCreditsToTokens(remaining);
    const next: TokenWalletState = {
        ...state,
        bonusCreditsConvertedToTokens: true,
        deviceBonusConvertedToTokens: hasDeviceData ? true : state.deviceBonusConvertedToTokens,
        convertedAdCredits: leftoverToConvert.adRewardCredits,
        convertedFreeCredits: leftoverToConvert.freeCredits,
        convertedGoogleCredits: leftoverToConvert.googleLoginCredits,
        convertedDeviceCredits: leftoverToConvert.deviceCredits,
        convertedBonusTokens: grantTokens,
    };
    if (grantTokens <= 0 && dumpedTokens <= 0) {
        if (!state.bonusCreditsConvertedToTokens || (hasDeviceData && !state.deviceBonusConvertedToTokens)) {
            next.snapshotPending = true;
        }
        return next;
    }
    return {
        ...next,
        snapshotPending: true,
        tokenBalance: state.tokenBalance + dumpedTokens + grantTokens,
        tokenGrantBalance: state.tokenGrantBalance + grantTokens,
    };
}

export function hydrateTokenWallet(args: {
    userData?: Record<string, unknown> | null;
    deviceData?: Record<string, unknown> | null;
}): TokenWalletState {
    const userData = args.userData ?? {};
    const hasDeviceData = args.deviceData != null;
    const deviceData = args.deviceData ?? {};
    const buckets = normalizePurchasedBuckets(userData);
    const existingPolicy = String(userData.creditPolicy ?? '').trim();

    const base: TokenWalletState = existingPolicy === CREDIT_POLICY_TOKEN_V1
        ? {
            creditPolicy: CREDIT_POLICY_TOKEN_V1,
            legacyFlatRateRemaining: clampNonNegativeInt(userData.legacyFlatRateRemaining),
            tokenBalance: clampNonNegativeInt(userData.tokenBalance),
            tokenGrantBalance: Math.min(
                clampNonNegativeInt(userData.tokenBalance),
                clampNonNegativeInt(userData.tokenGrantBalance),
            ),
            purchasedCredits: buckets.purchasedCredits,
            subscriptionPurchasedCredits: buckets.subscriptionPurchasedCredits,
            extraPurchasedCredits: buckets.extraPurchasedCredits,
            snapshotPending: false,
            ...emptyConvertedBonus(),
            bonusCreditsConvertedToTokens: userData.bonusCreditsConvertedToTokens === true,
            deviceBonusConvertedToTokens: deviceData.bonusCreditsConvertedToTokens === true,
        }
        : {
            creditPolicy: CREDIT_POLICY_TOKEN_V1,
            // Leftover paid credits stay 1 file = 1 credit until they run out.
            legacyFlatRateRemaining: buckets.purchasedCredits,
            tokenBalance: clampNonNegativeInt(userData.tokenBalance),
            tokenGrantBalance: clampNonNegativeInt(userData.tokenGrantBalance),
            purchasedCredits: buckets.purchasedCredits,
            subscriptionPurchasedCredits: buckets.subscriptionPurchasedCredits,
            extraPurchasedCredits: buckets.extraPurchasedCredits,
            snapshotPending: true,
            ...emptyConvertedBonus(),
        };

    return attachSubscriptionTokenBuckets(
        applyLeftoverBonusConversion(
            recoverMisappliedCreditDump(recoverInflatedBonusGrantConversion(base)),
            userData,
            deviceData,
            hasDeviceData,
        ),
        userData,
    );
}

function recoverInflatedBonusGrantConversion(state: TokenWalletState): TokenWalletState {
    if (state.tokenBalance < TOKENS_PER_LEGACY_CREDIT * 50_000) {
        return state;
    }
    if (state.tokenBalance % TOKENS_PER_LEGACY_CREDIT !== 0) {
        return state;
    }
    const impliedCredits = state.tokenBalance / TOKENS_PER_LEGACY_CREDIT;
    const split = recoverMisappliedBonusCredits(impliedCredits);
    if (split.dumpedTokens <= 0) {
        return state;
    }
    const undo = leftoverBonusCreditsToTokens(split.dumpedTokens);
    return {
        ...state,
        snapshotPending: true,
        bonusCreditsConvertedToTokens: true,
        tokenBalance: state.tokenBalance - undo + split.dumpedTokens,
        tokenGrantBalance: leftoverBonusCreditsToTokens(split.leftoverCredits),
    };
}

function recoverMisappliedCreditDump(state: TokenWalletState): TokenWalletState {
    const raw = Math.max(state.purchasedCredits, state.legacyFlatRateRemaining);
    const split = recoverMisappliedTokenCredits(raw);
    if (split.dumpedTokens <= 0) {
        return state;
    }
    const subscriptionPurchasedCredits = Math.min(
        state.subscriptionPurchasedCredits,
        split.fileCredits,
    );
    return {
        ...state,
        snapshotPending: true,
        purchasedCredits: split.fileCredits,
        subscriptionPurchasedCredits,
        extraPurchasedCredits: Math.max(0, split.fileCredits - subscriptionPurchasedCredits),
        legacyFlatRateRemaining: split.fileCredits,
        tokenBalance: state.tokenBalance + split.dumpedTokens,
    };
}

export function tokenWalletUserFields(state: TokenWalletState): Record<string, unknown> {
    return {
        creditPolicy: CREDIT_POLICY_TOKEN_V1,
        legacyFlatRateRemaining: state.legacyFlatRateRemaining,
        tokenBalance: state.tokenBalance,
        tokenGrantBalance: state.tokenGrantBalance,
        purchasedCredits: state.purchasedCredits,
        credits: state.purchasedCredits,
        subscriptionPurchasedCredits: state.subscriptionPurchasedCredits,
        extraPurchasedCredits: state.extraPurchasedCredits,
        subscriptionTokenPaidRemaining: state.subscriptionTokenPaidRemaining,
        subscriptionTokenGrantRemaining: state.subscriptionTokenGrantRemaining,
        bonusCreditsConvertedToTokens: true,
        freeCredits: 0,
        googleLoginCredits: 0,
        adRewardCredits: 0,
        ...(state.snapshotPending
            ? { creditPolicySnapshotAt: admin.firestore.FieldValue.serverTimestamp() }
            : {}),
    };
}

export function tokenWalletDeviceFields(state: TokenWalletState): Record<string, unknown> | null {
    if (!state.snapshotPending && !state.deviceBonusConvertedToTokens && state.convertedBonusTokens <= 0) {
        return null;
    }
    return {
        bonusCreditsConvertedToTokens: true,
        deviceCredits: 0,
        adRewardCredits: 0,
        bonusCredits: 0,
        ...(state.snapshotPending
            ? { tokenWalletSnapshotAt: admin.firestore.FieldValue.serverTimestamp() }
            : {}),
    };
}

export function addPurchasedTokens(state: TokenWalletState, tokens: number): TokenWalletState {
    const amount = clampNonNegativeInt(tokens);
    return {
        ...state,
        snapshotPending: false,
        tokenBalance: state.tokenBalance + amount,
    };
}

export function addTokenPackTokens(
    state: TokenWalletState,
    pack: { base: number; bonus: number },
): TokenWalletState {
    let next = addPurchasedTokens(state, clampNonNegativeInt(pack.base));
    if (clampNonNegativeInt(pack.bonus) > 0) {
        next = addGrantTokens(next, pack.bonus);
    }
    return next;
}

export function addGrantTokens(state: TokenWalletState, tokens: number): TokenWalletState {
    const amount = clampNonNegativeInt(tokens);
    return {
        ...state,
        snapshotPending: false,
        tokenBalance: state.tokenBalance + amount,
        tokenGrantBalance: state.tokenGrantBalance + amount,
    };
}

export function applyTokenSpend(
    state: TokenWalletState,
    fromPaidTokens: number,
    fromGrantTokens: number,
): TokenWalletState {
    const paid = clampNonNegativeInt(fromPaidTokens);
    const grant = clampNonNegativeInt(fromGrantTokens);
    const paidFromSub = Math.min(state.subscriptionTokenPaidRemaining, paid);
    const grantFromSub = Math.min(state.subscriptionTokenGrantRemaining, grant);
    return {
        ...state,
        snapshotPending: false,
        tokenBalance: Math.max(0, state.tokenBalance - paid - grant),
        tokenGrantBalance: Math.max(0, state.tokenGrantBalance - grant),
        subscriptionTokenPaidRemaining: Math.max(
            0,
            state.subscriptionTokenPaidRemaining - paidFromSub,
        ),
        subscriptionTokenGrantRemaining: Math.max(
            0,
            state.subscriptionTokenGrantRemaining - grantFromSub,
        ),
    };
}

export function forfeitSubscriptionTokens(state: TokenWalletState): {
    next: TokenWalletState;
    forfeitedPaid: number;
    forfeitedGrant: number;
} {
    const forfeitedPaid = Math.min(
        state.subscriptionTokenPaidRemaining,
        paidTokenBalance(state),
    );
    const forfeitedGrant = Math.min(
        state.subscriptionTokenGrantRemaining,
        state.tokenGrantBalance,
    );
    return {
        next: {
            ...state,
            snapshotPending: false,
            tokenBalance: Math.max(0, state.tokenBalance - forfeitedPaid - forfeitedGrant),
            tokenGrantBalance: Math.max(0, state.tokenGrantBalance - forfeitedGrant),
            subscriptionTokenPaidRemaining: 0,
            subscriptionTokenGrantRemaining: 0,
        },
        forfeitedPaid,
        forfeitedGrant,
    };
}

export function applySubscriptionTokenGrant(
    state: TokenWalletState,
    pack: { base: number; bonus: number },
    opts: { replace: boolean },
): {
    next: TokenWalletState;
    afterForfeit: TokenWalletState;
    forfeitedPaid: number;
    forfeitedGrant: number;
} {
    let afterForfeit = state;
    let forfeitedPaid = 0;
    let forfeitedGrant = 0;
    if (opts.replace) {
        const forfeited = forfeitSubscriptionTokens(state);
        afterForfeit = forfeited.next;
        forfeitedPaid = forfeited.forfeitedPaid;
        forfeitedGrant = forfeited.forfeitedGrant;
    }
    const granted = addTokenPackTokens(afterForfeit, pack);
    return {
        next: {
            ...granted,
            subscriptionTokenPaidRemaining: clampNonNegativeInt(pack.base),
            subscriptionTokenGrantRemaining: clampNonNegativeInt(pack.bonus),
        },
        afterForfeit,
        forfeitedPaid,
        forfeitedGrant,
    };
}

export function revokePurchasedTokens(state: TokenWalletState, tokens: number): TokenWalletState {
    const amount = clampNonNegativeInt(tokens);
    const fromPaid = Math.min(paidTokenBalance(state), amount);
    return {
        ...state,
        snapshotPending: false,
        tokenBalance: Math.max(0, state.tokenBalance - fromPaid),
    };
}

export function revokeTokenPack(
    state: TokenWalletState,
    pack: { base: number; bonus: number },
    opts?: { subscription?: boolean },
): {
    next: TokenWalletState;
    revokedPaid: number;
    revokedGrant: number;
} {
    if (opts?.subscription) {
        const forfeited = forfeitSubscriptionTokens(state);
        if (forfeited.forfeitedPaid + forfeited.forfeitedGrant > 0) {
            return {
                next: forfeited.next,
                revokedPaid: forfeited.forfeitedPaid,
                revokedGrant: forfeited.forfeitedGrant,
            };
        }
    }

    const bonus = clampNonNegativeInt(pack.bonus);
    const base = clampNonNegativeInt(pack.base);
    let fromGrant = Math.min(state.tokenGrantBalance, bonus);
    let fromPaid = Math.min(paidTokenBalance(state), base);
    const bonusShort = bonus - fromGrant;
    if (bonusShort > 0) {
        fromPaid += Math.min(Math.max(0, paidTokenBalance(state) - fromPaid), bonusShort);
    }
    const next: TokenWalletState = {
        ...state,
        snapshotPending: false,
        tokenBalance: Math.max(0, state.tokenBalance - fromPaid - fromGrant),
        tokenGrantBalance: Math.max(0, state.tokenGrantBalance - fromGrant),
    };
    if (opts?.subscription) {
        next.subscriptionTokenPaidRemaining = 0;
        next.subscriptionTokenGrantRemaining = 0;
    }
    return { next, revokedPaid: fromPaid, revokedGrant: fromGrant };
}

function spendLegacyFile(state: TokenWalletState): TokenWalletState {
    let remaining = 1;
    let subscriptionPurchasedCredits = state.subscriptionPurchasedCredits;
    let extraPurchasedCredits = state.extraPurchasedCredits;
    const fromSubscription = Math.min(subscriptionPurchasedCredits, remaining);
    subscriptionPurchasedCredits -= fromSubscription;
    remaining -= fromSubscription;
    extraPurchasedCredits = Math.max(0, extraPurchasedCredits - remaining);
    const purchasedCredits = subscriptionPurchasedCredits + extraPurchasedCredits;
    return {
        ...state,
        snapshotPending: false,
        legacyFlatRateRemaining: Math.max(0, state.legacyFlatRateRemaining - 1),
        purchasedCredits,
        subscriptionPurchasedCredits,
        extraPurchasedCredits,
    };
}

function clampBonusBuckets(bonus?: BonusFileBuckets | null): BonusFileBuckets {
    return {
        adRewardCredits: clampNonNegativeInt(bonus?.adRewardCredits),
        freeCredits: clampNonNegativeInt(bonus?.freeCredits),
        googleLoginCredits: clampNonNegativeInt(bonus?.googleLoginCredits),
        deviceCredits: clampNonNegativeInt(bonus?.deviceCredits),
    };
}

function bonusFileTotal(bonus: BonusFileBuckets): number {
    return bonus.adRewardCredits + bonus.freeCredits + bonus.googleLoginCredits + bonus.deviceCredits;
}

function spendOneBonusFile(bonus: BonusFileBuckets): {
    next: BonusFileBuckets;
    fromAdReward: number;
    fromFree: number;
    fromGoogleLogin: number;
    fromDevice: number;
} {
    const next = { ...bonus };
    if (next.adRewardCredits > 0) {
        next.adRewardCredits -= 1;
        return { next, fromAdReward: 1, fromFree: 0, fromGoogleLogin: 0, fromDevice: 0 };
    }
    if (next.freeCredits > 0) {
        next.freeCredits -= 1;
        return { next, fromAdReward: 0, fromFree: 1, fromGoogleLogin: 0, fromDevice: 0 };
    }
    if (next.googleLoginCredits > 0) {
        next.googleLoginCredits -= 1;
        return { next, fromAdReward: 0, fromFree: 0, fromGoogleLogin: 1, fromDevice: 0 };
    }
    if (next.deviceCredits > 0) {
        next.deviceCredits -= 1;
        return { next, fromAdReward: 0, fromFree: 0, fromGoogleLogin: 0, fromDevice: 1 };
    }
    throw new HttpsError('failed-precondition', 'INSUFFICIENT_CREDIT');
}

function emptyFilePlanFields(): Pick<
    TokenChargePlan,
    'fromLegacy' | 'fromBonusFile' | 'fromPaidTokens' | 'fromGrantTokens' |
    'fromAdReward' | 'fromFree' | 'fromGoogleLogin' | 'fromDevice'
> {
    return {
        fromLegacy: 0,
        fromBonusFile: 0,
        fromPaidTokens: 0,
        fromGrantTokens: 0,
        fromAdReward: 0,
        fromFree: 0,
        fromGoogleLogin: 0,
        fromDevice: 0,
    };
}

/**
 * One job is either 1 leftover paid file-credit or estimatedTokens, never mixed.
 *
 * Leftover bonus credits are converted to grant tokens on first snapshot.
 * Paid usage (toggle off): paid file-credits → paid tokens → bonus tokens.
 * "Use bonus first" (toggle on): leftover bonus files → bonus tokens, then
 * any shortfall from paid tokens → leftover paid file-credits.
 * A mixed bonus+paid token job still requires a rewarded ad.
 * Desktop paid-only: paid file-credits then paid tokens only.
 */
export function planTokenWalletCharge(args: {
    state: TokenWalletState;
    bonus?: BonusFileBuckets | null;
    charCount?: unknown;
    estimatedTokens?: unknown;
    platform?: string | null;
    appVersion?: string | null;
    preferFreeCreditsFirst?: boolean;
}): TokenChargePlan {
    const { state, platform, appVersion } = args;
    const desktopPaidOnly = shouldEnforceDesktopPaidCreditsOnly({ platform, appVersion })
        || isDesktopPlatform(platform);
    const bonus = desktopPaidOnly ? clampBonusBuckets(null) : clampBonusBuckets(args.bonus);
    const preferBonusFirst = !desktopPaidOnly && args.preferFreeCreditsFirst === true;
    const estimatedTokens = Math.max(
        estimateTokens(args.charCount),
        clampNonNegativeInt(args.estimatedTokens),
    );
    const paidFiles = state.legacyFlatRateRemaining;
    const bonusFiles = bonusFileTotal(bonus);
    const paidAvailable = paidTokenBalance(state);
    const grantAvailable = desktopPaidOnly ? 0 : Math.max(0, state.tokenGrantBalance);

    if (estimatedTokens <= 0 && (paidAvailable + grantAvailable) > 0) {
        throw new HttpsError('invalid-argument', 'CHAR_COUNT_REQUIRED');
    }

    const paidFilePlan = (): TokenChargePlan => ({
        mode: 'paid_file',
        estimatedTokens,
        ...emptyFilePlanFields(),
        fromLegacy: 1,
        next: spendLegacyFile(state),
        bonusNext: bonus,
    });

    const bonusFilePlan = (): TokenChargePlan => {
        const spent = spendOneBonusFile(bonus);
        return {
            mode: 'bonus_file',
            estimatedTokens,
            ...emptyFilePlanFields(),
            fromBonusFile: 1,
            fromAdReward: spent.fromAdReward,
            fromFree: spent.fromFree,
            fromGoogleLogin: spent.fromGoogleLogin,
            fromDevice: spent.fromDevice,
            next: { ...state, snapshotPending: false },
            bonusNext: spent.next,
        };
    };

    const tokenPlan = (preferGrantFirst: boolean): TokenChargePlan | null => {
        if (estimatedTokens <= 0) {
            return null;
        }
        if (paidAvailable + grantAvailable < estimatedTokens) {
            return null;
        }
        let remaining = estimatedTokens;
        let fromPaidTokens = 0;
        let fromGrantTokens = 0;
        if (preferGrantFirst) {
            fromGrantTokens = Math.min(grantAvailable, remaining);
            remaining -= fromGrantTokens;
            fromPaidTokens = Math.min(paidAvailable, remaining);
            remaining -= fromPaidTokens;
        } else {
            fromPaidTokens = Math.min(paidAvailable, remaining);
            remaining -= fromPaidTokens;
            fromGrantTokens = Math.min(grantAvailable, remaining);
            remaining -= fromGrantTokens;
        }
        if (remaining > 0) {
            return null;
        }
        return {
            mode: 'tokens',
            estimatedTokens,
            ...emptyFilePlanFields(),
            fromPaidTokens,
            fromGrantTokens,
            next: applyTokenSpend(state, fromPaidTokens, fromGrantTokens),
            bonusNext: bonus,
        };
    };

    const order = preferBonusFirst
        ? [
            () => (bonusFiles > 0 ? bonusFilePlan() : null),
            () => tokenPlan(true),
            () => (paidFiles > 0 ? paidFilePlan() : null),
        ]
        : [
            () => (paidFiles > 0 ? paidFilePlan() : null),
            () => (paidAvailable >= estimatedTokens ? tokenPlan(false) : null),
            () => (bonusFiles > 0 ? bonusFilePlan() : null),
            () => (grantAvailable >= estimatedTokens ? tokenPlan(true) : null),
            () => tokenPlan(false),
        ];

    for (const step of order) {
        const plan = step();
        if (plan) {
            return plan;
        }
    }

    if (paidAvailable + grantAvailable > 0 && estimatedTokens <= 0) {
        throw new HttpsError('invalid-argument', 'CHAR_COUNT_REQUIRED');
    }
    throw new HttpsError(
        'failed-precondition',
        `INSUFFICIENT_CREDIT: Token yetersiz. Mevcut: ${paidAvailable + grantAvailable}, Gerekli: ${estimatedTokens}`,
    );
}

export function tokenChargeUsesGrant(plan: TokenChargePlan): boolean {
    return plan.mode === 'tokens' && plan.fromGrantTokens > 0;
}

export function tokenChargeRequiresRewardedAd(plan: TokenChargePlan): boolean {
    return plan.mode === 'bonus_file' || tokenChargeUsesGrant(plan);
}

function resolvePackBonusFromProductId(productId: unknown): number {
    const key = String(productId ?? '').trim();
    if (!key) {
        return 0;
    }
    return clampNonNegativeInt(
        TOKEN_PACKS[key]?.bonus ?? SUBSCRIPTION_TOKEN_GRANTS[key]?.bonus ?? 0,
    );
}

function resolvePackBonusFromDoc(data: FirebaseFirestore.DocumentData): number {
    const fromField = clampNonNegativeInt(data.tokenBonus ?? data.token_bonus);
    if (fromField > 0) {
        return fromField;
    }
    return resolvePackBonusFromProductId(data.productId);
}

/**
 * Heuristic for packs that were written entirely into paid tokens (no tokenBonus
 * on the purchase doc). Only an exact match to a single known pack total
 * (base+bonus) is accepted — greedy "largest pack that fits" would mis-read
 * 1M+5M leftover as a 5.5M pack and steal 500k into grant.
 */
function inferMisfiledPackBonus(paidTokens: number): number {
    const paid = clampNonNegativeInt(paidTokens);
    if (paid <= 0) {
        return 0;
    }
    const packs = [
        ...Object.values(TOKEN_PACKS),
        ...Object.values(SUBSCRIPTION_TOKEN_GRANTS),
    ].filter((pack) => pack.tokens === paid && pack.bonus > 0);
    if (packs.length !== 1) {
        return 0;
    }
    return packs[0].bonus;
}

export async function maybeRebalancePackBonusGrant(args: {
    db: admin.firestore.Firestore;
    uid: string;
    userData: Record<string, unknown>;
}): Promise<Record<string, unknown>> {
    // V2: also recovers packs whose purchase docs lacked tokenBonus / were
    // marked done by V1 without moving grant balance.
    if (args.userData.packBonusGrantRebalancedV2 === true) {
        return args.userData;
    }
    const tokenBalanceEarly = clampNonNegativeInt(args.userData.tokenBalance);
    const hasTokenWalletPolicy =
        String(args.userData.creditPolicy ?? '').trim() === CREDIT_POLICY_TOKEN_V1;
    // Run even if creditPolicy is missing: some buys wrote tokenBalance first.
    if (!hasTokenWalletPolicy && tokenBalanceEarly <= 0) {
        return args.userData;
    }

    let bonusToGrant = 0;
    const purchaseUpdates: Array<{ ref: admin.firestore.DocumentReference }> = [];
    const txUpdates: Array<{ ref: admin.firestore.DocumentReference }> = [];

    try {
        const purchasesSnap = await args.db.collection('purchases')
            .where('userId', '==', args.uid)
            .where('processed', '==', true)
            .get();
        for (const doc of purchasesSnap.docs) {
            const data = doc.data();
            if (data.bonusGrantApplied === true) {
                continue;
            }
            const bonus = resolvePackBonusFromDoc(data);
            if (bonus <= 0) {
                continue;
            }
            bonusToGrant += bonus;
            purchaseUpdates.push({ ref: doc.ref });
        }
    } catch (error) {
        console.warn('maybeRebalancePackBonusGrant: purchases query failed', error);
    }

    try {
        const txSnap = await args.db.collection('users').doc(args.uid)
            .collection('credit_transactions')
            .where('unit', '==', 'token')
            .get();
        for (const doc of txSnap.docs) {
            const data = doc.data();
            const source = String(data.source ?? data.reason ?? '').trim();
            if (source !== 'purchase' && source !== 'subscription') {
                continue;
            }
            if (data.bonusGrantApplied === true) {
                continue;
            }
            const bonus = resolvePackBonusFromDoc(data);
            if (bonus <= 0) {
                continue;
            }
            // Avoid double-counting the same pack when purchase docs already matched.
            if (purchaseUpdates.length > 0 && source === 'purchase') {
                continue;
            }
            bonusToGrant += bonus;
            txUpdates.push({ ref: doc.ref });
        }
    } catch (error) {
        console.warn('maybeRebalancePackBonusGrant: credit_transactions query failed', error);
    }

    const tokenBalance = clampNonNegativeInt(args.userData.tokenBalance);
    const tokenGrantBalance = clampNonNegativeInt(args.userData.tokenGrantBalance);
    const paidTokens = Math.max(0, tokenBalance - tokenGrantBalance);

    // If docs didn't yield a bonus (old writes), infer from paid slice.
    if (bonusToGrant <= 0) {
        bonusToGrant = inferMisfiledPackBonus(paidTokens);
    }

    const userRef = args.db.collection('users').doc(args.uid);
    if (bonusToGrant <= 0) {
        await userRef.set({
            packBonusGrantRebalancedV1: true,
            packBonusGrantRebalancedV2: true,
        }, { merge: true });
        return {
            ...args.userData,
            packBonusGrantRebalancedV1: true,
            packBonusGrantRebalancedV2: true,
        };
    }

    const nextGrantBalance = Math.min(tokenBalance, tokenGrantBalance + bonusToGrant);
    const patch = {
        tokenGrantBalance: nextGrantBalance,
        packBonusGrantRebalancedV1: true,
        packBonusGrantRebalancedV2: true,
    };
    const batch = args.db.batch();
    batch.set(userRef, patch, { merge: true });
    for (const update of purchaseUpdates) {
        batch.set(update.ref, { bonusGrantApplied: true }, { merge: true });
    }
    for (const update of txUpdates) {
        batch.set(update.ref, { bonusGrantApplied: true }, { merge: true });
    }
    await batch.commit();
    console.info('maybeRebalancePackBonusGrant: moved pack bonus to grant', {
        uid: args.uid,
        bonusToGrant,
        tokenGrantBalance,
        nextGrantBalance,
    });
    return { ...args.userData, ...patch };
}

function resolveKnownPack(productId: unknown): {
    base: number;
    bonus: number;
    tokens: number;
} | null {
    const key = String(productId ?? '').trim();
    return resolveTokenPack(key) ?? resolveSubscriptionTokenGrant(key);
}

/**
 * Combined pack purchases were logged as one credit_transactions row (base+bonus).
 * Split them back into purchase + purchase_bonus like the daytime 1M history.
 */
export async function maybeSplitCombinedPackHistory(args: {
    db: admin.firestore.Firestore;
    uid: string;
    userData: Record<string, unknown>;
}): Promise<Record<string, unknown>> {
    if (args.userData.packHistorySplitV1 === true) {
        return args.userData;
    }

    const userRef = args.db.collection('users').doc(args.uid);
    const txCol = userRef.collection('credit_transactions');
    let writes = 0;
    const batch = args.db.batch();

    const splitTx = (
        txDoc: FirebaseFirestore.QueryDocumentSnapshot | FirebaseFirestore.DocumentSnapshot,
        pack: { base: number; bonus: number; tokens: number },
    ): void => {
        const data = txDoc.data() ?? {};
        const amount = clampNonNegativeInt(data.amount);
        if (amount !== pack.tokens || pack.bonus <= 0) {
            return;
        }
        batch.set(txDoc.ref, {
            amount: pack.base,
            tokenBase: pack.base,
            tokenBonus: pack.bonus,
        }, { merge: true });
        const bonusRef = txCol.doc(`${txDoc.id}_purchase_bonus`);
        batch.set(bonusRef, {
            type: 'add',
            amount: pack.bonus,
            unit: 'token',
            timestamp: data.timestamp ?? admin.firestore.FieldValue.serverTimestamp(),
            source: 'purchase_bonus',
            reason: 'purchase_bonus',
            creditType: 'token_grant',
            productId: data.productId ?? null,
            purchaseId: data.purchaseId ?? txDoc.id,
            purchaseRecordId: data.purchaseRecordId ?? txDoc.id,
            platform: data.platform ?? 'android',
            remainingTokenBalance: data.remainingTokenBalance ?? null,
            remainingTokenGrantBalance: data.remainingTokenGrantBalance ?? null,
        }, { merge: true });
        writes += 2;
    };

    try {
        const txSnap = await txCol.where('unit', '==', 'token').get();
        for (const doc of txSnap.docs) {
            const data = doc.data();
            const source = String(data.source ?? '').trim();
            if (source !== 'purchase' && source !== 'subscription') {
                continue;
            }
            if (String(data.reason ?? '').trim() === 'purchase_bonus') {
                continue;
            }
            const pack = resolveKnownPack(data.productId);
            if (pack == null) {
                continue;
            }
            splitTx(doc, pack);
        }
    } catch (error) {
        console.warn('maybeSplitCombinedPackHistory: credit_transactions query failed', error);
    }

    if (writes <= 0) {
        await userRef.set({ packHistorySplitV1: true }, { merge: true });
        return { ...args.userData, packHistorySplitV1: true };
    }

    batch.set(userRef, { packHistorySplitV1: true }, { merge: true });
    await batch.commit();
    console.info('maybeSplitCombinedPackHistory: split combined pack rows', {
        uid: args.uid,
        writes,
    });
    return { ...args.userData, packHistorySplitV1: true };
}

export async function grantWalletTokens(args: {
    db: admin.firestore.Firestore;
    uid: string;
    tokens: number;
    reason: string;
    source: string;
    asGrant: boolean;
    metadata?: Record<string, unknown>;
    deviceData?: Record<string, unknown> | null;
}): Promise<TokenWalletState> {
    const { db, uid, tokens, reason, source, asGrant, metadata } = args;
    const amount = clampNonNegativeInt(tokens);
    if (amount <= 0) {
        throw new HttpsError('invalid-argument', 'INVALID_TOKEN_AMOUNT');
    }

    return db.runTransaction(async (tx) => {
        const userRef = db.collection('users').doc(uid);
        const userDoc = await tx.get(userRef);
        const userData = userDoc.exists ? (userDoc.data() ?? {}) : {};
        let state = hydrateTokenWallet({
            userData,
            deviceData: args.deviceData ?? {},
        });
        state = asGrant ? addGrantTokens(state, amount) : addPurchasedTokens(state, amount);
        tx.set(userRef, {
            ...tokenWalletUserFields(state),
        }, { merge: true });
        const txRef = userRef.collection('credit_transactions').doc();
        tx.set(txRef, {
            type: 'add',
            amount,
            reason,
            source,
            creditType: asGrant ? 'token_grant' : 'token_purchased',
            unit: 'token',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            remainingTokenBalance: state.tokenBalance,
            remainingTokenGrantBalance: state.tokenGrantBalance,
            remainingLegacyFlatRateRemaining: state.legacyFlatRateRemaining,
            ...(metadata ?? {}),
        });
        return state;
    });
}
