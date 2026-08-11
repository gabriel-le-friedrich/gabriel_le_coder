# ASF Swine Finisher — Final Authentication & Backend Integration Audit

Every finding below is from reading the actual source in `flutter_app/` and the project root (`functions/`, `supabase_schema.sql`, `firebase.json`, `google-services.json`), not from trusting prior audit conclusions — several corrections to earlier reports are called out explicitly. Sandbox limitation, stated once here instead of on every line: **no Flutter/Dart toolchain, emulator, physical device, or Firebase/Supabase CLI session exists in this environment**, so nothing involving real SMS delivery, a live build, or a dashboard click-through could be executed — those are marked accordingly below, not glossed over.

## Correction to a previous report

My last report (the "ASF_BU2_FOLLOWUP_REPORT") said `FIREBASE_THIRDPARTY_AUTH_SETUP.md` didn't exist in the workspace and that there was no `functions/` directory. That was wrong — I had only searched inside `flutter_app/`. Both exist at the project root: `functions/index.js`, `functions/backfill-claims.js`, `functions/package.json`, and `FIREBASE_THIRDPARTY_AUTH_SETUP.md` are all present and correctly written (verified below). The underlying conclusion — that this app's RLS/Supabase auth doesn't work until you complete two manual steps outside this codebase — still stands; I was wrong about the doc's existence, not about the gap itself.

---

## 1. Firebase Authentication

| Item | Status | Detail |
|---|---|---|
| `Firebase.initializeApp()` | OK | Called at app startup before `initSupabase()`. |
| `firebase_core: ^3.6.0`, `firebase_auth: ^5.7.0` | OK | Current, compatible versions in `pubspec.yaml`. |
| `google-services.json` | **BUG — see below** | Present, correct `project_id`/`package_name`, but `oauth_client: []` is empty. |
| Android package name | OK | `applicationId = "ph.edu.psau.asf"` in `build.gradle.kts` matches `google-services.json`'s `package_name` exactly. |
| SHA-1 / SHA-256 | **BUG (confirmed)** | Not registered — see below. |
| Play Integrity | **Blocked by the above** | Firebase Phone Auth's silent/automatic device verification depends on the SHA-256 fingerprint being registered; without it, verification always falls back to reCAPTCHA (or fails). |
| reCAPTCHA fallback | Handled in code | `auth_error_mapper.dart` maps `missing-activity-for-recaptcha`, `captcha-check-failed`, `app-not-authorized`, `invalid-app-credential` — all the codes this exact gap produces. The code is ready for the fallback; the fallback just isn't configured to succeed yet. |
| SMS Region Policy (Philippines) | OK | `phone_utils.dart`'s `normalizePhilippineMobile()` only ever produces `+63` numbers; nothing in this app can dispatch to any other country code. |

### BUG — No SHA-1/SHA-256 fingerprint registered with this Firebase project
**Root cause (confirmed by reading the file):** `flutter_app/android/app/google-services.json`'s `client[0].oauth_client` array is `[]`. When you register a SHA-1/SHA-256 fingerprint in the Firebase Console, that console generates OAuth client entries that show up in this exact array the next time you download `google-services.json`. An empty array means **no fingerprint is currently registered for this app** in the live Firebase project, regardless of what any earlier session's task list says was done.
**Effect:** Firebase Phone Auth's Play Integrity–based silent verification cannot complete (it needs the signing certificate's SHA-256 to attest the app). Every phone verification will fall through to reCAPTCHA, which — depending on whether reCAPTCHA is itself configured for this Android package — may show a captcha challenge every time, or fail outright with `app-not-authorized`/`invalid-app-credential`.
**Severity:** High. This doesn't crash the app, but it can make phone OTP unreliable or completely broken on real devices, which is the core registration/login mechanism.
**Files requiring changes:** None in this repo — this is a Firebase Console configuration step, not a code bug.
**Fix (Firebase Console steps):**
1. Get your release keystore's fingerprints. From your machine (not this sandbox), in `flutter_app/android`:
   ```
   keytool -list -v -keystore app/asf-release.jks -alias asf-key
   ```
   (password is in `flutter_app/android/keystore.properties`, gitignored). Also run this against your **debug** keystore (`~/.android/debug.keystore`, password `android`) if you test debug builds on a device — Firebase needs a fingerprint for whichever keystore actually signs the APK you're testing/shipping.
