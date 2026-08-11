# ASF Flutter — Setup status

**Update:** the platform scaffolding (`android/` folder) has now been generated and merged in, `flutter pub get` has been run, and `flutter analyze` passes clean (one harmless info-level deprecation notice about Supabase's `anonKey` param, not an error). This was done by writing a one-shot `.bat` script and launching it via the Windows Run dialog (a tier-"full" app), since Android Studio/terminals are click-only in this environment — see the repo-root `flutter_*.bat`/`flutter_*log*.txt` files for exactly what was run, safe to delete once reviewed.

The Google Services Gradle plugin is applied (`android/settings.gradle.kts` + `android/app/build.gradle.kts`, version 4.4.2), and `applicationId` was changed to `ph.edu.psau.asf` (the existing Capacitor app's real Firebase-registered Android package name — `google-services.json` processing fails otherwise). `namespace` stays `com.asf.asf_flutter` (only affects generated R-class code, not Firebase identity).

## If you want to run it yourself

```
cd "C:\Users\erjan\OneDrive\Desktop\ASF mobile app\flutter_app"
flutter pub get
flutter analyze
flutter run
```

## What's built so far

- Project structure: `core/` (Firebase config, Supabase config, SQLite service matching the existing app's exact table schema, GoRouter setup, FCM init), `features/auth/`, `features/onboarding/`, `features/dashboard/` — all with real, compiling implementations now (see below), not placeholders.
- Full authentication flow, ported faithfully from `src/auth-main.js`: register (email/password + phone OTP **linked**, never session-switched, plus a Confirm Password field and a best-effort verification email sent alongside account creation), login (email/password or mobile OTP, a real sign-in), forgot password (pre-checks Supabase so unregistered emails get "No account was found..." instead of a fake success message), logout (preserves local SQLite cache), duplicate-email/phone messages matching your exact requested wording, remember-login preference.
- Declarative routing via GoRouter (`core/routing/app_router.dart`): signed-out → Welcome/Register/Login/etc., signed-in + onboarding incomplete → Onboarding, signed-in + onboarding complete → Dashboard. Same branching rules as `showAuthShell()`/`showOnboarding()`/`showAppShell()` on the web, including a special case so the register flow's OTP screen doesn't get redirected away mid-verification even though Firebase already has a session at that point.
- Firebase Cloud Messaging: permission request + token retrieval only (`core/services/push_notification_service.dart`) — no foreground UI, topic subscriptions, or server-side sending yet.
- **Onboarding** (`features/onboarding/`): the real 5-step flow — Set Up Your Pig (Pig Name, Batch Name, Number of Pigs, Starting Weight, Start Date, Feed Price — Pig Name and Batch Name are distinct fields, matching `farm_batches.batch_name` vs `pigs.name` in the Supabase schema, unlike the web app which reuses one field for both) → Notification permission (the only one actually requested here) → Camera info-only → Gallery info-only → You're All Set. Finishing seeds the account's first real pig/weight/expense rows (SQLite + best-effort Supabase), mirroring `submitOnboardStart()`.
- **Dashboard** (`features/dashboard/`): Good Morning {name}, Production Day (the persisted, calendar-decoupled counter, capped at 120), Days Remaining, Today's 10 Tasks (AM/PM split, with the same task-2/6/8/10 lock rules tied to Health Monitor observations — locked until that slice exists, which is correct, not a bug), Current Weight, Target ADG, FCR ("Weekly weight required." until a real weekly weigh-in exists, matching the web app's gate), ROI, Projected Net Profit, and "Proceed to Next Day" (gated on all tasks done, capped at Day 120, matching `confirmAdvanceDay()`).

## What's NOT built yet (future slices)

Pig management (add/edit/delete, photos, weekly images, read-only ID, starting-weight lock), Expenses/ROI page, Health monitoring (this also unlocks Dashboard tasks 2/6/8/10 once built), Weekly Weighing UI, Growth charts, Calendar, Activity Log screen, Settings (incl. new Barangay field), the sync engine (SQLite ⇄ Supabase background push/pull — local writes already happen, nothing pushes most tables to Supabase yet besides what Onboarding/Dashboard write directly), local (on-device) notifications, and the OTA update UI (Flutter side + a web "new build available" prompt). Each of these should be its own reviewed slice — the Run-dialog build/analyze workflow above makes that loop fast to repeat.
