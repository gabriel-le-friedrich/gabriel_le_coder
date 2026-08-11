// ══════════════════════════════════════════════════════════════════════
// Generic SQLite -> Supabase retry sync engine (the piece flagged as
// "a later slice" in several repositories' comments, and the main finding
// of the Offline Sync Audit: every repository already does a best-effort
// push at write time, but none of them ever retried a push that failed
// while offline — a row just sat with synced:0 forever until the user
// happened to edit it again).
//
// This does NOT replace each repository's own write-time push (that stays
// exactly as-is, for instant "online right now" syncing) — it's the
// missing other half: re-attempt every not-yet-confirmed write whenever
// connectivity is restored, using each repository's own already-correct
// mirror logic (never re-deriving Supabase payload shapes here, to avoid
// introducing a second, possibly-drifted copy of that logic).
//
// Real per-row retry paths with a genuine synced flag (weeklyPigImages,
// pigs, the user profile row + its avatar) and five idempotent full-resync
// paths (expenses, health, weigh-ins, settings/theme+language, notification
// prefs — all upsert-keyed so re-sending an already-synced value is a
// harmless no-op, not a duplicate) are covered. See each repository's
// resyncPending()/resyncPendingImages()/resyncPendingPigs()/
// resyncPendingProfile() for the per-table detail.
// ══════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../features/activity_log/data/activity_log_repository.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/consultation/data/consultation_repository.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/email/data/email_repository.dart';
import '../../features/expenses/data/expenses_repository.dart';
import '../../features/health/data/health_repository.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/pigs/data/pig_repository.dart';
import '../../features/settings/data/settings_repository.dart';

class SyncEngine {
  SyncEngine({
    ActivityLogRepository? activityLogRepo,
    PigRepository? pigRepo,
    ExpensesRepository? expensesRepo,
    HealthRepository? healthRepo,
    DashboardRepository? dashboardRepo,
    SettingsRepository? settingsRepo,
    NotificationRepository? notificationRepo,
    AuthRepository? authRepo,
    EmailRepository? emailRepo,
    ConsultationRepository? consultationRepo,
  })  : _activityLogRepo = activityLogRepo ?? ActivityLogRepository(),
        _pigRepo = pigRepo ?? PigRepository(),
        _expensesRepo = expensesRepo ?? ExpensesRepository(),
        _healthRepo = healthRepo ?? HealthRepository(),
        _dashboardRepo = dashboardRepo ?? DashboardRepository(),
        _settingsRepo = settingsRepo ?? SettingsRepository(),
        _notificationRepo = notificationRepo ?? NotificationRepository(),
        _authRepo = authRepo ?? AuthRepository(),
        _emailRepo = emailRepo ?? EmailRepository(),
        _consultationRepo = consultationRepo ?? ConsultationRepository();

  final ActivityLogRepository _activityLogRepo;
  final PigRepository _pigRepo;
  final ExpensesRepository _expensesRepo;
  final HealthRepository _healthRepo;
  final DashboardRepository _dashboardRepo;
  final SettingsRepository _settingsRepo;
  final NotificationRepository _notificationRepo;
  final AuthRepository _authRepo;
  final EmailRepository _emailRepo;
  final ConsultationRepository _consultationRepo;

  bool _running = false;
  Timer? _periodicTimer;

  /// Logging system audit fix #3 — scheduled sync. Until now, a sync pass
  /// only ever ran on Dashboard open (syncEngineBootstrapProvider's initial
  /// `await syncNow(uid)`) or on an offline->online connectivity edge
  /// (watchConnectivity). A device that stays online but simply never
  /// toggles connectivity and never revisits Dashboard could leave rows
  /// unsynced indefinitely. This adds a periodic timer — while the app is
  /// active — as a third, independent trigger.
  ///
  /// Deliberately a foreground `Timer.periodic`, not WorkManager/a
  /// background service: the task only requires "an appropriate background
  /// scheduling mechanism... a timer while the app is active, and
  /// WorkManager only if true background execution is required" — nothing
  /// here needs to run while the app is fully killed (every write already
  /// gets a write-time push attempt, and the very next foreground/
  /// reconnect/Dashboard-open catches anything that was missed), so the
  /// simplest mechanism that satisfies the requirement is the correct one.
  ///
  /// No duplicate uploads: this timer just calls the existing [syncNow],
  /// which is already idempotent (per-row synced flags / Supabase upsert
  /// keys) and already guarded by [_running] against overlapping passes —
  /// nothing new needed there.
  ///
  /// Start/stop lifecycle: calling this while a timer is already running
  /// cancels the old one first, so repeated calls (e.g. a hot-reload of
  /// the provider that owns this engine) never stack multiple timers.
  /// [stopPeriodicSync] is called from syncEngineBootstrapProvider's
  /// `ref.onDispose`, which already fires on logout (Dashboard route is
  /// torn down) — so the timer stops gracefully on logout and a fresh one
  /// starts automatically the next time that provider is watched after
  /// login, with no new lifecycle plumbing required.
  void startPeriodicSync(String uid,
      {Duration interval = const Duration(minutes: 25)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => syncNow(uid));
  }

