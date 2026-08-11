// ══════════════════════════════════════════════════════════════════════
// The 9 reminder types this Flutter app supports — an intentional
// expansion of the web/Capacitor app's original 5 (morning/afternoon
// feeding, weekly weigh-in, supplement, health), which only covered
// feeding + weigh-in + a generic supplement slot. Weekly Photo, Vaccination
// (split out from "supplement"), Medication, Market Day, Production Day,
// and Backup are new. Each type gets a fixed local-notification id (never
// reused across types) so rescheduling always cancels-and-replaces the
// right slot instead of stacking duplicates — same principle as the web
// app's NOTIF_IDS map in src/notifications.js.
// ══════════════════════════════════════════════════════════════════════

enum ReminderRepeat { daily, weekly }

/// Notification channel ids (Android 8+ requires a channel per notification).
/// Critical reminders (Market Day, Health Check) use a high-importance,
/// sound-on channel; everything else is a quieter, default-importance
/// "informational" channel — matches the spec's "High priority for Critical
/// reminders / Silent reminders for informational notifications."
const String kCriticalChannelId = 'asf_critical_reminders';
const String kCriticalChannelName = 'Critical Reminders';
const String kInfoChannelId = 'asf_reminders';
const String kInfoChannelName = 'Reminders';

class ReminderTypeDef {
  const ReminderTypeDef({
    required this.key,
    required this.notifId,
    required this.title,
    required this.description,
    required this.repeat,
    required this.defaultHour,
    required this.defaultMinute,
    this.defaultWeekday,
    this.isCritical = false,
  });

  final String key; // stable persistence key — never rename once shipped
  final int notifId; // fixed local-notification id
  final String title;
  final String description; // shown under the switch in Settings
  final ReminderRepeat repeat;
  final int defaultHour;
  final int defaultMinute;
  final int? defaultWeekday; // DateTime.monday..sunday (1-7), weekly only
  final bool isCritical;
}

const List<ReminderTypeDef> kReminderTypes = [
  ReminderTypeDef(
    key: 'feeding',
    notifId: 2001,
    title: 'Daily Feeding',
    description: 'Reminds you to feed your pigs at the same time every day.',
    repeat: ReminderRepeat.daily,
    defaultHour: 7,
    defaultMinute: 30,
  ),
  ReminderTypeDef(
    key: 'health',
    notifId: 2002,
    title: 'Health Check',
    description: "Reminds you to log today's Health Monitor observation.",
    repeat: ReminderRepeat.daily,
    defaultHour: 8,
    defaultMinute: 0,
    isCritical: true,
  ),
  ReminderTypeDef(
    key: 'weighin',
    notifId: 2003,
    title: 'Weekly Weigh-in',
    description: "Reminds you to record this week's official pig weight.",
    repeat: ReminderRepeat.weekly,
    defaultHour: 9,
    defaultMinute: 0,
    defaultWeekday: DateTime.sunday,
  ),
  ReminderTypeDef(
    key: 'photo',
    notifId: 2004,
    title: 'Weekly Photo',
    description:
        "Reminds you to capture this week's progress photo for each pig.",
    repeat: ReminderRepeat.weekly,
    defaultHour: 9,
    defaultMinute: 30,
    defaultWeekday: DateTime.sunday,
  ),
  ReminderTypeDef(
    key: 'vaccination',
    notifId: 2005,
    title: 'Vaccination',
    description: 'Reminds you to check whether any vaccinations are due.',
    repeat: ReminderRepeat.weekly,
    defaultHour: 8,
    defaultMinute: 0,
    defaultWeekday: DateTime.monday,
  ),
  ReminderTypeDef(
    key: 'medication',
    notifId: 2006,
    title: 'Medication',
    description: 'Reminds you to administer any scheduled medication.',
    repeat: ReminderRepeat.daily,
    defaultHour: 8,
    defaultMinute: 0,
  ),
  ReminderTypeDef(
    key: 'marketDay',
    notifId: 2007,
    title: 'Market Day',
    description:
        'Alerts you as the 120-day production cycle approaches its end.',
    repeat: ReminderRepeat.daily,
    defaultHour: 7,
    defaultMinute: 0,
    isCritical: true,
  ),
  ReminderTypeDef(
    key: 'productionDay',
    notifId: 2008,
    title: 'Production Day Reminder',
    description:
        "Reminds you to complete today's production tasks and advance the day.",
    repeat: ReminderRepeat.daily,
    defaultHour: 6,
    defaultMinute: 30,
  ),
  ReminderTypeDef(
    key: 'backup',
    notifId: 2009,
    title: 'Backup Reminder',
    description: 'Reminds you to export a CSV/PDF backup of your records.',
    repeat: ReminderRepeat.weekly,
    defaultHour: 18,
    defaultMinute: 0,
    defaultWeekday: DateTime.friday,
  ),
];

ReminderTypeDef? findReminderType(String key) {
  for (final r in kReminderTypes) {
    if (r.key == key) return r;
  }
  return null;
}
