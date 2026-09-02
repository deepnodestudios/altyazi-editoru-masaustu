import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import { GoogleGenAI, HarmCategory, HarmBlockThreshold, Type } from '@google/genai';
import { assertCreditsAvailable, consumeCreditInternal, getAuthEmail, normalizePlatform, requireDeviceId } from '../billing/creditUtils';
import { isUnsupportedDesktopClient } from '../referral/referralUtils';
import { resolveGeminiModel, shouldUseVertexAi } from './modelUtils';

const geminiApiKey = defineSecret('GEMINI_API_KEY_LEGACY');

// Gemini 2.5 Flash-Lite runs the job. Ledger costUsd uses 3.1 list prices
// so P&L matches the 1 Sep token packs. costUsdProvider is the real Google bill.
const LEDGER_PRICING_USD_PER_MILLION = { input: 0.25, output: 1.50 };
const PROVIDER_PRICING_USD_PER_MILLION: Record<string, { input: number; output: number }> = {
    'gemini-2.5-flash-lite': { input: 0.10, output: 0.40 },
};

function computeCostUsd(inputTokens: number, outputTokens: number): string {
    const cost = (inputTokens / 1_000_000) * LEDGER_PRICING_USD_PER_MILLION.input
        + (outputTokens / 1_000_000) * LEDGER_PRICING_USD_PER_MILLION.output;
    return cost.toFixed(6);
}

function computeCostUsdProvider(modelName: string, inputTokens: number, outputTokens: number): string {
    const pricing = PROVIDER_PRICING_USD_PER_MILLION[modelName]
        ?? { input: 0.10, output: 0.40 };
    const cost = (inputTokens / 1_000_000) * pricing.input
        + (outputTokens / 1_000_000) * pricing.output;
    return cost.toFixed(6);
}

type TranslateRequestData = {
    text: string;
    systemPrompt?: string;
    model?: string;
    deviceId?: string;
    chargeKey?: string;
    approveCharge?: boolean;
    fileName?: string;
    targetLanguage?: string;
    platform?: string;
    appVersion?: string;
    // JSON structured output: client lines'ı JSON array olarak gönderir,
    // model çevrilmiş string array döndürür.
    structuredOutput?: boolean;
    // Numaralı satır formatı: girdi "NUMARA|metin" biçiminde olur; çıktı
    // {"i": NUMARA, "t": "ceviri"} objelerinden oluşan dizi olarak zorlanır
    // (responseSchema). Konum kaymasına karşı index bazlı eşleme sağlar.
    // Yalnızca yeni istemciler gönderir.
    numberedLines?: boolean;
    charCount?: number;
    estimatedTokens?: number;
    quoteProtocolVersion?: number;
    quoteId?: string;
    contentHash?: string;
    quoteSourceContent?: string;
};

type TranslationSessionLookup = {
    exists: boolean;
    ref: FirebaseFirestore.DocumentReference | null;
    data: FirebaseFirestore.DocumentData;
};

const EXPLICIT_CONTENT_FALLBACK_INSTRUCTION = 'Additional rule: If a subtitle line is so sexually explicit that a direct translation would cause problems, never skip the line, leave it blank, or refuse to translate; translate it in softer, more veiled language while preserving meaning, and keep the SRT structure unchanged.';

function withExplicitContentFallback(systemPrompt?: string): string {
    const base = (systemPrompt ?? '').trim();
    if (!base) return EXPLICIT_CONTENT_FALLBACK_INSTRUCTION;
    if (
        base.includes('never skip the line') ||
        base.includes('refuse to translate') ||
        base.includes('asla atlama') ||
        base.includes('cevirmeyi reddetme')
    ) {
        return base;
    }
    return `${base}\n${EXPLICIT_CONTENT_FALLBACK_INSTRUCTION}`;
}

function parseChargeKeyMetadata(chargeKey: string): { sourceHash: string; targetToken: string } | null {
    const match = /^run_\d+_([a-f0-9]{32})_(.+)$/i.exec(chargeKey.trim());
    if (!match) return null;

    const sourceHash = (match[1] ?? '').trim().toLowerCase();
    const targetToken = (match[2] ?? '').trim().toLowerCase();
    if (!sourceHash || !targetToken) return null;

    return { sourceHash, targetToken };
}