2. Firebase Console → Project settings (gear icon) → your app (`ph.edu.psau.asf`, Android) → "Add fingerprint" → paste SHA-1, then again for SHA-256.
3. Re-download `google-services.json` from the same page and replace `flutter_app/android/app/google-services.json` with the new file — confirm `oauth_client` is no longer empty.
4. Rebuild.
**Verification method:** Confirmed by direct inspection of the JSON — this is a file-content fact, not a guess. Cannot verify the fix (a real registered fingerprint producing successful silent verification) without your Firebase Console access and a real device.
**Status:** Not Fixed — Needs Your Action (Firebase Console + a real keystore/device; not executable from this sandbox).

---

## 2 & 3. Registration and Login Flow

Traced end-to-end in `auth_repository.dart` and `auth_providers.dart`. Both match the required sequences exactly:

**Registration:** `submitRegister()` first checks `phoneNumberIsTaken()` and `getUidByEmail()` (both real Supabase lookups) and rejects duplicates *before* ever calling Firebase → `createEmailPasswordUser()` (creates the Firebase user, sends email verification, best-effort) → `state.step` is set to `otpSent` **before** `startPhoneVerification()` is even called (a deliberate fix for a router race condition, documented in the code and consistent with what an earlier session already found and fixed) → OTP screen → `submitVerify()` → `confirmLinkPhoneCredential()` calls `linkWithCredential()` (never `signInWithCredential()` — this is what prevents a duplicate Firebase user; the phone credential attaches to the *same* user created by the email/password step) → `_finishRegistration()` calls `createUserProfile()` (writes SQLite first, then a best-effort Supabase `profiles` upsert) → router's `authStateChangesProvider` redirect takes over navigation to Dashboard.

**Login (phone):** `submitLoginPhone()` checks `phoneNumberIsTaken()` first and returns "No account was found" if not — it will not send an OTP to an unregistered number → `startPhoneVerification()` → OTP screen → `submitVerify()` → `confirmSignInPhoneCredential()` calls the real `signInWithCredential()` (a genuine sign-in, not a link) → `_finishPhoneLogin()` stamps `lastLogin` and logs the event → Dashboard via the same router redirect.

**No duplicate Firebase users:** confirmed structurally — registration only ever creates one user (via email/password) and only ever *links* additional credentials to it; login only ever signs in to an existing user found by a prior lookup. Both auto-verification (Android SMS auto-retrieval, `onAutoVerified`/`_handleAutoVerifiedCredential`) and manual code entry funnel through the identical two branches.

**Status:** Fixed & Verified (by full manual trace of every call site — this is deterministic control flow, not something that needs a device to confirm logically, though a real device is still the only way to see the actual SMS/OTP round-trip happen).

---

## 4 & 5. OTP Verification and OTP UI

`phone_auth_service.dart` wraps `FirebaseAuth.verifyPhoneNumber()` in exactly one place, with all four official callbacks correctly wired (`verificationCompleted` → `onAutoVerified`, `verificationFailed` → `onFailed`, `codeSent` → `onCodeSent` with both `verificationId` and the resend token, `codeAutoRetrievalTimeout` → informational only). An `_inFlight` guard prevents a double-tap from firing two concurrent `verifyPhoneNumber()` calls.

`verify_otp_screen.dart` (315 lines, read in full) has: 6 individual digit boxes with auto-advance and backspace-to-previous, full 6-digit paste redistribution into all boxes from any box, `AutofillHints.oneTimeCode` wired for OS-level SMS-autofill suggestions, a 60-second resend cooldown with a live countdown, auto-submit the instant the 6th digit lands, a button-level loading spinner, a success checkmark animation plus snackbar, and both inline (under the boxes) and snackbar error display. Every one of these calls into the existing `AuthFlowController` — there's no second/parallel verification implementation to drift out of sync with the real one.

**Status:** Fixed & Verified by code trace. Actual SMS delivery/auto-retrieval behavior can only be confirmed on a real device with a Philippine SIM, which this sandbox doesn't have.

---

## 6. Philippine Phone Validation

`phone_utils.dart`'s `normalizePhilippineMobile()`: accepts `09XXXXXXXXX` (11 digits), `639XXXXXXXXX` (12 digits), or already-E.164 `+639XXXXXXXXX`; strips spaces/dashes/parentheses; rejects anything with a letter or other non-digit character, any prefix where the digit after the leading 0/country-code isn't `9` (i.e., non-mobile/landline numbers), and any wrong length. Read the full implementation, including the edge cases (bare "+" with no country code, 12-digit non-63 numbers, etc.) — all correctly rejected.

**Status:** Fixed & Verified by code trace.

---

## 7 & 14. Supabase Integration & Deployment Verification

This is the one area where the code is correct and complete, but **whether it's actually live depends on two manual steps outside this repository that I cannot verify or perform from this sandbox.**

