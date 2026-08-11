/* ═══════════════════════════════════════════════════════════════════════
   ASF — Local (on-device) Reminder Notifications
   ═══════════════════════════════════════════════════════════════════════
   Real, native scheduled notifications via @capacitor/local-notifications
   (Android AlarmManager / iOS UNCalendarNotificationTrigger under the
   hood) — NOT push notifications, so this works fully offline and needs
   no server/Firebase Cloud Messaging component.

   Permission is requested contextually, only when the user reaches the
   "Set Reminders" step of onboarding (or later opens Settings ▸
   Notifications) — never at app startup — per the app's permission
   policy (see index.html's camera/gallery inputs, which follow the same
   just-in-time principle).

   Reminder prefs shape (as already produced/consumed by index.html's
   getNotifPrefs()/saveNotifPrefs()):
     {
       morning:    { enabled: bool, time: 'h:mm AM/PM' },
       afternoon:  { enabled: bool, time: 'h:mm AM/PM' },
       weighin:    { enabled: bool, time: 'h:mm AM/PM', day: 0-6 (0=Sun) },
       supplement: { enabled: bool, freq: 'weekly'|'biweekly'|'monthly'|'custom' },
       health:     { enabled: bool, time: 'h:mm AM/PM' },
     }
   ═══════════════════════════════════════════════════════════════════════ */

import { LocalNotifications } from '@capacitor/local-notifications';

// Fixed notification IDs — one slot per reminder type, so re-scheduling
// (e.g. after the user edits a time) always cancels-and-replaces cleanly
// instead of stacking duplicates.
const NOTIF_IDS = {
  morning: 1001,
  afternoon: 1002,
  weighin: 1003,
  supplement: 1004,
  health: 1005,
};

// The Supplement Reminder UI (Settings ▸ Notifications) only offers a
// frequency dropdown (weekly/biweekly/monthly/custom), not a time-of-day
// or day-of-week picker. These internal defaults give it a concrete,
// schedulable moment without adding a new control the app's UI never had.
const SUPPLEMENT_DEFAULT_TIME = '9:00 AM';
const SUPPLEMENT_DEFAULT_WEEKDAY = 0; // Sunday, same default as Weekly Weigh-In

const FRIENDLY_DENIED_MESSAGE =
  'Notifications are required to remind you about feeding and health monitoring.';

/* ── Time parsing ─────────────────────────────────────────────────────── */

// '7:30 AM' / '2:00 PM' -> { hour: 0-23, minute: 0-59 }. Falls back to a
// safe default if the string is missing/malformed rather than throwing —
// reminders should never crash the app.
function parseTimeString(timeStr, fallback = { hour: 7, minute: 0 }) {
  if (!timeStr || typeof timeStr !== 'string') return fallback;
  const m = timeStr.trim().match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/i);
  if (!m) return fallback;
  let hour = parseInt(m[1], 10);
  const minute = parseInt(m[2], 10);
  const period = m[3].toUpperCase();
  if (period === 'PM' && hour !== 12) hour += 12;
  if (period === 'AM' && hour === 12) hour = 0;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
  return { hour, minute };
}

// JS/app weekday convention here is 0=Sunday..6=Saturday (matches the
// <select> in index.html). Capacitor/iOS's `on.weekday` is 1=Sunday..7=Saturday.
function toCapacitorWeekday(jsDay) {
  const d = Number.isInteger(jsDay) ? jsDay : 0;
  return ((d % 7) + 7) % 7 + 1;
}

/* ── Permission ────────────────────────────────────────────────────────── */

// Returns { granted: true } or { granted: false, message: <friendly text> }.
// Never throws — every call site can treat the result uniformly and never
// crash the app if the plugin is unavailable (e.g. running in a plain
// browser tab during development).
export async function requestNotificationPermission() {
  try {
    const current = await LocalNotifications.checkPermissions();
    if (current.display === 'granted') return { granted: true };

    const result = await LocalNotifications.requestPermissions();
    if (result.display === 'granted') return { granted: true };

    return { granted: false, message: FRIENDLY_DENIED_MESSAGE };
  } catch (err) {
    console.warn('[ASF Notifications] permission check/request failed', err);
    return { granted: false, message: FRIENDLY_DENIED_MESSAGE };
  }
}

export async function hasNotificationPermission() {
  try {
    const current = await LocalNotifications.checkPermissions();
    return current.display === 'granted';
  } catch {
    return false;
  }
}

/* ── Scheduling ────────────────────────────────────────────────────────── */

// Cancels every reminder slot this module owns. Safe to call even if
// nothing is scheduled yet (e.g. first run, or notifications were never
// granted) — cancel() on an unknown id is a no-op, not an error.
async function cancelAllReminders() {
  try {
    await LocalNotifications.cancel({
      notifications: Object.values(NOTIF_IDS).map((id) => ({ id })),
    });
  } catch (err) {
    console.warn('[ASF Notifications] cancel failed (non-fatal)', err);
  }
}

