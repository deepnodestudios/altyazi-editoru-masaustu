import { createHash } from 'crypto';
import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import {
    getAuthEmail,
    loadCreditSummary,
    normalizePlatform,
    requireDeviceId,
} from '../billing/creditUtils';
import {
    hydrateTokenWallet,
    planTokenWalletCharge,
    spendableTokenBalance,
    tokenChargeRequiresRewardedAd,
} from '../billing/tokenWallet';
import {
    isUnsupportedDesktopClient,
    shouldEnforceDesktopPaidCreditsOnly,
    shouldUseV160ClientRules,
} from '../referral/referralUtils';
import {
    quoteTokensFromCharacterCount,
    translationContentHash,
    TRANSLATION_QUOTE_MIN_DESKTOP_VERSION,
    TRANSLATION_QUOTE_MIN_MOBILE_VERSION,
    TRANSLATION_QUOTE_MULTIPLIER,
    TRANSLATION_QUOTE_PROTOCOL_VERSION,
    TRANSLATION_QUOTE_TTL_MS,
    TRANSLATION_QUOTE_VERSION,
} from './translationQuote';

type QuoteTranslationCostData = {
    deviceId?: string;
    chargeKey?: string;
    sourceContent?: string;
    sourceHash?: string;
    fileName?: string;
    targetLanguage?: string;
    platform?: string;
    appVersion?: string;
    preferFreeCreditsFirst?: boolean;
    quoteProtocolVersion?: number;
};

type QuotePreview = {
    sufficient: boolean;
    chargeMode: string;
    fromPaidTokens: number;
    fromGrantTokens: number;
    requiresRewardedAd: boolean;
    translationCreditType: 'paid' | 'free' | null;
    spendableTokens: number;
};

function quoteIdFor(args: {
    uid: string;
    deviceId: string;
    chargeKey: string;
    contentHash: string;
    targetLanguage: string;
    preferFreeCreditsFirst: boolean;
}): string {
    const digest = createHash('sha256')
        .update([
            TRANSLATION_QUOTE_VERSION,
            args.uid,
            args.deviceId,
            args.chargeKey,
            args.contentHash,
            args.targetLanguage.trim().toLowerCase(),
            args.preferFreeCreditsFirst ? 'grant_first' : 'paid_first',
        ].join('\u0000'))
        .digest('hex');
    return `quote_${digest}`;
}

function isInsufficientCredit(error: unknown): boolean {
    return error instanceof HttpsError
        && error.code === 'failed-precondition'
        && error.message.includes('INSUFFICIENT_CREDIT');
}

async function buildQuotePreview(args: {
    db: admin.firestore.Firestore;
    uid: string;
    deviceId: string;
    platform: string;
    appVersion: string;
    quotedAppTokens: number;
    preferFreeCreditsFirst: boolean;
}): Promise<QuotePreview> {
    const summary = await loadCreditSummary({
        db: args.db,
        uid: args.uid,
        deviceId: args.deviceId,
        platform: args.platform,
        appVersion: args.appVersion,
    });

    if (!summary.usesTokenWallet) {
        return {
            sufficient: summary.totalCredits > 0 || summary.accessActive,
            chargeMode: 'credits',
            fromPaidTokens: 0,
            fromGrantTokens: 0,
            requiresRewardedAd: false,
            translationCreditType: null,
            spendableTokens: 0,
        };
    }

    const spendableTokens = spendableTokenBalance({
        state: {
            tokenBalance: summary.tokenBalance,
            tokenGrantBalance: summary.tokenGrantBalance,
        },
        platform: args.platform,
        appVersion: args.appVersion,
        googleLoginTokenGrantBalance: summary.googleLoginTokenGrantBalance,
    });
    const userSnap = await args.db.collection('users').doc(args.uid).get();

    try {
        // accessExpiresAt is not a pricing entitlement for token-wallet jobs.
        const plan = planTokenWalletCharge({
            state: {
                ...hydrateTokenWallet({ userData: userSnap.data() ?? {} }),
                tokenBalance: summary.tokenBalance,
                tokenGrantBalance: summary.tokenGrantBalance,
                legacyFlatRateRemaining: summary.legacyFlatRateRemaining,
            },
            bonus: {
                adRewardCredits: 0,
                freeCredits: 0,
                googleLoginCredits: 0,
                deviceCredits: 0,
            },
            estimatedTokens: args.quotedAppTokens,
            platform: args.platform,
            appVersion: args.appVersion,
            preferFreeCreditsFirst: args.preferFreeCreditsFirst,
            googleLoginTokenGrantBalance: summary.googleLoginTokenGrantBalance,
        });
        const paid = plan.mode === 'paid_file' || plan.fromPaidTokens > 0;
        const free = plan.mode === 'bonus_file' || plan.fromGrantTokens > 0;
        return {
            sufficient: true,
            chargeMode: plan.mode,
            fromPaidTokens: plan.fromPaidTokens,
            fromGrantTokens: plan.fromGrantTokens,
            requiresRewardedAd:
                (args.platform === 'android' || args.platform === 'ios')
                && shouldUseV160ClientRules({
                    appVersion: args.appVersion,
                    platform: args.platform,
                })
                && tokenChargeRequiresRewardedAd(plan),
            translationCreditType: paid ? 'paid' : (free ? 'free' : null),
            spendableTokens,
        };
    } catch (error) {
        if (!isInsufficientCredit(error)) throw error;
        return {
            sufficient: false,
            chargeMode: 'tokens',
            fromPaidTokens: 0,
            fromGrantTokens: 0,
            requiresRewardedAd: false,
            translationCreditType: null,
            spendableTokens,
        };
    }
}

