import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from 'firebase-admin';
import { google } from 'googleapis';
import { GoogleAuth } from 'google-auth-library';

// UYGULAMA PAKET ADI (Android Manifest'teki applicationId)
const PACKAGE_NAME = 'com.deepnode.altyaziceviri';

interface AddCreditsData {
  amount: number;
  purchaseId: string;
  productId: string;
  purchaseToken: string;
  trackAsPurchased?: boolean;
}

/**
 * Kredi ekleme fonksiyonu (v2)
 * Satın alma doğrulaması yapar ve kullanıcıya kredi ekler
 */
export const addCredits = onCall<AddCreditsData>(async (request) => {
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
  const { amount, purchaseId, productId, purchaseToken } = data;

  // 2. Input validasyonu
  if (!amount || amount <= 0) {
    throw new HttpsError(
      'invalid-argument',
      'Geçersiz kredi miktarı'
    );
  }

  if (!purchaseId || !productId || !purchaseToken) {
    throw new HttpsError(
      'invalid-argument',
      'Eksik satın alma bilgileri'
    );
  }

  try {
    // 3. Duplicate purchase kontrolü (Önce bunu yapıp gereksiz API çağrısından kaçınalım)
    const purchaseRef = admin.firestore()
      .collection('purchases')
      .doc(purchaseId);
    
    const purchaseDoc = await purchaseRef.get();
    
    if (purchaseDoc.exists && purchaseDoc.data()?.processed === true) {
      console.warn(`⚠️ Duplicate purchase attempt: ${purchaseId}`);
      throw new HttpsError(
        'already-exists',
        'Bu satın alma daha önce işlendi'
      );
    }

    // 4. Satın alma doğrulaması (Google Play Developer API)
    const isValidPurchase = await verifyPurchaseWithStore(productId, purchaseToken);

    if (!isValidPurchase) {
      console.error(`❌ Invalid purchase: ${purchaseId}`);
      throw new HttpsError(
        'invalid-argument',
        'Satın alma doğrulanamadı veya iptal edilmiş'
      );
    }

    // 5. Transaction ile güvenli kredi ekleme
    const result = await admin.firestore().runTransaction(async (transaction) => {
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

      const newPurchasedCredits = currentPurchasedCredits + amount;

      // Purchase kaydı oluştur
      transaction.set(purchaseRef, {
        userId,
        amount,
        productId,
        purchaseToken,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        processed: true,
        platform: 'android',
        verified: true,
      });

      // Purchase history'ye ekle
      const historyRef = userRef.collection('purchase_history').doc(purchaseId);
      transaction.set(historyRef, {
        amount,
        productId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Unified credit history (preferred by UI)
      // Use purchaseId as deterministic docId.
      const creditTxRef = userRef.collection('credit_transactions').doc(purchaseId);
      transaction.set(creditTxRef, {
        type: 'add',
        amount,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        source: 'purchase',
        purchaseId,
        productId,
        platform: 'android',
      }, { merge: true });

      // Kullanıcı kredilerini güncelle
      // `credits` is kept as an alias of `purchasedCredits` for backwards compatibility.
      transaction.set(userRef, {
        credits: newPurchasedCredits,
        purchasedCredits: newPurchasedCredits,  // Satın alınan kredileri track et
        lastPurchase: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      return { success: true, newPurchasedCredits, newCredits: newPurchasedCredits };
    });

    console.log(`✅ Credits added: userId=${userId}, amount=${amount}, purchaseId=${purchaseId}`);
    return result;

  } catch (error: any) {
    console.error('❌ Error adding credits:', error);
    if (error instanceof HttpsError) { throw error; }
    throw new HttpsError('internal', 'Kredi eklenirken hata oluştu');
  }
});

async function verifyPurchaseWithStore(productId: string, purchaseToken: string): Promise<boolean> {
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

    // Google Play API'ye sorgu at
    const response = await androidPublisher.purchases.products.get({
      packageName: PACKAGE_NAME,
      productId: productId,
      token: purchaseToken,
    });

    // purchaseState: 0 (Purchased), 1 (Canceled), 2 (Pending)
    const purchaseState = response.data.purchaseState;
    const consumptionState = response.data.consumptionState; // 0 (Yet to be consumed), 1 (Consumed)

    console.log(`🔍 Verification Result for ${productId}: State=${purchaseState}, Consumption=${consumptionState}`);

    if (purchaseState === 0) {
      return true;
    } else {
      console.warn(`Purchase state is not valid: ${purchaseState}`);
      return false;
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
      return false;
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
