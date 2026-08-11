// ══════════════════════════════════════════════════════════════════════
// One-time backfill: stamps `role: authenticated` on every EXISTING
// Firebase user (index.js's onCreate trigger only covers users created
// AFTER it's deployed). Run this exactly once, right after the first
// `firebase deploy --only functions`, from your own machine — never from
// this sandbox, since it needs a real service-account credential.
//
// Usage:
//   1. Firebase Console → Project settings → Service accounts →
//      "Generate new private key" → save the JSON file somewhere OUTSIDE
//      this repo (never commit it).
//   2. In a terminal, from this functions/ directory:
//        npm install
//        GOOGLE_APPLICATION_CREDENTIALS="/path/to/that-key.json" node backfill-claims.js
//   3. Watch the console output — it logs one line per user, and a final
//      summary count. Safe to re-run (setCustomUserClaims is idempotent).
// ══════════════════════════════════════════════════════════════════════

const admin = require('firebase-admin');

admin.initializeApp();

async function backfillAllUsers() {
  let updated = 0;
  let skipped = 0;
  let failed = 0;
  let nextPageToken;

  do {
    const page = await admin.auth().listUsers(1000, nextPageToken);
    for (const user of page.users) {
      if (user.customClaims && user.customClaims.role === 'authenticated') {
        skipped++;
        continue;
      }
      try {
        await admin.auth().setCustomUserClaims(user.uid, {
          ...(user.customClaims || {}),
          role: 'authenticated',
        });
        console.log(`updated: ${user.uid} (${user.email || user.phoneNumber || 'no email/phone'})`);
        updated++;
      } catch (err) {
        console.error(`FAILED: ${user.uid}`, err.message);
        failed++;
      }
    }
    nextPageToken = page.pageToken;
  } while (nextPageToken);

  console.log('\n── Backfill complete ──');
  console.log(`  updated: ${updated}`);
  console.log(`  already had the claim (skipped): ${skipped}`);
  console.log(`  failed: ${failed}`);
  if (failed > 0) {
    console.log('\nRe-run this script to retry the failed users — it is idempotent.');
  }
}

backfillAllUsers()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Backfill script crashed:', err);
    process.exit(1);
  });
