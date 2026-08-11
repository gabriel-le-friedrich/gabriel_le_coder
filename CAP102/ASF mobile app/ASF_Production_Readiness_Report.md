# ASF Swine Finisher — Production Readiness Report

**Date:** 2026-07-31 (updated same day — follow-up pass addressing the punch list from your review)
**Scope:** `flutter_app` (Flutter/Riverpod/GoRouter, SQLite offline-first, Supabase Postgres+Storage, Firebase Auth)
**Supabase project:** `genxzsocmhgnxwwxjifz` (ASF-APP, org CAP102 - ASF)
**Firebase project:** `asf-app-2990c`

This report covers everything actually inspected, changed, and verified this session, honestly separating what's confirmed from what still needs your own device testing. **This is not a declaration of PRODUCTION READY** — the required gate (end-to-end validation on a physical device or emulator) has not been run in this sandboxed environment. See "What's left" and §13 for the concrete 3-device test script.

> **Update log:** After the original report below (§1–§10), you reviewed it and asked for five fixes plus two documentation additions before calling this Production Ready. All five fixes are now done and verified (see §11 "Follow-up fixes"); the two documentation additions are §12 (Backup Strategy) and §13 (3-device QA script). Sections 1–10 are left as originally written for the audit trail; §11 supersedes the now-stale findings in §7/§8 where noted.

---

## 1. Files modified this session

| File | Change |
|---|---|
| `supabase_schema.sql` | RLS rewritten from `using(true)` to `firebase_uid = auth.jwt()->>'sub'` on all 12 tables; storage policies scoped to the caller's own uid folder; header comment rewritten to document the Third-Party-Auth identity model |
| `flutter_app/lib/core/config/supabase_config.dart` | Added `accessToken` callback passing the live Firebase ID token to Supabase on every request |
| `flutter_app/lib/features/auth/data/auth_repository.dart` | Added `_forceRefreshIdTokenWithRetry()`, called before the first post-signup Supabase write |
| `functions/index.js`, `functions/backfill-claims.js`, `functions/package.json`, `functions/.gitignore` | New Cloud Functions project (not yet deployed — see §6) |
| `firebase.json` | Registered `functions` source directory |
| `FIREBASE_THIRDPARTY_AUTH_SETUP.md` | Handoff doc for the remaining manual steps (Blaze upgrade, function deploy, backfill) |
| `backups/2026-07-31_pre-thirdpartyauth_live_state.md` | Pre-change snapshot of live Supabase/Firebase state, for rollback reference |

No SQLite schema, Riverpod providers, routing, or business logic were touched — the changes are isolated to the auth/identity layer.

## 2. SQL executed against production

One statement batch (see `supabase_schema.sql`, 419 lines of executable SQL after stripping comments), applied via the Supabase SQL Editor on 2026-07-31. Idempotent throughout (`if not exists` / `drop policy if exists`). Result: **"Success. No rows returned."** No errors.

## 3. Firebase changes

