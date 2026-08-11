// ══════════════════════════════════════════════════════════════════════
// ASF — Cloud Function: stamp `role: authenticated` on every Firebase
// user, as required by Supabase's Firebase Third-Party Auth integration
// (https://supabase.com/docs/guides/auth/third-party/firebase-auth).
//
// Without this custom claim, Supabase's PostgREST layer grants the
// `anon` Postgres role instead of `authenticated` for this user's
// requests — this app's RLS policies (see supabase_schema.sql) apply to
// any role since none declare a `to` clause, but Supabase's own
// documented Third-Party Auth setup expects this claim to be present as
// part of how it recognizes a Firebase JWT as belonging to a real,
// signed-in user at all. This function follows that documented pattern
// exactly rather than deviating from it.
//
// Deliberately a REGULAR (1st-gen) `functions.auth.user().onCreate()`
// trigger, not a 2nd-gen blocking function (`beforeUserCreated`/
// `beforeUserSignedIn`). Blocking functions require upgrading the
// Firebase project to Identity Platform (a bigger, separate change);
// this trigger works on plain Firebase Authentication + the Blaze
// (pay-as-you-go) plan that Cloud Functions already requires, at the
// cost of running asynchronously — the claim lands a moment AFTER the
// user document is created, not synchronously during sign-up. The
// Flutter app already accounts for this (see
// AuthRepository._forceRefreshIdTokenWithRetry(), called before the
// first authenticated Supabase write during registration).
// ══════════════════════════════════════════════════════════════════════

const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();

exports.stampAuthenticatedRoleClaim = functions.auth.user().onCreate(async (user) => {
  try {
    await admin.auth().setCustomUserClaims(user.uid, {
      ...(user.customClaims || {}),
      role: 'authenticated',
    });
    functions.logger.info(`Stamped role:authenticated on new user ${user.uid}`);
  } catch (err) {
    // Don't throw — a failed claim stamp shouldn't be surfaced as a
    // sign-up error to the user. Worst case, the one-time backfill
    // script (backfill-claims.js) catches this user on its next run.
    functions.logger.error(`Failed to stamp role claim for ${user.uid}`, err);
  }
});
