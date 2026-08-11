# ASF Android App — Build, Install & Launch Verification Report

Verified directly in your Android Studio + emulator via live screen automation (not simulated). One real bug was found and fixed; everything else was already correctly configured from prior sessions.

## 1. Issues found

**Root cause of "Run" silently doing nothing — `android/local.properties` had a UTF-8 byte-order-mark (BOM).**
The file's content was visually correct (`sdk.dir=C:/Users/erjan/AppData/Local/Android/Sdk`), but the first three bytes were `EF BB BF` (a UTF-8 BOM), invisible in any editor. Java's `Properties.load()` — which Gradle's Android plugin uses to read `local.properties` — does not strip BOMs, so it parsed the key as `﻿sdk.dir` instead of `sdk.dir`. Every real build (`installDebug`, `Run 'app'`) failed instantly with `SDK location not found`, while Android Studio's own IDE-level Gradle *sync* kept succeeding because it resolves the SDK path from its own settings, not from this file — which is why sync looked fine while every build silently failed with zero visible error in the Run panel (the failure surfaced only in the separate Build tool window).

A secondary, cosmetic warning also appeared during sync ("SDK location not found" as an informational message) — same underlying cause, harmless once fixed.

No other issues were found. Project structure, manifest, permissions, `build.gradle`, Capacitor plugin wiring, and `google-services.json` were all already correct.

## 2. Fixes applied

- **`android/local.properties`** — rewritten without the UTF-8 BOM, same content (`sdk.dir=C:/Users/erjan/AppData/Local/Android/Sdk`). This was the only code/config change needed.
- Enabled "Configure all Gradle tasks during Gradle Sync" in Android Studio's experimental settings, so the Gradle tool window shows the full task tree (quality-of-life, not required for the fix).

## 3. Files modified

| File | Change |
|---|---|
| `android/local.properties` | Removed leading UTF-8 BOM (3 bytes); content otherwise unchanged |

No source files, manifest, or Gradle scripts required changes — they were already correct.

## 4. Dependencies updated

None. All dependency versions (Firebase BoM 34.16.0, AndroidX libs, Capacitor plugins) were already consistent and resolved cleanly.

## 5. Verification results (checked live, in order)

- **Gradle Sync**: Successful (confirmed in the Sync log; only pre-existing, non-blocking warnings: `flatDir` deprecation notice, and the now-resolved SDK-location informational warning).
- **Emulator**: `Medium Phone API 36.1` (Android 16, `emulator-5554`) was already running and is the active deployment target.
- **Run Configuration**: `app` configuration present and correctly targets the `app` module (confirmed via Run ▸ Run 'app' menu and the toolbar device/config selectors).
- **Project structure**: `app/src/main/AndroidManifest.xml` ✅, `MainActivity.java` ✅ (`ph.edu.psau.asf.MainActivity extends BridgeActivity`), `app/build.gradle` ✅ — uses the modern `plugins { id 'com.android.application' }` block (functionally equivalent to `apply plugin:`) and `namespace = "ph.edu.psau.asf"` exactly as required.
- **Build**: `gradlew installDebug` equivalent → **BUILD SUCCESSFUL** (152 actionable tasks, 1 executed + 151 up-to-date on the verification re-run).
- **Install**: **"Install successfully finished in 2 s 526 ms."**
- **Launch**: `Run 'app'` → `adb shell am start -n ph.edu.psau.asf/ph.edu.psau.asf.MainActivity` → **"Connected to process 18118 on device 'Medium_Phone_API_36.1 [emulator-5554]'"**, process still alive at end of verification (no "Process finished" / crash message). The app's Welcome screen (ASF crest logo, green branding, entry button into the login/registration flow) rendered correctly on the emulator.
- **Logcat**: Reviewed, filtered to `package:ph.edu.psau.asf`. Only normal Capacitor bridge/plugin traffic (SQLite plugin callbacks succeeding), one harmless emulator-level `userfaultfd` kernel warning (unrelated to the app), and routine GC logs. **No fatal exceptions, no red/Error-level entries.**
- **Firebase**: `android/app/google-services.json` present (671 bytes); `com.google.gms.google-services` plugin applied in `app/build.gradle`; no Firebase-related errors in Logcat.
- **Supabase**: `src/supabase-config.js` URL and publishable key confirmed valid and functional earlier this session — the project's SQL schema was executed live against `https://genxzsocmhgnxwwxjifz.supabase.co` successfully, with all 9 tables, indexes, RLS policies, and the `pig-photos` storage bucket confirmed present.
- **SQLite**: Capacitor SQLite plugin bridge active — Logcat shows successful `CapacitorSQLite` plugin callbacks during boot.
- **Capacitor plugins**: `capacitor-android`, `capacitor-app`, `capacitor-network`, `capacitor-community-sqlite`, `capacitor-firebase-authentication` all resolved and included in the Gradle module list; no version-conflict errors during build.
- **Permissions** (`AndroidManifest.xml`): `INTERNET` ✅, `CAMERA` ✅, `READ_MEDIA_IMAGES` ✅, `READ_EXTERNAL_STORAGE` (maxSdk 32) ✅. `ACCESS_NETWORK_STATE` is not declared in the app manifest directly but is auto-merged from `@capacitor/network`'s own manifest by Gradle's manifest merger — confirmed present in that library's manifest. No `POST_NOTIFICATIONS` needed (the app doesn't use OS push notifications — its "notifications" feature is in-app data only).

## 6. Remaining manual steps

None required to run the app — it is fully working end to end. Two informational items you may optionally act on:

1. **AGP upgrade available**: Android Studio flagged that Android Gradle Plugin 8.13.0 is available (you're on an earlier version). This is optional and unrelated to the bug fixed here — only take it if/when you want the latest AGP features.
2. **`flatDir` repository warning**: `app/build.gradle` uses a `flatDir` repository for the Cordova plugin libs, which Gradle flags as deprecated (doesn't support metadata). This is inherited from Capacitor's own project template and is harmless; no action needed unless you want to silence the warning.

## Bottom line

The app now builds, installs, and launches cleanly on `Medium Phone API 36.1`. The one real defect — a stray UTF-8 BOM in `local.properties` silently breaking every real Gradle build while IDE sync stayed green — is fixed. The project is ready for continued testing and, when you're ready, a release build.
