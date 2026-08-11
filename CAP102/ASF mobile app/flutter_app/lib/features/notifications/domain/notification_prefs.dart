// ══════════════════════════════════════════════════════════════════════
// Persisted notification preferences — one ReminderPref per reminder type,
// plus a master enable switch. Stored as a single JSON blob (settings/
// subkey 'notificationPrefs'), matching the same aggregate-blob pattern as
// pigBatchProfile/weightLogs/expenses/healthLogs elsewhere in this app.
// ══════════════════════════════════════════════════════════════════════

import 'reminder_types.dart';

class ReminderPref {
  const ReminderPref(
      {required this.enabled,
      required this.hour,
      required this.minute,
      this.weekday});

  final bool enabled;
  final int hour;
  final int minute;
  final int?
      weekday; // DateTime.monday..sunday — only meaningful for weekly reminders

  ReminderPref copyWith({bool? enabled, int? hour, int? minute, int? weekday}) {
    return ReminderPref(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekday: weekday ?? this.weekday,
    );
  }

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  factory ReminderPref.fromDefault(ReminderTypeDef def) => ReminderPref(
        enabled: true,
        hour: def.defaultHour,
        minute: def.defaultMinute,
        weekday: def.defaultWeekday,
      );

  factory ReminderPref.fromJson(
          Map<String, dynamic> json, ReminderTypeDef def) =>
      ReminderPref(
        enabled: json['enabled'] as bool? ?? true,
        hour: (json['hour'] as num?)?.toInt() ?? def.defaultHour,
        minute: (json['minute'] as num?)?.toInt() ?? def.defaultMinute,
        weekday: (json['weekday'] as num?)?.toInt() ?? def.defaultWeekday,
      );

  Map<String, dynamic> toJson() =>
      {'enabled': enabled, 'hour': hour, 'minute': minute, 'weekday': weekday};

  bool sameAs(ReminderPref other) =>
      enabled == other.enabled &&
      hour == other.hour &&
      minute == other.minute &&
      weekday == other.weekday;
}

class NotificationPrefs {
  const NotificationPrefs({required this.masterEnabled, required this.byKey});

  final bool masterEnabled;
  final Map<String, ReminderPref> byKey;

  ReminderPref prefFor(String key) {
    final def = findReminderType(key);
    return byKey[key] ??
        (def != null
            ? ReminderPref.fromDefault(def)
            : const ReminderPref(enabled: false, hour: 8, minute: 0));
  }

  NotificationPrefs copyWith(
      {bool? masterEnabled, Map<String, ReminderPref>? byKey}) {
    return NotificationPrefs(
        masterEnabled: masterEnabled ?? this.masterEnabled,
        byKey: byKey ?? this.byKey);
  }

  NotificationPrefs withUpdatedPref(String key, ReminderPref pref) {
    final updated = Map<String, ReminderPref>.from(byKey);
    updated[key] = pref;
    return copyWith(byKey: updated);
  }

  factory NotificationPrefs.defaults() {
    return NotificationPrefs(
      masterEnabled: true,
      byKey: {
        for (final def in kReminderTypes) def.key: ReminderPref.fromDefault(def)
      },
    );
  }

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    final rawByKey = Map<String, dynamic>.from((json['byKey'] as Map?) ?? {});
    final byKey = <String, ReminderPref>{};
    for (final def in kReminderTypes) {
      final raw = rawByKey[def.key];
      byKey[def.key] = raw != null
          ? ReminderPref.fromJson(Map<String, dynamic>.from(raw as Map), def)
          : ReminderPref.fromDefault(def);
    }
    return NotificationPrefs(
        masterEnabled: json['masterEnabled'] as bool? ?? true, byKey: byKey);
  }

  Map<String, dynamic> toJson() => {
        'masterEnabled': masterEnabled,
        'byKey': byKey.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// The next DateTime a reminder would fire, given [now] — used by the
/// Dashboard's "Upcoming Reminder" card. Returns null if the reminder (or
/// the master switch) is disabled.
DateTime? nextOccurrence(NotificationPrefs prefs, String key, DateTime now) {
  if (!prefs.masterEnabled) return null;
  final def = findReminderType(key);
  if (def == null) return null;
  final pref = prefs.prefFor(key);
  if (!pref.enabled) return null;

  if (def.repeat == ReminderRepeat.daily) {
    var next = DateTime(now.year, now.month, now.day, pref.hour, pref.minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  final targetWeekday = pref.weekday ?? def.defaultWeekday ?? DateTime.monday;
  var next = DateTime(now.year, now.month, now.day, pref.hour, pref.minute);
  var daysToAdd = (targetWeekday - next.weekday) % 7;
  if (daysToAdd < 0) daysToAdd += 7;
  next = next.add(Duration(days: daysToAdd));
  if (!next.isAfter(now)) next = next.add(const Duration(days: 7));
  return next;
}

const List<String> kWeekdayShortNames = [
  '',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun'
];
