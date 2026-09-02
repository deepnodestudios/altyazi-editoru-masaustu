import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';

import {
  BONUS_TOKEN_EXPIRY_REASON,
  TOKEN_GRANT_LOTS_COLLECTION,
  expireDueGrantLotsInTx,
  loadActiveGrantLots,
  loadGoogleLoginGrantLots,
} from '../billing/tokenGrantLots';
import {
  hydrateTokenWallet,
  resolveGoogleLoginTokenGrantBalance,
  tokenWalletUserFields,
} from '../billing/tokenWallet';

const PAGE_SIZE = 200;

/**
 * Daily job: expire active bonus-token lots past expiresAt.
 * Lazy expiry on spend/grant also covers most cases; this keeps balances honest at rest.
 */
export const expireBonusTokens = onSchedule(
  {
    schedule: '15 3 * * *',
    timeZone: 'UTC',
    retryCount: 1,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    let expiredLots = 0;
    let burnedTokens = 0;
    let cursor: FirebaseFirestore.QueryDocumentSnapshot | null = null;
    const processedUserPaths = new Set<string>();

    for (;;) {
      let query = db
        .collectionGroup(TOKEN_GRANT_LOTS_COLLECTION)
        .where('status', '==', 'active')
        .where('expiresAt', '<=', now)
        .orderBy('expiresAt', 'asc')
        .limit(PAGE_SIZE);

      if (cursor) {
        query = query.startAfter(cursor);
      }

      const snap = await query.get();
      if (snap.empty) break;

      for (const lotDoc of snap.docs) {
        const userRef = lotDoc.ref.parent.parent;
        if (!userRef) continue;
        if (processedUserPaths.has(userRef.path)) continue;

        try {
          const result = await db.runTransaction(async (tx) => {
            const userSnap = await tx.get(userRef);
            const userData = userSnap.exists ? (userSnap.data() ?? {}) : {};
            const state = hydrateTokenWallet({ userData });
            const activeLots = await loadActiveGrantLots(tx, userRef);
            const trackedGoogleLoginLots =
              await loadGoogleLoginGrantLots(userRef, tx);
            const expired = expireDueGrantLotsInTx(
              tx,
              userRef,
              state,
              activeLots,
              now.toDate(),
            );
            if (
              expired.expiredAmount > 0
              || expired.next.subscriptionTokenGrantRemaining
                !== state.subscriptionTokenGrantRemaining
            ) {
              tx.set(
                userRef,
                {
                  ...tokenWalletUserFields(expired.next),
                  googleLoginTokenGrantBalance:
                    resolveGoogleLoginTokenGrantBalance(
                      userData,
                      expired.lots,
                      trackedGoogleLoginLots.length > 0,
                    ),
                },
                { merge: true },
              );
            }
            return {
              burned: expired.expiredAmount,
              count: expired.expiredLotIds.length,
            };
          });
          processedUserPaths.add(userRef.path);

          if (result.burned > 0) {
            expiredLots += result.count;
            burnedTokens += result.burned;
          }
        } catch (error) {
          console.error('expireBonusTokens: lot failed', {
            lotId: lotDoc.id,
            path: lotDoc.ref.path,
            reason: BONUS_TOKEN_EXPIRY_REASON,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }

      cursor = snap.docs[snap.docs.length - 1] ?? null;
      if (snap.size < PAGE_SIZE) break;
    }

    console.log('expireBonusTokens: done', { expiredLots, burnedTokens });
  },
);