function getVertexModelCandidates(modelName: string): string[] {
    return [modelName.trim()];
}

function getApiModelCandidates(modelName: string): string[] {
    const requested = modelName.trim();
    const candidates = [requested];

    if (requested !== 'gemini-flash-lite-latest') {
        candidates.push('gemini-flash-lite-latest');
    }

    return [...new Set(candidates)];
}

async function loadTranslationSessionByChargeKey({
    db,
    deviceId,
    chargeKey,
    uid,
}: {
    db: admin.firestore.Firestore;
    deviceId: string;
    chargeKey: string;
    uid: string;
}): Promise<TranslationSessionLookup> {
    const directRef = db
        .collection('device_bonuses')
        .doc(deviceId)
        .collection('translation_sessions')
        .doc(chargeKey);
    const directSnap = await directRef.get();
    const directData = directSnap.data() ?? {};

    if (directSnap.exists) {
        if (directData.uid !== uid) {
            throw new HttpsError('permission-denied', 'Translation session mismatch.');
        }
        return {
            exists: true,
            ref: directRef,
            data: directData,
        };
    }

    const parsed = parseChargeKeyMetadata(chargeKey);
    if (parsed) {
        const historyDocId = `${parsed.sourceHash}_${parsed.targetToken}`;
        const historySnap = await db
            .collection('users')
            .doc(uid)
            .collection('translation_history')
            .doc(historyDocId)
            .get();
        const historyData = historySnap.data() ?? {};
        const resumeStateRaw = historyData.resumeState;
        const resumeState = resumeStateRaw && typeof resumeStateRaw === 'object'
            ? resumeStateRaw as Record<string, unknown>
            : null;
        const historyChargeKey = String(
            historyData.chargeKey ?? resumeState?.chargeKey ?? ''
        ).trim();
        const translatedBlocks = Array.isArray(resumeState?.translatedBlocks)
            ? resumeState?.translatedBlocks
            : [];
        const translatedLinesRaw = Number(historyData.translatedLines ?? resumeState?.processedLines ?? 0);
        const translatedLines = Number.isFinite(translatedLinesRaw) ? translatedLinesRaw : 0;
        const hasProgress = translatedBlocks.length > 0 || translatedLines > 0;

        if (historySnap.exists && historyChargeKey === chargeKey && hasProgress) {
            return {
                exists: true,
                ref: null,
                data: {
                    chargeKey,
                    uid,
                    email: historyData.lastUserEmail ?? null,
                    fileName: historyData.fileName ?? null,
                    targetLanguage: historyData.targetLanguage ?? null,
                    platform: historyData.completedPlatform ?? null,
                    prepared: true,
                    approved: true,
                    approvedAt: historyData.resumeUpdatedAt ?? historyData.updatedAt ?? null,
                    charged: true,
                    chargedAt: historyData.resumeUpdatedAt ?? historyData.updatedAt ?? null,
                    lastSeenAt: historyData.updatedAt ?? null,
                },
            };
        }
    }

    return {
        exists: false,
        ref: directRef,
        data: {},
    };
}

