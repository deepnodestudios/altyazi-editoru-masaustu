import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from 'firebase-admin';
import { meetsMinimumVersion, shouldUseV160ClientRules } from '../referral/referralUtils';
import {
    resolveFreeRewardsRestriction,
    RESTRICTED_STARTER_BONUS,
} from './regionPolicy';
import {
    addGrantTokens,
    hydrateTokenWallet,
    maybeRebalancePackBonusGrant,
    maybeSplitCombinedPackHistory,
    shouldUseTokenWallet,
    starterTokenGrant,
    tokenWalletDeviceFields,
    tokenWalletUserFields,
    usesFirstFreeTranslation,
} from './tokenWallet';
import {
    ensureGrantLotsConsistentInTx,
    expireDueGrantLotsInTx,
    loadActiveGrantLots,
    recordGrantLotInTx,
    type GrantLotDoc,
} from './tokenGrantLots';

const MOBILE_STARTER_BONUS_LEGACY = 5;
const MOBILE_STARTER_BONUS_V160 = 2;
const GOOGLE_LOGIN_BONUS = 2;
const STARTER_CREDIT_INTEGRITY_MIN_VERSION = '1.6.2';
const DESKTOP_PLATFORMS = new Set(['windows', 'macos', 'linux', 'desktop', 'desktop_client']);

type AuthLike = {
    token?: {
        email?: unknown;
        firebase?: {
            sign_in_provider?: unknown;
            identities?: unknown;
        };
    };
} | null;

function getAuthEmail(auth?: AuthLike): string | null {
    const raw = auth?.token?.email;
    if (typeof raw !== 'string') return null;
    const trimmed = raw.trim().toLowerCase();
    return trimmed.length > 0 ? trimmed : null;
}

function getGoogleTrackingEmail(auth?: AuthLike): string | null {
    const email = getAuthEmail(auth);
    if (!email) return null;

    const firebaseToken = auth?.token?.firebase;
    const signInProvider = typeof firebaseToken?.sign_in_provider === 'string'
        ? firebaseToken.sign_in_provider
        : '';
    const identities = firebaseToken?.identities;
    const hasGoogleIdentity = identities && typeof identities === 'object'
        ? Object.prototype.hasOwnProperty.call(identities, 'google.com')
        : false;

    return signInProvider === 'google.com' || hasGoogleIdentity
        ? email
        : null;
}

async function resolveGoogleTrackingEmail({
    auth,
    uid,
}: {
    auth?: AuthLike;
    uid: string;
}): Promise<string | null> {
    const tokenEmail = getGoogleTrackingEmail(auth);
    if (tokenEmail) {
        return tokenEmail;
    }

    // Fallback: when Firebase callable receives a stale ID token right after
    // link/sign-in, token claims may not include google provider yet.
    // Admin Auth providerData is authoritative for current account state.
    try {
        const userRecord = await admin.auth().getUser(uid);
        const hasGoogleProvider = userRecord.providerData
            .some((provider) => provider.providerId === 'google.com');
        if (!hasGoogleProvider) return null;

        const email = (userRecord.email ?? '').trim().toLowerCase();
        return email.length > 0 ? email : null;
    } catch (error) {
        logger.warn('giveStarterCredits: failed to resolve google provider from auth record', {
            uid,
            error: error instanceof Error ? error.message : String(error),
        });
        return null;
    }
}

interface StarterCreditsData {
    deviceId?: string;
    platform?: string;
    appVersion?: string;
    timeZoneOffsetMinutes?: number;
    countryCodes?: string[];
    languageCodes?: string[];
}

