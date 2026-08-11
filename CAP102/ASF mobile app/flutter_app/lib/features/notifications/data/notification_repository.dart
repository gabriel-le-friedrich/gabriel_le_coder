// ══════════════════════════════════════════════════════════════════════
// Notification preferences data access. Stored as settings/subkey
// 'notificationPrefs' (one JSON blob), matching every other aggregate in
// this app (pigBatchProfile/weightLogs/expenses/healthLogs). Supabase's
// existing notification_settings table only has fixed columns for the
// original 5 reminder types (morning/afternoon/weekly/supplement — see
// supabase_schema.sql), which can't hold this app's 9-type shape, so the
// mirror goes to the generic settings table instead, exactly like every
// other aggregate here — a first-class notification_settings redesign
// would need its own Supabase migration.
//
// Activity logging happens HERE (not in the UI layer) so every write path
// — Settings screen Save, Reset to Defaults, or a future automated change
// — produces the same precise log line.
// ══════════════════════════════════════════════════════════════════════

import '../../../core/config/supabase_config.dart';
import '../../../core/database/sqlite_service.dart';
import '../../../core/services/device_id_service.dart';
import '../../../core/services/local_notification_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../domain/notification_prefs.dart';
import '../domain/reminder_types.dart';

class NotificationRepository {
  NotificationRepository(
      {AuthRepository? authRepo, SettingsRepository? settingsRepo})
      : _authRepo = authRepo ?? AuthRepository(),
        _settingsRepo = settingsRepo ?? SettingsRepository();

  final SqliteService _sqlite = SqliteService.instance;
  final AuthRepository _authRepo;
  final SettingsRepository _settingsRepo;
  final LocalNotificationService _notifs = LocalNotificationService.instance;

  Future<NotificationPrefs> getPrefs(String uid) async {
    final data = await _sqlite.getAggregate('settings', uid,
        subkey: 'notificationPrefs');
    if (data == null) return NotificationPrefs.defaults();
    return NotificationPrefs.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Production audit finding: this repository only ever pushed local
  /// prefs to Supabase (resyncPending/_savePrefs) — there was no path
  /// back down, so a fresh device/reinstall (no local `notificationPrefs`
  /// row yet) silently fell back to [NotificationPrefs.defaults] instead
  /// of the reminder schedule the farmer actually set on another device.
  /// Same "pull only when local is empty" guard as every other
  /// pullFromCloudIfEmpty in this app — an existing device's own
  /// unsynced edit (this aggregate has no per-row `synced` flag, so
  /// "empty" is the only safe signal) is never clobbered.
  Future<void> pullFromCloudIfEmpty(String uid) async {
    try {
      final local = await _sqlite.getAggregate('settings', uid,
          subkey: 'notificationPrefs');
      if (local != null) return;
      final res = await supabase
          .from('settings')
          .select('data')
          .eq('firebase_uid', uid)
          .eq('subkey', 'notificationPrefs')
          .maybeSingle();
      if (res == null) return;
      final prefs = NotificationPrefs.fromJson(
          Map<String, dynamic>.from(res['data'] as Map));
      await _sqlite.setAggregate(
          'settings', uid, 'notificationPrefs', prefs.toJson(),
          synced: true);
      await rescheduleAll(uid);
    } catch (_) {
      // Offline/unreachable — getPrefs()'s default fallback still applies
      // until the next sync pass succeeds.
    }
  }

  Future<void> _savePrefs(String uid, NotificationPrefs prefs) async {
    final nowMs = SqliteService.nowMs();
    await _sqlite.setAggregate(
        'settings', uid, 'notificationPrefs', prefs.toJson());
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'notificationPrefs',
        'data': prefs.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(nowMs),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}
  }

