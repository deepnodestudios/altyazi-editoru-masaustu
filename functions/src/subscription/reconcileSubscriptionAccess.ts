import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';

import {
  applySubscriptionRenewal,
  buildSubscriptionDateFields,
  normalizeSubscriptionProductId,
  verifySubscriptionWithStore,
} from './subscriptionUtils';
import {
  subscriptionAccessEndMillis,
  syncUserSubscriptionFlags,
} from './subscriptionSync';

/** Play can report a renewal a little after the old period ends. */
const END_GRACE_MS = 6 * 60 * 60 * 1000;
const MAX_VERIFICATIONS_PER_RUN = 200;

/**
 * Daily safety net for missed RTDN events (e.g. subscriptions that ended
 * before RTDN was wired up). Only acts on Play's own answer: a record is never
 * expired from its stored date alone, and Play auth/network errors skip it.
 *
 * 1. subscriptions with accessActive=true whose access window has ended are
 *    re-verified with Play and written the same way handleVoidedPurchase does
 *    (a missed renewal is applied; applySubscriptionRenewal is expiry-idempotent).
 * 2. users with subscriptionActive=true are cleared when none of their
 *    subscription records still grants access.
 */
export const reconcileSubscriptionAccess = onSchedule(
  {
    schedule: '45 3 * * *',
    timeZone: 'UTC',
    retryCount: 1,
  },
  async () => {
    const db = admin.firestore();
    const nowMillis = Date.now();
    const touchedUsers = new Set<string>();
    let verified = 0;
    let deactivatedRecords = 0;
    let renewedRecords = 0;
    let verifyFailures = 0;

    const activeRecords = await db
      .collection('subscriptions')
      .where('accessActive', '==', true)
      .get();

    for (const doc of activeRecords.docs) {
      if (verified >= MAX_VERIFICATIONS_PER_RUN) break;
      const data = doc.data() ?? {};
      const endMillis = subscriptionAccessEndMillis(data);
      if (endMillis == null || endMillis + END_GRACE_MS > nowMillis) continue;

      const productId = normalizeSubscriptionProductId(String(data.productId ?? '').trim());
      const purchaseToken = String(data.purchaseToken ?? '').trim();
      const uid = typeof data.userId === 'string' ? data.userId.trim() : '';
      if (!productId || !purchaseToken || !uid) continue;

      verified++;
      try {
        const verification = await verifySubscriptionWithStore(productId, purchaseToken);
        const subscriptionDateFields = buildSubscriptionDateFields({
          status: verification.status,
          expiryTimeMillis: verification.expiryTimeMillis,
          autoRenewEnabled: verification.autoRenewEnabled,
        });
        if (verification.isActive && verification.productId != null) {
          await applySubscriptionRenewal({
            db,
            uid,
            email: typeof data.email === 'string' ? data.email : null,
            productId: verification.productId,
            purchaseToken,
            orderId: verification.orderId,
            expiryTimeMillis: verification.expiryTimeMillis,
            status: verification.status,
            subscriptionState: verification.subscriptionState,
            autoRenewEnabled: verification.autoRenewEnabled,
            linkedPurchaseToken: verification.linkedPurchaseToken,
            cancellationReason: verification.cancellationReason,
            appVersion: typeof data.appVersion === 'string' ? data.appVersion : null,
          });
          renewedRecords++;
        } else {
          deactivatedRecords++;
        }
        await doc.ref.set({
          status: verification.status,
          subscriptionState: verification.subscriptionState,
          autoRenewEnabled: verification.autoRenewEnabled,
          accessActive: verification.isActive,
          ...subscriptionDateFields,
          linkedPurchaseToken: verification.linkedPurchaseToken,
          cancellationReason: verification.cancellationReason,
          reconciledBy: 'reconcileSubscriptionAccess',
          reconciledAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        touchedUsers.add(uid);
      } catch (error) {
        verifyFailures++;
        console.warn(`[reconcileSubscriptionAccess] verify failed for ${doc.id.substring(0, 12)}…`, error);
      }
    }

    const flaggedUsers = await db
      .collection('users')
      .where('subscriptionActive', '==', true)
      .get();
    flaggedUsers.docs.forEach((doc) => touchedUsers.add(doc.id));

    let deactivatedUsers = 0;
    for (const uid of touchedUsers) {
      try {
        const result = await syncUserSubscriptionFlags(db, uid);
        if (result.deactivated) deactivatedUsers++;
      } catch (error) {
        console.warn(`[reconcileSubscriptionAccess] user sync failed for ${uid}`, error);
      }
    }

    console.log('[reconcileSubscriptionAccess] done', {
      verified,
      renewedRecords,
      deactivatedRecords,
      verifyFailures,
      usersChecked: touchedUsers.size,
      deactivatedUsers,
    });
  },
);
