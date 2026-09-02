import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from 'firebase-admin';
import { consumeCreditInternal, getAuthEmail } from './creditUtils';

interface ConsumeCreditsData {
  amount: number;
  deviceId: string;
  reason?: string;
  chargeKey?: string;
  fileName?: string;
  targetLanguage?: string;
  platform?: string;
  appVersion?: string;
  preferFreeCreditsFirst?: boolean;
  charCount?: number;
  estimatedTokens?: number;
  quoteProtocolVersion?: number;
  quoteId?: string;
  contentHash?: string;
  sourceContent?: string;
}

/**
 * Kredi düşme fonksiyonu (v2)
 */
export const consumeCredit = onCall<ConsumeCreditsData>({ invoker: 'public', enforceAppCheck: false }, async (request) => {
  const { data, auth } = request;
  const { amount, reason, deviceId, chargeKey, fileName, targetLanguage, platform, appVersion, preferFreeCreditsFirst, charCount, estimatedTokens, quoteProtocolVersion, quoteId, contentHash, sourceContent } = data;

  const trimmedDeviceId = (deviceId ?? '').trim();

  try {
    const result = await consumeCreditInternal({
      db: admin.firestore(),
      amount,
      deviceId: trimmedDeviceId,
      uid: auth?.uid ?? null,
      email: getAuthEmail(auth),
      reason,
      chargeKey,
      fileName,
      targetLanguage,
      platform,
      appVersion,
      preferFreeCreditsFirst,
      charCount,
      estimatedTokens,
      quoteProtocolVersion,
      quoteId,
      contentHash,
      sourceContent,
    });

    console.log(`✅ Credits consumed: deviceId=${trimmedDeviceId}, amount=${amount}`);
    return result;

  } catch (error: any) {
    console.error('❌ Error consuming credits:', error);
    if (error instanceof HttpsError) { throw error; }
    throw new HttpsError('internal', 'Kredi düşülürken hata oluştu');
  }
});

// force redeploy
