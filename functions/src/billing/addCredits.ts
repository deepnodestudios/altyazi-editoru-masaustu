import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from 'firebase-admin';
import { createHash } from 'crypto';
import { google } from 'googleapis';
import { GoogleAuth } from 'google-auth-library';

// UYGULAMA PAKET ADI (Android Manifest'teki applicationId)
const PACKAGE_NAME = 'com.deepnode.altyaziceviri';
const PLAY_BILLING_SERVICE_ACCOUNT =
  '203321032277-compute@developer.gserviceaccount.com';

interface AddCreditsData {
  amount: number;
  purchaseId?: string;
  productId: string;
  purchaseToken: string;
  trackAsPurchased?: boolean;
}

interface PurchaseAuditBase {
  userId: string;
  email: string;
  amount: number;
  productId: string;
  purchaseId: string | null;
  purchaseRecordId: string;
  purchaseToken: string;
  platform: 'android';
}

interface PlayVerificationResult {
  isValid: boolean;
  purchaseState: number | null;
  consumptionState: number | null;
  acknowledgementState: number | null;
  orderId: string | null;
  purchaseType: number | null;
  purchaseStateLabel: string | null;
  consumptionStateLabel: string | null;
  acknowledgementStateLabel: string | null;
  matchedProductId: string | null;
  verificationApi: 'products' | 'productsv2';
}

function normalizeOptionalString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length == 0 ? null : trimmed;
}

function buildPurchaseRecordId(purchaseId: string | null, purchaseToken: string): string {
  if (purchaseId != null) {
    return purchaseId;
  }

  const tokenHash = createHash('sha256').update(purchaseToken).digest('hex');
  return `token_${tokenHash}`;
}

function mapLegacyPurchaseStateLabel(value: number | null): string | null {
  switch (value) {
  case 0:
    return 'PURCHASED';
  case 1:
    return 'CANCELLED';
  case 2:
    return 'PENDING';
  default:
    return null;
  }
}

function mapV2PurchaseState(value: string | null): number | null {
  const normalized = normalizeOptionalString(value)?.toUpperCase() ?? null;
  switch (normalized) {
  case 'PURCHASED':
    return 0;
  case 'CANCELLED':
    return 1;
  case 'PENDING':
    return 2;
  default:
    return null;
  }
}

function mapV2ConsumptionState(value: string | null): number | null {
  const normalized = normalizeOptionalString(value)?.toUpperCase() ?? null;
  switch (normalized) {
  case 'CONSUMPTION_STATE_YET_TO_BE_CONSUMED':
    return 0;
  case 'CONSUMPTION_STATE_CONSUMED':
    return 1;
  default:
    return null;
  }
}

function mapV2AcknowledgementState(value: string | null): number | null {
  const normalized = normalizeOptionalString(value)?.toUpperCase() ?? null;
  switch (normalized) {
  case 'ACKNOWLEDGEMENT_STATE_PENDING':
    return 0;
  case 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED':
    return 1;
  default:
    return null;
  }
}

function extractFirstIdentityEmail(value: unknown): string | null {
  if (Array.isArray(value)) {
    for (const entry of value) {
      const normalized = normalizeOptionalString(entry);
      if (normalized != null) {
        return normalized;
      }
    }
  }

  return normalizeOptionalString(value);
}

async function resolvePurchaseEmail(
  auth: { uid: string; token: Record<string, any> },
): Promise<string> {
  const tokenEmail = normalizeOptionalString(auth.token.email);
  if (tokenEmail != null) {
    return tokenEmail;
  }

  const firebaseToken = (auth.token as any)?.firebase ?? {};
  const identities = firebaseToken.identities as Record<string, unknown> | undefined;
  const googleIdentityEmail = extractFirstIdentityEmail(identities?.['google.com']);
  if (googleIdentityEmail != null) {
    return googleIdentityEmail;
  }

  try {
    const authUser = await admin.auth().getUser(auth.uid);
    const authEmail = normalizeOptionalString(authUser.email);
    if (authEmail != null) {
      return authEmail;
    }
  } catch (error) {
    console.warn(`⚠️ Failed to load Firebase Auth user email for ${auth.uid}:`, error);
  }

  try {
    const userDoc = await admin.firestore().collection('users').doc(auth.uid).get();
    const firestoreEmail = normalizeOptionalString(userDoc.data()?.email);
    if (firestoreEmail != null) {
      return firestoreEmail;
    }
  } catch (error) {
    console.warn(`⚠️ Failed to load Firestore user email for ${auth.uid}:`, error);
  }

  throw new HttpsError(
    'failed-precondition',
    'Satın alma için kullanıcı e-posta adresi çözülemedi. Google hesabıyla yeniden giriş yapın.'
  );
}