**What's confirmed correct in code:**
- `supabase_config.dart`: `accessToken` callback returns the current Firebase ID token on every Supabase request.
- `auth_repository.dart`: `_forceRefreshIdTokenWithRetry()` forces a fresh ID token (with retry/backoff) before the first authenticated write after registration, specifically to close the race where a brand-new user's cached token predates their custom claim.
- `supabase_schema.sql`: every one of the 11 app tables plus `activity_logs` (insert/select split) plus both storage buckets' policies now check `firebase_uid = auth.jwt()->>'sub'` (confirmed by reading all ~30 `create policy` statements directly) instead of the old `using (true)` permissive policies.
- `functions/index.js`: a correctly-written Firebase Cloud Function (`functions.auth.user().onCreate()`, 1st-gen trigger) that stamps `role: authenticated` as a custom claim on every new user — exactly what Supabase's Firebase Third-Party Auth integration requires to grant the `authenticated` Postgres role instead of `anon`.
- `functions/backfill-claims.js` exists for one-time backfill of pre-existing users.
- `firebase.json` registers the `functions` source directory; `.firebaserc` exists, so `firebase deploy` has a target project.
- `FIREBASE_THIRDPARTY_AUTH_SETUP.md` at the project root is a complete, correct, step-by-step handoff doc for the manual half of this.

**What I cannot verify from this sandbox — no Firebase/Supabase CLI session, no dashboard access, no way to inspect a live deployment:**
1. Whether `stampAuthenticatedRoleClaim` has actually been deployed (`firebase deploy --only functions`).
2. Whether `backfill-claims.js` has actually been run against existing users.
3. Whether the Supabase Dashboard's Authentication → Third-Party Auth → Firebase integration has actually been turned on with this project's Firebase Project ID (`asf-app-2990c`).

**Until all three are done, `auth.jwt()->>'sub'` evaluates to `null` for every request**, which is exactly the "insert/select silently fails, nothing reaches Supabase, nothing is retrievable cross-device" symptom from earlier bug reports (A14/C11) — not a code defect, a deployment-state unknown.

### Exact steps required (condensed from `FIREBASE_THIRDPARTY_AUTH_SETUP.md` — see that file for full detail)
**Firebase Console:**
- Confirm the Blaze (pay-as-you-go) plan is active on project `asf-app-2990c` (Cloud Functions require it).

**Deployment commands (run from your own machine, logged into the Firebase CLI as an owner/editor of this project):**
```
cd functions
npm install
firebase deploy --only functions
```
```
# One-time backfill for users created before the function existed:
# Firebase Console → Project settings → Service accounts → Generate new private key
cd functions
GOOGLE_APPLICATION_CREDENTIALS="/path/to/that-key.json" node backfill-claims.js
```

**Supabase Dashboard:**
- Authentication → Sign In / Providers → Third-Party Auth → Add provider → Firebase → Project ID `asf-app-2990c` → Save.
- SQL Editor → New query → paste all of `supabase_schema.sql` → Run (idempotent, safe to re-run).

**Verification you can run yourself afterward** (from any machine, no Firebase token, only the public anon key):
```
curl "https://genxzsocmhgnxwwxjifz.supabase.co/rest/v1/profiles?select=*" \
  -H "apikey: <anon key>" -H "Authorization: Bearer <anon key>"
```
Before the fix is live: returns every user's rows. After: should return an empty array. Also re-run Supabase Dashboard → Advisors → Security and confirm the `rls_policy_always_true` (11 tables) and `public_bucket_allows_listing` warnings are gone.

**Status:** Fix Applied in code — Not Fixed / Needs Your Action for the three deployment steps above. I did not fabricate a "verified" status for something I have no way to check.

---

## 8. Cross-Device Synchronization

Read every repository's push AND pull paths (not just push) for all 8 requested categories. Two real, previously-undetected gaps found and fixed this round; everything else was already correct.

| Category | Push (Device → Cloud) | Pull (Cloud → fresh Device) | Status before this audit |
|---|---|---|---|
| Pigs | Yes (`pig_repository.dart`) | Yes (`pullRemoteChanges()`) | OK |
| Weekly photos | Yes (Storage + `weekly_pig_images`) | Yes (`pullRemoteChanges()`) | OK |
| Expenses | Yes | Yes (`pullFromCloudIfEmpty()`) | OK |
| Weight logs | Yes | Yes (`pullWeightLogsFromCloudIfEmpty()`) | OK |
| Health logs | Yes | Yes (`pullFromCloudIfEmpty()` equivalent) | OK |
| Profile | Yes | Yes (`getUserProfile()` falls back to Supabase when local is empty, plus a background refresh every read) | OK |
| **Notifications (prefs)** | Yes (`resyncPending()`) | **No — bug, now fixed** | Fresh device/reinstall silently got hardcoded defaults instead of the reminder schedule set on another device. |
| **Activity logs** | Yes (`pushUnsynced()`) | **No — bug, now fixed** | Fresh device/reinstall's Activity Log screen showed nothing from before, even though the history existed in Supabase. |
| Reports | N/A | N/A | **No feature exists.** `reports` is a defined-but-unused SQLite table (schema leftover); there's no `ReportsRepository`, no screen, nothing to sync. Not a bug — there's genuinely nothing built here to audit. Flagging so it isn't silently assumed covered. |

