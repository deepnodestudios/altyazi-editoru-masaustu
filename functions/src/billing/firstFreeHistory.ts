import * as admin from 'firebase-admin';

/**
 * Owner decision (Nov 2026): the free first translation is only for people
 * who have never translated. Accounts that translated before the gift
 * existed never got `firstFreeTranslationUsedAt`, so the gift (and its
 * "First translation free" badge) must also look at their history.
 */
export function userDocShowsTranslation(
    userData: Record<string, unknown>,
): boolean {
    return userData.firstFreeTranslationUsedAt != null
        || userData.lastCreditConsumption != null;
}

/**
 * True when the account has any translation charge on record: the user
 * document's markers, or one charge in its usage history.
 */
export async function hasTranslatedBefore(
    userRef: admin.firestore.DocumentReference,
    userData: Record<string, unknown>,
): Promise<boolean> {
    if (userDocShowsTranslation(userData)) return true;
    const [usage, spends] = await Promise.all([
        userRef.collection('credit_usage').limit(1).get(),
        userRef.collection('credit_transactions')
            .where('type', '==', 'spend')
            .limit(1)
            .get(),
    ]);
    return !usage.empty || !spends.empty;
}
