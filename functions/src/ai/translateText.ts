import { defineSecret } from 'firebase-functions/params';
import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { HarmCategory, HarmBlockThreshold } from '@google/generative-ai';
import { GoogleGenAI } from '@google/genai';
import { assertCreditsAvailable, consumeCreditInternal, getAuthEmail, normalizePlatform, requireDeviceId } from '../billing/creditUtils';
import { MODERN_GEMINI_MODEL } from './modelUtils';

// Initialize Gemini
// Important: Ensure 'gemini.api_key' is set in Firebase functions config
// Command: firebase functions:config:set gemini.api_key="YOUR_KEY"
// Or use process.env if you use environment variables (e.g. .env file)

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

const geminiApiKey = defineSecret('GEMINI_API_KEY');

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
};

type TranslationSessionLookup = {
    exists: boolean;
    ref: FirebaseFirestore.DocumentReference | null;
    data: FirebaseFirestore.DocumentData;
};

function parseChargeKeyMetadata(chargeKey: string): { sourceHash: string; targetToken: string } | null {
    const match = /^run_\d+_([a-f0-9]{32})_(.+)$/i.exec(chargeKey.trim());
    if (!match) return null;

    const sourceHash = (match[1] ?? '').trim().toLowerCase();
    const targetToken = (match[2] ?? '').trim().toLowerCase();
    if (!sourceHash || !targetToken) return null;

    return { sourceHash, targetToken };
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
    } = request.data;
    const resolvedAppVersion = (appVersion ?? '').trim() || '1.6.0';

    const trimmedChargeKey = (chargeKey ?? '').trim();
    if (trimmedChargeKey.includes('/')) {
        throw new HttpsError('invalid-argument', 'Invalid chargeKey');
    }

    if (!text) {
        throw new HttpsError('invalid-argument', 'The function must be called with "text" argument.');
    }

    const normalizedDeviceId = requireDeviceId(deviceId);
    const normalizedPlatform = normalizePlatform(platform);

    const db = admin.firestore();
    
    let finalFileName = fileName;
    let finalTargetLanguage = targetLanguage;

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

        await assertCreditsAvailable({
            db,
            uid: request.auth.uid,
            deviceId: normalizedDeviceId,
            platform: normalizePlatform(finalPlatform),
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
            const deviceDoc = await db.collection('device_bonuses').doc(normalizedDeviceId).get();
            const accessData = deviceDoc.data();

            if (!deviceDoc.exists || !accessData?.accessExpiresAt) {
                 console.warn(`Blocked request for device ${normalizedDeviceId}: No active access record.`);
                 throw new HttpsError('permission-denied', 'No active access found. Please purchase/consume credits.');
            }

            const expiryTime = (accessData.accessExpiresAt as admin.firestore.Timestamp).toMillis();
            if (Date.now() > expiryTime) {
                 console.warn(`Blocked expired request for device ${normalizedDeviceId}`);
                 throw new HttpsError('permission-denied', 'Access expired. Please consume a credit to continue.');
            }
        }
    }

    // 3. Get API Key (Secrets Manager)
    const apiKey = geminiApiKey.value();

    if (!apiKey) {
        throw new HttpsError('internal', 'Server-side API Key not configured. Please set GEMINI_API_KEY in Secrets Manager.');
    }

    const modelName = MODERN_GEMINI_MODEL; // Desktop always uses Vertex AI
    const useVertex = true;
    const ai = useVertex
        ? new GoogleGenAI({
            vertexai: true,
            project: 'altyazi-ceviri-editor',
            location: 'global',
        })
        : new GoogleGenAI({
            apiKey: apiKey,
            httpOptions: { apiVersion: 'v1beta' },
        });
    const modelCandidates = useVertex ? getVertexModelCandidates(modelName) : getApiModelCandidates(modelName);

    console.log('translateText provider/model', { provider: 'vertex', modelName });

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
                        safetySettings: [
                            { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_NONE },
                            { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_NONE },
                            { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_NONE },
                            { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_NONE },
                            { category: HarmCategory.HARM_CATEGORY_CIVIC_INTEGRITY, threshold: HarmBlockThreshold.BLOCK_NONE },
                        ],
                        ...(systemPrompt ? { systemInstruction: { parts: [{ text: systemPrompt }] } } : {}),
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
            throw lastError ?? new Error('No available model candidate');
        }
        const outputText = result.text ?? '';
        console.log('translateText model used', { modelUsed, providerUsed });

        if (approveCharge == true && trimmedChargeKey.length > 0) {
            // if we are here and platform is missing, use the one from session
            const sessionData = await db.collection('device_bonuses').doc(normalizedDeviceId).collection('translation_sessions').doc(trimmedChargeKey).get();
            const platformFromSession = sessionData.data()?.platform;

            await consumeCreditInternal({
                db,
                amount: 1,
                deviceId: normalizedDeviceId,
                uid: request.auth.uid,
                email: getAuthEmail(request.auth),
                reason: 'first_chunk',
                chargeKey: trimmedChargeKey,
                fileName: finalFileName,
                targetLanguage: finalTargetLanguage,
                platform: platform || platformFromSession || normalizedPlatform,
                appVersion: resolvedAppVersion,
                allowAutoApproveSession: true,
            });
        }
        
        return {
            text: outputText,
            inputTokens: result.usageMetadata?.promptTokenCount || 0,
            outputTokens: result.usageMetadata?.candidatesTokenCount || 0,
            modelUsed,
            providerUsed,
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
                modelUsed: modelName
            };
        }

        throw new HttpsError('internal', 'Translation provider failed', error.message);
    }
});

// force redeploy 2