export const giveStarterCredits = onCall<StarterCreditsData>({ invoker: 'public', enforceAppCheck: false }, async (request) => {

    const { deviceId, platform, appVersion, timeZoneOffsetMinutes, countryCodes } = request.data;
    const resolvedPlatform = String(platform ?? '').trim().toLowerCase();
    const isMobilePlatform = resolvedPlatform === 'android' || resolvedPlatform === 'ios';
    const isWebPlatform = resolvedPlatform === 'web';
    const isDesktopPlatform = DESKTOP_PLATFORMS.has(resolvedPlatform);
    const normalizedDeviceId = String(deviceId ?? '').trim();
    const geoPolicyArgs = {
        countryCodes,
        timeZoneOffsetMinutes,
        appVersion,
    };

    // NOTE: Starter bonus is device-based and must not require Google sign-in.
    // However, we still require Firebase Auth (anonymous is OK) to reduce abuse
    // and to keep behavior consistent across clients.
    const auth = request.auth;
    const userId = auth?.uid ?? null;
    if (!userId) {
        logger.warn('giveStarterCredits: unauthenticated call');
        throw new HttpsError('unauthenticated', 'Auth is required.');
    }

    // Device ID remains mandatory only on mobile.
    if (isMobilePlatform && !normalizedDeviceId) {
        logger.warn('giveStarterCredits: missing deviceId', { uid: userId });
        throw new HttpsError(
            'invalid-argument',
            'Device ID is required.'
        );
    }

    const deviceIdSuffix = normalizedDeviceId.length >= 6
        ? normalizedDeviceId.slice(-6)
        : normalizedDeviceId;
    logger.info('giveStarterCredits: called', {
        uid: userId,
        deviceIdLen: normalizedDeviceId.length,
        deviceIdSuffix,
    });

    const db = admin.firestore();
    const deviceBonusRef = normalizedDeviceId
        ? db.collection('device_bonuses').doc(normalizedDeviceId)
        : null;
    const userRef = db.collection('users').doc(userId);
    if (shouldUseTokenWallet({ appVersion, platform: resolvedPlatform })) {
        const userDoc = await userRef.get();
        if (userDoc.exists) {
            await maybeRebalancePackBonusGrant({
                db,
                uid: userId,
                userData: userDoc.data() ?? {},
            });
            await maybeSplitCombinedPackHistory({
                db,
                uid: userId,
                userData: (await userRef.get()).data() ?? {},
            });
        }
    }
    const googleTrackingEmail = await resolveGoogleTrackingEmail({ auth, uid: userId });
    const trackingRef = googleTrackingEmail
        ? db.collection('claimed_login_bonuses').doc(googleTrackingEmail)
        : null;

    let deviceBonusExisted = false;
    let grantedNow = false;

    // Transaction kullanarak veri bütünlüğünü sağlıyoruz (Atomik işlem)
    try {
        const payload = await db.runTransaction(async (transaction) => {
            // IMPORTANT: In Firestore transactions, all reads must happen before any writes.
            const deviceBonusDoc = deviceBonusRef
                ? await transaction.get(deviceBonusRef)
                : null;
            const userDoc = await transaction.get(userRef);
            const trackingDoc = trackingRef ? await transaction.get(trackingRef) : null;

            const restriction = resolveFreeRewardsRestriction({
                userData: userDoc.data(),
                ...geoPolicyArgs,
            });
            const freeRewardsRestricted = restriction.restricted;
            const freeRewardsRestrictedReason = restriction.reason;

            deviceBonusExisted = !!deviceBonusDoc?.exists;

            const useV160StarterBonus = shouldUseV160ClientRules({
                appVersion,
                platform: resolvedPlatform,
            });
            const mobileStarterBonus = freeRewardsRestricted
                ? RESTRICTED_STARTER_BONUS
                : (useV160StarterBonus
                    ? MOBILE_STARTER_BONUS_V160
                    : MOBILE_STARTER_BONUS_LEGACY);
            const starterBonusAmount = isMobilePlatform ? mobileStarterBonus : 0;
            const shouldEnforceStarterCreditIntegrity = meetsMinimumVersion(
                appVersion,
                STARTER_CREDIT_INTEGRITY_MIN_VERSION,
            );
            const starterBonusBlockedOnRootedDevice =
                shouldEnforceStarterCreditIntegrity &&
                isMobilePlatform &&
                !request.app &&
                !deviceBonusDoc?.exists;
            const trackingPlatform = resolvedPlatform || 'unknown';

            // Existing schema variants:
            // - legacy: { deviceId, userId, timestamp }
            // - legacy v2: { bonusCredits: 5 }
            // - new: { deviceCredits: <remaining> }
            const existingData = deviceBonusDoc?.exists ? (deviceBonusDoc.data() ?? {}) : {};
            const legacyBonus = Number(existingData.bonusCredits ?? 0);
            let deviceCredits = Number(existingData.deviceCredits ?? 0);
            const isAdRewardOnlyInit = existingData.adRewardOnlyInit === true;
            // Existing grants keep their historical cap so we don't claw back
            // already-issued free device credits when region policy lowers the starter amount.
            const historicalBonusAmount = Number(existingData.bonusAmount ?? NaN);
            const starterCapForClamp =
                deviceBonusDoc?.exists &&
                !isAdRewardOnlyInit &&
                Number.isFinite(historicalBonusAmount) &&
                historicalBonusAmount > 0
                    ? Math.max(starterBonusAmount, historicalBonusAmount)
                    : starterBonusAmount;

            const hasTrackingFields =
                Object.prototype.hasOwnProperty.call(existingData, 'deviceCredits') ||
                Object.prototype.hasOwnProperty.call(existingData, 'bonusCredits') ||
                Object.prototype.hasOwnProperty.call(existingData, 'totalBonusConsumed');

            // Legacy marker migration: old docs may exist without any tracking fields
            // (only deviceId/userId/timestamp). Treat them as "bonus granted" but
            // initialize remaining bonus to full amount once so users don't lose credits
            // on schema change. Lifetime cap is still enforced by totalBonusConsumed.
            if (deviceBonusDoc?.exists && !hasTrackingFields) {
                deviceCredits = starterCapForClamp;
            }

            // Track total bonus consumption per device to prevent any form of top-up.
            let totalBonusConsumed = Number(existingData.totalBonusConsumed ?? NaN);
            if (!Number.isFinite(totalBonusConsumed) || totalBonusConsumed < 0) {
                if (deviceBonusDoc?.exists && !hasTrackingFields) {
                    totalBonusConsumed = 0;
                } else {
                    // Infer best-effort from remaining deviceCredits.
                    const inferredRemaining = Number.isFinite(deviceCredits) ? deviceCredits : 0;
                    const clampedRemaining = Math.max(0, Math.min(starterCapForClamp, inferredRemaining));
                    totalBonusConsumed = Math.max(0, starterCapForClamp - clampedRemaining);
                }
            }

            // If we have an old doc but no deviceCredits field, seed it from legacy bonus.
            if (deviceBonusDoc?.exists && (!Number.isFinite(deviceCredits) || deviceCredits <= 0)) {
                if (Number.isFinite(legacyBonus) && legacyBonus > 0) {
                    deviceCredits = legacyBonus;
                } else {
                    deviceCredits = 0;
                }
            }

            // Clamp to remaining allowed bonus (starterCapForClamp - totalBonusConsumed)
            const remainingAllowed = Math.max(0, starterCapForClamp - totalBonusConsumed);
            if (!Number.isFinite(deviceCredits) || deviceCredits < 0) deviceCredits = 0;
            deviceCredits = Math.min(deviceCredits, remainingAllowed);

            const useWallet = shouldUseTokenWallet({
                appVersion,
                platform: resolvedPlatform,
            });
            // First-free translation era (mobile 1.8.5+): no starter tokens.
            // The very first translation is free up to a fair-use cap instead.
            const firstFreePolicyActive = usesFirstFreeTranslation({
                appVersion,
                platform: resolvedPlatform,
            });
            const canGiveStarterBonus =
                !firstFreePolicyActive &&
                starterBonusAmount > 0 &&
                (!deviceBonusDoc?.exists || isAdRewardOnlyInit) &&
                !starterBonusBlockedOnRootedDevice;
            if (canGiveStarterBonus && !useWallet) {
                grantedNow = true;
                deviceCredits = starterBonusAmount;
                totalBonusConsumed = 0;
            }
            if (canGiveStarterBonus && useWallet) {
                grantedNow = true;
                deviceCredits = 0;
                totalBonusConsumed = 0;
            }

            const trackingData = trackingDoc?.exists ? (trackingDoc.data() ?? {}) : {};
            const firstPlatform = String(trackingData.firstPlatform || trackingData.platform || trackingPlatform).trim() || trackingPlatform;

            // Unified Google login bonus: one-time 2 googleLoginCredits per Google account (any platform).
            // Token-wallet clients (mobile 1.8.0+, desktop/web after wallet start) do not receive it.
            // Uses claimed_login_bonuses/{email} for cross-platform dedup.
            // Backward-compat: also skip if loginBonusGranted === true (old desktop purchasedCredits grant).
            const alreadyHasLoginBonus =
                trackingData.googleLoginBonusGranted === true ||
                trackingData.loginBonusGranted === true;
            const deviceAlreadyHasLoginBonus =
                existingData.googleLoginBonusGranted === true ||
                existingData.loginBonusGranted === true ||
                existingData.googleLoginBonusClaimedAt != null;

            // Purchased credits and optional Google login bonus read (done before any writes).
            let purchasedCredits = 0;
            let googleLoginCredits = 0;
            if (userDoc.exists) {
                const userData = userDoc.data() ?? {};
                const raw = userData.purchasedCredits ?? userData.credits ?? 0;
                purchasedCredits = Number.isFinite(Number(raw)) ? Number(raw) : 0;
                googleLoginCredits = Number.isFinite(Number(userData.googleLoginCredits)) ? Number(userData.googleLoginCredits) : 0;
            }

            const googleLoginBonusToGive = !useWallet &&
                !freeRewardsRestricted &&
                trackingRef &&
                !alreadyHasLoginBonus &&
                !deviceAlreadyHasLoginBonus
                ? GOOGLE_LOGIN_BONUS
                : 0;
            // Authoritative first-free eligibility for client UI and starter buffer check.
            // Must mirror quoteTranslationCost: no prior first-free usage,
            // no legacy starter grant, and not a rooted (no App Check) device.
            const firstFreeUsed =
                (userDoc.data() ?? {}).firstFreeTranslationUsedAt != null ||
                existingData.firstFreeTranslationUsedAt != null;
            const starterAlreadyGranted =
                !!deviceBonusDoc?.exists &&
                existingData.bonusGranted === true &&
                Number(existingData.bonusAmount ?? 0) > 0 &&
                existingData.adRewardOnlyInit !== true;
            const firstTranslationFree =
                firstFreePolicyActive &&
                !starterBonusBlockedOnRootedDevice &&
                !firstFreeUsed &&
                !starterAlreadyGranted;

            const existingUserTokens = Number((userDoc.data() ?? {}).tokenBalance ?? 0);
            // Hotfix for legacy client v1.8.5: v1.8.5 checks `hasSpendableBalance` at line 1085
            // before running the translation engine, even when the quote is fully free.
            // In v1.8.6+ this client bug is fixed, so 1.8.6+ users correctly receive 0 starter tokens.
            const isV185BuggyClient =
                firstFreePolicyActive &&
                !meetsMinimumVersion(appVersion, '1.8.6');

            const firstFreeStarterBufferToGive =
                useWallet &&
                isV185BuggyClient &&
                firstTranslationFree &&
                existingUserTokens <= 0
                    ? 100
                    : 0;

            const starterTokensToGive = useWallet && canGiveStarterBonus
                ? starterTokenGrant(freeRewardsRestricted)
                : firstFreeStarterBufferToGive;

            if (firstFreeStarterBufferToGive > 0) {
                grantedNow = true;
            }
            // Token-wallet era: no Google login token grant (all regions).
            const googleLoginTokensToGive = 0;

            // All lot reads must happen before any writes in this transaction.
            let activeGrantLots: GrantLotDoc[] = [];
            if (useWallet) {
                activeGrantLots = await loadActiveGrantLots(transaction, userRef);
            }

            if (trackingRef && (!trackingDoc?.exists || googleLoginBonusToGive > 0)) {
                transaction.set(
                    trackingRef,
                    {
                        uid: userId,
                        email: googleTrackingEmail,
                        platform: firstPlatform,
                        firstPlatform,
                        lastPlatform: trackingPlatform,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        googleLoginBonusGranted: alreadyHasLoginBonus || googleLoginBonusToGive > 0,
                        loginBonusGranted: alreadyHasLoginBonus || googleLoginBonusToGive > 0,
                        ...(trackingDoc?.exists ? {} : {
                            firstSeenAt: admin.firestore.FieldValue.serverTimestamp(),
                            source: 'signup_tracking',
                        }),
                        ...(googleLoginBonusToGive > 0 ? {
                            creditsAdded: googleLoginTokensToGive > 0
                                ? googleLoginTokensToGive
                                : googleLoginBonusToGive,
                            creditType: googleLoginTokensToGive > 0 ? 'token_grant' : 'google_login',
                            unit: googleLoginTokensToGive > 0 ? 'token' : 'credit',
                            claimedAt: admin.firestore.FieldValue.serverTimestamp(),
                            googleLoginBonusGrantedAt: admin.firestore.FieldValue.serverTimestamp(),
                            googleLoginBonusPlatform: trackingPlatform,
                        } : {}),
                    },
                    { merge: true },
                );
            }

            let shouldWriteDeviceState = !!deviceBonusRef && (
                !isWebPlatform ||
                !!deviceBonusDoc?.exists ||
                canGiveStarterBonus ||
                googleLoginBonusToGive > 0
            );
            // First-free clients must not receive a starter-device document;
            // otherwise the device would look like a starter recipient and lose
            // its first-free translation allowance.
            if (firstFreePolicyActive && !deviceBonusDoc?.exists) {
                shouldWriteDeviceState = false;
            }
            if (starterBonusBlockedOnRootedDevice && !deviceBonusDoc?.exists) {
                shouldWriteDeviceState = false;
            }
            if (shouldWriteDeviceState && deviceBonusRef) {
                const deviceBonusUpdate: Record<string, any> = {
                    deviceId: normalizedDeviceId,
                    deviceCredits,
                    bonusGranted: true,
                    bonusAmount: canGiveStarterBonus
                        ? starterBonusAmount
                        : starterCapForClamp,
                    totalBonusConsumed,
                    createdAt: deviceBonusDoc?.exists
                        ? (existingData.createdAt ?? admin.firestore.FieldValue.serverTimestamp())
                        : admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    lastUserId: userId,
                    ...(googleLoginBonusToGive > 0 ? {
                        googleLoginBonusGranted: true,
                        loginBonusGranted: true,
                        googleLoginBonusClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
                        googleLoginBonusClaimedByUid: userId,
                        googleLoginBonusClaimedByEmail: googleTrackingEmail,
                    } : {}),
                };
                if (isAdRewardOnlyInit) {
                    deviceBonusUpdate.adRewardOnlyInit = admin.firestore.FieldValue.delete();
                }
                transaction.set(
                    deviceBonusRef,
                    deviceBonusUpdate,
                    { merge: true },
                );
            }

            if (googleLoginBonusToGive > 0 && !useWallet) {
                googleLoginCredits = Math.max(googleLoginCredits, googleLoginBonusToGive);

                transaction.set(
                    userRef,
                    {
                        googleLoginCredits,
                        googleLoginBonusGranted: true,
                        googleLoginBonusDate: admin.firestore.FieldValue.serverTimestamp(),
                    },
                    { merge: true },
                );

                const creditTxRef = userRef.collection('credit_transactions').doc();
                transaction.set(creditTxRef, {
                    type: 'add',
                    amount: googleLoginBonusToGive,
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    source: 'google_login_bonus',
                    creditType: 'google_login',
                    platform: resolvedPlatform || 'unknown',
                });
            }

            let walletState = useWallet
                ? hydrateTokenWallet({
                    userData: userDoc.exists ? (userDoc.data() ?? {}) : {},
                    deviceData: existingData,
                })
                : null;
            if (useWallet) {
                deviceCredits = 0;
            }
            const grantNow = new Date();
            if (walletState) {
                activeGrantLots = ensureGrantLotsConsistentInTx(
                    transaction,
                    userRef,
                    walletState,
                    activeGrantLots,
                    grantNow,
                );
                const expired = expireDueGrantLotsInTx(
                    transaction,
                    userRef,
                    walletState,
                    activeGrantLots,
                    grantNow,
                );
                walletState = expired.next;
                activeGrantLots = expired.lots;
                if (walletState.convertedBonusTokens > 0) {
                    const conversionLot = recordGrantLotInTx(transaction, userRef, {
                        amount: walletState.convertedBonusTokens,
                        source: 'legacy_conversion',
                        originId: `legacy_conversion_${userId}`,
                        grantedAt: grantNow,
                        existingLots: activeGrantLots,
                    });
                    if (conversionLot && !activeGrantLots.some((lot) => lot.id === conversionLot.id)) {
                        activeGrantLots = [...activeGrantLots, conversionLot];
                    }
                }
            }
            if (walletState && starterTokensToGive > 0) {
                walletState = addGrantTokens(walletState, starterTokensToGive);
                recordGrantLotInTx(transaction, userRef, {
                    amount: starterTokensToGive,
                    source: 'starter_bonus',
                    originId: `starter_${normalizedDeviceId || userId}`,
                    grantedAt: grantNow,
                    deviceId: normalizedDeviceId || null,
                    existingLots: activeGrantLots,
                });
            }
            if (walletState && googleLoginTokensToGive > 0) {
                walletState = addGrantTokens(walletState, googleLoginTokensToGive);
                recordGrantLotInTx(transaction, userRef, {
                    amount: googleLoginTokensToGive,
                    source: 'google_login_bonus',
                    originId: `google_login_${userId}`,
                    grantedAt: grantNow,
                    existingLots: activeGrantLots,
                });
            }
            if (walletState && (starterTokensToGive > 0 || googleLoginTokensToGive > 0 || walletState.snapshotPending || walletState.convertedBonusTokens > 0)) {
                transaction.set(userRef, {
                    ...tokenWalletUserFields(walletState),
                    ...(googleLoginTokensToGive > 0
                        ? {
                            googleLoginBonusGranted: true,
                            googleLoginBonusDate: admin.firestore.FieldValue.serverTimestamp(),
                        }
                        : {}),
                }, { merge: true });
                const deviceWalletPatch = tokenWalletDeviceFields(walletState);
                if (deviceWalletPatch && deviceBonusRef) {
                    transaction.set(deviceBonusRef, deviceWalletPatch, { merge: true });
                }
                if (walletState.convertedBonusTokens > 0) {
                    transaction.set(userRef.collection('credit_transactions').doc(), {
                        type: 'add',
                        amount: walletState.convertedBonusTokens,
                        unit: 'token',
                        timestamp: admin.firestore.FieldValue.serverTimestamp(),
                        source: 'legacy_bonus_conversion',
                        creditType: 'token_grant',
                        convertedAdCredits: walletState.convertedAdCredits,
                        convertedFreeCredits: walletState.convertedFreeCredits,
                        convertedGoogleCredits: walletState.convertedGoogleCredits,
                        convertedDeviceCredits: walletState.convertedDeviceCredits,
                        remainingTokenBalance: walletState.tokenBalance,
                        remainingTokenGrantBalance: walletState.tokenGrantBalance,
                    });
                }
                if (starterTokensToGive > 0) {
                    transaction.set(userRef.collection('credit_transactions').doc(), {
                        type: 'add',
                        amount: starterTokensToGive,
                        unit: 'token',
                        timestamp: admin.firestore.FieldValue.serverTimestamp(),
                        source: 'starter_bonus',
                        creditType: 'token_grant',
                        platform: resolvedPlatform || 'unknown',
                        remainingTokenBalance: walletState.tokenBalance,
                    });
                }
                if (googleLoginTokensToGive > 0) {
                    transaction.set(userRef.collection('credit_transactions').doc(), {
                        type: 'add',
                        amount: googleLoginTokensToGive,
                        unit: 'token',
                        timestamp: admin.firestore.FieldValue.serverTimestamp(),
                        source: 'google_login_bonus',
                        creditType: 'token_grant',
                        platform: resolvedPlatform || 'unknown',
                        remainingTokenBalance: walletState.tokenBalance,
                    });
                }
            }

            if (restriction.clearLegacyRestrictedFlag) {
                transaction.set(
                    userRef,
                    {
                        freeRewardsRestricted: admin.firestore.FieldValue.delete(),
                        freeRewardsRestrictedReason: admin.firestore.FieldValue.delete(),
                        freeRewardsRestrictedAt: admin.firestore.FieldValue.delete(),
                    },
                    { merge: true },
                );
            } else if (freeRewardsRestricted) {
                transaction.set(
                    userRef,
                    {
                        freeRewardsRestricted: true,
                        freeRewardsGeoLocked: restriction.geoLocked,
                        freeRewardsRestrictedReason: freeRewardsRestrictedReason ?? 'RESTRICTED',
                        freeRewardsRestrictedAt: admin.firestore.FieldValue.serverTimestamp(),
                    },
                    { merge: true },
                );
            }

            const totalCredits = useWallet
                ? (walletState?.legacyFlatRateRemaining ?? purchasedCredits)
                : purchasedCredits + googleLoginCredits + deviceCredits;
            const bonusAmount = useWallet
                ? starterTokensToGive + googleLoginTokensToGive
                : (canGiveStarterBonus ? starterBonusAmount : 0) + googleLoginBonusToGive;
            const baseMessage = starterBonusBlockedOnRootedDevice
                ? 'Cihaz bütünlüğü doğrulanamadığı için başlangıç kredisi verilmedi.'
                : canGiveStarterBonus
                    ? 'Başlangıç kredisi verildi.'
                    : ((isWebPlatform || isDesktopPlatform) ? 'Hesap kredisi hazır.' : 'Cihaz kredisi hazır.');


            return {
                success: true,
                message: googleLoginBonusToGive > 0
                    ? `${baseMessage} Google oturum açma bonusu eklendi!`
                    : baseMessage,
                deviceCredits,
                purchasedCredits,
                googleLoginCredits,
                totalCredits,
                bonusAmount,
                tokenBalance: walletState?.tokenBalance ?? 0,
                legacyFlatRateRemaining: walletState?.legacyFlatRateRemaining ?? 0,
                usesTokenWallet: useWallet,
                firstTranslationFree,
                starterBonusBlockedReason: starterBonusBlockedOnRootedDevice
                    ? 'ROOTED_DEVICE'
                    : null,
                freeRewardsRestricted,
                freeRewardsGeoLocked: restriction.geoLocked,
                freeRewardsRestrictedReason,
            };
        });

        logger.info('giveStarterCredits: success', {
            uid: userId,
            deviceIdSuffix,
            deviceBonusExisted,
            grantedNow,
            deviceCredits: payload.deviceCredits,
            purchasedCredits: payload.purchasedCredits,
            totalCredits: payload.totalCredits,
            bonusAmount: payload.bonusAmount,
            firstTranslationFree: payload.firstTranslationFree,
            starterBonusBlockedReason: payload.starterBonusBlockedReason ?? null,
            freeRewardsRestricted: payload.freeRewardsRestricted,
            freeRewardsGeoLocked: payload.freeRewardsGeoLocked,
            freeRewardsRestrictedReason: payload.freeRewardsRestrictedReason,
        });

        return payload;
    } catch (e) {
        logger.error('giveStarterCredits: failed', {
            uid: userId,
            deviceIdSuffix,
            deviceBonusExisted,
            grantedNow,
            error: e instanceof Error ? e.message : String(e),
        });
        throw e;
    }
});

