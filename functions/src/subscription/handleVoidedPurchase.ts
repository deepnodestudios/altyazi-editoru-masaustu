import { onRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

import {
  applySubscriptionRenewal,
  buildSubscriptionDateFields,
  subscriptionDocIdForToken,
  verifySubscriptionWithStore,
} from './subscriptionUtils';
import {
  CREDIT_POLICY_TOKEN_V1,
  hydrateTokenWallet,
  paidTokenBalance,
  resolveSubscriptionTokenGrant,
  resolveTokenPack,
  revokeTokenPack,
  tokenWalletUserFields,
} from '../billing/tokenWallet';

/**
 * Google Play Real-Time Developer Notifications (RTDN) webhook.
 * Handles voided purchases — revokes credits from users who got refunds.
 *
 * Configure this URL in the Google Play Console under:
 *   Monetize > Monetization setup > Real-time developer notifications
 *
 * This endpoint handles VoidedPurchaseNotification events.
 */
export const handleVoidedPurchase = onRequest(
  { cors: false },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    try {
      const message = req.body?.message;
      if (!message?.data) {
        res.status(400).send('No message data');
        return;
      }

      const decoded = JSON.parse(Buffer.from(message.data, 'base64').toString('utf8'));
      const db = admin.firestore();

      const subscriptionNotification = decoded.subscriptionNotification;
      if (subscriptionNotification) {
        const purchaseToken = String(subscriptionNotification.purchaseToken ?? '').trim();
        const subscriptionId = String(subscriptionNotification.subscriptionId ?? '').trim();
        const notificationType = Number(subscriptionNotification.notificationType ?? -1);

        if (!purchaseToken || !subscriptionId) {
          res.status(400).send('Missing subscription payload');
          return;
        }

        const subscriptionRef = db.collection('subscriptions').doc(subscriptionDocIdForToken(purchaseToken));
        const subscriptionDoc = await subscriptionRef.get();
        if (!subscriptionDoc.exists) {
          console.warn(`⚠️ Subscription RTDN received before local mapping existed: token=${purchaseToken.substring(0, 20)}...`);
          res.status(200).send('OK — subscription mapping not found');
          return;
        }

        const subscriptionData = subscriptionDoc.data() ?? {};
        const mappedUserId = typeof subscriptionData.userId === 'string'
          ? subscriptionData.userId.trim()
          : '';
        if (!mappedUserId) {
          res.status(200).send('OK — subscription user missing');
          return;
        }
        const verification = await verifySubscriptionWithStore(subscriptionId, purchaseToken);
        const subscriptionDateFields = buildSubscriptionDateFields({
          status: verification.status,
          expiryTimeMillis: verification.expiryTimeMillis,
          autoRenewEnabled: verification.autoRenewEnabled,
        });
        if (!verification.isActive || verification.productId == null) {
          await subscriptionRef.set({
            status: verification.status,
            subscriptionState: verification.subscriptionState,
            autoRenewEnabled: verification.autoRenewEnabled,
            accessActive: verification.isActive,
            ...subscriptionDateFields,
            linkedPurchaseToken: verification.linkedPurchaseToken,
            cancellationReason: verification.cancellationReason,
            lastWebhookAt: admin.firestore.FieldValue.serverTimestamp(),
            lastNotificationType: notificationType,
          }, { merge: true });
          res.status(200).send('OK — subscription inactive');
          return;
        }

        await applySubscriptionRenewal({
          db,
          uid: mappedUserId,
          email: typeof subscriptionData.email === 'string' ? subscriptionData.email : null,
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

        await subscriptionRef.set({
          lastWebhookAt: admin.firestore.FieldValue.serverTimestamp(),
          lastNotificationType: notificationType,
          status: verification.status,
          subscriptionState: verification.subscriptionState,
          autoRenewEnabled: verification.autoRenewEnabled,
          accessActive: verification.isActive,
          ...subscriptionDateFields,
          linkedPurchaseToken: verification.linkedPurchaseToken,
          cancellationReason: verification.cancellationReason,
        }, { merge: true });

        res.status(200).send('OK — subscription synced');
        return;
      }

      const notification = decoded.voidedPurchaseNotification;

      if (!notification) {
        res.status(200).send('OK — unsupported RTDN event');
        return;
      }

      const { purchaseToken, productType, refundType } = notification;
      if (!purchaseToken) {
        res.status(400).send('Missing purchaseToken');
        return;
      }

      // Find the purchase/subscription by token
      const purchaseQuery = await db.collection('purchases')
        .where('purchaseToken', '==', purchaseToken)
        .limit(1)
        .get();

      const subscriptionRef = db.collection('subscriptions').doc(subscriptionDocIdForToken(purchaseToken));
      const subscriptionDoc = await subscriptionRef.get();

      let userId: string | null = null;
      let creditsToRevoke = 0;
      let tokensToRevoke = 0;
      let source = 'unknown';
      let productId: string | null = null;

      if (!purchaseQuery.empty) {
        const doc = purchaseQuery.docs[0];
        const data = doc.data();
        userId = data.userId ?? null;
        productId = typeof data.productId === 'string' ? data.productId : null;
        const tokenPack = resolveTokenPack(productId);
        tokensToRevoke = Number(data.tokensGranted ?? tokenPack?.tokens ?? 0) || 0;
        creditsToRevoke = tokensToRevoke > 0 ? 0 : Number(data.amount ?? data.credits ?? 0);
        source = 'purchase';
      } else if (subscriptionDoc.exists) {
        const data = subscriptionDoc.data() ?? {};
        userId = typeof data.userId === 'string' ? data.userId : null;
        productId = typeof data.productId === 'string' ? data.productId : null;
        const tokenGrant = resolveSubscriptionTokenGrant(productId);
        tokensToRevoke = Number(data.tokensGranted ?? tokenGrant?.tokens ?? 0) || 0;
        creditsToRevoke = tokensToRevoke > 0 ? 0 : Number(data.credits ?? 0);
        source = 'subscription';

        // Mark subscription as voided
        await subscriptionRef.update({
          status: 'voided',
          voidedAt: admin.firestore.FieldValue.serverTimestamp(),
          refundType: refundType ?? null,
        });
      }

      if (!userId) {
        console.warn(`⚠️ Voided purchase — could not find user for token: ${purchaseToken.substring(0, 20)}...`);
        res.status(200).send('OK — no user found');
        return;
      }

      // Revoke credits
      const userRef = db.collection('users').doc(userId);
      await db.runTransaction(async (tx) => {
        const userDoc = await tx.get(userRef);
        if (!userDoc.exists) return;

        const userData = userDoc.data()!;
        if (
          tokensToRevoke > 0
          || String(userData.creditPolicy ?? '') === CREDIT_POLICY_TOKEN_V1
        ) {
          const tokenPack = resolveTokenPack(productId) ?? resolveSubscriptionTokenGrant(productId);
          if (tokenPack != null || tokensToRevoke > 0) {
            const packToRevoke = tokenPack ?? { base: tokensToRevoke, bonus: 0 };
            const revoked = revokeTokenPack(
              hydrateTokenWallet({ userData }),
              packToRevoke,
              { subscription: source === 'subscription' },
            );
            const walletState = revoked.next;
            const revokedTokens = revoked.revokedPaid + revoked.revokedGrant;
            tx.set(userRef, {
              ...tokenWalletUserFields(walletState),
              ...(source === 'subscription'
                ? {
                    subscriptionActive: false,
                    isPaidUser: walletState.purchasedCredits > 0
                      || walletState.legacyFlatRateRemaining > 0
                      || paidTokenBalance(walletState) > 0,
                  }
                : {}),
            }, { merge: true });
            if (revokedTokens > 0) {
              const txRef = userRef.collection('credit_transactions').doc();
              tx.set(txRef, {
                type: 'spend',
                amount: revokedTokens,
                unit: 'token',
                reason: 'voided_purchase',
                source,
                creditType: 'token_purchased',
                purchaseToken: purchaseToken.substring(0, 30),
                refundType: refundType ?? null,
                productType: productType ?? null,
                productId,
                revokedPaidTokens: revoked.revokedPaid,
                revokedGrantTokens: revoked.revokedGrant,
                remainingTokenBalance: walletState.tokenBalance,
                remainingTokenGrantBalance: walletState.tokenGrantBalance,
                remainingLegacyFlatRateRemaining: walletState.legacyFlatRateRemaining,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          }
          return;
        }

        const currentCredits = Number(userData.purchasedCredits ?? userData.credits ?? 0);
        let subscriptionBucket = Number(userData.subscriptionPurchasedCredits ?? Number.NaN);
        if (!Number.isFinite(subscriptionBucket) || subscriptionBucket < 0) subscriptionBucket = 0;
        subscriptionBucket = Math.min(subscriptionBucket, Math.max(0, currentCredits));
        let extraBucket = Number(userData.extraPurchasedCredits ?? Number.NaN);
        if (!Number.isFinite(extraBucket) || extraBucket < 0) {
          extraBucket = Math.max(0, currentCredits - subscriptionBucket);
        } else {
          extraBucket = Math.min(extraBucket, Math.max(0, currentCredits - subscriptionBucket));
        }

        const revokeFromSubscription = Math.min(subscriptionBucket, creditsToRevoke);
        const revokeFromExtra = Math.max(0, creditsToRevoke - revokeFromSubscription);
        subscriptionBucket = Math.max(0, subscriptionBucket - revokeFromSubscription);
        extraBucket = Math.max(0, extraBucket - revokeFromExtra);
        const newCredits = subscriptionBucket + extraBucket;

        const updates: Record<string, any> = {
          purchasedCredits: newCredits,
          credits: newCredits,
          subscriptionPurchasedCredits: subscriptionBucket,
          extraPurchasedCredits: extraBucket,
        };

        // If subscription was voided, revoke paid status
        if (source === 'subscription') {
          updates.subscriptionActive = false;
          updates.isPaidUser = newCredits > 0;
        }

        tx.update(userRef, updates);

        // Audit trail
        const txRef = userRef.collection('credit_transactions').doc();
        tx.set(txRef, {
          type: 'revoke',
          amount: -creditsToRevoke,
          reason: 'voided_purchase',
          source,
          creditType: 'purchased',
          purchaseToken: purchaseToken.substring(0, 30),
          refundType: refundType ?? null,
          productType: productType ?? null,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      console.log(`✅ Voided purchase processed: user=${userId}, revoked=${creditsToRevoke}, source=${source}`);
      res.status(200).send('OK');
    } catch (error: any) {
      console.error('❌ Voided purchase handler error:', error);
      res.status(500).send('Internal error');
    }
  }
);
