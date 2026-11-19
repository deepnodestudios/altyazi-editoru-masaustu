import * as admin from 'firebase-admin';

import {
  hydrateTokenWallet,
  paidTokenBalance,
} from '../billing/tokenWallet';

/** End of the paid access window stored on a subscriptions/{docId} record. */
export function subscriptionAccessEndMillis(data: Record<string, any>): number | null {
  for (const key of ['accessEndsAtMillis', 'expiryTimeMillis', 'renewsAtMillis']) {
    const value = Number(data[key]);
    if (Number.isFinite(value) && value > 0) return value;
  }
  return null;
}

/**
 * True when a subscription record still grants access right now. A record
 * without any end date keeps its stored flag so we never revoke on missing data.
 */
export function subscriptionRecordGrantsAccess(
  data: Record<string, any>,
  nowMillis: number,
): boolean {
  if (data.accessActive !== true) return false;
  const endMillis = subscriptionAccessEndMillis(data);
  return endMillis == null || endMillis > nowMillis;
}

/**
 * Clears users/{uid}.subscriptionActive once none of the user's subscription
 * records grants access any more. Never sets it to true: activation stays with
 * applySubscriptionRenewal. Tokens are not touched.
 */
export async function syncUserSubscriptionFlags(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<{ deactivated: boolean; hasActiveSubscription: boolean }> {
  const nowMillis = Date.now();
  const subscriptions = await db
    .collection('subscriptions')
    .where('userId', '==', uid)
    .get();
  const hasActiveSubscription = subscriptions.docs.some(
    (doc) => subscriptionRecordGrantsAccess(doc.data() ?? {}, nowMillis),
  );
  if (hasActiveSubscription) {
    return { deactivated: false, hasActiveSubscription: true };
  }

  const userRef = db.collection('users').doc(uid);
  const deactivated = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) return false;
    const userData = userSnap.data() ?? {};
    if (userData.subscriptionActive !== true) return false;

    const walletState = hydrateTokenWallet({ userData });
    tx.set(userRef, {
      subscriptionActive: false,
      isPaidUser: walletState.purchasedCredits > 0
        || walletState.legacyFlatRateRemaining > 0
        || paidTokenBalance(walletState) > 0,
      subscriptionDeactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return true;
  });

  return { deactivated, hasActiveSubscription: false };
}