- **Third-Party Auth:** Firebase registered as a Supabase auth provider (Project ID `asf-app-2990c`) — confirmed enabled in the dashboard.
- **Cloud Functions:** written but **not deployed** — deploying requires the Blaze (pay-as-you-go) plan, which requires you to add a payment method yourself. You chose to defer this. The app works today without it; the only effect is that a brand-new signup's `role: authenticated` claim isn't auto-stamped by a function (the client-side force-refresh-with-retry covers most cases, but isn't as reliable as the function once it exists).
- **SHA certificate fingerprints:** still none registered on the Android app — phone auth falls back to reCAPTCHA instead of silent Play Integrity verification. Not fixed (a keytool automation attempt hung; recommend adding manually via Firebase Console → Project Settings → Android app → Add fingerprint).

## 4. Supabase changes

- **Tables:** `activity_logs` and `app_releases` created (previously missing live). Table count went from 11 → 13.
- **RLS:** all 12 previously-permissive (`using(true)`) policies replaced with `firebase_uid = auth.jwt()->>'sub'` (verified via live `pg_policies` query — `qual` now reads `(firebase_uid = (auth.jwt() ->> 'sub'::text))` for every row except `app_releases`, which is intentionally public-read since it holds no user data).
- **Storage:** `profile-photos` bucket created (was missing — every profile-photo upload was silently failing against production before this). Both `pig-photos` and `profile-photos` insert/update policies now require the object path's first folder segment to equal the caller's own Firebase uid, closing the "any signed-in caller can overwrite another user's file" gap. Broad list/enumerate policies removed.
- **Security Advisor:** re-run after the change — **0 errors, 0 warnings, 0 info suggestions.** (Previously: 11× `rls_policy_always_true` + 1× public bucket listing warning.)

## 5. Storage policy changes

| Bucket | Before | After |
|---|---|---|
| `pig-photos` | `for all using (bucket_id='pig-photos')` — any caller, including listing | insert/update only, scoped to `(storage.foldername(name))[1] = auth.jwt()->>'sub'` |
| `profile-photos` | didn't exist | created; same folder-scoped insert/update policy |

Reads are unaffected either way — the app only ever calls `getPublicUrl()` (bypasses Storage RLS via the public bucket's unauthenticated read path), never `.list()`/`.download()`.

## 6. Flutter changes + tests executed

Ran in the sandbox this session (`flutter_phase9_verify_log.txt`):

- `flutter pub get` — succeeded, 57 packages have newer versions available (non-blocking).
- `flutter analyze` — 1 pre-existing, unrelated info-level notice (`anonKey` deprecated in `supabase_flutter`). No errors.
- `flutter test` — **99/99 passed.**
- `flutter build apk --release --split-per-abi` — succeeded: `app-armeabi-v7a-release.apk` (21.2MB), `app-arm64-v8a-release.apk` (23.2MB), `app-x86_64-release.apk` (24.6MB).

## 7. Root cause / impact / fix — for every non-trivial finding

| Finding | Root cause | Impact | Fix | Verified by |
|---|---|---|---|---|
| 11× RLS always-true | Policies used `using(true)` — Postgres had no way to check *who* was asking | Any holder of the public anon key could read/write every user's rows via the REST API directly (bypassing the app entirely) | Firebase-as-Supabase-Third-Party-Auth + `firebase_uid = auth.jwt()->>'sub'` policies | Live `pg_policies` query + Security Advisor 0 warnings |
| Storage listing warning | `pig_photos_all` policy covered SELECT too, permitting `.storage.from('pig-photos').list()` to enumerate every file path | Anyone with the anon key could enumerate all uploaded file paths (not the images themselves, but their existence/naming) | Dropped the broad policy; insert/update only, folder-scoped | Security Advisor 0 warnings |
| `profile-photos` bucket missing | Never created in an earlier schema pass | Every profile-photo upload has been failing silently in production until now | Bucket created via schema apply | Live `storage.buckets` query shows both buckets |
| Notifications module has zero `tr()` calls | Localization work was scoped to Settings/Health only; Notifications screen was built before/separately | Notification Settings screen (titles, dialogs, reminder descriptions) stays English-only when the user switches to Filipino | Not fixed this session — needs the same `tr()` wiring pattern already used in Feeding/Expenses | Code audit (grep for `tr(` in `lib/features/notifications` returns 0 matches) |
| One hardcoded string in Dashboard | `Text('Next $title', ...)` at `dashboard_screen.dart:269` was written as a literal instead of via `tr()`, despite the sibling line 262 using `tr()` correctly | Minor: one label on the Dashboard won't localize | Same fix pattern, one line | Code audit |
| Pending pig/image resync is one-row-per-request | `resyncPendingPigs`/`resyncPendingImages` loop and call `.upsert()` per row instead of batching | After an extended offline period with many pending changes, sync takes more round-trips and more battery/network than necessary — functionally correct, just not optimal at scale | Batch the upsert call with an array of rows in one request | Code audit (`pig_repository.dart:369-395`, `:300-324`) |
| SHA fingerprint not registered | Automation attempt hung; not retried manually | Phone-auth OTP falls back to reCAPTCHA verification instead of silent Play Integrity | Add manually via Firebase Console (2-minute task, needs your keystore password) | Confirmed via empty `oauth_client` in `google-services.json` + Console UI |

## 8. Final acceptance checklist

| Category | Status | Notes |
|---|---|---|
| Authentication | ✅ PASS (code+config) / ⚠️ device test pending | Third-Party Auth wired and verified server-side; OTP/email flows unchanged; SHA fingerprint gap noted above |
| Profile | ⚠️ PARTIAL | Sync path code-verified; cross-device round-trip not device-tested this session |
| Dashboard | ⚠️ PARTIAL | Builds/tests clean; one hardcoded string noted above |
| Pig Management | ✅ PASS (code) | CRUD + sync logic unchanged and covered by existing tests |
| Health Monitor | ✅ PASS | Fully translated, has its own coverage test + widget test proving reactive language switch |
| Weekly Weight | ✅ PASS (code) | Week-lock logic unchanged from earlier verified state; no regressions in `flutter test` |
| Weekly Photos | ✅ PASS (code) | Same — logic untouched this session |
| Growth | ✅ PASS (code) | Untouched, tests pass |
| Expenses | ✅ PASS (code) | Untouched, tests pass |
| ROI | ✅ PASS (code) | Untouched, tests pass |
| Notifications | ❌ FAIL (translations) / ✅ PASS (scheduling logic) | Duplicate-prevention, boot-receiver, and reconnect-reschedule all present and correct; translation gap listed above |
| Offline Mode | ✅ PASS (code) | SQLite remains source of truth; unaffected by this session's changes |
| Synchronization | ⚠️ PARTIAL | Push-to-Supabase path confirmed working (schema/RLS now correct); batching inefficiency noted; no live two-device test run |
| SQLite | ✅ PASS (code) | Indexes match actual query patterns (`uid`-based lookups); date/pig_id filtering happens in-memory on JSON blobs by design, not a defect at current scale |
| Supabase | ✅ PASS | 13 tables, correct RLS, 0 Security Advisor findings |
| Firebase | ⚠️ PARTIAL | Auth registered and working; Cloud Functions deferred by your choice; SHA fingerprint gap open |
| Storage | ✅ PASS | Both buckets present, folder-scoped, no listing exposure |
| Security | ✅ PASS | 0 errors / 0 warnings / 0 info on Security Advisor after the fix |
| Translations | ❌ FAIL | Notifications module untranslated; Dashboard has one hardcoded string; only Health Monitor has a formal coverage test |
| Performance | ⚠️ PARTIAL | Indexes correct; sync batching is the one concrete inefficiency found |

## 9. What's left (needs your own device/emulator)

These fundamentally require a physical Android device or emulator with two live Firebase accounts — not something drivable from this sandbox:

1. **Two-account isolation test:** Account A creates pigs/expenses/health logs/photos; confirm Account B cannot see them; confirm Account A still syncs across two of their own devices.
2. **Runtime pass:** registration → OTP → login → logout → every screen → offline mode → reconnect.
3. **Notification firing:** confirm reminders actually fire at scheduled times, survive a reboot, and don't duplicate after a reconnect.

I can write you a concrete step-by-step test script for these whenever you'd like.

## 10. Rollback instructions

- **RLS/schema:** re-run the pre-change policy SQL (`for all using (true) with check (true)`) captured in `backups/2026-07-31_pre-thirdpartyauth_live_state.md` and in git history of `supabase_schema.sql`.
- **Storage buckets:** `profile-photos` can be dropped via the Supabase dashboard if you want to fully revert (not recommended — it was a missing feature, not a regression).
- **Flutter/Firebase client changes:** `git revert` on `supabase_config.dart` and `auth_repository.dart` restores the pre-session behavior (anon-key-only access).
- **Cloud Functions:** never deployed, so nothing to roll back there.

## 11. Follow-up fixes (this pass) — resolves your five punch-list items

| # | Item | What changed | Files | Verified by |
|---|---|---|---|---|
| 1 | Notification translations | Notifications module now fully wired to `tr()`. Added `reminderTitle()`/`reminderDescription()`/`reminderTranslationCoverageGaps()` to `settings_strings.dart` as a display-layer-only lookup (same pattern as Health Monitor's `healthOptionLabel()`) — the canonical `ReminderTypeDef.title`/`.description` fields stay untouched because `local_notification_service.dart` schedules the OS notification's actual title/body directly from those fields at schedule-time; translating them there would silently break already-scheduled notifications. Every string in `notification_settings_screen.dart` (AppBar title, discard-changes dialog, master switch, reset-to-defaults dialog, error/retry state, save button, each reminder card's title/description) now reads through `tr()`/`reminderTitle()`/`reminderDescription()`. | `settings_strings.dart`, `notification_settings_screen.dart` | New `test/notification_translation_test.dart` (mirrors `health_translation_test.dart`): asserts zero coverage gaps across all 9 reminder types and that every screen-chrome key resolves in both languages. `flutter test` 106/106 passing. |
| 2 | Dashboard hardcoded string | `Text('Next $title', ...)` → `Text('${tr(lang, 'nextReminderPrefix')} $title', ...)`. Added `nextReminderPrefix` key (`'Next'` / `'Susunod'`). | `dashboard_screen.dart` | `flutter test` (dashboard responsive suite unaffected), code re-read post-edit. |
| 3 | Batch synchronization | `resyncPendingPigs()` and `resyncPendingImages()` in `pig_repository.dart` now build the full pending-rows payload first and push it in one batched `upsert(list)` call, mirroring `ActivityLogRepository.pushUnsynced()`'s pattern, instead of one request per row. Image uploads to Storage still happen per-file (Supabase Storage has no bulk-binary endpoint) — only the `weekly_pig_images` **table** mirror is batched. Preserved the existing "one bad row never blocks the rest" guarantee: if the batch itself fails (offline, RLS, one row rejected), both methods fall back to per-row upserts so a single bad row can't strand every other row unsynced. **Profile sync was investigated but left unchanged** — a user has exactly one `profiles` row, so `updateProfileFields`/`updateProfileImage`/`resyncPendingAvatar` are inherently single-row operations with nothing to batch; there was no gap there. | `pig_repository.dart` | Re-read the full diff; `flutter analyze` clean, `flutter test` 106/106. |
| 4 | SHA-1 / SHA-256 fingerprints | Extracted both fingerprints from the release keystore (`keytool -list -v` against `asf-release.jks`, alias `asf-key`) and registered both in Firebase Console → Project Settings → Android app (`ph.edu.psau.asf`). SHA-1: `62:63:00:17:4B:4E:63:1B:DF:72:52:63:74:F3:E5:41:B9:5E:BD:12`. SHA-256: `F1:64:DC:DA:AD:E1:AB:66:5F:91:68:6E:C8:C9:79:8A:D6:2D:32:9E:6A:9C:C0:52:92:BA:CD:69:48:2A:53:89`. Phone-auth OTP can now use Play Integrity's silent verification instead of falling back to reCAPTCHA. | Firebase Console (no source file change) | Screenshot-confirmed both fingerprints listed under the Android app with correct SHA-1/SHA-256 type labels. |
| 5 | Cloud Functions deployment | Left deliberately deferred — this is gated behind you upgrading the Firebase project to the Blaze (pay-as-you-go) plan, which requires you to add a billing method yourself. Not something I can or should do on your behalf. Once you've upgraded, deploy with `firebase deploy --only functions` from the project root and confirm via `firebase functions:log` that the `role: authenticated` claim gets stamped on new signups. | — | Not applicable until you upgrade billing. |

A full re-verification build was run after items 1–3 (source changes): `flutter analyze` → 4 pre-existing info-level notices only (0 errors — this run also caught and fixed a duplicate-const-map-key bug the notification translation edit had introduced, which was breaking compilation; now clean). `flutter test` → **106/106 passing.**

This resolves §7/§8's "Notifications ❌ FAIL (translations)" and "Translations ❌ FAIL" rows to PASS, "Synchronization ⚠️ PARTIAL" (batching) to PASS, and "Firebase ⚠️ PARTIAL" (SHA fingerprint) to PASS. The only remaining open item from your punch list is physical-device end-to-end validation (§13) and, if you choose to use it, Cloud Functions deployment once you're on Blaze.

## 12. Production Backup Strategy

Recommended backup cadence and pre-migration checklist, per your request to document this before calling the project Production Ready.

**Automated backups**
- **Daily — Supabase automatic backups.** Supabase's own point-in-time/daily backup feature (Project Settings → Database → Backups in the dashboard) should be enabled/confirmed active. This covers accidental data loss between manual exports and is the primary safety net for the live database.
- **Weekly — manual SQL export.** Export the full schema + data via the dashboard's "Database → Backups → Download" or `pg_dump` against the connection string, saved outside the repo (e.g. a dated file in a `backups/` folder, as already established this session with `2026-07-31_pre-thirdpartyauth_live_state.md`). Keep at least the last 4 weekly exports.
- **Monthly — Storage backup.** Both `pig-photos` and `profile-photos` buckets should be mirrored to a separate location (e.g. downloaded via the Supabase dashboard's storage browser, or scripted with the Storage API) since Supabase's database backups do not include Storage objects.

**Pre-migration checklist** (run before any schema change, RLS change, or destructive SQL against production — same discipline already used for this session's Third-Party-Auth migration):
1. **Export schema** — `supabase_schema.sql` in the repo should already reflect the intended end state; additionally pull the *live* schema (`pg_dump --schema-only` or the dashboard's schema view) so there's a snapshot of what's actually running, not just what's intended.
2. **Export policies** — a live `pg_policies` query result saved to a dated file (as done in `backups/2026-07-31_pre-thirdpartyauth_live_state.md`), so any RLS regression can be diffed against a known-good state.
3. **Export storage rules** — the current bucket policies (insert/update/select rules per bucket), since these aren't part of a standard schema dump.
4. **Create a rollback point** — a dated markdown file (matching the existing `backups/` convention) recording: table count, policy count and their `qual` expressions, storage bucket list, and any other live-state facts that would be needed to manually revert if the migration goes wrong. This is exactly the pattern already used before this session's RLS rewrite, and should be repeated before every future production change.

None of this is automated yet — it's a documented manual process for now. If you'd like, a future pass could script the weekly/monthly export steps (e.g. a small Node or Python script using the Supabase Management API) so they're one command instead of a manual dashboard trip.

## 13. Final QA Checklist — 3-device end-to-end test script

This is the concrete test you described; it requires two physical Android devices/emulators (or one device plus one emulator) and two separate Firebase accounts, and cannot be run from this sandbox. Recommended sequence:

**Device A — Account 1 (create everything)**
1. Register → verify OTP → land on Dashboard.
2. Create a Profile (name, municipality, farm details, profile photo).
3. Add a Pig (breed, gender, birth date, initial weight, pen number).
4. Add a Weekly Weigh-in for that pig.
5. Upload a Weekly Photo for that pig.
6. Add an Expense entry.
7. Add a Health Monitor record.
8. Confirm each save shows a success state and appears in its respective list before moving on.

**Device B — same Account 1 (verify sync down)**
1. Log in with the same account on a second device.
2. Confirm Profile, Pig, Weight entry, Health record, Expense, and the Weekly Photo all appear — this proves the cloud→local pull path (`pullPigsFromCloudIfEmpty` and equivalents) works, not just the local→cloud push path already covered by existing tests.

**Device C — Account 2 (verify isolation)**
1. Register a brand-new, different account on a third device (or log out/back in with a different account on Device A/B).
2. Confirm this account sees **none** of Account 1's data: no pigs, no profile fields, no expenses, no health records, no weekly photos.
3. This is the test that directly proves the RLS fix (`firebase_uid = auth.jwt()->>'sub'`) is doing its job in practice, not just in the Security Advisor's static analysis.

If all of the above pass, the RLS and synchronization work is verified end-to-end, matching your own stated criterion: *"If all of these pass, your RLS and synchronization are working correctly."* Combine this with a plain runtime pass (registration → OTP → login → logout → every screen → offline mode → reconnect) and a check that scheduled notifications actually fire, survive a reboot, and don't duplicate after reconnecting, and every item on your Final Verdict list is covered.

## Final result

**Code-complete and verified in the sandbox; still not yet formally ✅ PRODUCTION READY by your own stated criteria** — every fix you asked for (notification translations, the Dashboard string, batch sync, SHA fingerprints) is done and passing `flutter analyze`/`flutter test` (106/106), and the Backup Strategy is now documented (§12). The remaining gate, entirely by design, is the one only you can run: the 3-device physical/emulator end-to-end test in §13, plus Cloud Functions deployment if and when you upgrade to Blaze. Once §13 passes, this meets your own bar for ✅ PRODUCTION READY.
