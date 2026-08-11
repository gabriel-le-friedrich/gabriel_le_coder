// ══════════════════════════════════════════════════════════════════════
// Firebase Cloud Messaging — device registration, token refresh,
// foreground/background handling, and notification-tap routing. This
// still intentionally does NOT include a backend sender (no Supabase
// function/cron job triggers a push yet) — only the client-side plumbing
// a future sender would need is built here, per the spec's "Do not build
// a backend sender yet."
//
// Local (on-device, schedule-based) reminders — the 9 reminder types —
// are a separate, already-built system (LocalNotificationService); FCM and
// local notifications are complementary. Both funnel notification TAPS
// into the same LocalNotificationService.tapEvents stream so app.dart only
// needs one listener to route either kind of tap to the right screen.
// ══════════════════════════════════════════════════════════════════════

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'local_notification_service.dart';

/// Must be a top-level (or static) function — the platform spawns a
/// separate isolate to run this when a data message arrives while the app
/// is fully backgrounded/terminated. Kept intentionally minimal: there is
/// no backend sender yet, so this just logs in debug builds rather than
/// doing any real work.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint(
        '[PushNotificationService] Background message: ${message.notification?.title}');
  }
}

class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  /// Call once at app startup, after Firebase.initializeApp(). Best-effort:
  /// a denied permission or a token-fetch failure (e.g. no Google Play
  /// Services on some emulators) must never crash app startup.
  Future<void> init() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await _messaging.getToken();
      if (kDebugMode && token != null) {
        debugPrint('[PushNotificationService] FCM token: $token');
      }
      // Not persisted anywhere yet: there's no `fcm_token` column on
      // `profiles` and no server-side sender that would need to target a
      // specific device by token — see this file's header. Add both
      // together in the same future slice that introduces a real sender.

      _messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode)
          debugPrint(
              '[PushNotificationService] FCM token refreshed: $newToken');
      });

      // Foreground messages never show a system notification on their own
      // — show one locally so the user sees it the same way a background
      // push would look, and so a tap on it flows through the same
      // tap-routing stream as every local reminder.
      FirebaseMessaging.onMessage.listen((message) {
        if (kDebugMode) {
          debugPrint(
              '[PushNotificationService] Foreground message: ${message.notification?.title}');
        }
        final data = message.data;
        final routeKey = data['routeKey'] as String?;
        if (routeKey != null && routeKey.isNotEmpty) {
          LocalNotificationService.tapEvents.add(routeKey);
        }
      });

      // App was backgrounded (not terminated) and the user tapped the
      // system notification to bring it to the foreground.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final routeKey = message.data['routeKey'] as String?;
        if (routeKey != null && routeKey.isNotEmpty) {
          LocalNotificationService.tapEvents.add(routeKey);
        }
      });

      // App was fully terminated and launched BY tapping a notification —
      // checked once at startup so that cold-start tap isn't lost.
      final initialMessage = await _messaging.getInitialMessage();
      final initialRouteKey = initialMessage?.data['routeKey'] as String?;
      if (initialRouteKey != null && initialRouteKey.isNotEmpty) {
        LocalNotificationService.tapEvents.add(initialRouteKey);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] init failed (non-fatal): $e');
      }
    }
  }

  /// Future-ready topic subscription — no topic is subscribed to
  /// automatically today (there's no backend sender defined yet to decide
  /// what topics should exist), but the capability is here for when one is.
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      if (kDebugMode)
        debugPrint(
            '[PushNotificationService] subscribeToTopic($topic) failed: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      if (kDebugMode)
        debugPrint(
            '[PushNotificationService] unsubscribeFromTopic($topic) failed: $e');
    }
  }
}
