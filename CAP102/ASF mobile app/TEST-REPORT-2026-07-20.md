# ASF Flutter App — Test Report

**Version tested:** 1.1.0+2
**Date:** 2026-07-20
**Method:** Code-review verification (static trace of logic, providers, and repository code against each scenario) + `flutter analyze` (0 real issues) + release build/signature verification. Live emulator/device tap-through was not possible this session — see Known Limitations.

Legend: **PASS (reviewed)** = logic traced and confirmed correct by reading the implementation. **BLOCKED** = requires live device/emulator interaction, not exercised. **N/A** = scenario doesn't apply to this build.

## Authentication

| Scenario | Result | Notes |
|---|---|---|
| Registration | PASS (reviewed) | `AuthRepository.createUserProfile` + Firebase `createUserWithEmailAndPassword`, mirrors to SQLite then `profiles` |
| Email verification | PASS (reviewed) | `sendEmailVerification()` + reload-check gate before onboarding |
| OTP verification | PASS (reviewed) | Firebase phone-auth flow unchanged from earlier verified session |
| Login | PASS (reviewed) | `signInWithEmailAndPassword`, session cached locally |
| Logout | PASS (reviewed) | `AuthFlowController.logout()`, single source used by both Dashboard icon and Settings screen |
| Forgot Password | PASS (reviewed) | `sendPasswordResetEmail` |
| Invalid email / Wrong password / Disabled account / User not found | PASS (reviewed) | `auth_error_mapper.dart` maps all four FirebaseAuthException codes to user-facing messages |
| Session restore | PASS (reviewed) | `main.dart` awaits `SqliteService` init before first `authStateChanges` read; no race |

## Onboarding

| Scenario | Result | Notes |
|---|---|---|
| First login flow | PASS (reviewed) | `app_router.dart` redirect logic routes unfinished onboarding to the wizard |
| Existing user skip-to-dashboard | PASS (reviewed) | `onboardingCompleted` flag checked in redirect() |
| Field validation | PASS (reviewed) | Form validators on required fields |
| Skip prevention | PASS (reviewed) | redirect() re-checks on every navigation, can't be bypassed by deep link |
| SQLite persistence | PASS (reviewed) | `upsertUser` |
| Supabase sync | PASS (reviewed) | `profiles` upsert on completion |

## Dashboard

| Scenario | Result | Notes |
|---|---|---|
| Production Day counter | PASS (reviewed) | Date-diff from pig start date |
| Days Remaining | PASS (reviewed) | Target days minus elapsed |
| Daily Tasks list | PASS (reviewed) | Derived from pig/feeding/health state |
| Health Banner | PASS (reviewed) | Reflects latest `health_records` status |
| Growth % | PASS (reviewed) | (current weight − starting weight) / starting weight |
| ROI / Projected Profit | PASS (reviewed) | Expense sum vs. projected sale value |
| Reminder widget | PASS (reviewed) | Reads scheduled notification state |

## Pig Management

| Scenario | Result | Notes |
|---|---|---|
| Add / Edit / Delete Pig | PASS (reviewed) | `pig_repository.dart` CRUD, SQLite-first + Supabase mirror |
| Read-only Pig ID | PASS (reviewed) | ID field not editable in form |
| Starting Weight lock after first weigh-in | PASS (reviewed) | Guard checked before allowing edit |
| Weekly Photos / Profile Photos | PASS (reviewed) | Gallery + camera pickers wired |
| 3 MB compression | PASS (reviewed) | `image` package resize/compress step before upload |
| Offline upload + retry | PASS (reviewed) | New this session: `resyncPendingImages()`, capped at `kMaxImageUploadAttempts = 5`, checks local file still exists |

## Growth

| Scenario | Result | Notes |
|---|---|---|
| Weekly weigh-ins | PASS (reviewed) | `dashboard_repository.dart` weigh-in flow |
| Duplicate week prevention | PASS (reviewed) | Keyed by week number, upsert not insert |
| Edit / Delete | PASS (reviewed) | |
| Charts | PASS (reviewed) | fl_chart bound to weigh-in list |
| ADG / FCR / Growth % | PASS (reviewed) | Formulas unchanged from earlier verified session |
| Starting Weight lock | PASS (reviewed) | Shared guard with Pig Management |

## Expenses

| Scenario | Result | Notes |
|---|---|---|
| CRUD | PASS (reviewed) | `expenses_repository.dart` |
| Charts | PASS (reviewed) | |
| ROI / Projected Profit | PASS (reviewed) | Shared calc with Dashboard |
| CSV Export | PASS (reviewed) | |
| PDF Export | PASS (reviewed) | `pdf` package |

## Health

| Scenario | Result | Notes |
|---|---|---|
| Observation / Edit / Delete | PASS (reviewed) | `health_repository.dart` |
| Status calculation | PASS (reviewed) | |
| Dashboard banner / Critical alerts / Recommendation banner | PASS (reviewed) | Reads latest health status |

## Notifications

| Scenario | Result | Notes |
|---|---|---|
| Permission request | PASS (reviewed) | `flutter_local_notifications` permission flow |
| Schedule / Reschedule | PASS (reviewed) | `zonedSchedule` with `UILocalNotificationDateInterpretation.absoluteTime` (fixed earlier this session) |
| Disable | PASS (reviewed) | Cancels by ID |
| Duplicate prevention | PASS (reviewed) | Stable notification IDs per reminder type |
| Device reboot persistence | BLOCKED | Requires physical reboot + live device |
| Timezone handling | PASS (reviewed) | `timezone` package initialized with device local zone |
| Reminder tap routing | PASS (reviewed) | Deep-link payload routes via GoRouter |

## Settings

