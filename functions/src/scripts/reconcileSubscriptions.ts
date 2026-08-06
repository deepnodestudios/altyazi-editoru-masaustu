import * as admin from 'firebase-admin';

import {
  buildSubscriptionDateFields,
  normalizeSubscriptionProductId,
  verifySubscriptionWithStore,
} from '../subscription/subscriptionUtils';

type Options = {
  userId?: string;
  docId?: string;
  limit?: number;
  write: boolean;
};

function parseArgs(argv: string[]): Options {
  const options: Options = {write: false};

  for (let index = 0; index < argv.length; index++) {
    const arg = argv[index];
    if (arg === '--write') {
      options.write = true;
      continue;
    }
    if (arg === '--userId') {
      options.userId = argv[index + 1]?.trim();
      index++;
      continue;
    }
    if (arg === '--docId') {
      options.docId = argv[index + 1]?.trim();
      index++;
      continue;
    }
    if (arg === '--limit') {
      const parsed = Number(argv[index + 1]);
      if (Number.isFinite(parsed) && parsed > 0) {
        options.limit = parsed;
      }
      index++;
    }
  }

  return options;
}

function formatMillis(value: number | null): string {
  if (!Number.isFinite(value ?? Number.NaN) || value == null) {
    return '-';
  }
  return new Date(value).toISOString();
}

function formatBool(value: boolean | null): string {
  if (value == null) return '-';
  return value ? 'true' : 'false';
}

async function loadDocs(options: Options): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  const db = admin.firestore();

  if (options.docId) {
    const doc = await db.collection('subscriptions').doc(options.docId).get();
    return doc.exists ? [doc as FirebaseFirestore.QueryDocumentSnapshot] : [];
  }

  let query: FirebaseFirestore.Query = db.collection('subscriptions');
  if (options.userId && options.userId.trim().length > 0) {
    query = query.where('userId', '==', options.userId.trim());
  }
  if (options.limit != null) {
    query = query.limit(options.limit);
  }

  const snapshot = await query.get();
  return snapshot.docs;
}

async function main() {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }

  const options = parseArgs(process.argv.slice(2));
  const docs = await loadDocs(options);

  if (docs.length === 0) {
    console.log('No subscription documents found for the provided filter.');
    return;
  }

  console.log(`Reconciling ${docs.length} subscription document(s). write=${options.write}`);

  const summary = new Map<string, number>();
  let failures = 0;

  for (const doc of docs) {
    const data = doc.data() ?? {};
    const rawProductId = String(data.productId ?? '').trim();
    const productId = normalizeSubscriptionProductId(rawProductId);
    const purchaseToken = String(data.purchaseToken ?? '').trim();

    if (!productId || !purchaseToken) {
      failures++;
      console.error(`[${doc.id}] skipped: missing productId or purchaseToken`);
      continue;
    }

    try {
      const verification = await verifySubscriptionWithStore(productId, purchaseToken);
      const subscriptionDateFields = buildSubscriptionDateFields({
        status: verification.status,
        expiryTimeMillis: verification.expiryTimeMillis,
        autoRenewEnabled: verification.autoRenewEnabled,
      });
      summary.set(verification.status, (summary.get(verification.status) ?? 0) + 1);

      const updatePayload: Record<string, unknown> = {
        productId: verification.productId ?? productId,
        orderId: verification.orderId,
        expiryTimeMillis: verification.expiryTimeMillis,
        status: verification.status,
        subscriptionState: verification.subscriptionState,
        autoRenewEnabled: verification.autoRenewEnabled,
        ...subscriptionDateFields,
        linkedPurchaseToken: verification.linkedPurchaseToken,
        cancellationReason: verification.cancellationReason,
        accessActive: verification.isActive,
        reconciledBy: 'src/scripts/reconcileSubscriptions.ts',
        reconciledAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      console.log(
        [
          `[${doc.id}]`,
          `product=${verification.productId ?? productId}`,
          `status=${verification.status}`,
          `accessActive=${formatBool(verification.isActive)}`,
          `autoRenew=${formatBool(verification.autoRenewEnabled)}`,
          `expiry=${formatMillis(verification.expiryTimeMillis)}`,
          `renewsAt=${formatMillis(subscriptionDateFields.renewsAtMillis)}`,
          `accessEndsAt=${formatMillis(subscriptionDateFields.accessEndsAtMillis)}`,
          `orderId=${verification.orderId ?? '-'}`,
          `cancelReason=${verification.cancellationReason ?? '-'}`,
        ].join(' '),
      );

      if (options.write) {
        await doc.ref.set(updatePayload, {merge: true});
      }
    } catch (error: any) {
      failures++;
      console.error(
        `[${doc.id}] verify failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  console.log('Summary:');
  for (const [status, count] of summary.entries()) {
    console.log(`  ${status}: ${count}`);
  }
  console.log(`  failures: ${failures}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});