import { createHash } from 'crypto';

import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';
import { GoogleAuth } from 'google-auth-library';

const PACKAGE_NAME = 'com.deepnode.altyaziceviri';

const SUBSCRIPTION_PRODUCT_ALIASES: Record<string, string> = {
  hobi_paket_monthly: 'sub_20_credits_monthly',
  sinema_paketi_monthly: 'sub_30_credits_monthly',
};

export function normalizeSubscriptionProductId(productId: string): string {
  const trimmed = String(productId ?? '').trim();
  return SUBSCRIPTION_PRODUCT_ALIASES[trimmed] ?? trimmed;
}

export const SUBSCRIPTION_PRODUCTS: Record<string, { credits: number; tier: string }> = {
  sub_20_credits_monthly: { credits: 20, tier: 'hobi' },
  sub_30_credits_monthly: { credits: 30, tier: 'sinema' },
};

export type SubscriptionStatus =
  | 'active'
  | 'in_grace_period'
  | 'on_hold'
  | 'paused'
  | 'canceled'
  | 'expired'
  | 'pending'
  | 'pending_purchase_canceled'
  | 'inactive';

export type SubscriptionCancellationReason =
  | 'user'
  | 'system'
  | 'developer'
  | 'replacement'
  | null;

export type VerifiedSubscription = {
  isActive: boolean;
  status: SubscriptionStatus;
  subscriptionState: string | null;
  productId: string | null;
  orderId: string | null;
  expiryTimeMillis: number | null;
  autoRenewEnabled: boolean | null;
  linkedPurchaseToken: string | null;
  cancellationReason: SubscriptionCancellationReason;
};

function mapSubscriptionStatus(subscriptionState: string): SubscriptionStatus {
  switch (subscriptionState) {
    case 'SUBSCRIPTION_STATE_ACTIVE':
      return 'active';
    case 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD':
      return 'in_grace_period';
    case 'SUBSCRIPTION_STATE_ON_HOLD':
      return 'on_hold';
    case 'SUBSCRIPTION_STATE_PAUSED':
      return 'paused';
    case 'SUBSCRIPTION_STATE_CANCELED':
      return 'canceled';
    case 'SUBSCRIPTION_STATE_EXPIRED':
      return 'expired';
    case 'SUBSCRIPTION_STATE_PENDING':
      return 'pending';
    case 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED':
      return 'pending_purchase_canceled';
    default:
      return 'inactive';
  }
}

function resolveCancellationReason(canceledStateContext: any): SubscriptionCancellationReason {
  if (!canceledStateContext || typeof canceledStateContext !== 'object') {
    return null;
  }
  if (canceledStateContext.userInitiatedCancellation) return 'user';
  if (canceledStateContext.systemInitiatedCancellation) return 'system';
  if (canceledStateContext.developerInitiatedCancellation) return 'developer';
  if (canceledStateContext.replacementCancellation) return 'replacement';
  return null;
}

function inferAccessActive(status: SubscriptionStatus): boolean {
  return status === 'active' ||
    status === 'in_grace_period' ||
    status === 'on_hold' ||
    status === 'canceled';
}

export function buildSubscriptionDateFields(args: {
  status: SubscriptionStatus;
  expiryTimeMillis: number | null;
  autoRenewEnabled: boolean | null;
}): {
  renewsAtMillis: number | null;
  renewsAt: admin.firestore.Timestamp | null;
  accessEndsAtMillis: number | null;
  accessEndsAt: admin.firestore.Timestamp | null;
} {
  const {status, expiryTimeMillis, autoRenewEnabled} = args;
  const normalizedExpiry = Number.isFinite(expiryTimeMillis ?? Number.NaN) && expiryTimeMillis != null
    ? expiryTimeMillis
    : null;

  if (normalizedExpiry == null) {
    return {
      renewsAtMillis: null,
      renewsAt: null,
      accessEndsAtMillis: null,
      accessEndsAt: null,
    };
  }

  const renewsAtMillis = (
    (status === 'active' || status === 'in_grace_period' || status === 'on_hold') &&
    autoRenewEnabled !== false
  )
    ? normalizedExpiry
    : null;
  const accessEndsAtMillis = (
    status === 'canceled' ||
    status === 'expired' ||
    status === 'pending_purchase_canceled' ||
    autoRenewEnabled === false
  )
    ? normalizedExpiry
    : null;

  return {
    renewsAtMillis,
    renewsAt: renewsAtMillis != null
      ? admin.firestore.Timestamp.fromMillis(renewsAtMillis)
      : null,
    accessEndsAtMillis,
    accessEndsAt: accessEndsAtMillis != null
      ? admin.firestore.Timestamp.fromMillis(accessEndsAtMillis)
      : null,
  };
}

export function subscriptionDocIdForToken(purchaseToken: string): string {
  return createHash('sha256').update(purchaseToken).digest('hex');
}

