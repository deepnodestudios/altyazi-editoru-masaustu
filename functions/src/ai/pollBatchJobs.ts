import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';
import { GoogleGenAI } from '@google/genai';
import { defineSecret } from 'firebase-functions/params';
import { normalizePlatform } from '../billing/creditUtils';

const geminiApiKey = defineSecret('GEMINI_API_KEY');

export const pollBatchJobs = onSchedule({
    schedule: 'every 2 minutes',
    secrets: [geminiApiKey],
    timeoutSeconds: 300,
}, async (event) => {
    try {
        const db = admin.firestore();
        const apiKey = geminiApiKey.value();
        const ai = new GoogleGenAI({ apiKey, httpOptions: { apiVersion: 'v1beta' } });

        console.log("Starting pollBatchJobs...");

        // Look for IN_PROGRESS batch jobs
        const jobsSnapshot = await db.collectionGroup('batch_jobs')
            .where('status', '==', 'IN_PROGRESS')
            .get();

        console.log(`Found ${jobsSnapshot.size} IN_PROGRESS jobs.`);

        for (const doc of jobsSnapshot.docs) {
            const jobData = doc.data();
            const jobName = jobData.jobName;
            if (!jobName) continue;

            console.log(`Polling job: ${jobName}`);
            
            try {
                // Wait briefly to avoid hitting rate limits too quickly
                await new Promise(resolve => setTimeout(resolve, 500));
                
                const job = await ai.batches.get({
                    name: jobName,
                });
                
                if (job.state === 'JOB_STATE_SUCCEEDED') {
                    console.log(`Job ${jobName} succeeded on Google's end. Processing...`);

                    const outputUri = job.dest?.fileName;
                    if (!outputUri) {
                        console.error(`Job ${jobName} has no outputUri, although it succeeded.`);
                        continue;
                    }

                    // Attempt to download the output from Google GenAI
                    // Note: Google's Files API has a bug where batch output files > 40 chars 
                    // return 400 Bad Request via standard fetch. Using :download bypasses this constraint.
                    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/${outputUri}:download?alt=media&key=${apiKey}`);
                    if (!response.ok) {
                        console.error(`Failed to fetch output for job ${jobName}: ${response.statusText}`);
                        continue;
                    }

                    const jsonLines = await response.text();
                    
                    const lines = jsonLines.split('\n').filter((l: string) => l.trim().length > 0);
                    const results: string[] = [];

                    for (const line of lines) {
                        try {
                            const parsed = JSON.parse(line);
                            let text = parsed.response?.candidates?.[0]?.content?.parts?.[0]?.text;
                            
                            if (!text) {
                                // Eğer güvenlik politikası nedeniyle metin boş geldiyse orijinal metne dön
                                const reqText = parsed.request?.contents?.[0]?.parts?.[0]?.text || '';
                                text = reqText.replace(/\[CHUNK_ID:[^\]]+\]\n/, '');
                            }

                            // Boş dahi olsa dizinin sırasını/blok zamanlamalarını bozmamak için ekliyoruz
                            results.push(text || '');
                        } catch (e) {
                            console.error(`Failed to parse line for job ${jobName}`);
                        }
                    }

                    const fullTransSrt = results.join('\n\n');
                    
                    // Firestore writes using exactly same logic
                    if (jobData.sourceHash && jobData.targetLanguage) {
                        const cacheKey = `${jobData.sourceHash}_${jobData.targetLanguage.toLowerCase()}`;
                        const normalizedDeviceId = (jobData.deviceId ?? doc.ref.parent.parent?.id ?? '').trim();
                        const resolvedPlatform = normalizePlatform(jobData.completedPlatform);
                        const actorEmail = typeof jobData.email === 'string' && jobData.email.trim().length > 0
                            ? jobData.email.trim().toLowerCase()
                            : null;
                        
                        if (jobData.sourceContent && jobData.originalNameForGlobalCache) {
                            const globalCacheRef = db.collection('global_translations').doc(cacheKey);
                            await db.runTransaction(async (t) => {
                                const snap = await t.get(globalCacheRef);
                                if (snap.exists) {
                                    const data = snap.data() || {};
                                    t.update(globalCacheRef, {
                                        usageCount: admin.firestore.FieldValue.increment(1),
                                        lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
                                        platforms: admin.firestore.FieldValue.arrayUnion(resolvedPlatform),
                                        ...(data.isBatch === undefined || data.isBatch === null ? { isBatch: true } : {}),
                                        ...(normalizedDeviceId ? {
                                            deviceIds: admin.firestore.FieldValue.arrayUnion(normalizedDeviceId),
                                            lastDeviceId: normalizedDeviceId,
                                        } : {}),
                                        ...(actorEmail ? { lastUserEmail: actorEmail } : {}),
                                    });
                                } else {
                                    t.set(globalCacheRef, {
                                        sourceContent: jobData.sourceContent,
                                        translatedContent: fullTransSrt,
                                        originalName: jobData.originalNameForGlobalCache,
                                        targetLanguage: jobData.targetLanguage,
                                        sourceHash: jobData.sourceHash,
                                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                                        lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
                                        usageCount: 1,
                                        isBatch: true,
                                        completedPlatform: resolvedPlatform,
                                        platforms: [resolvedPlatform],
                                        ...(normalizedDeviceId ? {
                                            deviceIds: [normalizedDeviceId],
                                            lastDeviceId: normalizedDeviceId,
                                            creatorDeviceId: normalizedDeviceId,
                                        } : {}),
                                        ...(actorEmail ? { creatorEmail: actorEmail, lastUserEmail: actorEmail } : {}),
                                    });
                                }
                            });
                        }

                        if (jobData.canWriteUserHistory && jobData.uid && jobData.fileNameForHistory) {
                            const historyDocRef = db.collection('users').doc(jobData.uid).collection('translation_history').doc(cacheKey);
                            const historySnap = await historyDocRef.get();

                            const historyData: any = {
                                globalTranslationRef: cacheKey,
                                fileName: jobData.fileNameForHistory,
                                targetLanguage: jobData.targetLanguage,
                                sourceHash: jobData.sourceHash,
                                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                                isPartial: false,
                                isActive: false,
                                completedPlatform: jobData.completedPlatform || 'unknown',
                                completedAt: admin.firestore.FieldValue.serverTimestamp(),
                            };

                            if (!historySnap.exists) {
                                historyData.createdAt = admin.firestore.FieldValue.serverTimestamp();
                            }
                            if (jobData.totalLines) {
                                historyData.totalLines = jobData.totalLines;
                                historyData.translatedLines = jobData.totalLines;
                            }

                            historyData.partialTranslatedContent = admin.firestore.FieldValue.delete();
                            historyData.sourceContentForResume = admin.firestore.FieldValue.delete();
                            historyData.resumeState = admin.firestore.FieldValue.delete();
                            historyData.resumeUpdatedAt = admin.firestore.FieldValue.delete();

                            await historyDocRef.set(historyData, { merge: true });
                        }
                    }

                    await doc.ref.update({
                        status: 'SUCCEEDED',
                        completedAt: admin.firestore.FieldValue.serverTimestamp()
                    });

                    // Send push notification!
                    if (jobData.fcmToken) {
                        try {
                            const isMulti = jobData.isMultiFileBatch === true;
                            await admin.messaging().send({
                                token: jobData.fcmToken,
                                notification: {
                                    title: isMulti ? 'Toplu Çeviri Tamamlandı! 🎉' : 'İşlem Başarılı! 🎉',
                                    body: isMulti
                                         ? `Toplu Dosya Çevirisi Tamamlandı ve Geçmişe Eklendi.`
                                         : `${jobData.fileNameForHistory || 'Dosyanızın'} çevirisi başarıyla tamamlandı ve geçmiş sekmesine kaydedildi.`
                                },
                                android: {
                                    priority: 'high',
                                    notification: {
                                        channelId: 'high_importance_channel',
                                        defaultSound: true,
                                        defaultVibrateTimings: true,
                                        notificationCount: 1
                                    }
                                }
                            });
                        } catch (pushErr: any) {
                            if (pushErr?.code === 'messaging/registration-token-not-registered' || pushErr?.message?.includes('Requested entity was not found')) {
                                console.log(`FCM token expired or device uninstalled (Requested entity was not found). Ignored.`);
                            } else {
                                console.error('Failed to send success FCM:', pushErr);
                            }
                        }
                    }
                    
                } else if (job.state === 'JOB_STATE_FAILED') {
                    console.log(`Job ${jobName} failed on Google's end.`);
                    await doc.ref.update({
                        status: 'FAILED',
                        completedAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                    
                    if (jobData.fcmToken) {
                        try {
                            const isMulti = jobData.isMultiFileBatch === true;
                            await admin.messaging().send({
                                token: jobData.fcmToken,
                                notification: {
                                    title: isMulti ? 'Toplu Çeviri Başarısız' : 'Çeviri Başarısız',
                                    body: isMulti
                                        ? `Toplu çeviri kapsamındaki dosyanızın çevirisi başarısız oldu.`
                                        : `${jobData.fileNameForHistory || 'Dosyanızın'} çevirisi başarısız oldu.`
                                },
                                android: {
                                    priority: 'high',
                                    notification: {
                                        channelId: 'high_importance_channel',
                                        defaultSound: true,
                                        defaultVibrateTimings: true,
                                    }
                                }
                            });
                        } catch (pushErr) {}
                    }
                } else {
                    console.log(`Job ${jobName} state is ${job.state}`);
                }
            } catch (err: any) {
                console.error(`Check batch failed for ${jobName}`, err);
            }
        }
    } catch (e: any) {
        console.error("Top-level pollBatchJobs error:", e.message ?? e);
    }
});

// force redeploy 2
