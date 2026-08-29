import { defineSecret } from 'firebase-functions/params';
import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { GoogleGenAI } from '@google/genai';
import * as os from 'os';
import * as path from 'path';
import * as fs from 'fs';
import { assertCreditsAvailable, consumeCreditInternal, getAuthEmail, normalizePlatform, requireDeviceId } from '../billing/creditUtils';
import { resolveGeminiModel } from './modelUtils';

const geminiApiKey = defineSecret('GEMINI_API_KEY_LEGACY');

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

interface BatchChunk {
    id: string; // so we know which chunk is which
    text: string;
}

interface StartBatchRequestData {
    chunks: BatchChunk[];
    systemPrompt?: string;
    model?: string;
    deviceId?: string;
    chargeKey?: string;
    fcmToken?: string;
    sourceHash?: string;
    sourceContent?: string;
    targetLanguage?: string;
    originalNameForGlobalCache?: string;
    fileNameForHistory?: string;
    totalLines?: number;
    canWriteUserHistory?: boolean;
    completedPlatform?: string;
    isMultiFileBatch?: boolean;
    appVersion?: string;
}

export const startBatchTranslation = onCall({ secrets: [geminiApiKey], invoker: 'public', enforceAppCheck: false, timeoutSeconds: 300 }, async (request: CallableRequest<StartBatchRequestData>) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
    }

    const {
        chunks, systemPrompt, deviceId, chargeKey,
        fcmToken, sourceHash, sourceContent, targetLanguage,
        originalNameForGlobalCache, fileNameForHistory,
        totalLines, canWriteUserHistory, completedPlatform, isMultiFileBatch,
        appVersion,
    } = request.data;
    const resolvedAppVersion = (appVersion ?? '').trim() || '1.6.0';

    if (!chunks || chunks.length === 0) {
        throw new HttpsError('invalid-argument', 'Chunks are required');
    }

    const normalizedDeviceId = requireDeviceId(deviceId);
    const normalizedChargeKey = (chargeKey ?? '').trim();
    const resolvedPlatform = normalizePlatform(completedPlatform);
    if (!normalizedChargeKey) {
        throw new HttpsError('failed-precondition', 'Translation session not prepared.');
    }

    const db = admin.firestore();
    const sessionDoc = await db
        .collection('device_bonuses')
        .doc(normalizedDeviceId)
        .collection('translation_sessions')
        .doc(normalizedChargeKey)
        .get();
    const sessionData = sessionDoc.data() ?? {};
    if (!sessionDoc.exists || sessionData.uid !== request.auth.uid) {
        throw new HttpsError('permission-denied', 'Translation session mismatch.');
    }
    if (sessionData.charged === true) {
        throw new HttpsError('failed-precondition', 'Translation session already charged.');
    }
    if (sessionData.requiresRewardedAd === true && sessionData.rewardedAdConfirmed !== true) {
        throw new HttpsError('failed-precondition', 'REWARDED_AD_REQUIRED');
    }

    await assertCreditsAvailable({
        db,
        uid: request.auth.uid,
        deviceId: normalizedDeviceId,
        platform: resolvedPlatform,
        appVersion: resolvedAppVersion,
    });
    
    const apiKey = geminiApiKey.value();
    if (!apiKey) {
        throw new HttpsError('internal', 'Server-side API Key not configured.');
    }

    try {
        const ai = new GoogleGenAI({ apiKey, httpOptions: { apiVersion: 'v1beta' } });
        const effectiveSystemPrompt = withExplicitContentFallback(systemPrompt);

        // Construct JSONL content
        // Based on Gemini Batch API schema: each line must have a request object
        // For @google/genai: Each line should match the GenerateContentRequest structure
        // But since we want to map back, wait... does it return in the same order?
        // Let's create an standard jsonl:
        // {"request": { "contents": [{"role": "user", "parts": [{"text": "..."}]}] }}
        // The results file will contain a JSON object with "request" and "response" per line.
        // Or we can embed our chunk id inside the text? Actually we don't strictly need to if we assume they are processed.
        // Actually, we can embed the chunk ID inside a custom field, or just inside the text to parse it out, but usually the response contains the original request!
        let jsonlContent = '';
        for (const chunk of chunks) {
            const reqObj: any = {
                request: {
                    contents: [
                        { role: 'user', parts: [{ text: `[CHUNK_ID:${chunk.id}]\n${chunk.text}` }] }
                    ],
                    safetySettings: [
                        { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_NONE' },
                        { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_NONE' },
                        { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_NONE' },
                        { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' },
                        { category: 'HARM_CATEGORY_CIVIC_INTEGRITY', threshold: 'BLOCK_NONE' },
                    ]
                }
            };
            if (effectiveSystemPrompt) {
                reqObj.request.systemInstruction = {
                    parts: [{ text: effectiveSystemPrompt }]
                };
            }
            jsonlContent += JSON.stringify(reqObj) + '\n';
        }

        // Write to temp file
        const tempFilePath = path.join(os.tmpdir(), `batch_req_${Date.now()}.jsonl`);
        fs.writeFileSync(tempFilePath, jsonlContent);

        // Upload file
        const uploadedFile = await ai.files.upload({
            file: tempFilePath,
            config: {
                mimeType: 'application/jsonlines'
            }
        });

        // Clean up temp file
        fs.unlinkSync(tempFilePath);

        if (!uploadedFile.name) {
            throw new Error('Upload failed, file name is missing');
        }

        // Create Batch Job
        const batchJob = await ai.batches.create({
            model: resolveGeminiModel(resolvedAppVersion),
            src: uploadedFile.name,
        });

        if (!batchJob.name) {
            throw new Error('Batch job creation failed, job name is missing');
        }

        await consumeCreditInternal({
            db,
            amount: 1,
            deviceId: normalizedDeviceId,
            uid: request.auth.uid,
            email: getAuthEmail(request.auth),
            reason: 'batch_request',
            chargeKey: normalizedChargeKey,
            fileName: fileNameForHistory,
            targetLanguage,
            platform: resolvedPlatform,
            appVersion: resolvedAppVersion,
            preferFreeCreditsFirst: sessionData.preferFreeCreditsFirst === true,
            allowAutoApproveSession: true,
            charCount: Number(sessionData.charCount ?? 0) || null,
            estimatedTokens: Number(sessionData.estimatedTokens ?? 0) || null,
        });

        // Save batch job info to Firestore so we can track it
        const jobDoc = db.collection('device_bonuses').doc(normalizedDeviceId).collection('batch_jobs').doc(batchJob.name.replace(/\//g, '_'));
        await jobDoc.set({
            jobName: batchJob.name,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            status: 'IN_PROGRESS',
            chargeKey: normalizedChargeKey,
            uid: request.auth.uid,
            email: getAuthEmail(request.auth),
            deviceId: normalizedDeviceId,
            fcmToken: fcmToken ?? null,
            sourceHash: sourceHash ?? null,
            sourceContent: sourceContent ?? null,
            targetLanguage: targetLanguage ?? null,
            originalNameForGlobalCache: originalNameForGlobalCache ?? null,
            fileNameForHistory: fileNameForHistory ?? null,
            totalLines: totalLines ?? null,
            canWriteUserHistory: canWriteUserHistory ?? true,
            completedPlatform: resolvedPlatform,
            isMultiFileBatch: isMultiFileBatch ?? false,
        });

        return {
            success: true,
            jobName: batchJob.name,
            message: 'Batch job started successfully'
        };

    } catch (e: any) {
        console.error('Batch start failed:', e);
        throw new HttpsError('internal', 'Failed to start batch job', e.message);
    }
});

interface CheckBatchRequestData {
    jobName: string;
    deviceId: string;
    sourceHash?: string;
    sourceContent?: string;
    targetLanguage?: string;
    originalNameForGlobalCache?: string;
    fileNameForHistory?: string;
    totalLines?: number;
    canWriteUserHistory?: boolean;
    completedPlatform?: string;
}

export const checkBatchTranslation = onCall({ secrets: [geminiApiKey], invoker: 'public', enforceAppCheck: false }, async (request: CallableRequest<CheckBatchRequestData>) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'The function must be called while authenticated.');
    }

    const { 
        jobName, 
        deviceId,
        sourceHash,
        sourceContent,
        targetLanguage,
        originalNameForGlobalCache,
        fileNameForHistory,
        totalLines,
        canWriteUserHistory,
        completedPlatform
    } = request.data;

    if (!jobName || !deviceId) {
        throw new HttpsError('invalid-argument', 'jobName and deviceId are required');
    }

    const apiKey = geminiApiKey.value();
    const ai = new GoogleGenAI({ apiKey, httpOptions: { apiVersion: 'v1beta' } });

    try {
        const job = await ai.batches.get({ name: jobName });

        if (job.state === 'JOB_STATE_SUCCEEDED') {
            // Process the output file
            if (!job.dest?.fileName) {
                // Should not happen on success
                return { status: job.state, results: null };
            }
            
            const destFileName = job.dest.fileName;

            // Download file content via HTTP or SDK
            // The python example has `client.files.download(file=batch_job.dest.file_name)`
            // We use standard fetch with API key since JS SDK might not expose simple download yet or we don't know the method
const fileRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/${destFileName}:download?key=${apiKey}&alt=media`);
            const fileContent = await fileRes.text();

            const lines = fileContent.split('\n').filter(l => l.trim().length > 0);
            const results = [];

            for (const line of lines) {
                try {
                    const parsed = JSON.parse(line);
                    let text = parsed.response?.candidates?.[0]?.content?.parts?.[0]?.text;
                    
                    if (!text) {
                        // Eğer güvenlik politikası veya PROHIBITED_CONTENT sebebiyle yanıt boş döndüyse orijinal metne dön
                        const reqText = parsed.request?.contents?.[0]?.parts?.[0]?.text || '';
                        // Başına eklediğimiz [CHUNK_ID:...] işaretini temizle
                        text = reqText.replace(/\[CHUNK_ID:[^\]]+\]\n/, '');
                    }

                    results.push(text || '');
                } catch(e) {
                    console.error('Failed to parse line:', e);
                }
            }

            // Update firestore
            const db = admin.firestore();
            const jobDoc = db.collection('device_bonuses').doc(deviceId).collection('batch_jobs').doc(jobName.split('/').join('_'));
            
            const fullTransSrt = results.join('\n\n');

            if (sourceHash && targetLanguage) {
                const cacheKey = `${sourceHash}_${targetLanguage.toLowerCase()}`;
                const actorEmail = getAuthEmail(request.auth);

                // 1. Global Cache
                if (sourceContent && originalNameForGlobalCache) {
                    const globalCacheRef = db.collection('global_translations').doc(cacheKey);
                    await db.runTransaction(async (t) => {
                        const snap = await t.get(globalCacheRef);
                        if (snap.exists) {
                            const data = snap.data() || {};
                            t.update(globalCacheRef, {
                                usageCount: admin.firestore.FieldValue.increment(1),
                                lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
                                platforms: admin.firestore.FieldValue.arrayUnion(completedPlatform || 'unknown'),
                                deviceIds: admin.firestore.FieldValue.arrayUnion(deviceId),
                                lastDeviceId: deviceId,
                                ...(data.isBatch === undefined || data.isBatch === null ? { isBatch: true } : {}),
                                ...(actorEmail ? { lastUserEmail: actorEmail } : {}),
                            });
                        } else {
                            t.set(globalCacheRef, {
                                sourceContent: sourceContent,
                                translatedContent: fullTransSrt,
                                originalName: originalNameForGlobalCache,
                                targetLanguage: targetLanguage,
                                sourceHash: sourceHash,
                                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                                lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
                                usageCount: 1,
                                isBatch: true,
                                completedPlatform: completedPlatform || 'unknown',
                                platforms: [completedPlatform || 'unknown'],
                                deviceIds: [deviceId],
                                lastDeviceId: deviceId,
                                creatorDeviceId: deviceId,
                                ...(actorEmail ? { creatorEmail: actorEmail, lastUserEmail: actorEmail } : {}),
                            });
                        }
                    });
                }

                // 2. User History
                if (canWriteUserHistory && request.auth.uid && fileNameForHistory) {
                    const historyDocRef = db.collection('users').doc(request.auth.uid).collection('translation_history').doc(cacheKey);
                    const historySnap = await historyDocRef.get();
                    
                    const historyData: any = {
                        globalTranslationRef: cacheKey,
                        fileName: fileNameForHistory,
                        targetLanguage: targetLanguage,
                        sourceHash: sourceHash,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        isPartial: false,
                        isActive: false,
                        completedPlatform: completedPlatform || 'unknown',
                        completedAt: admin.firestore.FieldValue.serverTimestamp(),
                    };
                    
                    if (!historySnap.exists) {
                        historyData.createdAt = admin.firestore.FieldValue.serverTimestamp();
                    }
                    if (totalLines !== null && totalLines !== undefined) {
                        historyData.totalLines = totalLines;
                        // Approximate translated lines with total lines since batch succeeded on all chunks 
                        historyData.translatedLines = totalLines; 
                    }

                    // Remove resume states if any using merge true & FieldValue.delete()
                    historyData.partialTranslatedContent = admin.firestore.FieldValue.delete();
                    historyData.sourceContentForResume = admin.firestore.FieldValue.delete();
                    historyData.resumeState = admin.firestore.FieldValue.delete();
                    historyData.resumeUpdatedAt = admin.firestore.FieldValue.delete();

                    await historyDocRef.set(historyData, { merge: true });
                }
            }

            await jobDoc.update({
                status: 'SUCCEEDED',
                completedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            return {
                status: 'SUCCEEDED',
                results: results
            };

        } else if (job.state === 'JOB_STATE_FAILED') {
            console.error('Batch job failed on Google GenAI:', job);
            return { status: 'FAILED', results: null, error: 'Job failed' };
        } else {
            console.log(`Job ${jobName} is in state: ${job.state}`);
            return { status: job.state || 'IN_PROGRESS', results: null };
        }

    } catch (e: any) {
        console.error('Check batch failed:', e);
        throw new HttpsError('internal', 'Failed to check batch job', e.message);
    }
});
// force redeploy 2