export async function verifySubscriptionWithStore(
  productId: string,
  purchaseToken: string,
): Promise<VerifiedSubscription> {
  const requestedProductId = normalizeSubscriptionProductId(productId);
  const scopes = ['https://www.googleapis.com/auth/androidpublisher'];
  const auth = new GoogleAuth({ scopes });
  const client = await auth.getClient();

  try {
    const response = await (client as any).request({
      url: `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(PACKAGE_NAME)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
      method: 'GET',
    });

    const subscriptionState = String(response.data?.subscriptionState ?? '').toUpperCase();
    const lineItems = Array.isArray(response.data?.lineItems)
      ? response.data.lineItems
      : [];
    const matchedLineItem =
      lineItems.find(
        (item: any) => normalizeSubscriptionProductId(String(item?.productId ?? '')) === requestedProductId,
      ) ??
      lineItems[0] ??
      null;
    const rawProductId = normalizeSubscriptionProductId(
      String(matchedLineItem?.productId ?? requestedProductId).trim(),
    );
    const rawOrderId = String(
      response.data?.latestOrderId ?? matchedLineItem?.latestSuccessfulOrderId ?? '',
    ).trim();
    const linkedPurchaseToken = String(response.data?.linkedPurchaseToken ?? '').trim();
    const expiryRaw = String(matchedLineItem?.expiryTime ?? '').trim();
    const parsedExpiry = expiryRaw.length === 0 ? Number.NaN : Date.parse(expiryRaw);
    const status = mapSubscriptionStatus(subscriptionState);
    const autoRenewEnabledRaw = matchedLineItem?.autoRenewingPlan?.autoRenewEnabled;
    const autoRenewEnabled = typeof autoRenewEnabledRaw === 'boolean'
      ? autoRenewEnabledRaw
      : (status === 'canceled' || status === 'expired' || status === 'pending_purchase_canceled'
        ? false
        : null);
    const cancellationReason = resolveCancellationReason(response.data?.canceledStateContext);

    return {
      isActive:
        subscriptionState === 'SUBSCRIPTION_STATE_ACTIVE' ||
        subscriptionState === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' ||
        subscriptionState === 'SUBSCRIPTION_STATE_ON_HOLD' ||
        subscriptionState === 'SUBSCRIPTION_STATE_CANCELED',
      status,
      subscriptionState: subscriptionState.length === 0 ? null : subscriptionState,
      productId: rawProductId.length === 0 ? null : rawProductId,
      orderId: rawOrderId.length === 0 ? null : rawOrderId,
      expiryTimeMillis: Number.isFinite(parsedExpiry) ? parsedExpiry : null,
      autoRenewEnabled,
      linkedPurchaseToken: linkedPurchaseToken.length === 0 ? null : linkedPurchaseToken,
      cancellationReason,
    };
  } catch (error: any) {
    const status: number | undefined =
      error?.code ?? error?.response?.status ?? error?.response?.statusCode;

    if (status === 400 || status === 404) {
      return {
        isActive: false,
        status: 'inactive',
        subscriptionState: null,
        productId: null,
        orderId: null,
        expiryTimeMillis: null,
        autoRenewEnabled: null,
        linkedPurchaseToken: null,
        cancellationReason: null,
      };
    }

    if (status === 410) {
      return {
        isActive: false,
        status: 'expired',
        subscriptionState: null,
        productId: null,
        orderId: null,
        expiryTimeMillis: null,
        autoRenewEnabled: null,
        linkedPurchaseToken: null,
        cancellationReason: null,
      };
    }

    if (status === 401 || status === 403) {
      throw new HttpsError(
        'internal',
        'Google Play abonelik doğrulaması için yetki yok. Play Console izinlerini kontrol edin.',
      );
    }

    throw new HttpsError(
      'internal',
      'Google Play abonelik doğrulaması şu an yapılamıyor. Lütfen daha sonra tekrar deneyin.',
    );
  }
}

export async function applySubscriptionRenewal(args: {
  db: admin.firestore.Firestore;
  uid: string;
  email: string | null;
  productId: string;
  purchaseToken: string;
  orderId: string | null;
  expiryTimeMillis: number | null;
  status: SubscriptionStatus;
  subscriptionState: string | null;
  autoRenewEnabled: boolean | null;
  linkedPurchaseToken: string | null;
  cancellationReason: SubscriptionCancellationReason;
}): Promise<{ alreadyProcessed: boolean; credits: number; tier: string }> {
  const {
    db,
    uid,
    email,
    productId,
    purchaseToken,
    orderId,
    expiryTimeMillis,
    status,
    subscriptionState,
    autoRenewEnabled,
    linkedPurchaseToken,
    cancellationReason,
  } = args;
  const canonicalProductId = normalizeSubscriptionProductId(productId);
  const product = SUBSCRIPTION_PRODUCTS[canonicalProductId];
  const accessActive = inferAccessActive(status);
  const subscriptionDateFields = buildSubscriptionDateFields({
    status,
    expiryTimeMillis,
    autoRenewEnabled,
  });
  if (!product) {
    throw new HttpsError('invalid-argument', 'INVALID_SUBSCRIPTION_PRODUCT');
  }

  const subscriptionRef = db.collection('subscriptions').doc(subscriptionDocIdForToken(purchaseToken));
  const userRef = db.collection('users').doc(uid);

  let alreadyProcessed = false;

  await db.runTransaction(async (tx) => {
    const subscriptionDoc = await tx.get(subscriptionRef);
    const userDoc = await tx.get(userRef);
    const existingData = subscriptionDoc.exists ? (subscriptionDoc.data() ?? {}) : {};
    const userData = userDoc.exists ? (userDoc.data() ?? {}) : {};
    const existingExpiry = Number(existingData.expiryTimeMillis ?? 0);
    const nextExpiry = expiryTimeMillis ?? existingExpiry;
    const existingOrderId = String(existingData.orderId ?? '').trim();
    const nextOrderId = String(orderId ?? '').trim();
    const shouldSkipCreditGrant =
      subscriptionDoc.exists && (
        (existingExpiry > 0 && nextExpiry > 0 && existingExpiry >= nextExpiry) ||
        (existingExpiry <= 0 && nextExpiry <= 0 && existingOrderId.length > 0 && existingOrderId === nextOrderId)
      );

    if (shouldSkipCreditGrant) {
      alreadyProcessed = true;
    }

    if (!alreadyProcessed) {
      const existingPurchasedA = Number(userData.purchasedCredits ?? 0);
      const existingPurchasedB = Number(userData.credits ?? 0);
      const currentPurchasedCredits = Math.max(existingPurchasedA, existingPurchasedB, 0);
      const existingSubscriptionBucketRaw = Number(userData.subscriptionPurchasedCredits ?? Number.NaN);
      const existingExtraBucketRaw = Number(userData.extraPurchasedCredits ?? Number.NaN);
      const fallbackSubscriptionBucket = Math.max(0, Number(existingData.credits ?? 0));
      const normalizedSubscriptionBucket = Number.isFinite(existingSubscriptionBucketRaw) && existingSubscriptionBucketRaw >= 0
        ? existingSubscriptionBucketRaw
        : Math.min(fallbackSubscriptionBucket, currentPurchasedCredits);
      const normalizedExtraBucket = Number.isFinite(existingExtraBucketRaw) && existingExtraBucketRaw >= 0
        ? existingExtraBucketRaw
        : Math.max(0, currentPurchasedCredits - normalizedSubscriptionBucket);

      const isRenewalOfSameSubscription =
        subscriptionDoc.exists && existingExpiry > 0 && nextExpiry > existingExpiry;
      // Renewal rule: monthly subscription leftovers do not carry over.
      // Plan change/new token rule: preserve existing paid balance and add new package credits.
      const newSubscriptionBucket = isRenewalOfSameSubscription
        ? product.credits
        : (normalizedSubscriptionBucket + product.credits);
      const newExtraBucket = normalizedExtraBucket;
      const newPurchasedCredits = Math.max(0, newSubscriptionBucket + newExtraBucket);

      tx.set(userRef, {
        email,
        credits: newPurchasedCredits,
        purchasedCredits: newPurchasedCredits,
        subscriptionPurchasedCredits: newSubscriptionBucket,
        extraPurchasedCredits: newExtraBucket,
        subscriptionTier: product.tier,
        subscriptionProductId: productId,
        subscriptionActive: status !== 'expired' && status !== 'inactive',
        subscriptionRenewedAt: admin.firestore.FieldValue.serverTimestamp(),
        subscriptionExpiresAt: expiryTimeMillis != null
          ? admin.firestore.Timestamp.fromMillis(expiryTimeMillis)
          : admin.firestore.FieldValue.serverTimestamp(),
        isPaidUser: true,
      }, { merge: true });

      const txLogRef = userRef.collection('credit_transactions').doc();
      tx.set(txLogRef, {
        type: 'add',
        amount: product.credits,
        reason: 'subscription_renewal',
        source: 'subscription',
        creditType: 'purchased',
        productId,
        tier: product.tier,
        orderId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    tx.set(subscriptionRef, {
      userId: uid,
      email,
      productId,
      tier: product.tier,
      credits: product.credits,
      purchaseToken,
      orderId,
      expiryTimeMillis,
      status,
      subscriptionState,
      autoRenewEnabled,
      accessActive,
      ...subscriptionDateFields,
      linkedPurchaseToken,
      cancellationReason,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return {
    alreadyProcessed,
    credits: product.credits,
    tier: product.tier,
  };
}
