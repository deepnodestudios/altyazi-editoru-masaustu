import { defineSecret } from 'firebase-functions/params';
import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { GoogleGenerativeAI, HarmCategory, HarmBlockThreshold } from '@google/generative-ai';
import * as admin from 'firebase-admin';

// Initialize Gemini
// Important: Ensure 'gemini.api_key' is set in Firebase functions config
// Command: firebase functions:config:set gemini.api_key="YOUR_KEY"
// Or use process.env if you use environment variables (e.g. .env file)

// Helper to get allowed model
function getModelName(requestedModel?: string): string {
    // CURRENT POLICY: Enforce Flash model regardless of client request.
    // This prevents clients from spoofing 'gemini-1.5-pro' to use expensive models.
    // If you want to support Pro later, add logic here (e.g. check user plan).
    // NOTE: Keep this to a generally-available alias.
    return "gemini-flash-latest";
}

const geminiApiKey = defineSecret('GEMINI_API_KEY');

type TranslateRequestData = {
    text: string;
    systemPrompt?: string;
    model?: string;
    chargeKey?: string;
    approveCharge?: boolean;
};

export const translateText = onCall({
    secrets: [geminiApiKey],
    invoker: 'public',
    enforceAppCheck: false,
}, async (request: CallableRequest<TranslateRequestData>) => {
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
        chargeKey,
        approveCharge,
        // We ignore 'model' from client or use it for logging only
        // model: clientRequestedModel 
    } = request.data;

    const trimmedChargeKey = (chargeKey ?? '').trim();
    const shouldApproveCharge = approveCharge == true && trimmedChargeKey.length > 0;

    if (!text) {
        throw new HttpsError('invalid-argument', 'The function must be called with "text" argument.');
    }

    // 3. Get API Key (Secrets Manager)
    const apiKey = geminiApiKey.value();

    if (!apiKey) {
        throw new HttpsError('internal', 'Server-side API Key not configured. Please set GEMINI_API_KEY in Secrets Manager.');
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const modelName = getModelName();

    console.log('translateText model', { modelName });

    const model = genAI.getGenerativeModel({
        model: modelName,
        systemInstruction: systemPrompt ? { role: 'system', parts: [{ text: systemPrompt }]} : undefined,
        safetySettings: [
            { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_NONE },
            { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_NONE },
            { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_NONE },
            { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_NONE },
        ],
        generationConfig: {
            temperature: 0.7,
            topK: 40,
            topP: 0.95,
        }
    });

    try {
        const result = await model.generateContent(text);
        const response = await result.response;
        const outputText = response.text();

        if (shouldApproveCharge) {
            await admin
                .firestore()
                .collection('translation_sessions')
                .doc(trimmedChargeKey)
                .set(
                    {
                        approved: true,
                        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        uid: request.auth.uid,
                    },
                    { merge: true }
                );
        }
        
        return {
            text: outputText,
            inputTokens: response.usageMetadata?.promptTokenCount || 0,
            outputTokens: response.usageMetadata?.candidatesTokenCount || 0,
            modelUsed: modelName // Inform client what was actually used
        };

    } catch (error: any) {
        console.error(`Gemini API Error (model=${modelName}):`, error);
        throw new HttpsError('internal', 'Translation provider failed', error.message);
    }
});
