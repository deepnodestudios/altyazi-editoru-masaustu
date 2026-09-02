import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// ── Billing ──
export { addCredits } from './billing/addCredits';
export { getAdRewardStatus, recordAdRewardWatch } from './billing/adRewardCredits';
export { consumeCredit } from './billing/consumeCredit';
export { giveStarterCredits } from './billing/giveStarterCredits';
export { transferDeviceCreditsToGoogleAccount } from './billing/transferDeviceCreditsToGoogleAccount';
export { checkDailyAdLimit, recordAdUsage } from './billing/dailyAdLimit';

// ── AI ──
export { quoteTranslationCost } from './ai/quoteTranslationCost';
export { checkTranslationAccess } from './ai/checkTranslationAccess';
export { translateText } from './ai/translateText';
export { startBatchTranslation, checkBatchTranslation } from './ai/batchTranslate';
export { pollBatchJobs } from './ai/pollBatchJobs';

// ── Referral (v1.6.0+) ──
export { generateReferralCode } from './referral/generateReferralCode';
export { claimReferral } from './referral/claimReferral';

// ── Subscriptions (v1.6.0+) ──
export { handleSubscription } from './subscription/handleSubscription';
export { handleVoidedPurchase } from './subscription/handleVoidedPurchase';

// ── Bonus & Notifications (v1.6.0+) ──
// Keep monthlyGoogleBonus exported (no-op) so deploy does not delete the live scheduled job.
export { monthlyGoogleBonus } from './bonus/monthlyGoogleBonus';
export { notifyExpiringCredits } from './bonus/notifyExpiringCredits';
export { expireBonusTokens } from './bonus/expireBonusTokens';
