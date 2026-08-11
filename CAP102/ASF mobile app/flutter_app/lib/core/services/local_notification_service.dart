// ══════════════════════════════════════════════════════════════════════
// Local (on-device) scheduled reminder engine — the Flutter equivalent of
// src/notifications.js, built on flutter_local_notifications instead of
// @capacitor/local-notifications. Fully offline: this only talks to the
// OS notification scheduler, never the network.
//
// Timezone note: this app's real user base (PSAU / Philippines) sits in a
// single, no-DST timezone (Asia/Manila, UTC+8), so a full native-timezone
// plugin isn't needed to "respect the user's timezone" in practice. We set
// the timezone database's local location to Asia/Manila directly, with a
// same-UTC-offset fallback if that lookup ever fails on some device.
// ══════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/notifications/domain/reminder_types.dart';
import '../../features/notifications/domain/notification_prefs.dart';
import '../../features/settings/domain/app_language.dart';
import '../../features/settings/domain/settings_strings.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Emits the reminder `key` (e.g. 'health', 'weighin') whenever the user
  /// taps a notification — the app-level tap-routing listener (see app.dart)
  /// subscribes to this to navigate to the right screen. Broadcast so both
  /// a cold-start tap (consumed once auth/router is ready) and later taps
  /// all reach the same listener.
  static final StreamController<String> tapEvents =
      StreamController<String>.broadcast();

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    } catch (_) {
      // Fallback: pick any known location sharing the device's current UTC
      // offset, so scheduling still works even if 'Asia/Manila' is somehow
      // missing from the bundled tz database.
      final offset = DateTime.now().timeZoneOffset;
      final match = tz.timeZoneDatabase.locations.values.firstWhere(
        (loc) => loc.currentTimeZone.offset == offset.inMilliseconds,
        orElse: () => tz.UTC,
      );
      tz.setLocalLocation(match);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final key = response.payload;
        if (key != null && key.isNotEmpty) tapEvents.add(key);
      },
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin
          .createNotificationChannel(const AndroidNotificationChannel(
        kCriticalChannelId,
        kCriticalChannelName,
        description: 'Health checks and Market Day alerts — high priority.',
        importance: Importance.max,
      ));
      await androidPlugin
          .createNotificationChannel(const AndroidNotificationChannel(
        kInfoChannelId,
        kInfoChannelName,
        description:
            'Feeding, weigh-in, photo, vaccination, medication, and backup reminders.',
        importance: Importance.defaultImportance,
      ));
    }
  }

  /// Android 13+ requires this explicit runtime request; a no-op (returns
  /// true) on older Android/other platforms. Never throws — a denied or
  /// unavailable permission must never crash reminder setup.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    } catch (e) {
      if (kDebugMode)
        debugPrint('[LocalNotificationService] requestPermission failed: $e');
      return false;
    }
  }

  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.areNotificationsEnabled();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cancels then (re)schedules one reminder type from its current pref —
  /// always cancel-then-schedule rather than diffing, same reasoning as
  /// the web app's scheduleAllReminders(): the volume (9 reminders max)
  /// makes this simpler and just as reliable, and it's what guarantees no
  /// duplicate ever stacks on the same notifId.
  /// Bug B1 fix: [lang] picks the OS-level notification's actual title/body
  /// via reminderTitle()/reminderDescription() (settings_strings.dart) —
  /// previously this always scheduled def.title/def.description verbatim,
  /// so the on-screen Notification Settings list was translated but the
  /// real push notification that lands in the Android tray was English-only
  /// regardless of the user's selected app language. Defaults to English so
  /// every existing call site that hasn't been updated yet still compiles
  /// and behaves exactly as before.
  Future<void> scheduleReminder(ReminderTypeDef def, ReminderPref pref,
      {AppLanguage lang = AppLanguage.en}) async {
    await cancelReminder(def.notifId);
    if (!pref.enabled) return;
    if (!await hasPermission()) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, pref.hour, pref.minute);

    DateTimeComponents matchComponents;
    if (def.repeat == ReminderRepeat.daily) {
      if (!scheduled.isAfter(now))
        scheduled = scheduled.add(const Duration(days: 1));
      matchComponents = DateTimeComponents.time;
    } else {
      final targetWeekday =
          pref.weekday ?? def.defaultWeekday ?? DateTime.monday;
      var daysToAdd = (targetWeekday - scheduled.weekday) % 7;
      if (daysToAdd < 0) daysToAdd += 7;
      scheduled = scheduled.add(Duration(days: daysToAdd));
      if (!scheduled.isAfter(now))
        scheduled = scheduled.add(const Duration(days: 7));
      matchComponents = DateTimeComponents.dayOfWeekAndTime;
    }

    final channelId = def.isCritical ? kCriticalChannelId : kInfoChannelId;
    final channelName =
        def.isCritical ? kCriticalChannelName : kInfoChannelName;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance:
            def.isCritical ? Importance.max : Importance.defaultImportance,
        priority: def.isCritical ? Priority.high : Priority.defaultPriority,
        playSound: def.isCritical,
        enableVibration: def.isCritical,
      ),
    );

    Future<void> doSchedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          def.notifId,
          reminderTitle(lang, def.key, def.title),
          reminderDescription(lang, def.key, def.description),
          scheduled,
          details,
          androidScheduleMode: mode,
          matchDateTimeComponents: matchComponents,
          payload: def.key,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );

    try {
      // "Exact alarms when supported" — falls back to an inexact (but
      // still power-efficient, allowWhileIdle) schedule on any device/OS
      // version where the exact-alarm permission isn't available, rather
      // than crashing reminder setup entirely.
      await doSchedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      if (kDebugMode)
        debugPrint(
            '[LocalNotificationService] exact schedule failed, falling back: $e');
      await doSchedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  Future<void> cancelReminder(int notifId) async {
    try {
      await _plugin.cancel(notifId);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