### BUG (fixed) — Activity Log history didn't sync to a new device
**Root cause:** `ActivityLogRepository` had `pushUnsynced()` but no pull method at all — confirmed by reading the entire file before this fix; only `getLogs()` (local-only read) and `pushUnsynced()` existed.
**Fix applied:** Added `pullFromCloudIfEmpty(uid)` — pulls every row from Supabase's `activity_logs` table into local SQLite, but only when the local `activityLogs` table is empty for that uid (so an existing device's own logs are never touched), keyed by the same `app_entry_id` the push path already uses so pulled rows land with their original ids. Wired into `SyncEngine.syncNow()` alongside the existing push.
**Files changed:** `flutter_app/lib/features/activity_log/data/activity_log_repository.dart`, `flutter_app/lib/core/services/sync_engine.dart`.
**Verification method:** Traced the new method against the exact column names `pushUnsynced()` already writes (`app_entry_id`, `action_type`, `description`, `action`, `status`, `created_at`) to confirm the read side maps back correctly. Not run against a live Supabase project from this sandbox.
**Status:** Fix Applied — Unverified at runtime.

### BUG (fixed) — Notification reminder schedule didn't sync to a new device
**Root cause:** `NotificationRepository.getPrefs()` read local SQLite only, falling back to `NotificationPrefs.defaults()` if empty — with no code path that ever consulted the Supabase `settings/notificationPrefs` mirror that `_savePrefs()`/`resyncPending()` were already writing to.
**Fix applied:** Added `pullFromCloudIfEmpty(uid)` — checks the local `settings/notificationPrefs` row, and if genuinely empty, pulls the Supabase mirror down, saves it locally as synced, and calls the existing `rescheduleAll()` so the device's actual scheduled local notifications immediately match the pulled prefs rather than whatever defaults may have already been scheduled at first launch. Wired into `SyncEngine.syncNow()`.
**Files changed:** `flutter_app/lib/features/notifications/data/notification_repository.dart`, `flutter_app/lib/core/services/sync_engine.dart`.
**Verification method:** Traced against the existing `_savePrefs()` write shape (`data`/`subkey: notificationPrefs`) to confirm the read side matches exactly.
**Status:** Fix Applied — Unverified at runtime.

---

## 9. Offline Sync (SQLite → Queue → Sync Engine → Supabase → Conflict Resolution → Remote Pull)

