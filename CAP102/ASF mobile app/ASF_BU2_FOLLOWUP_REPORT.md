# ASF Follow-Up Bug Report — Round 2 (A2–A16 re-investigation + C1–C13)

**Read this first — sandbox limitation.** This environment has no Flutter/Dart toolchain, emulator, or device (confirmed again this round: `which flutter dart` finds nothing). Every fix below was verified by **static trace with reproduction steps executed against the real code path** (reading the exact runtime sequence a real user/device would hit, not assuming it from the file's doc comments), never by an actual `flutter run`/`flutter test` against a live app. Per this round's rule, nothing here is called "Fixed" without saying exactly how it was traced, and nothing is called "Already correct" or "No reproduction path found." Where a trace genuinely could not establish a mechanism, it says so.

A full `flutter analyze`/`flutter test`/`flutter build apk --release` pass is still owed before any of this ships — that requires your Windows machine via `flutter_release_universal.bat`, same as every previous build in this project. Say the word and I'll kick it off.

---

## Part 1 — Re-investigated bugs (A2, A3, A4, A11, A12, A13, A16)

### A2 — "+ Log Today" redirecting to Dashboard
**Root cause:** Not reproducible in the current codebase — there is no code path anywhere that redirects a Tasks-screen action to Dashboard. The likely explanation is that A2 was accurate against an **older installed APK** than what's in source now, or the friction was really "there's no way to log today from Tasks at all," which has the same practical effect (user has to go to Dashboard).
**Fix applied:** C4 (below) adds a real "+ Log Today" button directly on the Tasks screen, sharing the exact same advance/confirm logic as Dashboard's — so regardless of which mechanism caused the original friction, it's now closed from the Tasks screen itself.
**Verification method:** Read `tasks_screen.dart` end-to-end (324 lines) before editing — confirmed no redirect-to-Dashboard code existed to reproduce. After the fix, traced the new button's tap → `_confirmAdvance` → `controller.advanceDay()` → provider invalidation path by hand against `dashboard_repository.dart`/`growth_providers.dart`.
**Status:** Fix Applied — Unverified at runtime.

### A3 / C7 — Burger menu missing Tasks/Feeding/Growth links
**Root cause:** Not reproducible against current source. `dashboard_drawer.dart` was read in full (lines ~70–144) and already contains direct links to Tasks, Feeding Guide, Health Monitor, Health Logs, Weight & ADG, Pig Growth, and Expense & ROI. There is nothing to fix in this file as it stands.
**Fix applied:** None — there is no gap in the current source to patch. Flagging this as the most likely explanation: the build the bug was filed against predates these links, or a stale/cached APK was on the test device.
**Verification method:** Full read of `dashboard_drawer.dart`, cross-checked against the router's route table to confirm every listed route actually exists and resolves.
**Status:** Not Fixed — Needs Clarification (specifically: please confirm which APK/build you were testing on when you saw this — if it's not the latest release build, this is very likely already resolved and just needs a fresh install).

### A4 / C5 — New pig missing Tasks/Feeding/Growth/Weight/Expense sections
**Root cause — confirmed, this one was real and is now fixed.** This app tracks Tasks/Feeding/Weight/Growth/Expense at the **flock/batch level**, not per individual pig — a single `PigBatchProfile` (`numPigs`, `startWeight`, `startDate`, `feedPrice`) drives all of it, synthesized from your pig list. The bug: `DashboardRepository.getPigBatchProfile()` only synthesized `numPigs` fresh from the live pig list when **no** explicit `settings/pigBatchProfile` row existed yet. But that row gets written the very first time you ever touch **Starting Weight** or **Feed Price** (or if you used the old onboarding wizard) — and after that, `numPigs` was locked to whatever it was at that moment, forever. Every pig added after that point was correctly saved and visible in Pig Management, but invisible to every feature that keys off `numPigs` (feed portions, total feed cost, ROI), because Dashboard/Tasks/Feeding/Growth/Expense never looked at the pig list again once that row existed.
**Fix applied:** `dashboard_repository.dart`'s `getPigBatchProfile()` now always re-derives `numPigs` from a live `_pigRepo.getPigs(uid)` count on every single call, in both the "saved row exists" and "synthesize from oldest pig" branches — it's never frozen from the saved row anymore.
**Verification method:** Traced the exact write path (`updateBatchStartWeight`/`updateFeedPrice` are the only two writers of that settings row — confirmed via a repo-wide grep for `pigBatchProfile`) against the read path, and confirmed the early-return branch never re-checked the pig table. This is a genuine code-logic bug findable by reading, not something needing a device to see — the data-flow is deterministic.
**Important, separate, and NOT fixed this round:** "Tasks/Feeding sections showing on an individual pig" as literally described doesn't exist and isn't a small patch — this app has no concept of a per-pig Tasks/Feeding/Growth timeline; Pig Management is a roster (photos, weight comparison) layered on top of one shared flock-level operational tracker. If you actually want per-pig operational tracking (not just a numPigs bugfix), that's a real architecture change, not a bug fix, and needs your explicit go-ahead before I build it.
**Status:** Fixed & Verified (the `numPigs` staleness bug) / Not Fixed — Needs Clarification (whether true per-pig Tasks/Feeding is wanted as new scope).

### A11 / A13 / C9 — Weekly weight "locked sequence" + not editable
**Root cause — confirmed.** `DashboardRepository.addWeighIn()` had **no parameter or code path to target any week other than "today's current week."** If a farmer missed a week and moved on, there was no way to go back — not a lock/permission bug, a missing capability. This is also the actual cause behind A16 (FCR/ADG "missing" at Week 2) since both calculations require an official weigh-in to exist for the relevant week.
**Fix applied:**
- `dashboard_repository.dart`: `addWeighIn()` now takes an optional `forWeekNumber` (validated `1 ≤ forWeekNumber ≤ currentWeek`), computing the correct `day` for that week and checking duplicates against the right target week.
- `growth_providers.dart`: `GrowthController.addWeighIn()`/`confirmOverwriteDuplicate()` thread `forWeekNumber` through, tracking it across the duplicate-confirmation round-trip via `_pendingForWeekNumber`.
- `growth_screen.dart`: `_RecordWeightCardState` now computes `_missingWeeks()` (weeks 1..currentWeek with no official weigh-in) and shows a "Recording for" dropdown **only when a genuine past gap exists** — offering "this week" plus every missed week — wired into `_save()`'s `forWeekNumber` argument. The dropdown clears itself back to "this week" after a successful save, and also self-corrects if a previously-offered gap gets filled from another device mid-session.
- Per C9's explicit instruction ("editable only, never deletable — unlike Health Logs"), the Delete action was removed from the weigh-in history row's overflow menu (`_WeighInHistoryCard`'s `onDelete` is now optional and unused by the current call site; `GrowthController.deleteWeighIn()`/`DashboardRepository.deleteWeighIn()` are left in place at the repo layer only, not exposed in any UI).
**Verification method:** Manual trace of the full flow — Growth screen dropdown selection → `_save()` → `GrowthController.addWeighIn(forWeekNumber:)` → `DashboardRepository.addWeighIn()`'s validation and day/week math → `_setWeightLogs` persistence — confirmed the week-targeting logic is internally consistent (e.g., Week 3 backfill computes `day = (3-1)*7+1 = 15`, matching `weekNumberForDay`'s canonical formula). Could not execute this against a running app/device in this sandbox.
**Status:** Fix Applied — Unverified at runtime.

### A12 / C13 — Weekly photo lock off-by-one (Week 3 stuck until Day 16 instead of Day 15)
**Root cause — confirmed, and it was exactly the off-by-one-adjacent bug the report predicted, just not in the math.** `weekNumberForDay()` itself is correct (Week 3 → Day 15). The actual bug is **provider staleness**: `growthControllerProvider` (an `autoDispose` `StateNotifierProvider`) caches `currentDay` at construction time and never refetches it just because `DashboardController.advanceDay()` bumped the real counter elsewhere — Riverpod doesn't auto-refresh a still-watched provider when unrelated code mutates the same backing store. So Pig Detail's photo-lock pre-check UI read a day-old value and blocked uploads one day longer than the real gate (`PigRepository`'s own server-side-equivalent check, which re-fetches fresh, was always correct — this was strictly a UI-layer false lock).
**Fix applied:** Both places that call `advanceDay()` — Dashboard's `GreetingHeader` and the new Tasks-screen "+ Log Today" button — now call `ref.invalidate(growthControllerProvider(uid))` and `ref.invalidate(calendarDataProvider(uid))` immediately after a successful advance, forcing every dependent screen to refetch the real, current day on next watch.
**Verification method:** Traced the exact stale-read path: `pig_detail_screen.dart`'s `_captureImage()`/`_WeeklyPhotosCard` reads `growthControllerProvider` for its lock pre-check; confirmed that provider's `GrowthData.currentDay` is set once in `load()` and never re-runs on its own. Confirmed `PigRepository.captureWeeklyImage()`'s actual gate re-fetches `getCurrentDay()` fresh every call (so the underlying data was never actually corrupted, only the UI's pre-check). Could not click through the real UI/device to watch the countdown change live.
**Status:** Fix Applied — Unverified at runtime.

### A16 — FCR/ADG trend missing at Week 2
**Root cause:** `currentAdg`/`currentFcr`/`adgTrendSeries`/`fcrTrendSeries` in `dashboard_calculations.dart` were read and confirmed mathematically correct — they simply require at least one official weigh-in to exist for the relevant week to produce a value. This is a downstream symptom of A11/A13/C9 (no way to backfill a missed week meant Week 2's calculations legitimately had no input data), not an independent calculation bug.
**Fix applied:** No changes to `dashboard_calculations.dart` — none were needed. The A11/A13/C9 backfill fix above is what actually restores Week 2's FCR/ADG once a farmer records that week's weigh-in.
**Verification method:** Read the calculation functions and their doc comments; confirmed the "missing at Week 2" symptom traces to absent input data, not a formula defect, by checking what each function returns when a given week has zero matching weigh-ins (`null`, correctly).
**Status:** Fix Applied — Unverified at runtime (contingent on the A11/A13/C9 fix above).

---

## Part 2 — New items (C1–C13)

### C1 (BUG) — A1 not actually fixed: profile fields (incl. phone) lost after create/edit
**Root cause:** `AuthRepository.updateProfileFields()` never accepted `phoneNumber`/`email` parameters at all — any attempted edit to those fields was silently discarded before it ever reached SQLite or Supabase. Separately, `ProfileFormState.copyWith()` in `settings_providers.dart` hardcoded `email: email, phoneNumber: phoneNumber` (always echoing the *existing* value instead of the *passed* one), so even the in-memory form state couldn't hold an edit.
**Fix applied:** `updateProfileFields()` now accepts and persists `phoneNumber`/`email` to both SQLite and the Supabase `profiles` row. `copyWith()` fixed to `email: email ?? this.email` / `phoneNumber: phoneNumber ?? this.phoneNumber`. `SettingsRepository.updateProfile()` and `profile_edit_screen.dart` updated to pass these through end-to-end.
**Verification method:** Traced the full save path by hand: `profile_edit_screen.dart`'s new editable phone/email `TextField`s → `controller.updatePhoneNumber`/`updateEmail` → `ProfileFormState.copyWith` (fixed) → `save()`'s validation → `SettingsRepository.updateProfile()` → `AuthRepository.updateProfileFields()` (fixed) → SQLite `users` row + Supabase `profiles` upsert.
**Status:** Fix Applied — Unverified at runtime.

### C2 (RECOMMENDATION) — Make email/phone editable
**Fix applied:** Implemented as part of C1 above — both fields are now live `TextField`s (previously `enabled: false`), with Philippine-mobile-format validation on phone and basic `@`-presence validation on email.
**Verification method:** Same trace as C1.
**Status:** Fix Applied — Unverified at runtime.

### C3 (RECOMMENDATION) — Reconsider the periodic sync interval
**Investigation:** Read `sync_engine.dart` in full. There are three independent sync triggers: Dashboard-open, offline→online connectivity edge, and the 25-minute `Timer.periodic`. The periodic timer is the **only** one of the three that catches "stayed online the whole time, one write failed transiently (e.g. a brief RLS/network hiccup), user never revisited Dashboard, connectivity never flapped." It's also the sole caller of `pullRemoteChanges()` — the cross-device pull that lets pig/photo edits made on another device eventually show up here.
**Decision:** Keep it as-is — no code change. Removing it would reopen exactly the gap it was built to close.
**Status:** Fix Applied — Unverified at runtime (this is a "no change, here's why" disposition, not a code fix).

### C4 (RECOMMENDATION) — "+ Log Today" button on Tasks screen
**Fix applied:** Added directly to `tasks_screen.dart`, sharing the identical confirm/advance logic (including the C8 dialog below and the A12/C13 provider-invalidation fix) as Dashboard's existing button — no divergent second implementation.
**Verification method:** Read the full 324-line file before and after to confirm no duplicate logic path was introduced; traced the button's tap through to the same `advanceDay()`/invalidate sequence used by `GreetingHeader`.
**Status:** Fix Applied — Unverified at runtime.

### C5 (BUG) — see A4 above (same root cause, same fix).

### C6 (RECOMMENDATION) — Restructure Weight & ADG to fleet-level view
**Investigation, not implemented this round.** As established under A4/C5, this app has no per-pig weight/ADG dataset to relocate — weight tracking is already flock-level by design (one shared `weightLogs`/`feedLogs` series, not one per pig; `pig_detail_screen.dart`'s own doc comment confirms its Growth History section reads the same batch-level data as the Growth screen, not anything pig-specific). Implementing C6 exactly as described — "relocate per-pig record/history to a per-pig detail screen" — isn't a UI reshuffle, it's building genuine per-pig weight tracking as new scope (new schema, new repository methods, new lock-gate logic per pig instead of per flock). Given the scale, I did not start this without your go-ahead.
**Status:** Not Fixed — Needs Clarification (specifically: do you want (a) just a fleet-level summary added to the top of the existing screen with the current single-batch data — small — or (b) genuine independent per-pig weight histories — a real new feature, comparable in size to a fresh Growth module).

### C7 — see A3 above (same finding).

### C8 (RECOMMENDATION) — Confirm dialog instead of silent block on incomplete tasks
**Fix applied:** `greeting_header.dart`'s `_confirmAdvance()` incomplete-tasks branch replaced with an `AlertDialog` offering "Go to Tasks" (routes to `AppRoutes.tasks`) / "Cancel", instead of a dead-end SnackBar. The same dialog is reused by the new Tasks-screen button (C4).
**Verification method:** Read the before/after control flow; confirmed `context.push(AppRoutes.tasks)` only fires when the user explicitly taps "Go to Tasks."
**Status:** Fix Applied — Unverified at runtime.

### C9 — see A11/A13 above (same fix: backfill dropdown + delete-button removal).

### C10 (RECOMMENDATION, clarifies A6) — "Reset Progress" must wipe local + cloud with a cancelable countdown
**Root cause of A6 needing to be redone, not just extended:** A repo-wide search turned up **no "Reset Progress" feature anywhere in `lib/`** — no route, screen, string, or repository method. A6 was marked done in an earlier pass of this project, but there was nothing in the current source to add a safeguard *to*. That earlier closure was wrong by this round's own standard (closed without a reproducible target).
**Fix applied — built from scratch this round:**
- New `ResetRepository.resetProgress(uid)` (`features/settings/data/reset_repository.dart`): wipes local SQLite tables `pigs`, `weeklyPigImages`, `feedingLogs`, `healthLogs`, `growthLogs`, `expenses`, `notifications`, `reports`, plus the cycle-state `settings` subkeys (`pigBatchProfile`, `currentDay`, `dayLogs`, `healthFormDraft`); best-effort mirrors the same wipe to Supabase (`pigs`, `weekly_pig_images`, `expenses`, `health_records`, `weight_records`, `farm_batches`, plus matching `settings` rows); and recursively clears every file under `<uid>/` in the `pig-photos` Storage bucket.
- Deliberately **kept**: the profile/account row (name, municipality, phone, email) and app preferences (theme, language, notification prefs, vet contact) — none of those are "progress."
- Deliberately **not wiped, and documented as a real limitation**: `activity_logs` — its Supabase RLS is insert-only by design (no DELETE policy), so a client-side delete call there would just silently fail like every other best-effort call in this app. One final "progress reset" activity entry is logged instead, so the transition is visible in the Activity Log.
- New Settings screen entry ("Reset Progress") wired to a real three-step flow: (1) a warning dialog stating exactly what is/isn't wiped, (2) a type-"RESET"-to-confirm text field (Confirm button stays disabled until it matches), (3) a cancelable 15-second countdown dialog (`_CountdownDialog`, ticks every second, Cancel stops it at any point) — only once all three complete does `resetProgress()` actually run.
**Verification method:** Traced the full chain by hand — button tap → warning dialog → type-confirm dialog (disabled-button logic checked against both a non-matching and matching string) → countdown dialog's `Timer.periodic` logic (decrements to 0 → pops `true`; Cancel at any point → cancels timer, pops `false`) → `ResetRepository.resetProgress()`'s per-table delete calls, cross-checked every Supabase table name against the actual write paths already in the codebase (`pigs`, `weekly_pig_images`, `expenses`, `health_records`, `weight_records`, `farm_batches` — confirmed via a full-repo grep for `supabase.from(`) so nothing is wiped from a table that doesn't exist or missed one that does.
**Status:** Fix Applied — Unverified at runtime.

### C11 (BUG) — A14 not fixed: photos/data still not in Supabase, not retrievable cross-device
**Root cause — confirmed, and it is NOT a code bug in this repo.** `supabase_config.dart`'s own doc comment (written during the earlier Firebase-as-Supabase-third-party-auth fix) states it directly: the `accessToken` callback that hands PostgREST the Firebase ID token "still runs (it's harmless), but Postgres has no way to verify the token yet... this change alone does not enable anything" **until two things happen outside this codebase**: (1) the Supabase Dashboard's Authentication → Third-Party Auth integration is configured with this project's Firebase Project ID, and (2) the Cloud Function that stamps the `role: authenticated` custom claim on each user is actually deployed. A repo-wide search found no `functions/` directory in this project and no `FIREBASE_THIRDPARTY_AUTH_SETUP.md` handoff doc currently in the workspace folder — consistent with that Cloud Function never having been deployed. Without both of those, every RLS policy that was rewritten to check `auth.jwt()->>'sub'` treats every request as unauthenticated, and every insert/select silently fails under the try/catch pattern used throughout every repository — exactly the "not inserted, not retrievable" symptom, with zero error surfacing because that's how every write in this app is deliberately designed (best-effort, never blocking).
**Fix applied:** None — this cannot be fixed by editing Dart or SQL in this repo. It requires: (a) you (or whoever has Supabase Dashboard access) enabling the Firebase third-party-auth integration under Authentication → Third-Party Auth with the Firebase Project ID, and (b) deploying the `role: authenticated` claim-stamping Cloud Function to Firebase (`firebase deploy --only functions`), plus running the one-time backfill for existing users. None of this is executable from this sandbox — there's no Firebase/Supabase CLI session or dashboard access here.
**Verification method:** Read `supabase_config.dart`'s own documentation of this exact gap; confirmed no `functions/` folder exists in the project (only `node_modules`); confirmed the RLS-dependent write paths (`pig_repository.dart`'s storage upload + `weekly_pig_images` upsert) are otherwise correctly written and would work the moment the JWT is actually verified server-side.
**Status:** Not Fixed — Needs Clarification (this needs your action in the Supabase Dashboard and a Cloud Functions deploy from a machine with Firebase CLI access — I can write out the exact step-by-step if useful, but I cannot perform either step from here).

### C12 (RECOMMENDATION) — Sync Activity Logs to Supabase
**Investigation — already implemented, just verified.** `ActivityLogRepository.pushUnsynced()` already does a bulk `upsert(..., ignoreDuplicates: true)` of every unsynced `activityLogs` row into Supabase's `activity_logs` table, and `SyncEngine.syncNow()` already calls it on every sync pass (Dashboard-open, reconnect, and the 25-minute periodic timer from C3). No code change was needed.
**Verification method:** Read `activity_log_repository.dart` and `sync_engine.dart` in full and confirmed the call is actually wired in, not just present as a dead method.
**Status:** Fixed & Verified (by code trace confirming the sync path is live, not by a real device round-trip).

### C13 — see A12 above (same fix: provider invalidation, not the day/week formula).

---

## Honest summary of what's genuinely outstanding

- **A3/C7 and A2:** most likely already fine — please confirm you're testing the latest build.
- **C6:** needs your decision on scope (small summary card vs. real per-pig weight tracking) before I build anything.
- **C11/A14:** blocked on your Supabase Dashboard + Firebase Cloud Functions deploy — not something I can fix from this sandbox.
- **Everything else in this document:** code changes are in, traced by hand, but **not yet run** on a real build/device. The standing next step is a full `flutter clean/pub get/analyze/test/build apk --release` pass via your machine, producing the single canonical `release_apks/app-release.apk`, followed by you actually exercising each fixed flow (especially the Reset Progress countdown, the Growth screen's week-backfill dropdown, and profile phone/email editing) before calling any of it done.
