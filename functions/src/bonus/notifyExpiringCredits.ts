import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';

import { getExpiryNotificationText } from './bonusI18n';

/**
 * Scheduled Cloud Function that runs daily at 10:00 UTC.
 * Sends a push notification to users whose free credits are about to expire
 * (3 days before the end of the month).
 *
 * Schedule: "0 10 * * *" = At 10:00 every day
 */
export const notifyExpiringCredits = onSchedule(
  {
    schedule: '0 10 * * *',
    timeZone: 'UTC',
    retryCount: 1,
  },
  async () => {
    const now = new Date();
    const year = now.getUTCFullYear();
    const month = now.getUTCMonth(); // 0-based
    const lastDay = new Date(year, month + 1, 0).getUTCDate();
    const currentDay = now.getUTCDate();

    // Only trigger 3 days before month end
    if (currentDay !== lastDay - 3) {
      console.log(`📅 Not 3 days before month end (day ${currentDay}, last day ${lastDay}). Skipping.`);
      return;
    }

    console.log(`📅 Expiring credits notification: day ${currentDay} of ${lastDay}`);

    const db = admin.firestore();

    // Find users with freeCredits > 0
    const usersSnapshot = await db.collection('users')
      .where('freeCredits', '>', 0)
      .get();

    console.log(`  Found ${usersSnapshot.size} users with expiring free credits`);

    const messages: admin.messaging.Message[] = [];

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const uid = userDoc.id;

      // Get the user's FCM token
      let fcmToken: string | null = null;
      try {
        const tokenDoc = await db.collection('fcm_tokens').doc(uid).get();
        fcmToken = tokenDoc.data()?.token ?? null;
      } catch {
        // no token, skip
      }

      if (!fcmToken) continue;

      // Determine user's language for localized notification
      const lang = (userData.appLanguage ?? 'en').toLowerCase();

      const notificationText = getExpiryNotificationText(lang);

      messages.push({
        token: fcmToken,
        notification: {
          title: notificationText.title,
          body: notificationText.body,
        },
        data: {
          type: 'credit_expiry_warning',
          userId: uid,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'credit_alerts',
            sound: 'default',
          },
        },
      });
    }

    // Send in batches of 500
    for (let i = 0; i < messages.length; i += 500) {
      const batch = messages.slice(i, i + 500);
      const result = await admin.messaging().sendEach(batch);
      console.log(`  Batch ${Math.floor(i / 500) + 1}: ${result.successCount} sent, ${result.failureCount} failed`);
    }

    console.log(`✅ Expiring credit notifications sent to ${messages.length} users`);
  }
);
