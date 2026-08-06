import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';

const MONTHLY_BONUS_CREDITS = 2;

/**
 * Scheduled Cloud Function that runs on the 1st of every month at 00:05 UTC.
 * Awards 2 googleLoginCredits to all Google-signed-in users.
 * Credits do NOT accumulate — they are reset to MONTHLY_BONUS_CREDITS if the user
 * already has leftover monthly bonus credits.
 *
 * Schedule: "5 0 1 * *" = At 00:05 on day 1 of every month
 */
export const monthlyGoogleBonus = onSchedule(
  {
    schedule: '5 0 1 * *',
    timeZone: 'UTC',
    retryCount: 2,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const monthKey = new Date().toISOString().slice(0, 7); // e.g. "2026-04"
    let count = 0;
    let pageToken: string | undefined;

    do {
      const listResult = await admin.auth().listUsers(1000, pageToken);
      pageToken = listResult.pageToken;
      const googleUsers = listResult.users.filter((u) =>
        u.providerData.some((p) => p.providerId === 'google.com')
      );

      let batch = db.batch();
      let opCount = 0;

      for (const user of googleUsers) {
        const userRef = db.collection('users').doc(user.uid);
        const userDoc = await userRef.get();
        if (userDoc.exists && userDoc.data()?.freeRewardsRestricted === true) {
          continue;
        }

        const bonusRef = db.collection('monthly_bonuses').doc(`${user.uid}_${monthKey}`);
        const bonusDoc = await bonusRef.get();
        if (bonusDoc.exists) continue;

        batch.set(userRef, {
          googleLoginCredits: MONTHLY_BONUS_CREDITS,
          lastMonthlyBonusAt: now,
          lastMonthlyBonusMonth: monthKey,
        }, { merge: true });

        batch.set(bonusRef, {
          uid: user.uid,
          email: user.email ?? null,
          credits: MONTHLY_BONUS_CREDITS,
          month: monthKey,
          grantedAt: now,
        });

        const txRef = userRef.collection('credit_transactions').doc();
        batch.set(txRef, {
          type: 'add',
          amount: MONTHLY_BONUS_CREDITS,
          reason: 'monthly_google_bonus',
          source: 'bonus',
          creditType: 'google_login',
          month: monthKey,
          timestamp: now,
        });

        count++;
        opCount += 3;

        if (opCount >= 450) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }

      if (opCount > 0) {
        await batch.commit();
      }
    } while (pageToken != null);

    console.log(`✅ Monthly bonus granted to ${count} users (${MONTHLY_BONUS_CREDITS} credits each)`);
  }
);
