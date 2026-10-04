import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import { resolveCountryFullName } from '../billing/geoIp';

/**
 * Ensures all documents in `global_translations` have the author's full country name (e.g. 'Laos', 'Brazil', 'South Korea').
 * If written by an older client that didn't include `country`, this trigger
 * looks up the user or device profile in Firestore and enriches the doc.
 * If written with a 2-letter ISO abbreviation (e.g. 'LA', 'BR'), this converts it to the full name.
 */
export const enrichGlobalTranslationCountry = onDocumentCreated(
  { document: 'global_translations/{cacheKey}', region: 'us-central1' },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    if (!data) return;

    const db = admin.firestore();
    const existingCountry = data.country ? String(data.country).trim() : null;

    // If country is already a full name (> 2 chars), no need to re-enrich
    if (existingCountry && existingCountry.length > 2) {
      return;
    }

    let rawCountryCode: string | null = (existingCountry && existingCountry.length === 2)
      ? existingCountry.toUpperCase()
      : null;

    // 1. Try finding user by email if code not present
    if (!rawCountryCode) {
      const email = (data.lastUserEmail || data.creatorEmail || '').toString().trim().toLowerCase();
      if (email) {
        const userSnap = await db.collection('users').where('email', '==', email).limit(1).get();
        if (!userSnap.empty) {
          const uCountry = userSnap.docs[0].data()?.country;
          if (uCountry) rawCountryCode = String(uCountry).trim();
        }
      }
    }

    // 2. Fall back to device_bonuses if code not present
    if (!rawCountryCode) {
      const deviceId = (data.lastDeviceId || data.creatorDeviceId || '').toString().trim();
      if (deviceId) {
        const devDoc = await db.collection('device_bonuses').doc(deviceId).get();
        if (devDoc.exists) {
          const dCountry = devDoc.data()?.country;
          if (dCountry) rawCountryCode = String(dCountry).trim();
        }
      }
    }

    if (!rawCountryCode) return;

    const fullCountryName = resolveCountryFullName(rawCountryCode) || rawCountryCode;
    const isoCode = rawCountryCode.length === 2 ? rawCountryCode.toUpperCase() : undefined;

    await snap.ref.set(
      {
        country: fullCountryName,
        creatorCountry: fullCountryName,
        lastCountry: fullCountryName,
        countries: [fullCountryName],
        ...(isoCode ? { countryCode: isoCode } : {}),
      },
      { merge: true },
    );
  },
);

