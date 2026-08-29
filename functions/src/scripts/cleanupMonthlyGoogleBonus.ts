import * as admin from 'firebase-admin';

/**
 * One-off cleanup: remove monthly Google bonus metadata from Firestore.
 * Does NOT touch googleLoginCredits / googleLoginBonus* (first-login wallet).
 *
 * Usage (from functions/):
 *   npm run build
 *   node lib/scripts/cleanupMonthlyGoogleBonus.js --write
 */

type Options = { write: boolean };

function parseArgs(argv: string[]): Options {
  return { write: argv.includes('--write') };
}

async function deleteMonthlyBonusesCollection(
  db: admin.firestore.Firestore,
  write: boolean,
): Promise<number> {
  let deleted = 0;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snap = await db.collection('monthly_bonuses').limit(400).get();
    if (snap.empty) break;

    if (!write) {
      deleted += snap.size;
      console.log(`[dry-run] would delete ${snap.size} monthly_bonuses docs (sample page)`);
      break;
    }

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deleted += snap.size;
    console.log(`Deleted ${deleted} monthly_bonuses docs so far...`);
  }
  return deleted;
}

async function stripUserMonthlyFields(
  db: admin.firestore.Firestore,
  write: boolean,
): Promise<number> {
  let updated = 0;
  let scanned = 0;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;

  // eslint-disable-next-line no-constant-condition
  while (true) {
    let query: FirebaseFirestore.Query = db.collection('users').orderBy(admin.firestore.FieldPath.documentId()).limit(300);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    let ops = 0;

    for (const doc of snap.docs) {
      scanned++;
      const data = doc.data() ?? {};
      const hasAt = Object.prototype.hasOwnProperty.call(data, 'lastMonthlyBonusAt');
      const hasMonth = Object.prototype.hasOwnProperty.call(data, 'lastMonthlyBonusMonth');
      if (!hasAt && !hasMonth) continue;

      if (write) {
        batch.update(doc.ref, {
          lastMonthlyBonusAt: admin.firestore.FieldValue.delete(),
          lastMonthlyBonusMonth: admin.firestore.FieldValue.delete(),
        });
        ops++;
      }
      updated++;
    }

    if (write && ops > 0) {
      await batch.commit();
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    console.log(
      `Scanned ${scanned} users; monthly fields ${write ? 'stripped' : 'found'}: ${updated}`,
    );
  }

  return updated;
}

async function main() {
  if (admin.apps.length === 0) {
    admin.initializeApp({ projectId: 'altyazi-ceviri-editor' });
  }

  const { write } = parseArgs(process.argv.slice(2));
  const db = admin.firestore();

  console.log(`cleanupMonthlyGoogleBonus write=${write}`);

  const bonusesDeleted = await deleteMonthlyBonusesCollection(db, write);
  const usersUpdated = await stripUserMonthlyFields(db, write);

  console.log(
    `Done. monthly_bonuses=${bonusesDeleted}, usersWithMonthlyFields=${usersUpdated}`,
  );
  if (!write) {
    console.log('Dry-run only. Re-run with --write to apply.');
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
