# Firebase → Supabase Third-Party Auth — setup & rollout

Closes the Supabase linter's `rls_policy_always_true` finding (11 tables) and
`public_bucket_allows_listing` finding (`pig-photos` bucket) for real, by
giving Postgres a way to verify who's actually calling it, instead of
trusting the app to always filter by `firebase_uid` itself.

**Status: fully deployed and live.** The claim-stamping piece below no longer
uses a Firebase Cloud Function — that would have required upgrading the
Firebase project off its free Spark plan, which this project intentionally
avoids. Instead, a Supabase Edge Function (`stamp-claim`) does the same job
and has already been deployed. Sections below are kept as a historical/
reference record of what's live, not a to-do list.

## What's already done (code, in this repo)

- **`flutter_app/lib/core/config/supabase_config.dart`** — `Supabase.initialize()`
  now passes an `accessToken` callback that returns the current Firebase ID
  token on every request.
- **`flutter_app/lib/features/auth/data/auth_repository.dart`** —
  `_forceRefreshIdTokenWithRetry()` force-refreshes the ID token (with a short
  retry) before every authenticated Supabase write, and — the first time in
  that retry loop it notices the `role: authenticated` claim is still
  missing — calls the `stamp-claim` Edge Function (best-effort, non-blocking)
  before continuing to retry. This covers both a brand-new registration and
  any pre-existing account automatically; no separate backfill step needed.
- **`supabase/functions/stamp-claim/index.ts`** — the Edge Function that
  replaces the Cloud Function. It decodes the caller's already-Supabase-
  verified Firebase ID token to read `sub` (uid), then uses a hand-rolled
  service-account JWT-bearer OAuth2 flow (RFC 7523, via Deno's native Web
  Crypto API — no npm dependencies) to get a Google OAuth2 access token and
  calls the Identity Toolkit REST API (`accounts:update`) to stamp
  `role: authenticated` as a custom claim on that uid. A caller can only ever
  stamp their own uid — there's no uid parameter accepted from the request
  body, and Supabase's gateway has already verified the bearer token's
  signature/audience/expiry before this function's code runs (see
  `supabase/functions/_shared/cors.ts`'s doc comment for why that's safe to
  rely on). Idempotent and safe to call repeatedly.
- **`supabase_schema.sql`** — every table's `using (true) with check (true)`
  policy is now `firebase_uid = auth.jwt()->>'sub'` (both directions), and the
  two storage buckets' insert/update policies now also require the object
  path's first folder segment to match the caller's own uid. This file is
  still idempotent — re-running it is safe.
- **Deployed secrets** (Supabase project `genxzsocmhgnxwwxjifz`) —
  `FIREBASE_SERVICE_ACCOUNT_JSON` and `FIREBASE_PROJECT_ID` are set as Edge
  Function secrets. The local copy of the service account key used to set
  them has been deleted; the only copy that matters now lives in Supabase's
  encrypted secrets store.
- Superseded and no longer used: `functions/` (the old Cloud Functions
  project — `index.js` onCreate trigger + `backfill-claims.js`) and
  `firebase.json`'s `functions` source registration. Left in place for
  reference but not deployed and not needed.

None of the RLS tightening takes effect until Third-Party Auth is registered
in the Supabase Dashboard and the schema above has been applied — both are
confirmed done (see "Status" above).

## Manual steps (historical — already completed)

### 1. ~~Confirm the Blaze (pay-as-you-go) plan on Firebase~~ — not needed

The original plan assumed a Firebase Cloud Function, which requires the
Blaze plan. That approach was replaced by the `stamp-claim` Supabase Edge
Function above specifically so this project can stay on Firebase's free
Spark plan indefinitely.

### 2. ~~Deploy the Cloud Function~~ — replaced by Edge Function deploy

Done via `supabase functions deploy stamp-claim --project-ref
genxzsocmhgnxwwxjifz`, with `FIREBASE_SERVICE_ACCOUNT_JSON` and
`FIREBASE_PROJECT_ID` set as secrets first. Both steps already completed.

### 3. ~~Run the one-time backfill for existing users~~ — not needed

`_forceRefreshIdTokenWithRetry()` calls `stamp-claim` lazily on every user's
next authenticated write, whether their account is brand-new or predates
this function. No separate backfill script/run required.

### 4. Register Firebase as a Third-Party Auth provider in Supabase

Supabase Dashboard → your project → Authentication → Sign In / Providers →
Third-Party Auth → Add provider → Firebase → enter Project ID `asf-app-2990c`
→ Save. (Full reference: [Supabase's Firebase Auth guide](https://supabase.com/docs/guides/auth/third-party/firebase-auth).)

### 5. Apply the updated schema to your live Supabase project

Supabase Dashboard → SQL Editor → New query → paste the entire contents of
`supabase_schema.sql` from this repo → Run. It's the same file you've run
before; this just carries the new policies plus the still-pending
`pig-photos` broad-SELECT cleanup from last round.

### 6. Rebuild and test the app

`firebase_auth` and `supabase_flutter` are both already app dependencies, so
no `pubspec.yaml` change is needed — just a normal rebuild:

```
cd flutter_app
flutter pub get
flutter build apk --release --split-per-abi
```

Test with a **new** registration (so you see the full flow: sign-up → Cloud
Function stamps the claim → app force-refreshes the token → profile write
succeeds). Then confirm an **existing** account still logs in and loads its
data (proves the backfill script covered it).

### 7. Verify the fix actually closes the hole

From any machine, with only the public anon key (no Firebase token) —
this should now return an empty array instead of every user's rows:

```
curl "https://genxzsocmhgnxwwxjifz.supabase.co/rest/v1/profiles?select=*" \
  -H "apikey: <anon key>" -H "Authorization: Bearer <anon key>"
```

Re-run Supabase's database linter (Dashboard → Advisors → Security) and
confirm the 11 `rls_policy_always_true` warnings and the
`public_bucket_allows_listing` warning are gone.

## If something goes wrong mid-rollout

Steps 2-5 don't have to happen in the same sitting, but until step 4 (the
Dashboard integration) is turned on, `auth.jwt()->>'sub'` is null for every
request — meaning if you apply the new schema (step 5) *before* turning on
Third-Party Auth (step 4), every user, including yourself, gets locked out of
their own data until step 4 catches up. Do step 4 before step 5, or do them
in the same sitting.

To roll back entirely: re-run the previous version of `supabase_schema.sql`'s
policy section (`using (true) with check (true)`, no `firebase_uid` check),
or ask me to regenerate it — the git history in this repo also has the prior
version.
