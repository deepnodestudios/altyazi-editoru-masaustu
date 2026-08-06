import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { meetsVersionRequirement } from '../referral/referralUtils';
import {
  SUBSCRIPTION_PRODUCTS,
  applySubscriptionRenewal,
  normalizeSubscriptionProductId,
  verifySubscriptionWithStore,
} from './subscriptionUtils';

interface HandleSubscriptionData {
  productId: string;
  purchaseToken: string;
  appVersion?: string;
}

/**
 * Handles subscription activation/renewal.
 * Verifies the subscription with Google Play and grants credits.
 * On same-token monthly renewal, leftover subscription credits are reset.
 * On plan change (new token), paid credits are preserved and new package credits are added.
 */
export const handleSubscription = onCall<HandleSubscriptionData>(
  { invoker: 'public', enforceAppCheck: false },
  async (request) => {
    const { auth, data } = request;

    if (!auth?.uid) {
      throw new HttpsError('unauthenticated', 'AUTH_REQUIRED');
    }

    const firebaseToken = (auth.token as any)?.firebase ?? {};
    const signInProvider = firebaseToken.sign_in_provider as string | undefined;
    if (signInProvider !== 'google.com') {
      throw new HttpsError('failed-precondition', 'GOOGLE_SIGN_IN_REQUIRED');
    }

    if (!meetsVersionRequirement(data.appVersion)) {
      throw new HttpsError('failed-precondition', 'VERSION_TOO_OLD');
    }

    const { productId, purchaseToken } = data;
    const canonicalProductId = normalizeSubscriptionProductId(productId);
    const product = SUBSCRIPTION_PRODUCTS[canonicalProductId];
    if (!product) {
      throw new HttpsError('invalid-argument', 'INVALID_SUBSCRIPTION_PRODUCT');
    }

    if (!purchaseToken) {
      throw new HttpsError('invalid-argument', 'PURCHASE_TOKEN_REQUIRED');
    }

    const db = admin.firestore();
    const verification = await verifySubscriptionWithStore(canonicalProductId, purchaseToken);
    if (!verification.isActive || verification.productId == null) {
      throw new HttpsError('invalid-argument', 'INVALID_SUBSCRIPTION_PURCHASE');
    }

    const trimmedEmail =
      typeof auth.token.email === 'string' ? auth.token.email.trim() : '';
    const email = trimmedEmail.length > 0 ? trimmedEmail.toLowerCase() : null;

    const result = await applySubscriptionRenewal({
      db,
      uid: auth.uid,
      email,
      productId: verification.productId,
      purchaseToken,
      orderId: verification.orderId,
      expiryTimeMillis: verification.expiryTimeMillis,
      status: verification.status,
      subscriptionState: verification.subscriptionState,
      autoRenewEnabled: verification.autoRenewEnabled,
      linkedPurchaseToken: verification.linkedPurchaseToken,
      cancellationReason: verification.cancellationReason,
    });

    console.log(`✅ Subscription synced: user=${auth.uid}, product=${canonicalProductId}, credits=${product.credits}`);
    return {
      success: true,
      alreadyProcessed: result.alreadyProcessed,
      credits: result.credits,
      tier: result.tier,
    };
  }
);
