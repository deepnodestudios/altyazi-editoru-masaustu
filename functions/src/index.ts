import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// Export functions
export { addCredits } from './billing/addCredits';
export { consumeCredit } from './billing/consumeCredit';
export { giveStarterCredits } from './billing/giveStarterCredits';
export { transferDeviceCreditsToGoogleAccount } from './billing/transferDeviceCreditsToGoogleAccount';
export { translateText } from './ai/translateText';