Re-read `sync_engine.dart` in full for this audit (not reused from memory). Three independent triggers call the same idempotent `syncNow(uid)`: Dashboard-open bootstrap, an offline→online connectivity-edge listener, and a 25-minute `Timer.periodic` (kept deliberately — see the C3 finding in the prior report; it's the only trigger that catches "stayed online, one write failed transiently, never revisited Dashboard"). `syncNow()` runs every repository's push/pull path concurrently via `Future.wait`, guarded by a `_running` flag so overlapping passes can't stack.

**Conflict resolution:** every synced table carries `deviceId`/`syncVersion`/`lastSyncedAt` columns (added in a prior schema migration, confirmed present in `sqlite_service.dart`'s schema and the v2→v3 migration block). Writes are last-write-wins via Supabase `upsert` keyed on a stable identifier (row id, or `firebase_uid`+`subkey` for aggregates) — there's no field-level merge, which is a reasonable, documented tradeoff for a single-farmer-per-account app, not an oversight.

**No data loss:** every write path is SQLite-first (local write always happens before any Supabase attempt), and every Supabase call is wrapped in try/catch with the local `synced` flag only ever flipped to 1 after Supabase actually confirms success — a failed network call never loses the local write, it just stays queued for the next `syncNow()` pass.

**Status:** Fixed & Verified by code trace (this is the same engine audited and built in prior sessions; re-verified fresh for this round rather than assumed correct).

---

## 10. Error Handling

`auth_error_mapper.dart` maps every Firebase Auth error code relevant to this app's flows, including every phone-auth-specific and Play-Integrity/reCAPTCHA-specific code the official docs list: `missing-activity-for-recaptcha`, `captcha-check-failed`, `app-not-authorized`, `missing-client-identifier`, `invalid-app-credential`, `operation-not-allowed`, `provider-already-linked`, `user-mismatch`, `timeout`, plus the standard set (`invalid-verification-code`, `code-expired`, `too-many-requests`, `quota-exceeded`, `network-request-failed`, `email-already-in-use`, `wrong-password`, etc.) — 25 codes total, each with a plain-language message, falling back to a generic "Something went wrong" for anything unmapped (never a raw exception shown to the user). Supabase-side failures are handled by the "never throw, never block the local write" pattern used identically across every repository.

**Status:** Fixed & Verified by code trace.

---

## 11. Android Release

`build.gradle.kts`: `applicationId` matches `google-services.json`'s package name exactly (verified — this is what makes the Google Services Gradle plugin not fail at build time). Signing config reads from a gitignored `keystore.properties`, falling back to debug signing if that file is missing (fails safe, doesn't break the build). `isMinifyEnabled`/`isShrinkResources` are both on for release, with `proguard-rules.pro` correctly keeping Firebase (`com.google.firebase.**`, `com.google.android.gms.**`), `flutter_local_notifications` (reflection-based activity/receiver lookup), and `sqflite` classes — the three plugin families that actually need explicit R8 keep rules in a Flutter app (Dart code itself isn't touched by R8 at all, so no other plugin needed one). `-dontwarn` rules correctly suppress the unused Play Core split-install classes Flutter references defensively.

**Status:** Fixed & Verified by code trace. Cannot confirm an actual release APK builds clean end-to-end without your Windows machine's Flutter toolchain.

---

## 12 & 13. Debug Logging / Real Device Testing

Not performed this round. Adding temporary debug logging and then removing it, and real-device SMS/Play-Integrity/cross-device testing, both require either editing+rebuilding+running on a physical device or at minimum an emulator with Google Play services — neither exists in this sandbox. If you want, I can add the requested temporary log lines (OTP requested, verification ID, code received, credential creation, Firebase UID, Supabase auth, SQLite save, remote sync, storage upload, sync completion, error codes) as an actual patch you apply, test, and then have me strip back out — say the word and I'll write it.

---

## Summary — deliverables checklist

1. **Every remaining bug** — see the two BUG sections above (SHA fingerprints missing; Activity Log + Notification prefs cross-device pull, now fixed in code) plus the Supabase deployment-status unknown (three manual steps).
2. **Root cause** — stated for each, from direct file inspection, not inference.
3. **Severity** — SHA fingerprints: High (breaks reliable phone verification). Cross-device sync gaps: Medium (data existed safely, just wasn't visible on other devices — now fixed). Supabase deployment status: High if still not deployed (RLS silently blocks all real access).
4. **Files requiring changes** — listed per bug above; two files actually changed this round (`activity_log_repository.dart`, `notification_repository.dart`, plus `sync_engine.dart` wiring both).
5. **Corrected code** — applied directly (see the two "Fix applied" sections); SHA fingerprint fix is a console action, not code.
6. **Firebase Console changes** — SHA-1/SHA-256 registration steps above; Blaze plan confirmation for Cloud Functions.
7. **Supabase Dashboard changes** — Third-Party Auth provider registration, re-running `supabase_schema.sql`.
8. **Google Cloud Console changes** — none identified as outstanding; Play Integrity here rides on the Firebase-registered fingerprint, no separate GCP API console step was found missing.
9. **Deployment commands** — `firebase deploy --only functions`, the backfill script invocation, both given above.
10. **Verification checklist** — the `curl` anon-key probe and Security Advisor re-check above; a full `flutter clean/pub get/analyze/test/build apk --release` pass still owed on your machine.
11. **Confirmations, stated honestly rather than assumed:**
    - Phone OTP works on a real Android device: **cannot confirm** — no device in this sandbox, and the SHA-fingerprint gap means it may not work reliably until that's fixed.
    - Registration and login are fully functional: **code-verified correct by trace**, not device-verified.
    - Supabase sync works across devices: **code-verified correct for 6 of 8 categories, two gaps just fixed in code (unverified at runtime), one category (Reports) doesn't exist as a feature** — and all of it depends on the three pending Supabase/Firebase deployment steps actually being done.
    - No duplicate Firebase users are created: **verified by code trace** (registration only links, never creates a second user).
    - The app is production-ready: **not yet** — blocked on the SHA fingerprint registration and confirming the Supabase Third-Party Auth deployment steps, both of which require your own Firebase/Supabase account access that isn't available here.
