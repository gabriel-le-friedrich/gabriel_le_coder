# Supabase Setup — Generated SQL + Manual Checklist

Your Supabase project: `https://genxzsocmhgnxwwxjifz.supabase.co`

You asked for **proper `firebase_uid`-based RLS** rather than the doc's
permissive fallback. That requires Supabase's real Firebase Auth
integration (not just an anon key + app-level filtering) — Supabase can
verify actual Firebase ID tokens and expose the Firebase uid to Postgres
as `auth.jwt()->>'sub'`. `supabase_schema.sql` (generated alongside this
file) is built entirely around that. Here's what that requires end to end.

## What I generated for you

**`supabase_schema.sql`** — paste into Supabase Dashboard → **SQL Editor**
→ Run. Creates:
- `profiles`, `pigs`, `feeding_logs`, `weight_records`, `health_records` —
  each with a `firebase_uid text` column
- RLS enabled on all 5, with real per-user policies (`firebase_uid =
  auth.jwt()->>'sub'`) for select/insert/update/delete
- Storage policies for a `pig-photos` bucket, scoped by a
  `<firebase_uid>/filename.jpg` folder-per-user path convention

## Manual steps — in order

### 1. Supabase Dashboard: turn on the Firebase integration
Authentication → **Third-Party Auth** → Add integration → paste your
**Firebase Project ID** (Firebase Console → Project Settings → General).
Without this step, `auth.jwt()->>'sub'` in the SQL above will always be
null and every RLS policy will silently deny access.

### 2. Run `supabase_schema.sql`
SQL Editor → New query → paste the whole file → Run. Safe to re-run.

### 3. Create the Storage bucket
Storage → New bucket → name it `pig-photos` → **Private** (not Public —
the RLS policies already generated only make sense for a private bucket;
a public bucket has no access control at all, which would defeat the
point of the folder-per-user RLS policies above).

### 4. Give every Firebase user the `authenticated` role claim
This is the part Supabase's own docs call out as required: by default a
Firebase ID token has no `role` claim, so Supabase falls back to the
`anon` Postgres role — meaning every RLS policy above (`to authenticated`)
would reject the request even with a valid, correctly-scoped token. Two
pieces of code, both need deploying from your machine (real Firebase CLI
+ credentials, which this sandbox doesn't have access to):

**a) Blocking Cloud Function — covers every future sign-up/sign-in.**
Requires Firebase's **Blaze (pay-as-you-go)** plan — Cloud Functions
can't deploy on the free Spark plan, though the free monthly quota
comfortably covers a capstone-scale app.

```js
// functions/index.js (or add to your existing functions file)
import { beforeUserCreated, beforeUserSignedIn } from 'firebase-functions/v2/identity';

export const beforecreated = beforeUserCreated((event) => ({
  customClaims: { role: 'authenticated' },
}));

export const beforesignedin = beforeUserSignedIn((event) => ({
  customClaims: { role: 'authenticated' },
}));
```
Deploy with: `firebase deploy --only functions`

**b) One-time backfill — covers every account that already exists.**
Run once, locally, with a Firebase service account key (Project Settings
→ Service Accounts → Generate new private key):

```js
// backfill-role-claim.mjs — run once with: node backfill-role-claim.mjs
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import serviceAccount from './serviceAccountKey.json' with { type: 'json' };

initializeApp({ credential: cert(serviceAccount) });

async function setRoleCustomClaim() {
  let nextPageToken;
  do {
    const { users, pageToken } = await getAuth().listUsers(1000, nextPageToken);
    nextPageToken = pageToken;
    await Promise.all(users.map(async (u) => {
      try { await getAuth().setCustomUserClaims(u.uid, { role: 'authenticated' }); }
      catch (e) { console.error('Failed for', u.uid, e); }
    }));
  } while (nextPageToken);
}
setRoleCustomClaim().then(() => { console.log('Done.'); process.exit(0); });
```
Existing signed-in users won't see the new claim until they get a fresh
ID token — have them sign out/in once, or force a refresh with
`getIdToken(/* forceRefresh */ true)`.

### 5. When you're ready to wire the app to Supabase
The Supabase client needs to send the real Firebase ID token on every
request — not just the anon key — or `auth.jwt()->>'sub'` has nothing to
read:

```js
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://genxzsocmhgnxwwxjifz.supabase.co',
  'YOUR_SUPABASE_ANON_KEY',
  {
    accessToken: async () =>
      (await firebase.auth().currentUser?.getIdToken(false)) ?? null,
  }
);
```
I haven't touched the ASF app's code for this — the app currently runs on
its own Firestore + SQLite offline-sync layer (finished earlier this
session), and adding Supabase as a second data store is a separate
architectural decision. Say the word if/when you want it actually wired
into the app, and which of the 5 tables should be the real source of
truth vs. Firestore.

## Checklist

- [ ] Firebase integration added under Supabase → Third-Party Auth
- [ ] `supabase_schema.sql` run in the SQL Editor
- [ ] `pig-photos` bucket created, set to Private
- [ ] Blocking Cloud Function deployed (`role: 'authenticated'` claim on
      every new sign-up/sign-in) — needs Blaze plan
- [ ] One-time backfill script run for existing users
- [ ] Supabase anon key retrieved and saved somewhere accessible for code
- [ ] Decided which data (Firestore vs. Supabase) is authoritative for
      which table, if the app is going to write to both