  /// Sync engine support — re-pushes the current prefs blob. Idempotent
  /// (same subkey upsert as every save), so safe to call on every
  /// reconnect regardless of whether the previous push actually failed.
  Future<void> resyncPending(String uid) async {
    final prefs = await getPrefs(uid);
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'notificationPrefs',
        'data': prefs.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}
  }

  /// Reconciles every OS-scheduled reminder with the saved prefs — cancels
  /// everything if the master switch is off, otherwise schedules/cancels
  /// each type individually. Call once per app session after auth resolves
  /// (covers "restore after reboot" as a belt-and-suspenders on top of the
  /// Android boot receiver, and "restore after app update" outright, since
  /// an update can't be relied on to preserve AlarmManager state).
  Future<void> rescheduleAll(String uid) async {
    final prefs = await getPrefs(uid);
    await LocalNotificationService.instance.init();
    if (!prefs.masterEnabled) {
      await _notifs.cancelAll();
      return;
    }
    final lang = await _settingsRepo.getLanguage(uid);
    for (final def in kReminderTypes) {
      await _notifs.scheduleReminder(def, prefs.prefFor(def.key), lang: lang);
    }
  }

  Future<void> setMasterEnabled(String uid, bool enabled) async {
    final prefs = await getPrefs(uid);
    final updated = prefs.copyWith(masterEnabled: enabled);
    await _savePrefs(uid, updated);
    if (enabled) {
      final lang = await _settingsRepo.getLanguage(uid);
      for (final def in kReminderTypes) {
        await _notifs.scheduleReminder(def, updated.prefFor(def.key),
            lang: lang);
      }
    } else {
      await _notifs.cancelAll();
    }
    await _authRepo.recordActivityLog(
      uid: uid,
      actionType: 'notifications',
      description:
          enabled ? 'Enabled all notifications' : 'Disabled all notifications',
    );
  }

  /// Updates one reminder's pref, reschedules just that one, and logs the
  /// precise change — matching the spec's example log lines exactly
  /// ("Enabled Health Reminder", "Changed Weekly Weigh-in Time").
  Future<void> setReminder(String uid, String key, ReminderPref newPref) async {
    final def = findReminderType(key);
    if (def == null) return;
    final prefs = await getPrefs(uid);
    final oldPref = prefs.prefFor(key);
    final updated = prefs.withUpdatedPref(key, newPref);
    await _savePrefs(uid, updated);

    if (prefs.masterEnabled) {
      final lang = await _settingsRepo.getLanguage(uid);
      await _notifs.scheduleReminder(def, newPref, lang: lang);
    }

    if (oldPref.enabled != newPref.enabled) {
      await _authRepo.recordActivityLog(
        uid: uid,
        actionType: 'notifications',
        description:
            '${newPref.enabled ? 'Enabled' : 'Disabled'} ${def.title} Reminder',
      );
    } else if (oldPref.hour != newPref.hour ||
        oldPref.minute != newPref.minute ||
        oldPref.weekday != newPref.weekday) {
      await _authRepo.recordActivityLog(
        uid: uid,
        actionType: 'notifications',
        description:
            'Changed ${def.title} Reminder time to ${newPref.timeLabel}',
      );
    }
  }

  Future<void> resetToDefaults(String uid) async {
    final defaults = NotificationPrefs.defaults();
    await _savePrefs(uid, defaults);
    if (defaults.masterEnabled) {
      final lang = await _settingsRepo.getLanguage(uid);
      for (final def in kReminderTypes) {
        await _notifs.scheduleReminder(def, defaults.prefFor(def.key),
            lang: lang);
      }
    } else {
      await _notifs.cancelAll();
    }
    await _authRepo.recordActivityLog(
        uid: uid,
        actionType: 'notifications',
        description: 'Reset Notification Preferences');
  }

  Future<void> recordPermissionResult(String uid, bool granted) async {
    await _authRepo.recordActivityLog(
      uid: uid,
      actionType: 'notifications',
      description: granted
          ? 'Granted Notification Permission'
          : 'Denied Notification Permission',
    );
  }
}
