// ══════════════════════════════════════════════════════════════════════
// Riverpod state for the Notification Settings screen. Edits happen on a
// DRAFT copy of the prefs; nothing is persisted/scheduled/logged until the
// user taps Save — this is what backs "Save confirmation" and
// "Unsaved-changes detection" in the spec, and keeps the Activity Log from
// getting one entry per single chip tap.
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/local_notification_service.dart';
import '../../data/notification_repository.dart';
import '../../domain/notification_prefs.dart';
import '../../domain/reminder_types.dart';

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository());

class NotificationSettingsState {
  const NotificationSettingsState({
    required this.saved,
    required this.draft,
    this.isSaving = false,
    this.message,
    this.errorMessage,
  });

  final NotificationPrefs saved;
  final NotificationPrefs draft;
  final bool isSaving;
  final String? message;
  final String? errorMessage;

  bool get hasUnsavedChanges {
    if (saved.masterEnabled != draft.masterEnabled) return true;
    for (final def in kReminderTypes) {
      if (!saved.prefFor(def.key).sameAs(draft.prefFor(def.key))) return true;
    }
    return false;
  }

  NotificationSettingsState copyWith({
    NotificationPrefs? saved,
    NotificationPrefs? draft,
    bool? isSaving,
    String? message,
    bool clearMessage = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationSettingsState(
      saved: saved ?? this.saved,
      draft: draft ?? this.draft,
      isSaving: isSaving ?? this.isSaving,
      message: clearMessage ? null : (message ?? this.message),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class NotificationSettingsController
    extends StateNotifier<AsyncValue<NotificationSettingsState>> {
  NotificationSettingsController(this._repo, this._uid)
      : super(const AsyncValue.loading()) {
    load();
  }

  final NotificationRepository _repo;
  final String _uid;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await _repo.getPrefs(_uid);
      state = AsyncValue.data(
          NotificationSettingsState(saved: prefs, draft: prefs));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void toggleMaster(bool enabled) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
        draft: current.draft.copyWith(masterEnabled: enabled),
        clearMessage: true));
  }

  /// Toggling a reminder ON requests the OS permission immediately (a
  /// discrete grant/deny event, not a value change) and records it right
  /// away rather than waiting for Save.
  Future<void> toggleReminder(String key, bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (enabled && !await LocalNotificationService.instance.hasPermission()) {
      final granted =
          await LocalNotificationService.instance.requestPermission();
      await _repo.recordPermissionResult(_uid, granted);
      if (!granted) {
        final latest = state.valueOrNull;
        if (latest != null) {
          state = AsyncValue.data(latest.copyWith(
            errorMessage:
                'Notification permission was denied — enable it in system settings to receive reminders.',
          ));
        }
      }
    }
    final pref = current.draft.prefFor(key);
    _updateDraftPref(key, pref.copyWith(enabled: enabled));
  }

  void updateTime(String key, int hour, int minute) {
    final current = state.valueOrNull;
    if (current == null) return;
    _updateDraftPref(
        key, current.draft.prefFor(key).copyWith(hour: hour, minute: minute));
  }

  void updateWeekday(String key, int weekday) {
    final current = state.valueOrNull;
    if (current == null) return;
    _updateDraftPref(
        key, current.draft.prefFor(key).copyWith(weekday: weekday));
  }

  void _updateDraftPref(String key, ReminderPref pref) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
        draft: current.draft.withUpdatedPref(key, pref), clearMessage: true));
  }

  Future<void> save() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasUnsavedChanges) return;
    state = AsyncValue.data(current.copyWith(isSaving: true, clearError: true));
    try {
      if (current.saved.masterEnabled != current.draft.masterEnabled) {
        await _repo.setMasterEnabled(_uid, current.draft.masterEnabled);
      }
      for (final def in kReminderTypes) {
        final oldPref = current.saved.prefFor(def.key);
        final newPref = current.draft.prefFor(def.key);
        if (!oldPref.sameAs(newPref)) {
          await _repo.setReminder(_uid, def.key, newPref);
        }
      }
      final refreshed = await _repo.getPrefs(_uid);
      state = AsyncValue.data(NotificationSettingsState(
        saved: refreshed,
        draft: refreshed,
        message: 'Notification preferences saved.',
      ));
    } catch (_) {
      state = AsyncValue.data(current.copyWith(
          isSaving: false,
          errorMessage:
              'Could not save notification preferences. Please try again.'));
    }
  }

  void discardChanges() {
    final current = state.valueOrNull;
    if (current != null)
      state = AsyncValue.data(current.copyWith(
          draft: current.saved, clearMessage: true, clearError: true));
  }

  Future<void> resetToDefaults() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.resetToDefaults(_uid);
      final refreshed = await _repo.getPrefs(_uid);
      state = AsyncValue.data(NotificationSettingsState(
        saved: refreshed,
        draft: refreshed,
        message: 'Notification preferences reset to defaults.',
      ));
    } catch (_) {
      state = AsyncValue.data(current.copyWith(
          isSaving: false,
          errorMessage:
              'Could not reset notification preferences. Please try again.'));
    }
  }

  void clearMessages() {
    final current = state.valueOrNull;
    if (current != null)
      state = AsyncValue.data(
          current.copyWith(clearMessage: true, clearError: true));
  }
}

final notificationSettingsControllerProvider = StateNotifierProvider.autoDispose
    .family<NotificationSettingsController,
        AsyncValue<NotificationSettingsState>, String>((ref, uid) {
  return NotificationSettingsController(
      ref.watch(notificationRepositoryProvider), uid);
});

/// Read-only prefs for widgets that just need to DISPLAY upcoming reminders
/// (Dashboard) without pulling in the full Settings controller/draft state.
final notificationPrefsProvider =
    FutureProvider.autoDispose.family<NotificationPrefs, String>((ref, uid) {
  return ref.watch(notificationRepositoryProvider).getPrefs(uid);
});

/// Reconciles OS-scheduled reminders with saved prefs once per app session
/// per signed-in user — watched once from the Dashboard route wrapper (see
/// app_router.dart's _DashboardRoute) so a fresh install, a reboot, or an
/// app update all end up with the right reminders scheduled without the
/// user having to reopen Settings.
final notificationBootstrapProvider =
    FutureProvider.autoDispose.family<void, String>((ref, uid) {
  return ref.watch(notificationRepositoryProvider).rescheduleAll(uid);
});