function buildDailyNotification(id, title, body, timeStr) {
  const { hour, minute } = parseTimeString(timeStr);
  return {
    id,
    title,
    body,
    schedule: { on: { hour, minute }, allowWhileIdle: true },
  };
}

function buildWeeklyNotification(id, title, body, timeStr, jsDay, everyOverride) {
  const { hour, minute } = parseTimeString(timeStr, { hour: 9, minute: 0 });
  const weekday = toCapacitorWeekday(jsDay);
  const schedule = { on: { weekday, hour, minute }, allowWhileIdle: true };
  if (everyOverride) schedule.every = everyOverride;
  return { id, title, body, schedule };
}

function buildMonthlyNotification(id, title, body, timeStr, dayOfMonth) {
  const { hour, minute } = parseTimeString(timeStr, { hour: 9, minute: 0 });
  return {
    id,
    title,
    body,
    schedule: { on: { day: dayOfMonth, hour, minute }, allowWhileIdle: true },
  };
}

// Rebuilds every reminder from scratch based on the current prefs object —
// always cancel-then-reschedule rather than diffing, since the volume of
// reminders (max 5) makes that far simpler and just as reliable. Must
// continue working fully offline: this only talks to the OS notification
// scheduler, never the network.
export async function scheduleAllReminders(prefs) {
  if (!prefs) return { scheduled: 0 };

  const granted = await hasNotificationPermission();
  if (!granted) return { scheduled: 0, reason: 'not-granted' };

  await cancelAllReminders();

  const toSchedule = [];

  if (prefs.morning?.enabled) {
    toSchedule.push(
      buildDailyNotification(
        NOTIF_IDS.morning,
        'Morning Feeding Reminder',
        "It's time for your pigs' morning feeding.",
        prefs.morning.time
      )
    );
  }

  if (prefs.afternoon?.enabled) {
    toSchedule.push(
      buildDailyNotification(
        NOTIF_IDS.afternoon,
        'Afternoon Feeding Reminder',
        "It's time for your pigs' afternoon feeding.",
        prefs.afternoon.time
      )
    );
  }

  if (prefs.weighin?.enabled) {
    toSchedule.push(
      buildWeeklyNotification(
        NOTIF_IDS.weighin,
        'Weekly Weigh-In Reminder',
        'Time to record this week’s pig weights.',
        prefs.weighin.time,
        prefs.weighin.day
      )
    );
  }

  if (prefs.supplement?.enabled) {
    const freq = prefs.supplement.freq || 'weekly';
    if (freq === 'weekly') {
      toSchedule.push(
        buildWeeklyNotification(
          NOTIF_IDS.supplement,
          'Supplement Reminder',
          "Don't forget your pigs' supplement today.",
          SUPPLEMENT_DEFAULT_TIME,
          SUPPLEMENT_DEFAULT_WEEKDAY
        )
      );
    } else if (freq === 'biweekly') {
      toSchedule.push(
        buildWeeklyNotification(
          NOTIF_IDS.supplement,
          'Supplement Reminder',
          "Don't forget your pigs' supplement today.",
          SUPPLEMENT_DEFAULT_TIME,
          SUPPLEMENT_DEFAULT_WEEKDAY,
          'two-weeks'
        )
      );
    } else if (freq === 'monthly') {
      toSchedule.push(
        buildMonthlyNotification(
          NOTIF_IDS.supplement,
          'Supplement Reminder',
          "Don't forget your pigs' supplement today.",
          SUPPLEMENT_DEFAULT_TIME,
          1 // 1st of the month — no day-of-month picker exists in the UI
        )
      );
    }
    // 'custom' has no defined cadence in the current UI — intentionally
    // not auto-scheduled; the user can still see/toggle it in Settings.
  }

  if (prefs.health?.enabled) {
    toSchedule.push(
      buildDailyNotification(
        NOTIF_IDS.health,
        'Health Check Reminder',
        "Don't forget to log today's Health Monitor observation.",
        prefs.health.time
      )
    );
  }

  if (!toSchedule.length) return { scheduled: 0 };

  try {
    await LocalNotifications.schedule({ notifications: toSchedule });
    return { scheduled: toSchedule.length };
  } catch (err) {
    console.warn('[ASF Notifications] schedule failed (non-fatal)', err);
    return { scheduled: 0, reason: 'schedule-error' };
  }
}

export async function cancelReminder(key) {
  const id = NOTIF_IDS[key];
  if (!id) return;
  try {
    await LocalNotifications.cancel({ notifications: [{ id }] });
  } catch (err) {
    console.warn('[ASF Notifications] cancelReminder failed (non-fatal)', err);
  }
}

export const AsfNotifications = {
  requestNotificationPermission,
  hasNotificationPermission,
  scheduleAllReminders,
  cancelReminder,
  FRIENDLY_DENIED_MESSAGE,
};

if (typeof window !== 'undefined') {
  window.AsfNotifications = AsfNotifications;
}