export const quoteTranslationCost = onCall(
    { invoker: 'public', enforceAppCheck: false },
    async (request: CallableRequest<QuoteTranslationCostData>) => {
        if (!request.auth?.uid) {
            throw new HttpsError(
                'unauthenticated',
                'The function must be called while authenticated.',
            );
        }

        const protocolVersion = Math.floor(
            Number(request.data.quoteProtocolVersion ?? 0),
        );
        if (protocolVersion !== TRANSLATION_QUOTE_PROTOCOL_VERSION) {
            throw new HttpsError(
                'failed-precondition',
                'QUOTE_PROTOCOL_UNSUPPORTED',
            );
        }

        const deviceId = requireDeviceId(request.data.deviceId);
        const chargeKey = String(request.data.chargeKey ?? '').trim();
        if (!chargeKey || chargeKey.includes('/')) {
            throw new HttpsError('invalid-argument', 'Invalid chargeKey');
        }

        const sourceContent = request.data.sourceContent;
        if (typeof sourceContent !== 'string' || sourceContent.length <= 0) {
            throw new HttpsError(
                'invalid-argument',
                'SOURCE_CONTENT_REQUIRED',
            );
        }

        const platform = normalizePlatform(request.data.platform);
        const appVersion = String(request.data.appVersion ?? '').trim()
            || '1.6.0';
        if (isUnsupportedDesktopClient({ appVersion, platform })) {
            throw new HttpsError(
                'failed-precondition',
                'DESKTOP_UPDATE_REQUIRED',
            );
        }

        const targetLanguage = String(
            request.data.targetLanguage ?? '',
        ).trim();
        const fileName = String(request.data.fileName ?? '').trim();
        const sourceHash = String(request.data.sourceHash ?? '').trim();
        const paidCreditsOnly = shouldEnforceDesktopPaidCreditsOnly({
            appVersion,
            platform,
        });
        const preferFreeCreditsFirst = paidCreditsOnly
            ? false
            : request.data.preferFreeCreditsFirst === true;
        const quotedCharacterCount = sourceContent.length;
        const quotedAppTokens = quoteTokensFromCharacterCount(
            quotedCharacterCount,
        );
        const contentHash = translationContentHash(sourceContent);
        const quoteId = quoteIdFor({
            uid: request.auth.uid,
            deviceId,
            chargeKey,
            contentHash,
            targetLanguage,
            preferFreeCreditsFirst,
        });
        const preview = await buildQuotePreview({
            db: admin.firestore(),
            uid: request.auth.uid,
            deviceId,
            platform,
            appVersion,
            quotedAppTokens,
            preferFreeCreditsFirst,
        });
        const now = Date.now();
        const expiresAt = admin.firestore.Timestamp.fromMillis(
            now + TRANSLATION_QUOTE_TTL_MS,
        );
        const db = admin.firestore();
        const sessionRef = db
            .collection('device_bonuses')
            .doc(deviceId)
            .collection('translation_sessions')
            .doc(chargeKey);
        let resolvedPreview = preview;
        let resolvedExpiresAt = expiresAt;

        await db.runTransaction(async (tx) => {
            const existingSnap = await tx.get(sessionRef);
            const existing = existingSnap.data() ?? {};
            if (
                existingSnap.exists
                && existing.uid != null
                && existing.uid !== request.auth?.uid
            ) {
                throw new HttpsError(
                    'permission-denied',
                    'Translation session mismatch.',
                );
            }
            if (
                existingSnap.exists
                && existing.quoteId != null
                && (
                    existing.quoteId !== quoteId
                    || existing.contentHash !== contentHash
                )
            ) {
                throw new HttpsError(
                    'failed-precondition',
                    'QUOTE_CONTENT_MISMATCH',
                );
            }

            const alreadyCharged = existing.charged === true;
            const existingExpiryMillis =
                existing.quoteExpiresAt?.toMillis?.() ?? 0;
            if (
                existingSnap.exists
                && existing.quoteId === quoteId
                && existing.contentHash === contentHash
                && (alreadyCharged || existingExpiryMillis >= now)
            ) {
                resolvedPreview = {
                    sufficient: existing.quotedSufficient === true,
                    chargeMode: String(existing.quotedChargeMode ?? 'tokens'),
                    fromPaidTokens: Math.max(
                        0,
                        Math.floor(Number(existing.quotedFromPaidTokens ?? 0)),
                    ),
                    fromGrantTokens: Math.max(
                        0,
                        Math.floor(Number(existing.quotedFromGrantTokens ?? 0)),
                    ),
                    requiresRewardedAd:
                        existing.quotedRequiresRewardedAd === true,
                    translationCreditType:
                        existing.quotedTranslationCreditType === 'paid'
                        || existing.quotedTranslationCreditType === 'free'
                            ? existing.quotedTranslationCreditType
                            : null,
                    spendableTokens: Math.max(
                        0,
                        Math.floor(Number(
                            existing.quotedSpendableTokens
                            ?? preview.spendableTokens,
                        )),
                    ),
                };
                if (existing.quoteExpiresAt != null) {
                    resolvedExpiresAt = existing.quoteExpiresAt;
                }
                tx.set(sessionRef, {
                    lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
                return;
            }
            tx.set(sessionRef, {
                chargeKey,
                uid: request.auth?.uid,
                email: getAuthEmail(request.auth),
                deviceId,
                fileName: fileName || null,
                targetLanguage: targetLanguage || null,
                sourceHash: sourceHash || null,
                platform,
                appVersion,
                quoteProtocolVersion: TRANSLATION_QUOTE_PROTOCOL_VERSION,
                quoteProtocolMinAppVersion:
                    platform === 'android' || platform === 'ios'
                        ? TRANSLATION_QUOTE_MIN_MOBILE_VERSION
                        : TRANSLATION_QUOTE_MIN_DESKTOP_VERSION,
                quoteVersion: TRANSLATION_QUOTE_VERSION,
                quoteId,
                contentHash,
                quotedCharacterCount,
                characterMultiplier: TRANSLATION_QUOTE_MULTIPLIER,
                quotedAppTokens,
                quotedChargeMode: preview.chargeMode,
                quotedFromPaidTokens: preview.fromPaidTokens,
                quotedFromGrantTokens: preview.fromGrantTokens,
                quotedTranslationCreditType:
                    preview.translationCreditType,
                quotedRequiresRewardedAd:
                    preview.requiresRewardedAd,
                quotedSufficient: preview.sufficient,
                quotedSpendableTokens: preview.spendableTokens,
                preferFreeCreditsFirst,
                prepared: false,
                approved: false,
                ...(!alreadyCharged && { charged: false }),
                quoteCreatedAt: existing.quoteCreatedAt
                    ?? admin.firestore.FieldValue.serverTimestamp(),
                quoteExpiresAt: expiresAt,
                lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        });

        return {
            success: true,
            quoteProtocolVersion: TRANSLATION_QUOTE_PROTOCOL_VERSION,
            quoteProtocolMinAppVersion:
                platform === 'android' || platform === 'ios'
                    ? TRANSLATION_QUOTE_MIN_MOBILE_VERSION
                    : TRANSLATION_QUOTE_MIN_DESKTOP_VERSION,
            quoteVersion: TRANSLATION_QUOTE_VERSION,
            quoteId,
            contentHash,
            quotedCharacterCount,
            characterMultiplier: TRANSLATION_QUOTE_MULTIPLIER,
            quotedAppTokens,
            sufficient: resolvedPreview.sufficient,
            chargeMode: resolvedPreview.chargeMode,
            fromPaidTokens: resolvedPreview.fromPaidTokens,
            fromGrantTokens: resolvedPreview.fromGrantTokens,
            requiresRewardedAd: resolvedPreview.requiresRewardedAd,
            translationCreditType: resolvedPreview.translationCreditType,
            spendableTokens: resolvedPreview.spendableTokens,
            expiresAtMillis: resolvedExpiresAt.toMillis(),
        };
    },
);
