# ASF Flutter App — Changelog

**Version 1.1.0+2** — 2026-07-20

## New in this release

- **Settings module**: Profile editing (name, municipality, province, farm name, farmer type), Language (English/Filipino), Theme (light/dark/system — new, the legacy web app has no theme system), Notifications shortcut, Activity Log shortcut, About, Privacy Policy, Terms of Service, Logout. All changes are SQLite-first with a best-effort Supabase mirror and an immutable activity log entry.
- **Activity Log Viewer**: search, date-range filter, action-type filter, CSV export, and a new push-sync path that finally uploads locally recorded activity log entries to Supabase (this had been a known gap since the activity-logging system was first built).
- **OTA Update Check**: reads the same `app_releases` Supabase table the legacy web app uses, compares versions, and shows an Update Now / Later dialog. Runs only after auth and onboarding have resolved, so it can never interrupt either.
- **Offline Sync Engine**: listens for connectivity being restored and retries every write that failed while offline — weekly pig photo uploads, pig profile edits, expenses, health logs, weigh-ins, settings, and notification preferences. This closes a gap that existed since early in the Flutter migration: every module already wrote to Supabase best-effort at save time, but nothing ever retried a failed write until now.
- **Image Handling fix**: weekly pig photo uploads that fail while offline are now actually retried (previously they just sat unsynced forever), and the `uploadAttempts` counter — present in the database schema since the Pig Management module was built but never wired up — is now used to cap retries on a permanently broken row.

## Production hardening

- Fixed a real release-build failure: `flutter_local_notifications` requires Android core library desugaring, which wasn't enabled. Both `flutter build apk --release` and `flutter build appbundle --release` now succeed.
- Wired up release signing using the existing `asf-release.jks` keystore (the same one used for the Capacitor app's release build) — release builds are no longer debug-signed.
- Removed leftover TODO markers in the FCM push service; reworded as plain explanatory comments.
- Fixed a small memory leak: the Pig Detail screen's "Edit Starting Weight" dialog created a `TextEditingController` that was never disposed.
- Bumped `versionName`/`versionCode` to 1.1.0+2.

## Known limitations

- Both signed artifacts (`ASF-v1.1.0-release.apk`, `ASF-v1.1.0-release.aab`) were built and verified to compile/sign cleanly, but could not be exercised on a live device or emulator this session — the machine's Android emulator (`Medium_Phone_API_36.1`) fails to start with a `libandroid-emu-metrics.dll` missing error, indicating a corrupted or incomplete Android Emulator component install (fixable via Android Studio's SDK Manager, re-downloading the Emulator package). Everything reported as "working" below was verified by careful code review and `flutter analyze`, not by tapping through the running app.
- Website (Vite/Capacitor) parity: the new Flutter-only features this release adds — Theme (dark mode) and the 9-type Notification system — don't exist on the web app, which still has neither a theme system nor more than its original 5 reminder types. No regression was introduced on the web side (the Supabase schema changes this release relies on — `province`/`farm_name`/`farmer_type` on `profiles` — already existed before this session and the web app already reads/writes them). Whether to backport Theme/9-type-Notifications to the web app is an open product decision, not something this pass changed.
- FCM device-token persistence is still intentionally not built (no `fcm_token` column, no backend sender) — unchanged from the prior session's explicit scope.