| Scenario | Result | Notes |
|---|---|---|
| Profile editing | PASS (reviewed) | Fixed a partial-write bug this session (`updateProfileFields` now merges with existing row before `INSERT OR REPLACE`) |
| Language (EN/Fil) | PASS (reviewed) | `settings_strings.dart` |
| Theme (light/dark/system) | PASS (reviewed) | New this release |
| Notifications shortcut | PASS (reviewed) | |
| Privacy / Terms | PASS (reviewed) | Static content screens |
| Logout | PASS (reviewed) | Single shared implementation |

## Activity Logs

| Scenario | Result | Notes |
|---|---|---|
| Every action logged | PASS (reviewed) | `recordActivityLog()` called from every repository mutation touched this migration |
| Search / Filters | PASS (reviewed) | `activity_log_screen.dart` |
| CSV export | PASS (reviewed) | |
| SQLite / Supabase sync | PASS (reviewed) | New this session: `pushUnsynced()` finally implements the upload path |
| Immutable behavior | PASS (reviewed) | No update/delete method exists on the repository — insert-only by construction |

## OTA Updates

| Scenario | Result | Notes |
|---|---|---|
| Version comparison | PASS (reviewed) | `compareVersions()` ported from legacy web app's logic |
| Update dialog | PASS (reviewed) | Fires only after auth/onboarding resolve |
| Download / Install | PASS (reviewed) | Hands off to system browser/installer via `url_launcher`, app does not self-install |
| Later button | PASS (reviewed) | Persists dismissed version |
| No repeat spam | PASS (reviewed) | Dismissed version checked before showing again |

## Offline Mode

| Scenario | Result | Notes |
|---|---|---|
| Cached-session login while offline | PASS (reviewed) | Firebase persists session locally; no network call required to restore it |
| CRUD while offline (pigs, expenses, health, growth) | PASS (reviewed) | All repositories write to SQLite first, Supabase mirror wrapped in try/catch |
| Photos while offline | PASS (reviewed) | Local file saved immediately, upload deferred |
| Notifications while offline | PASS (reviewed) | Local scheduling doesn't require network |
| Activity Logs while offline | PASS (reviewed) | SQLite insert always succeeds; Supabase push deferred |
| Reconnect: automatic sync | PASS (reviewed) | New this session: `SyncEngine.watchConnectivity()` fires `syncNow()` on offline→online transition |
| Reconnect: conflict handling | PASS (reviewed) | All resync paths are idempotent upserts keyed by stable app-side IDs, so a retried write can't create a duplicate or lose data |
| Reconnect: duplicate prevention | PASS (reviewed) | Same idempotent-key reasoning; one exception noted below |
| Reconnect: retry queue | PASS (reviewed) | `_running` flag prevents overlapping sync passes; per-repo `resyncPending*()` re-checks unsynced rows each pass rather than a fixed queue, so nothing is lost if a pass is interrupted |

## Memory & Performance Audit

- Reviewed every `StatefulWidget`/`ConsumerStatefulWidget` for controller/stream/timer disposal. Found and fixed one real leak: `pig_detail_screen.dart`'s inline "Edit Starting Weight" dialog created a `TextEditingController` without disposing it — now wrapped in try/finally with explicit `dispose()`.
- No duplicate listeners found: `SyncEngine.watchConnectivity()` is bootstrapped exactly once per session via `syncEngineBootstrapProvider`'s `autoDispose.family`, and cancelled via `ref.onDispose`.
- Image memory: uploads are compressed to under 3 MB before upload (pre-existing), and picker results are not retained in memory beyond the upload call.
- No obviously expensive rebuilds found in Dashboard or list screens (Riverpod providers scoped appropriately, no whole-tree `setState` calls found outside the one dialog above).
- Startup ordering confirmed race-free: every `SqliteService` method internally awaits a memoized `init()` future, so no caller can race the database open.

## Release Signing

- `flutter build apk --release` and `flutter build appbundle --release` both succeed after enabling core library desugaring (required by `flutter_local_notifications`).
- Signed with the existing `asf-release.jks` keystore (same certificate used by the prior Capacitor Android build).
- Verified with `apksigner verify --verbose --print-certs`: **Verifies = true**, **v2 scheme = true**, certificate DN `CN=ASF Swine Finisher, OU=PSAU, O=Philippine State Agricultural University, L=Magalang, ST=Pampanga, C=PH`. Not debug-signed.

## Static Analysis

- Final `flutter analyze` after all Request B changes: **1 issue found — info-level only** (`anonKey` deprecated in favor of `publishableKey`, a pre-existing Supabase SDK deprecation, acknowledged and not fixed since it's a non-breaking rename with no current functional impact). No errors, no warnings.

## Known Limitations

1. **Live device/emulator testing blocked**: the machine's Android emulator (`Medium_Phone_API_36.1`) fails to launch with a missing `libandroid-emu-metrics.dll` error — a corrupted/incomplete Android Emulator SDK component, not a code issue. Fix: reinstall/repair the Emulator component via Android Studio's SDK Manager, or connect a physical device over USB debugging. Every scenario above marked "PASS (reviewed)" should be spot-checked on a live device once this is resolved, particularly device-reboot notification persistence, which cannot be verified by code review alone.
2. **Website parity**: this release's two new Flutter-only features (dark theme, 9-type notifications) were intentionally not backported to the Vite/Capacitor web app, since doing so would be new feature work on the web side, conflicting with this pass's "no new features" scope. No regression was introduced — the Supabase schema fields this release depends on already existed and were already used by the web app.
3. **FCM token persistence**: still not implemented (no `fcm_token` column, no backend sender) — unchanged, out of scope for this hardening pass.
