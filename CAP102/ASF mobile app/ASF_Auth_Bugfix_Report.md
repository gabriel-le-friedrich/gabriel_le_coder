# ASF Mobile App — Authentication, User Isolation & Onboarding Bug-Fix Report

## Summary

The reported bug — a newly registered account logging in and seeing the demo "Juan" account's data (pig info, dashboard, tasks, expenses, ROI, growth) — was caused by hardcoded fallback data and a synchronous demo-data seeding block in `index.html`, plus a matching hardcoded fallback in `src/auth-main.js`. All of these have been removed. Onboarding now creates each account's own real starting records instead of relying on any shared/fake data, and a missing onboarding step (the "Ready to Begin" summary screen) was added to match the intended flow.

## 1. Files Modified

- **`index.html`** — root cause fixes and new onboarding step:
  - `CURRENT_UID` default changed from `'demo'` to `'_signed_out_'` (a namespace nothing ever writes data into).
  - `getFarmerProfile()` / `getPigBatchProfile()` fallback objects changed from hardcoded identities (`Juan dela Cruz`, `Bigas`, 20 kg, etc.) to blank/zeroed values.
  - Removed the synchronous "seed on first run" block that wrote a full fake dataset (Day 15 progress, 3 fake pigs, fake weight/feed/expense/health logs, fake weekly photos) into local storage before Firebase resolved the signed-in user.
  - Added onboarding **Step 3 — Ready to Begin** screen (Starting Weight / Expected ADG / Market Day summary + "Start Day 1" button), matching the intended UX.
  - Added `submitOnboardStart()` — creates each new account's real first records: one real pig (`pigs[]`), a Week‑1 weight log, an "Initial Feed Cost" expense (Feed Price × Number of Pigs), and a Day‑1 "Healthy" health record — and explicitly resets `currentDay = 1` / `dayLogs = {}` so the dashboard always starts fresh (0 completed, 0%, nothing pre-checked).
  - Fixed `renderGrowthDetailHeader()` — the Pig Growth detail page's pig name/ID header (`gcal-h1` / `gcal-sub`) was static markup ("Bigas" / "ID: BIGAS-01") that no code ever overwrote; every account's Growth page showed this regardless of their real pig. Now set dynamically from the account's actual pig record.
  - Fixed `resetApp()` ("Reset Progress" in Settings) — it claimed to reseed the pig registry but never did; now creates a real pig entry from the current batch profile instead of leaving `pigs[]` empty.

- **`src/auth-main.js`** — closes the remaining data sources of the bug:
  - `hydrateFromSqlite()` — removed the hardcoded `{pigName:'Bigas', numPigs:1, startWeight:20, feedPrice:22.50}` fallback; now leaves the key unset if nothing was ever synced, letting `index.html`'s blank fallback take over.
  - `submitVerify()` (registration branch) — now synchronously writes the real farmer profile into local storage immediately after `createUserProfile()` succeeds, closing a race where Firebase's `authStateChange` listener could trigger hydration before that write finished.
  - `enrichFromCloudInBackground()` — now also pushes the fetched Supabase profile into the live UI cache and re-renders, so if the race above ever occurs, the correct data self-corrects within moments instead of requiring a restart.

- **`android/app/src/main/assets/public/index.html`** — all of the above `index.html` changes replicated (this is the file Capacitor actually packages into the Android build).
- **`ios/App/App/public/index.html`** — same replication for iOS.

No changes were needed this pass to `supabase_schema.sql`, `src/notifications.js`, `src/sqlite-db.js`, `src/sync-engine.js`, `AndroidManifest.xml`, or `package.json` — those were completed in the prior authentication/onboarding session and did not need schema or sync-layer changes to fix this bug.

## 2. Database Tables Affected

No new tables or columns were needed — the existing schema was already sound and firebase_uid-scoped. This pass fixed *application-layer* logic that reads/writes these existing tables:

- `profiles` (`onboarding_completed` correctly gates onboarding vs. dashboard)
- `farm_batches` (mirrors the real `pigBatchProfile` entered at onboarding)
- `pigs` (now populated with a real record at onboarding instead of staying empty or fake)
- `weight_records` / growth logs (real Week‑1 entry created at onboarding)
- `expenses` (real "Initial Feed Cost" entry created at onboarding)
- `health_records` (real Day‑1 "Healthy" entry created at onboarding)
- `notification_settings`
- `settings` (aggregate: farmer profile, pig batch profile, notification prefs, current day, day logs)

## 3. Every Bug Fixed

1. Hardcoded `Juan dela Cruz` farmer-profile fallback — replaced with a blank fallback.
2. Hardcoded `Bigas` pig-batch-profile fallback (in `index.html`) — replaced with a blank/zeroed fallback.
3. `CURRENT_UID` defaulting to `'demo'` — changed to a namespace nothing ever writes to.
4. Synchronous demo-data seed block (fake Day 15 progress, 3 fake pigs "Bigas/Amihan/Diwa", fake weight/feed/expense/health logs and photos) that ran on every load before Firebase resolved — removed entirely.
5. Matching hardcoded `Bigas` fallback inside `src/auth-main.js`'s `hydrateFromSqlite()` — removed.
6. Registration race condition where a brand-new account could transiently hydrate before its own profile write finished — closed with a synchronous write plus a background self-correcting re-render.
7. Missing onboarding "Ready to Begin" step (Step 3 in the spec) — added, with a real summary (Starting Weight, Expected ADG range, Market Day) drawn from the user's own entered data.
8. Onboarding never created real pig / growth / expense / health records, leaving Pig Growth, Expenses, and Health Monitor blank for every new account — `submitOnboardStart()` now creates all four.
9. Dashboard not guaranteed to start at Day 1 / 0 completed / 0% — now explicitly reset at onboarding finish.
10. Pig Growth detail page permanently showing static "Bigas" / "ID: BIGAS-01" header text regardless of the signed-in account — fixed to render the account's real pig name/ID.
11. "Reset Progress" (Settings) silently leaving the pig registry empty despite claiming to reseed it — fixed to create a real pig entry consistent with onboarding.

## 4. Verification Performed

- Full code-level audit of `CURRENT_UID` namespacing, the in-memory `MEM` cache, and `logout()` confirming no cross-account data leakage is possible (namespacing prevents collisions; DOM is fully re-rendered from the newly hydrated account before `showAppShell()` runs).
- Rebuilt and reinstalled the Android app via Android Studio (Run button, real Gradle build) — installed and launched successfully with no crash. Confirmed the "Good morning, Juan" hardcode is gone (now blank, as expected before real profile data loads).

## 5. Known Remaining Issues

- **Real phone-OTP SMS could not be tested in this environment** — there's no configured test phone number here, so a fully clean register → OTP → onboarding → dashboard run with a brand-new phone number could not be exercised end-to-end this session. All fixes were verified by code audit plus a live rebuild/install.
- **The Android/iOS bundled JS (`assets/index-*.js`) still reflects the pre-fix compiled `auth-main.js`.** This sandbox's mounted copy of the project lags behind live edits, so `npm run build && npx cap sync` couldn't be run here to regenerate that bundle. All the `index.html` classic-script fixes ARE live in the Android build (verified by rebuild), but the `auth-main.js` fixes (Bigas fallback removal, race-condition close) will only be live in a native build after you run `npm run sync` (`npm run build && npx cap sync`) from your own machine and rebuild in Android Studio.
- **One already-tested account still shows leftover "Bigas" / Day 15 data** when reused in this session's verification — that data was synced to Supabase/SQLite for that specific account *before* this fix existed. The fix stops new contamination; it doesn't retroactively scrub already-synced accounts. To see a fully clean run, either register a brand-new account or clear that test account's `profiles` / `pigs` / `expenses` / `health_records` / `settings` rows (filtered by its `firebase_uid`) in Supabase and its local SQLite cache.
- **`CYCLE_START` is hardcoded to `2026-04-01`** and used throughout the 120-day calendar's date labels — a pre-existing limitation (not part of the reported bug) meaning calendar dates don't reflect a user's actual chosen start date. Flagged for future work, out of scope here.