async function mergePurchaseRecord(
  purchaseRef: FirebaseFirestore.DocumentReference,
  base: PurchaseAuditBase,
  data: Record<string, unknown>,
): Promise<void> {
  await purchaseRef.set({
    ...base,
    ...data,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

function buildFailureStatus(error: HttpsError): Record<string, unknown> {
  switch (error.code) {
  case 'already-exists':
    return {
      status: 'already_processed',
      processed: true,
      verified: true,
      failureCode: admin.firestore.FieldValue.delete(),
      failureMessage: admin.firestore.FieldValue.delete(),
      duplicateDetectedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  case 'invalid-argument':
    return {
      status: 'invalid_purchase',
      processed: false,
      verified: false,
      failureCode: error.code,
      failureMessage: error.message ?? 'Satın alma doğrulanamadı veya iptal edilmiş',
    };
  default:
    return {
      status: 'verification_error',
      processed: false,
      verified: false,
      failureCode: error.code,
      failureMessage: error.message ?? 'Kredi eklenirken hata oluştu',
    };
  }
}

/**
 * Kredi ekleme fonksiyonu (v2)
 * Satın alma doğrulaması yapar ve kullanıcıya kredi ekler
 */
export const addCredits = onCall<AddCreditsData>({
  region: 'us-central1',
  serviceAccount: PLAY_BILLING_SERVICE_ACCOUNT,
}, async (request) => {
  const { data, auth } = request;

  // 1. Kimlik doğrulama
  if (!auth) {
    throw new HttpsError(
      'unauthenticated',
      'Kullanıcı girişi gerekli'
    );
  }

  // Enforce: purchasing/paid credits require Google sign-in.
  // (Anonymous usage is allowed for starter/device credits.)
  const firebaseToken = (auth.token as any)?.firebase ?? {};
  const signInProvider = firebaseToken.sign_in_provider as string | undefined;
  const identities = firebaseToken.identities as Record<string, unknown> | undefined;
  const hasGoogleIdentity =
    signInProvider === 'google.com' ||
    (identities != null && Object.prototype.hasOwnProperty.call(identities, 'google.com'));
  if (!hasGoogleIdentity) {
    throw new HttpsError(
      'failed-precondition',
      'Kredi satın almak için Google ile giriş yapmalısınız'
    );
  }

  const userId = auth.uid;
  const amount = Number(data.amount);
  const purchaseId = normalizeOptionalString(data.purchaseId);
  const productId = normalizeOptionalString(data.productId);
  const purchaseToken = normalizeOptionalString(data.purchaseToken);
  const resolvedEmail = await resolvePurchaseEmail({
    uid: auth.uid,
    token: auth.token as Record<string, any>,
  });

  // 2. Input validasyonu
  if (!amount || amount <= 0) {
    throw new HttpsError(
      'invalid-argument',
      'Geçersiz kredi miktarı'
    );
  }

  if (!productId || !purchaseToken) {
    throw new HttpsError(
      'invalid-argument',
      'Eksik satın alma bilgileri'
    );
  }

  const purchaseRecordId = buildPurchaseRecordId(purchaseId, purchaseToken);
  const purchaseRef = admin.firestore()
    .collection('purchases')
    .doc(purchaseRecordId);
  const purchaseAuditBase: PurchaseAuditBase = {
    userId,
    email: resolvedEmail,
    amount,
    productId,
    purchaseId,
    purchaseRecordId,
    purchaseToken,
    platform: 'android',
  };

  try {
    await mergePurchaseRecord(purchaseRef, purchaseAuditBase, {
      status: 'received',
      processed: false,
      verified: false,
      attemptCount: admin.firestore.FieldValue.increment(1),
      firstSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (purchaseId == null) {
      console.warn(
        `⚠️ Missing purchaseId for ${productId}; using fallback recordId=${purchaseRecordId}`
      );
    }

    // 4. Satın alma doğrulaması (Google Play Developer API)
    const verification = await verifyPurchaseWithStore(productId, purchaseToken);

    await mergePurchaseRecord(purchaseRef, purchaseAuditBase, {
      playPurchaseState: verification.purchaseState,
      playConsumptionState: verification.consumptionState,
      playAcknowledgementState: verification.acknowledgementState,
      playPurchaseStateLabel: verification.purchaseStateLabel,
      playConsumptionStateLabel: verification.consumptionStateLabel,
      playAcknowledgementStateLabel: verification.acknowledgementStateLabel,
      playMatchedProductId: verification.matchedProductId,
      playVerificationApi: verification.verificationApi,
      playOrderId: verification.orderId,
      playPurchaseType: verification.purchaseType,
    });

    if (!verification.isValid) {
      await mergePurchaseRecord(purchaseRef, purchaseAuditBase, {
        status: 'invalid_purchase',
        processed: false,
        verified: false,
        failureCode: 'invalid-argument',
        failureMessage: `Satın alma doğrulanamadı veya iptal edilmiş (state=${verification.purchaseState ?? 'unknown'})`,
      });
      console.error(`❌ Invalid purchase: ${purchaseRecordId}`);
      throw new HttpsError(
        'invalid-argument',
        'Satın alma doğrulanamadı veya iptal edilmiş'
      );
    }

    await mergePurchaseRecord(purchaseRef, purchaseAuditBase, {
      status: 'verified',
      verified: true,
      verificationPassedAt: admin.firestore.FieldValue.serverTimestamp(),
      failureCode: admin.firestore.FieldValue.delete(),
      failureMessage: admin.firestore.FieldValue.delete(),
    });

    // 5. Transaction ile güvenli kredi ekleme
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const purchaseDoc = await transaction.get(purchaseRef);
      if (purchaseDoc.exists && purchaseDoc.data()?.processed === true) {
        console.warn(`⚠️ Duplicate purchase attempt: ${purchaseRecordId}`);
        throw new HttpsError(
          'already-exists',
          'Bu satın alma daha önce işlendi'
        );
      }

      const userRef = admin.firestore().collection('users').doc(userId);
      const userDoc = await transaction.get(userRef);

      const userData = userDoc.exists ? (userDoc.data() ?? {}) : {};
      const legacyCredits = Number(userData.credits ?? 0);
      const legacyBonusCredits = Number(userData.bonusCredits ?? 0);

      const existingPurchasedRaw = userData.purchasedCredits;
      const inferredPurchased = Math.max(legacyCredits - legacyBonusCredits, 0);
      const purchasedCandidate = Number.isFinite(Number(existingPurchasedRaw))
        ? Number(existingPurchasedRaw)
        : inferredPurchased;

      // Back-compat / admin edits: if `credits` is higher than purchasedCredits,
      // treat it as authoritative account credits and absorb it.
      const currentPurchasedCredits = Math.max(purchasedCandidate, legacyCredits);
      const subscriptionBucketRaw = Number(userData.subscriptionPurchasedCredits ?? Number.NaN);
      const normalizedSubscriptionBucket = Number.isFinite(subscriptionBucketRaw) && subscriptionBucketRaw >= 0
        ? subscriptionBucketRaw
        : 0;
      const extraBucketRaw = Number(userData.extraPurchasedCredits ?? Number.NaN);
      const normalizedExtraBucket = Number.isFinite(extraBucketRaw) && extraBucketRaw >= 0
        ? extraBucketRaw
        : Math.max(0, currentPurchasedCredits - normalizedSubscriptionBucket);

      const newExtraPurchasedCredits = normalizedExtraBucket + amount;
      const newPurchasedCredits = newExtraPurchasedCredits + normalizedSubscriptionBucket;

      // Purchase kaydı oluştur
      transaction.set(purchaseRef, {
        ...purchaseAuditBase,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        processed: true,
        verified: true,
        status: 'processed',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        failureCode: admin.firestore.FieldValue.delete(),
        failureMessage: admin.firestore.FieldValue.delete(),
      }, { merge: true });

      // Purchase history'ye ekle
      const historyRef = userRef.collection('purchase_history').doc(purchaseRecordId);
      transaction.set(historyRef, {
        amount,
        purchaseId,
        purchaseRecordId,
        productId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Unified credit history (preferred by UI)
      const creditTxRef = userRef.collection('credit_transactions').doc(purchaseRecordId);
      transaction.set(creditTxRef, {
        type: 'add',
        amount,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        source: 'purchase',
        purchaseId: purchaseId ?? purchaseRecordId,
        purchaseRecordId,
        productId,
        platform: 'android',
      }, { merge: true });

      // Kullanıcı kredilerini güncelle
      // `credits` is kept as an alias of `purchasedCredits` for backwards compatibility.
      transaction.set(userRef, {
        email: resolvedEmail,
        credits: newPurchasedCredits,
        purchasedCredits: newPurchasedCredits,  // Satın alınan kredileri track et
        extraPurchasedCredits: newExtraPurchasedCredits,
        subscriptionPurchasedCredits: normalizedSubscriptionBucket,
        lastPurchase: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      return { success: true, newPurchasedCredits, newCredits: newPurchasedCredits };
    });

    console.log(
      `✅ Credits added: userId=${userId}, amount=${amount}, purchaseRecordId=${purchaseRecordId}, purchaseId=${purchaseId ?? 'null'}`
    );
    return result;

  } catch (error: any) {
    console.error('❌ Error adding credits:', error);
    if (error instanceof HttpsError) {
      await mergePurchaseRecord(
        purchaseRef,
        purchaseAuditBase,
        buildFailureStatus(error),
      );
      throw error;
    }

    await mergePurchaseRecord(purchaseRef, purchaseAuditBase, {
      status: 'processing_error',
      processed: false,
      verified: false,
      failureCode: 'internal',
      failureMessage: 'Kredi eklenirken hata oluştu',
    });
    throw new HttpsError('internal', 'Kredi eklenirken hata oluştu');
  }
});

async function verifyPurchaseWithStore(productId: string, purchaseToken: string): Promise<PlayVerificationResult> {
  try {
    const scopes = ['https://www.googleapis.com/auth/androidpublisher'];
    const auth = new GoogleAuth({ scopes });

    const client = await auth.getClient();
    
    // DEBUG: Hangi e-posta ile kimlik doğrulaması yapıldığını logla
    const credentials = await auth.getCredentials();
    console.log(`🔑 Authenticating as: ${credentials.client_email || 'Unknown (Using ADC)'}`);

    const androidPublisher = google.androidpublisher({
      version: 'v3',
      auth: client as any,
    });

    try {
      const response = await (client as any).request({
        url: `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(PACKAGE_NAME)}/purchases/productsv2/tokens/${encodeURIComponent(purchaseToken)}`,
        method: 'GET',
      });

      const purchaseStateLabel =
        normalizeOptionalString(response.data?.purchaseStateContext?.purchaseState);
      const lineItems = Array.isArray(response.data?.productLineItem)
        ? response.data.productLineItem
        : [];
      const matchedLineItem =
        lineItems.find((item: any) => normalizeOptionalString(item?.productId) === productId)
        ?? lineItems[0]
        ?? null;
      const matchedProductId = normalizeOptionalString(matchedLineItem?.productId);
      const consumptionStateLabel = normalizeOptionalString(
        matchedLineItem?.productOfferDetails?.consumptionState,
      );
      const acknowledgementStateLabel = normalizeOptionalString(
        response.data?.acknowledgementState,
      );
      const orderId = normalizeOptionalString(response.data?.orderId);

      console.log(
        `🔍 Verification V2 Result for ${productId}: State=${purchaseStateLabel ?? '-'}, LineProduct=${matchedProductId ?? '-'}, Consumption=${consumptionStateLabel ?? '-'}`,
      );

      return {
        isValid: purchaseStateLabel === 'PURCHASED' &&
          (matchedProductId == null || matchedProductId === productId),
        purchaseState: mapV2PurchaseState(purchaseStateLabel),
        consumptionState: mapV2ConsumptionState(consumptionStateLabel),
        acknowledgementState: mapV2AcknowledgementState(acknowledgementStateLabel),
        orderId,
        purchaseType: null,
        purchaseStateLabel,
        consumptionStateLabel,
        acknowledgementStateLabel,
        matchedProductId,
        verificationApi: 'productsv2',
      };
    } catch (v2Error: any) {
      const v2Status: number | undefined =
        v2Error?.code ?? v2Error?.response?.status ?? v2Error?.response?.statusCode;

      console.warn('Productsv2 verification failed, falling back to legacy endpoint', {
        status: v2Status,
        message: v2Error?.message,
        errors: v2Error?.errors,
      });

      if (v2Status === 401 || v2Status === 403) {
        throw new HttpsError(
          'internal',
          'Google Play satın alma doğrulaması için yetki yok. Play Console API erişimini ve servis hesabı izinlerini kontrol edin.',
        );
      }
    }

    // Google Play API'ye sorgu at
    const response = await androidPublisher.purchases.products.get({
      packageName: PACKAGE_NAME,
      productId: productId,
      token: purchaseToken,
    });

    // purchaseState: 0 (Purchased), 1 (Canceled), 2 (Pending)
    const purchaseState = response.data.purchaseState;
    const consumptionState = response.data.consumptionState; // 0 (Yet to be consumed), 1 (Consumed)
    const acknowledgementState = response.data.acknowledgementState;
    const orderId = normalizeOptionalString(response.data.orderId);
    const purchaseType = typeof response.data.purchaseType === 'number'
      ? response.data.purchaseType
      : null;

    console.log(`🔍 Verification Result for ${productId}: State=${purchaseState}, Consumption=${consumptionState}`);

    if (purchaseState === 0) {
      return {
        isValid: true,
        purchaseState: typeof purchaseState === 'number' ? purchaseState : null,
        consumptionState: typeof consumptionState === 'number' ? consumptionState : null,
        acknowledgementState: typeof acknowledgementState === 'number' ? acknowledgementState : null,
        orderId,
        purchaseType,
        purchaseStateLabel: mapLegacyPurchaseStateLabel(
          typeof purchaseState === 'number' ? purchaseState : null,
        ),
        consumptionStateLabel: null,
        acknowledgementStateLabel: null,
        matchedProductId: productId,
        verificationApi: 'products',
      };
    } else {
      console.warn(`Purchase state is not valid: ${purchaseState}`);
      return {
        isValid: false,
        purchaseState: typeof purchaseState === 'number' ? purchaseState : null,
        consumptionState: typeof consumptionState === 'number' ? consumptionState : null,
        acknowledgementState: typeof acknowledgementState === 'number' ? acknowledgementState : null,
        orderId,
        purchaseType,
        purchaseStateLabel: mapLegacyPurchaseStateLabel(
          typeof purchaseState === 'number' ? purchaseState : null,
        ),
        consumptionStateLabel: null,
        acknowledgementStateLabel: null,
        matchedProductId: productId,
        verificationApi: 'products',
      };
    }
  } catch (error: any) {
    // Distinguish "invalid purchase" from "verification infrastructure" errors.
    const status: number | undefined =
      error?.code ?? error?.response?.status ?? error?.response?.statusCode;

    console.error('API Verification Failed:', {
      status,
      message: error?.message,
      errors: error?.errors,
    });

    // Invalid token / wrong product / not found -> treat as invalid purchase.
    if (status === 400 || status === 404) {
      return {
        isValid: false,
        purchaseState: null,
        consumptionState: null,
        acknowledgementState: null,
        orderId: null,
        purchaseType: null,
        purchaseStateLabel: null,
        consumptionStateLabel: null,
        acknowledgementStateLabel: null,
        matchedProductId: null,
        verificationApi: 'products',
      };
    }

    // Permission / auth problems should surface as internal, not "canceled".
    if (status === 401 || status === 403) {
      throw new HttpsError(
        'internal',
        'Google Play satın alma doğrulaması için yetki yok. Play Console API erişimini ve servis hesabı izinlerini kontrol edin.'
      );
    }

    throw new HttpsError(
      'internal',
      'Google Play satın alma doğrulaması şu an yapılamıyor. Lütfen daha sonra tekrar deneyin.'
    );
  }
}