  /// Stops the periodic timer started by [startPeriodicSync]. Safe to call
  /// even if no timer is running. Does not wake anything while offline —
  /// this only ever cancels a `Timer.periodic`, it never schedules a
  /// background wake, so there is nothing to "not wake" in the first place
  /// once this is called.
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Runs every resync path in parallel. Safe to call as often as you
  /// like (app open, reconnect, pull-to-refresh) — every path underneath
  /// is either keyed on a real synced flag or a Supabase-side upsert key,
  /// so a redundant call never duplicates data. `_running` just avoids
  /// piling up overlapping passes if connectivity flaps rapidly.
  Future<void> syncNow(String uid) async {
    if (_running) return;
    _running = true;
    try {
      await Future.wait([
        _activityLogRepo.pushUnsynced(uid),
        // Production audit finding: activity_logs was push-only — a fresh
        // device/reinstall never saw another device's history. See
        // ActivityLogRepository.pullFromCloudIfEmpty's doc.
        _activityLogRepo.pullFromCloudIfEmpty(uid),
        _pigRepo.resyncPendingImages(uid),
        _pigRepo.resyncPendingPigs(uid),
        // Continuous cross-device pull (issue: photos/pig edits uploaded on
        // one device never appearing on another once that other device
        // already had at least one pig locally) — see pullRemoteChanges's
        // doc. Runs alongside the push paths above on every pass; safe to
        // run concurrently with them since it never touches a local row
        // that still has a pending unsynced edit (synced == 0).
        _pigRepo.pullRemoteChanges(uid),
        _expensesRepo.resyncPending(uid),
        _healthRepo.resyncPending(uid),
        _dashboardRepo.resyncPendingWeighIns(uid),
        _settingsRepo.resyncPending(uid),
        _notificationRepo.resyncPending(uid),
        // Production audit finding: notification prefs were push-only —
        // see NotificationRepository.pullFromCloudIfEmpty's doc.
        _notificationRepo.pullFromCloudIfEmpty(uid),
        _authRepo.resyncPendingAvatar(uid),
        // Offline/OTP registration fix: a profile created while offline (or
        // hitting a transient Supabase error right after Firebase account
        // creation + phone verification) now lands in SQLite immediately
        // with synced:0 instead of throwing — this is what retries the
        // Supabase mirror once connectivity/the auth-claim race resolves.
        _authRepo.resyncPendingProfile(uid),
        // Brevo email integration — retries any queued outbound email
        // (see EmailRepository's doc) and pushes any not-yet-synced
        // Expert Consultation request.
        _emailRepo.resyncPending(uid),
        _consultationRepo.pushUnsynced(uid),
      ]);
    } catch (_) {
      // Every path above already swallows its own per-row/per-field
      // errors — this outer catch is just a last-resort net so a truly
      // unexpected failure can never surface as a crash.
    } finally {
      _running = false;
    }
  }

  /// Starts a connectivity listener that triggers [syncNow] whenever the
  /// device transitions from offline to online. Returns the subscription
  /// so the caller can cancel it (see sync_engine_providers.dart's
  /// ref.onDispose).
  StreamSubscription<List<ConnectivityResult>> watchConnectivity(String uid) {
    var wasOffline = false;
    return Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && wasOffline) {
        syncNow(uid);
      }
      wasOffline = !online;
    });
  }
}
