import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/firebase_options.dart';
import 'core/config/supabase_config.dart';
import 'core/database/sqlite_service.dart';
import 'core/services/device_id_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase Authentication — sole identity provider, matching the web
  // app's hybrid-backend design (see firebase_options.dart / auth_repository.dart).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crash reporting — collection is switched off in debug builds (so a
  // crash while developing on `flutter run` never pollutes the Firebase
  // console with noise), and on in release/profile. Both error surfaces a
  // Flutter app can produce are forwarded:
  //   - FlutterError.onError: errors thrown during the framework's own
  //     build/layout/paint pipeline (the ones that would otherwise only
  //     ever show as a red error screen no real user sees in release mode).
  //   - PlatformDispatcher.onError: everything else — async errors, errors
  //     in isolates, anything outside a Flutter widget callback.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);
  // IMPORTANT: record to Crashlytics AND still call Flutter's own default
  // presentation (FlutterError.presentError — console dump + the inline
  // ErrorWidget in place of whatever failed to build). Setting onError to
  // ONLY recordFlutterFatalError (as this was previously written) means a
  // real build/layout exception gets silently swallowed from the user's
  // point of view — no red/gray error box, the failing widget's slot in
  // the tree just renders as nothing — while still being recorded to
  // Crashlytics in the background. That "invisible on screen, recorded
  // remotely" gap is exactly what made a real on-device Health Monitor
  // rendering bug look like a data/logic problem instead of a caught
  // exception during a fresh QA pass.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Flutter's BUILT-IN release-mode ErrorWidget deliberately shows just the
  // word "Error" with no detail (a sensible default for a public app, so a
  // stray exception never leaks internals to an end user) — but that's
  // exactly what made a real widget-build exception on this exact screen
  // indistinguishable from "the options are just empty": a small grey box
  // reading only "Error" is easy to miss/mistake for blank space, especially
  // if it happens to render at roughly the same size as the missing
  // content. For this app (single-developer/thesis QA phase, not a public
  // app store release yet), showing the real exception text directly is far
  // more useful than protecting against a low-probability info leak — this
  // is exactly the mechanism that makes the NEXT on-device report
  // conclusive instead of another guess.
  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            details.exceptionAsString(),
            style: TextStyle(color: Colors.red.shade900, fontSize: 11),
          ),
        ),
      );

  // Local offline-first database — starts opening in parallel, same as
  // SqliteDB.initSqlite() being kicked off immediately in auth-main.js.
  unawaited(SqliteService.instance.init());

  // Splash-duration fix: on Android, nothing the user sees changes from
  // "the launcher icon full-size on a black/white background" (Android
  // 12+'s own system splash screen, drawn from this app's launcher icon —
  // see android/app/src/main/res/values*/styles.xml) until Flutter draws
  // its first frame, i.e. until this function reaches runApp() below. The
  // three inits below used to run one at a time, back to back — each
  // real async work (Postgres client setup, reading a persisted device id,
  // opening the local notification plugin + timezone database) stacking on
  // top of the last and extending exactly that "long pig-logo splash"
  // window for no reason, since none of the three actually depends on
  // either of the others. Starting all three concurrently and awaiting them
  // together only waits as long as the SLOWEST one, not the sum of all
  // three.
  final supabaseInit = initSupabase();
  // Stable per-install device id — sync conflict-resolution metadata
  // (device_id/sync_version/last_synced_at) tagged onto every synced row.
  // Still awaited (unlike SqliteService/PushNotificationService above/below)
  // because it must be ready before the very first repository write of this
  // app run — just no longer waited on sequentially after Supabase.
  final deviceIdInit = DeviceIdService.ensureLoaded();
  // Local reminder engine — sets the timezone database's local location and
  // creates the two Android notification channels. Still awaited because
  // notificationBootstrapProvider can fire as soon as the Dashboard route
  // builds, and it must never call scheduleReminder before tz.local has
  // been set — it just no longer blocks behind Supabase/device-id first.
  final notificationsInit = LocalNotificationService.instance.init();
  await Future.wait([supabaseInit, deviceIdInit, notificationsInit]);

  // Firebase Cloud Messaging — permission request + token retrieval only
  // at this slice (see push_notification_service.dart's file header for
  // what's deliberately not built yet). Runs in parallel, never blocks
  // startup on a denied permission or a flaky token fetch.
  unawaited(PushNotificationService().init());

  runApp(const ProviderScope(child: AsfApp()));
}