export const translateText = onCall({ secrets: [geminiApiKey], invoker: 'public', enforceAppCheck: false }, async (request: CallableRequest<TranslateRequestData>) => {
    // NOTE: This function is invoked from client apps via Firebase callable.
    // It must be publicly invokable at the infrastructure (Cloud Run) layer.
    // Access is still enforced here via request.auth.

    console.log('translateText called', {
        hasAuth: !!request.auth,
        uid: request.auth?.uid ?? null,
    });

    // 1. Auth Check
    if (!request.auth) {
        throw new HttpsError(
            'unauthenticated',
            'The function must be called while authenticated.'
        );
    }

    // 2. Extract Data
    const {
        text,
        systemPrompt,
        deviceId,
        chargeKey,
        approveCharge,
        fileName,
        targetLanguage,
        platform,
        appVersion,
        structuredOutput,
        numberedLines,
        quoteProtocolVersion,
        quoteId,
        contentHash,
        quoteSourceContent,
    } = request.data;
    const resolvedAppVersion = (appVersion ?? '').trim() || '1.6.0';
    const requestCharCount = Number(request.data.charCount);
    const requestEstimatedTokens = Number(request.data.estimatedTokens);
    const useStructuredOutput = structuredOutput === true;
    // Numaralı satır formatı yalnızca bunu bilen yeni istemciler için etkindir.
    // Eski canlı istemciler bu bayrağı göndermez → prompt aynen eski davranır.
    const useNumberedLines = numberedLines === true;

    const trimmedChargeKey = (chargeKey ?? '').trim();
    if (trimmedChargeKey.includes('/')) {
        throw new HttpsError('invalid-argument', 'Invalid chargeKey');
    }

    if (!text) {
        throw new HttpsError('invalid-argument', 'The function must be called with "text" argument.');
    }

    const normalizedDeviceId = requireDeviceId(deviceId);
    const normalizedPlatform = normalizePlatform(platform);
    if (isUnsupportedDesktopClient({
        appVersion: resolvedAppVersion,
        platform: normalizedPlatform,
    })) {
        throw new HttpsError('failed-precondition', 'DESKTOP_UPDATE_REQUIRED');
    }

    const db = admin.firestore();
    
    let finalFileName = fileName;
    let finalTargetLanguage = targetLanguage;
    let chargeReceipt: Record<string, unknown> | null = null;

    if (approveCharge) {
        if (!trimmedChargeKey) {
            throw new HttpsError('failed-precondition', 'Translation session not prepared.');
        }

        const session = await loadTranslationSessionByChargeKey({
            db,
            deviceId: normalizedDeviceId,
            chargeKey: trimmedChargeKey,
            uid: request.auth.uid,
        });
        const sessionData = session.data ?? {};

        if (!session.exists) {
            throw new HttpsError('permission-denied', 'Translation session mismatch.');
        }
        if (sessionData.charged === true) {
            throw new HttpsError('failed-precondition', 'Translation session already charged.');
        }

        finalFileName = finalFileName || sessionData.fileName;
        finalTargetLanguage = finalTargetLanguage || sessionData.targetLanguage;
        // Platform bilgisi eksik gelirse oturumdaki bilgiyi kullan
        const finalPlatform = platform || sessionData.platform;

        const normalizedFinalPlatform = normalizePlatform(finalPlatform);
        if (sessionData.requiresRewardedAd === true && sessionData.rewardedAdConfirmed !== true) {
            throw new HttpsError('failed-precondition', 'REWARDED_AD_REQUIRED');
        }

        await assertCreditsAvailable({
            db,
            uid: request.auth.uid,
            deviceId: normalizedDeviceId,
            platform: normalizedFinalPlatform,
            appVersion: resolvedAppVersion,
        });
        chargeReceipt = await consumeCreditInternal({
            db,
            amount: 1,
            deviceId: normalizedDeviceId,
            uid: request.auth.uid,
            email: getAuthEmail(request.auth),
            reason: 'first_chunk',
            chargeKey: trimmedChargeKey,
            fileName: finalFileName,
            targetLanguage: finalTargetLanguage,
            platform: normalizedFinalPlatform,
            appVersion: resolvedAppVersion,
            preferFreeCreditsFirst:
                sessionData.preferFreeCreditsFirst === true,
            allowAutoApproveSession: true,
            charCount: Number.isFinite(requestCharCount)
                && requestCharCount > 0
                ? requestCharCount
                : Number(sessionData.charCount ?? 0) || null,
            estimatedTokens: Number.isFinite(requestEstimatedTokens)
                && requestEstimatedTokens > 0
                ? requestEstimatedTokens
                : Number(sessionData.estimatedTokens ?? 0) || null,
            quoteProtocolVersion,
            quoteId,
            contentHash,
            sourceContent: quoteSourceContent,
        });
    } else {
        let hasChargedSession = false;

        if (trimmedChargeKey) {
            const session = await loadTranslationSessionByChargeKey({
                db,
                deviceId: normalizedDeviceId,
                chargeKey: trimmedChargeKey,
                uid: request.auth.uid,
            });
            const sessionData = session.data ?? {};

            if (session.exists) {
                hasChargedSession = sessionData.charged === true;
                if (hasChargedSession) {
                    finalFileName = finalFileName || sessionData.fileName;
                    finalTargetLanguage = finalTargetLanguage || sessionData.targetLanguage;

                    const currentSessionRef = db
                        .collection('device_bonuses')
                        .doc(normalizedDeviceId)
                        .collection('translation_sessions')
                        .doc(trimmedChargeKey);
                    if (session.ref?.path !== currentSessionRef.path) {
                        await currentSessionRef.set({
                            chargeKey: trimmedChargeKey,
                            uid: request.auth.uid,
                            email: sessionData.email ?? getAuthEmail(request.auth),
                            deviceId: normalizedDeviceId,
                            fileName: sessionData.fileName ?? finalFileName ?? null,
                            targetLanguage: sessionData.targetLanguage ?? finalTargetLanguage ?? null,
                            platform: sessionData.platform ?? normalizedPlatform,
                            prepared: true,
                            approved: sessionData.approved === true,
                            approvedAt: sessionData.approvedAt ?? null,
                            charged: true,
                            chargedAt: sessionData.chargedAt ?? admin.firestore.FieldValue.serverTimestamp(),
                            lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
                        }, { merge: true });
                    }
                }
            }
        }

        if (!hasChargedSession) {
            await assertCreditsAvailable({
                db,
                uid: request.auth.uid,
                deviceId: normalizedDeviceId,
                platform: normalizedPlatform,
                appVersion: resolvedAppVersion,
            });
        }
    }

    const modelName = resolveGeminiModel(resolvedAppVersion);
    const useVertex = shouldUseVertexAi(resolvedAppVersion);
    const ai = useVertex
        ? new GoogleGenAI({
            vertexai: true,
            project: 'altyazi-ceviri-editor',
            location: 'global',
        })
        : new GoogleGenAI({
            apiKey: geminiApiKey.value(),
            httpOptions: { apiVersion: 'v1beta' },
        });
    const modelCandidates = useVertex ? getVertexModelCandidates(modelName) : getApiModelCandidates(modelName);

    console.log('translateText provider/model', { provider: useVertex ? 'vertex' : 'gemini_api', modelName, appVersion: resolvedAppVersion, structuredOutput: useStructuredOutput, numberedLines: useNumberedLines });
    let effectiveSystemPrompt = withExplicitContentFallback(systemPrompt);
    if (useStructuredOutput) {
        // Altyapı katmanı kuralı: çıktı her zaman JSON string array olmalı.
        // (System prompt yalnızca ek bilgidir; asıl garanti responseSchema'da.)
        const baseRules = `\n\nOutput rules (MANDATORY):\n- Your reply must be a single JSON array: ["translated line 1", "translated line 2", ...].\n- Array elements must be in EXACTLY the same order and the same count as the input array.\n- Do NOT add timecodes, block numbers, or SRT framing; only the translated texts.`;
        const numberedRules = `\n- The INPUT is numbered in "NUMBER|text" form and the NUMBERS ARE NOT SEQUENTIAL (e.g. 17, 3, 290, 81...). Each element in the output array MUST be a JSON object of the form {"i": NUMBER, "t": "translation"}. The "i" field is an exact COPY of that line's own number from the input; do not renumber in sequence, invent your own numbers, skip, change, or repeat them. NEVER MERGE TWO INPUT LINES INTO A SINGLE OUTPUT OBJECT; produce exactly one object for each input line.
- EVEN IF AN INPUT LINE IS A HALF/SPLIT SENTENCE, DO NOT COMPLETE IT, DO NOT GUESS THE MISSING PART, AND DO NOT ADD MEANING FROM THE PREVIOUS/NEXT LINE INTO YOUR OWN TRANSLATION; translate each line independently, using only its own words. DO NOT WRITE THE SAME/VERY SIMILAR SENTENCE INTO TWO SEPARATE OUTPUT OBJECTS.`;
        effectiveSystemPrompt = `${effectiveSystemPrompt}${baseRules}${useNumberedLines ? numberedRules : ''}`;
    }

    try {
        let result: any = null;
        let modelUsed = modelName;
        const providerUsed = useVertex ? 'vertex' : 'gemini_api';
        let lastError: any = null;

        for (const candidate of modelCandidates) {
            try {
                console.log('translateText model candidate', { candidate });
                result = await ai.models.generateContent({
                    model: candidate,
                    contents: [{ role: 'user', parts: [{ text }] }],
                    config: {
                        temperature: 0.7,
                        topK: 40,
                        topP: 0.95,
                    ...(useStructuredOutput
                        ? {
                              responseMimeType: 'application/json',
                              responseSchema: useNumberedLines
                                  ? {
                                        type: Type.ARRAY,
                                        items: {
                                            type: Type.OBJECT,
                                            properties: {
                                                i: { type: Type.INTEGER },
                                                t: { type: Type.STRING },
                                            },
                                            required: ['i', 't'],
                                        },
                                    }
                                  : {
                                        type: Type.ARRAY,
                                        items: { type: Type.STRING },
                                    },
                          }
                        : {}),
                        safetySettings: [
                            { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_NONE },
                            { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_NONE },
                            { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_NONE },
                            { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_NONE },
                            { category: HarmCategory.HARM_CATEGORY_CIVIC_INTEGRITY, threshold: HarmBlockThreshold.BLOCK_NONE },
                        ],
                        systemInstruction: { parts: [{ text: effectiveSystemPrompt }] },
                    },
                });
                modelUsed = candidate;
                break;
            } catch (candidateError: any) {
                lastError = candidateError;
                const message = String(candidateError?.message ?? '');
                const status = Number(candidateError?.status ?? 0);
                const notFound = status === 404 || message.includes('NOT_FOUND') || message.includes('was not found');
                if (!notFound) {
                    throw candidateError;
                }
                console.warn('translateText model candidate unavailable', { candidate, status });
            }
        }

        if (!result) {
            throw lastError ?? new Error('No available Vertex model candidate');
        }
        const outputText = result.text ?? '';
        console.log('translateText model used', { modelUsed, providerUsed });
        console.log('translateText output preview', {
            numberedLines: useNumberedLines,
            preview: outputText.slice(0, 300),
        });

        return {
            text: outputText,
            inputTokens: result.usageMetadata?.promptTokenCount || 0,
            outputTokens: result.usageMetadata?.candidatesTokenCount || 0,
            costUsd: computeCostUsd(result.usageMetadata?.promptTokenCount || 0, result.usageMetadata?.candidatesTokenCount || 0),
            costUsdProvider: computeCostUsdProvider(modelUsed, result.usageMetadata?.promptTokenCount || 0, result.usageMetadata?.candidatesTokenCount || 0),
            modelUsed,
            providerUsed,
            ...(chargeReceipt ? { chargeReceipt } : {}),
        };

    } catch (error: any) {
        console.error(`Gemini API Error (model=${modelName}):`, error);

        // Güvenlik veya PROHIBITED_CONTENT nedeniyle engellenen metinleri atlamak için hata kontrolü
        const errorMessage = error.message || '';
        if (
            errorMessage.includes('PROHIBITED_CONTENT') || 
            errorMessage.includes('SAFETY') || 
            errorMessage.includes('blocked')
        ) {
            console.warn('İçerik Gemini API tarafından engellendi. Akışın kopmaması için orijinal metin geri dönülüyor.');
            return {
                text: text, // Süreci kırmamak için orijinal kaynak metni olduğu gibi geri veriyoruz
                inputTokens: 0,
                outputTokens: 0,
                costUsd: '0.000000',
                costUsdProvider: '0.000000',
                modelUsed: modelName
            };
        }

        throw new HttpsError('internal', 'Translation provider failed', error.message);
    }
});

// force redeploy 2
