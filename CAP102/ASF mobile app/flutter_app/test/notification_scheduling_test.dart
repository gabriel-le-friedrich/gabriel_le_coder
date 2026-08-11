// ══════════════════════════════════════════════════════════════════════
// Verifies the notification scheduling engine's TESTABLE pure logic —
// flutter_local_notifications itself can't run in a widget-test sandbox
// (it talks to the real Android AlarmManager), so this locks down the two
// things that actually determine "reminders fire correctly, once, with no
// duplicates, and reschedule after login/reboot":
//
// 1. kReminderTypes' notifId/key uniqueness — LocalNotificationService.
//    scheduleReminder() and NotificationRepository.rescheduleAll() both
//    rely on "one fixed OS notification id per reminder type, cancelled
//    then rescheduled" to guarantee no duplicate ever stacks. If two
//    reminder types ever accidentally shared a notifId, the second would
//    silently overwrite (cancel) the first's OS-scheduled alarm — this
//    test fails loudly instead if that ever regresses.
// 2. nextOccurrence()'s daily/weekly rollover math — this is the exact
//    same algorithm LocalNotificationService.scheduleReminder() uses
//    internally to compute its `scheduled` TZDateTime before calling
//    zonedSchedule(...) with matchDateTimeComponents. Testing it here is
//    the closest thing to testing "does the reminder actually fire at
//    the right time" without a real device/emulator in this environment.
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';

import 'package:asf_flutter/features/notifications/domain/notification_prefs.dart';
import 'package:asf_flutter/features/notifications/domain/reminder_types.dart';

void main() {
  group('kReminderTypes registry — duplicate-schedule guard', () {
    test('every reminder type has a unique notifId', () {
      final ids = kReminderTypes.map((d) => d.notifId).toList();
      expect(ids.toSet().length, ids.length,
          reason:
              'Two reminder types sharing a notifId would silently overwrite '
              "each other's OS-scheduled alarm — cancel-then-schedule only "
              'prevents duplicates if every type has its own fixed id.');
    });

    test('every reminder type has a unique, stable persistence key', () {
      final keys = kReminderTypes.map((d) => d.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('exactly the 9 documented reminder types exist', () {
      expect(kReminderTypes.length, 9);
      expect(
        kReminderTypes.map((d) => d.key).toSet(),
        {
          'feeding',
          'health',
          'weighin',
          'photo',
          'vaccination',
          'medication',
          'marketDay',
          'productionDay',
          'backup',
        },
      );
    });

    test(
        'findReminderType resolves every registered key and rejects unknown ones',
        () {
      for (final def in kReminderTypes) {
        expect(findReminderType(def.key), same(def));
      }
      expect(findReminderType('not_a_real_key'), isNull);
    });
  });

  group('NotificationPrefs JSON round-trip', () {
    test('defaults() produces one enabled pref per reminder type', () {
      final prefs = NotificationPrefs.defaults();
      expect(prefs.masterEnabled, isTrue);
      for (final def in kReminderTypes) {
        final pref = prefs.prefFor(def.key);
        expect(pref.enabled, isTrue);
        expect(pref.hour, def.defaultHour);
        expect(pref.minute, def.defaultMinute);
        expect(pref.weekday, def.defaultWeekday);
      }
    });

    test(
        'toJson/fromJson preserves every field exactly, including a disabled reminder',
        () {
      final original = NotificationPrefs.defaults().withUpdatedPref(
        'health',
        const ReminderPref(enabled: false, hour: 20, minute: 15, weekday: null),
      );
      final restored = NotificationPrefs.fromJson(original.toJson());

      expect(restored.masterEnabled, original.masterEnabled);
      for (final def in kReminderTypes) {
        final a = original.prefFor(def.key);
        final b = restored.prefFor(def.key);
        expect(b.enabled, a.enabled, reason: 'mismatch for ${def.key}');
        expect(b.hour, a.hour, reason: 'mismatch for ${def.key}');
        expect(b.minute, a.minute, reason: 'mismatch for ${def.key}');
        expect(b.weekday, a.weekday, reason: 'mismatch for ${def.key}');
      }
    });

    test(
        'fromJson tolerates a missing/legacy key by falling back to that type\'s default',
        () {
      final restored = NotificationPrefs.fromJson(
          {'masterEnabled': true, 'byKey': <String, dynamic>{}});
      for (final def in kReminderTypes) {
        expect(restored.prefFor(def.key).hour, def.defaultHour);
      }
    });
  });

  group('nextOccurrence — daily reminder rollover math', () {
    test('later today when the reminder time has not yet passed', () {
      final prefs = NotificationPrefs.defaults();
      final now = DateTime(2026, 7, 26, 6, 0); // 06:00, feeding fires 07:30
      final next = nextOccurrence(prefs, 'feeding', now);
      expect(next, DateTime(2026, 7, 26, 7, 30));
    });

    test('rolls to tomorrow once the reminder time has already passed today',
        () {
      final prefs = NotificationPrefs.defaults();
      final now = DateTime(2026, 7, 26, 12, 0); // past 07:30
      final next = nextOccurrence(prefs, 'feeding', now);
      expect(next, DateTime(2026, 7, 27, 7, 30));
    });

    test(
        'exactly-at-time counts as already passed (rolls to tomorrow), matching scheduleReminder\'s isAfter check',
        () {
      final prefs = NotificationPrefs.defaults();
      final now = DateTime(2026, 7, 26, 7, 30); // exactly the feeding time
      final next = nextOccurrence(prefs, 'feeding', now);
      expect(next, DateTime(2026, 7, 27, 7, 30));
    });
  });

  group('nextOccurrence — weekly reminder rollover math', () {
    test('later this week when the target weekday has not yet arrived', () {
      final prefs = NotificationPrefs.defaults();
      // weighin defaults to Sunday 09:00. 2026-07-26 is a Sunday.
      final wednesday = DateTime(2026, 7, 22, 8, 0); // Wed before that Sunday
      final next = nextOccurrence(prefs, 'weighin', wednesday);
      expect(next, DateTime(2026, 7, 26, 9, 0));
      expect(next!.weekday, DateTime.sunday);
    });

    test('rolls a full 7 days once this week\'s target weekday/time has passed',
        () {
      final prefs = NotificationPrefs.defaults();
      final sundayAfternoon =
          DateTime(2026, 7, 26, 15, 0); // Sunday, after 09:00
      final next = nextOccurrence(prefs, 'weighin', sundayAfternoon);
      expect(next, DateTime(2026, 8, 2, 9, 0));
      expect(next!.weekday, DateTime.sunday);
    });
  });

  group('nextOccurrence — disabled states return null (no phantom reminder)',
      () {
    test(
        'master switch off suppresses every reminder regardless of its own enabled flag',
        () {
      final prefs = NotificationPrefs.defaults().copyWith(masterEnabled: false);
      expect(nextOccurrence(prefs, 'feeding', DateTime(2026, 7, 26)), isNull);
    });

    test('an individually disabled reminder returns null even with master on',
        () {
      final prefs = NotificationPrefs.defaults().withUpdatedPref(
        'health',
        const ReminderPref(enabled: false, hour: 8, minute: 0),
      );
      expect(nextOccurrence(prefs, 'health', DateTime(2026, 7, 26)), isNull);
    });

    test('an unknown reminder key returns null', () {
      final prefs = NotificationPrefs.defaults();
      expect(nextOccurrence(prefs, 'not_a_real_key', DateTime(2026, 7, 26)),
          isNull);
    });
  });
}
