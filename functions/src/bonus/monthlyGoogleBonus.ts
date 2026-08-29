import { onSchedule } from 'firebase-functions/v2/scheduler';

/**
 * Formerly awarded 2 googleLoginCredits monthly to all Google-signed-in users.
 * Disabled for everyone — kept exported so deploy does not delete the live
 * scheduled job. Handler exits immediately without granting credits.
 *
 * Schedule: "5 0 1 * *" = At 00:05 on day 1 of every month (UTC)
 */
export const monthlyGoogleBonus = onSchedule(
  {
    schedule: '5 0 1 * *',
    timeZone: 'UTC',
    retryCount: 0,
  },
  async () => {
    console.log('monthlyGoogleBonus disabled: no credits granted');
  },
);
