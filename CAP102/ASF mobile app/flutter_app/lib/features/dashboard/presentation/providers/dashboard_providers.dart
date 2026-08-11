// ══════════════════════════════════════════════════════════════════════
// Riverpod state for the Dashboard — loads every input loadData() reads in
// index.html (production day, dayLogs/tasks, weightLogs, expenses,
// feedLogs, pigBatchProfile) and exposes the same derived values (ADG, FCR,
// ROI/Projected Net Profit, stage, days remaining) computed via
// dashboard_calculations.dart's pure functions.
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../health/data/health_repository.dart';
import '../../../health/domain/health_calculations.dart';
import '../../../pigs/data/pig_repository.dart';
import '../../domain/pig_batch_profile.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/daily_task.dart';
import '../../domain/dashboard_calculations.dart';

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) => DashboardRepository());
final _dashboardHealthRepositoryProvider =
    Provider<HealthRepository>((ref) => HealthRepository());
final _dashboardPigRepositoryProvider =
    Provider<PigRepository>((ref) => PigRepository());

class DashboardData {
  const DashboardData({
    required this.currentDay,
    required this.tasksToday,
    required this.weightLogs,
    required this.expenses,
    required this.feedLogs,
    required this.batchProfile,
    this.healthLogs = const [],
    this.pigCount = 0,
    this.isAdvancing = false,
    this.errorMessage,
  });

  final int currentDay;
  final Map<String, bool> tasksToday;
  final List<WeightLogEntry> weightLogs;
  final List<ExpenseEntry> expenses;
  final List<FeedLogEntry> feedLogs;
  final PigBatchProfile? batchProfile;
  final List<HealthLogEntry> healthLogs;
  final int pigCount;
  final bool isAdvancing;
  final String? errorMessage;

  /// True once the user has added at least one pig. Gates the Dashboard's
  /// "--" empty-state display for Current Weight/ROI (requirement: never
  /// show a fabricated 0/₱0 for a user who hasn't created a pig yet).
  bool get hasPigs => pigCount > 0;

  /// Most recent health observation by real save timestamp — powers the
  /// Dashboard's Critical/Needs-Monitoring/Healthy banner, matching
  /// getLatestHealthLog() in index.html.
  HealthLogEntry? get latestHealthLog {
    if (healthLogs.isEmpty) return null;
    final sorted = [...healthLogs]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted.last;
  }

  /// Last 10 observations, oldest first — a lightweight trend strip (a full
  /// chart isn't needed here; Growth already owns the charting UI pattern).
  List<HealthLogEntry> get healthTrend {
    final sorted = [...healthLogs]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted.length > 10 ? sorted.sublist(sorted.length - 10) : sorted;
  }

  bool get hasHealthLogToday => healthLogs.any((h) => h.day == currentDay);

  int get daysRemaining => kMaxProductionDay - currentDay;
  int get doneTaskCount =>
      kDailyTaskDefs.where((d) => tasksToday[d.id] == true).length;
  bool get allTasksDone => doneTaskCount >= kDailyTaskDefs.length;
  bool get cycleComplete => currentDay >= kMaxProductionDay;

  double get currentWeight => weightLogs.isNotEmpty
      ? weightLogs.last.weight
      : (batchProfile?.startWeight ?? 0);

  double? get adg => currentAdg(
      startWeight: batchProfile?.startWeight,
      startDateIso: batchProfile?.startDate,
      weightLogs: weightLogs);

  double? get fcr => currentFcr(
        startWeight: batchProfile?.startWeight,
        startDateIso: batchProfile?.startDate,
        weightLogs: weightLogs,
        feedLogs: feedLogs,
      );

  bool get onTrack {
    final a = adg;
    if (a == null) return true;
    return a >= adgTargetMin && a <= adgTargetMax;
  }

  RoiResult get roi =>
      computeRoi(currentWeight: currentWeight, expenses: expenses);

  double? get growthPct => growthPercent(
      startWeight: batchProfile?.startWeight, currentWeight: currentWeight);

  DashboardData copyWith({
    int? currentDay,
    Map<String, bool>? tasksToday,
    List<WeightLogEntry>? weightLogs,
    List<ExpenseEntry>? expenses,
    List<FeedLogEntry>? feedLogs,
    PigBatchProfile? batchProfile,
    List<HealthLogEntry>? healthLogs,
    int? pigCount,
    bool? isAdvancing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardData(
      currentDay: currentDay ?? this.currentDay,
      tasksToday: tasksToday ?? this.tasksToday,
      weightLogs: weightLogs ?? this.weightLogs,
      expenses: expenses ?? this.expenses,
      feedLogs: feedLogs ?? this.feedLogs,
      batchProfile: batchProfile ?? this.batchProfile,
      healthLogs: healthLogs ?? this.healthLogs,
      pigCount: pigCount ?? this.pigCount,
      isAdvancing: isAdvancing ?? this.isAdvancing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  static const empty = DashboardData(
      currentDay: 1,
      tasksToday: {},
      weightLogs: [],
      expenses: [],
      feedLogs: [],
      batchProfile: null);
}

class DashboardController extends StateNotifier<AsyncValue<DashboardData>> {
  DashboardController(
      this._repo, this._healthRepo, this._pigRepo, this._authRepo, this._uid)
      : super(const AsyncValue.loading()) {
    load();
  }

  final DashboardRepository _repo;
  final HealthRepository _healthRepo;
  final PigRepository _pigRepo;
  final AuthRepository _authRepo;
  final String _uid;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final day = await _repo.getCurrentDay(_uid);
      final results = await Future.wait([
        _repo.getTasksForDay(_uid, day),
        _repo.getWeightLogs(_uid),
        _repo.getExpenses(_uid),
        _repo.getFeedLogs(_uid),
        _repo.getPigBatchProfile(_uid),
        _healthRepo.getHealthLogs(_uid),
        _pigRepo.getPigs(_uid),
      ]);
      state = AsyncValue.data(DashboardData(
        currentDay: day,
        tasksToday: results[0] as Map<String, bool>,
        weightLogs: results[1] as List<WeightLogEntry>,
        expenses: results[2] as List<ExpenseEntry>,
        feedLogs: results[3] as List<FeedLogEntry>,
        batchProfile: results[4] as PigBatchProfile?,
        healthLogs: results[5] as List<HealthLogEntry>,
        pigCount: (results[6] as List).length,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleTask(String taskId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    // A single Health Monitor save covers behavior AND physical together,
    // so both lock gates share the same "logged today" signal.
    final behaviorLoggedToday = current.hasHealthLogToday;
    final physicalLoggedToday = current.hasHealthLogToday;
    final alreadyDone = current.tasksToday[taskId] == true;
    if (!alreadyDone) {
      final lockMsg = taskLockMessage(
        id: taskId,
        tasksToday: current.tasksToday,
        behaviorLoggedToday: behaviorLoggedToday,
        physicalLoggedToday: physicalLoggedToday,
      );
      if (lockMsg != null) {
        state = AsyncValue.data(current.copyWith(errorMessage: lockMsg));
        return;
      }
    }
    await _repo.toggleTask(_uid, current.currentDay, taskId);
    final updatedTasks = await _repo.getTasksForDay(_uid, current.currentDay);
    state = AsyncValue.data(
        current.copyWith(tasksToday: updatedTasks, clearError: true));
    // Bug A7 fix: the Activity Log previously never recorded which daily
    // task was tapped (only pig/expense/health/settings/auth actions were
    // logged) — recordActivityLog() itself already stamps a full date+time
    // (SqliteService.nowMs()), so naming the specific task and its new
    // state here is all that was missing.
    DailyTaskDef? def;
    for (final d in kDailyTaskDefs) {
      if (d.id == taskId) {
        def = d;
        break;
      }
    }
    final nowDone = updatedTasks[taskId] == true;
    await _authRepo.recordActivityLog(
      uid: _uid,
      actionType: 'task',
      description:
          '${nowDone ? 'Completed' : 'Unmarked'} daily task: ${def?.title ?? 'Task $taskId'}',
      action: 'DAILY_TASK',
      status: nowDone ? 'COMPLETED' : 'UNMARKED',
    );
  }

  /// Returns true if the day actually advanced (false if tasks weren't all
  /// done yet, matching attemptAdvanceDay()'s gate in index.html).
  ///
  /// Bug A15 fix: also blocks leaving the LAST day of a production week
  /// (day 7, 14, 21, ...) — i.e. the transition that would unlock the next
  /// week starting on day 8/15/22/... — until that week's official weigh-in
  /// AND at least one weekly photo (for every pig on the account) have been
  /// recorded. Skipped entirely when the account has no pigs yet (nothing to
  /// weigh/photograph, and Bug A5's guard already keeps tasks/advance
  /// unreachable in that case).
  Future<bool> advanceDay() async {
    final current = state.valueOrNull;
    if (current == null) return false;
    if (!current.allTasksDone) {
      state = AsyncValue.data(
          current.copyWith(errorMessage: 'Complete all tasks first!'));
      return false;
    }
    if (current.hasPigs && current.currentDay % 7 == 0) {
      final completingWeek = weekNumberForDay(current.currentDay);
      final hasWeekWeighIn = current.weightLogs
          .any((e) => e.isOfficial && e.weekNumber == completingWeek);
      if (!hasWeekWeighIn) {
        state = AsyncValue.data(current.copyWith(
          errorMessage:
              'Record this week\'s official weigh-in before starting the next week.',
        ));
        return false;
      }
      try {
        final pigs = await _pigRepo.getPigs(_uid);
        for (final pig in pigs) {
          final images = await _pigRepo.getWeeklyImages(_uid, pig.id);
          final hasWeekPhoto =
              images.any((img) => img.weekNumber == completingWeek);
          if (!hasWeekPhoto) {
            state = AsyncValue.data(current.copyWith(
              errorMessage:
                  'Upload this week\'s progress photo for ${pig.name} before starting the next week.',
            ));
            return false;
          }
        }
      } catch (_) {
        // Best-effort check — a transient read failure here should never
        // trap the farmer unable to advance at all; fall through and allow
        // the advance rather than fail closed on our own error.
      }
    }
    state =
        AsyncValue.data(current.copyWith(isAdvancing: true, clearError: true));
    try {
      await _repo.advanceDay(_uid);
      await load();
      return true;
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
          isAdvancing: false,
          errorMessage:
              'Could not advance to the next day. Please try again.'));
      return false;
    }
  }

  void clearError() {
    final current = state.valueOrNull;
    if (current != null)
      state = AsyncValue.data(current.copyWith(clearError: true));
  }

  /// Persists an edited feed price then reloads, so every consumer watching
  /// this provider (the Feeding Guide's cost calculator, in particular)
  /// picks up the new price and its dependent cost figures in one shot —
  /// same reload-after-write shape as advanceDay().
  Future<void> updateFeedPrice(double newPrice) async {
    await _repo.updateFeedPrice(_uid, newPrice);
    await load();
  }
}

final dashboardControllerProvider = StateNotifierProvider.autoDispose
    .family<DashboardController, AsyncValue<DashboardData>, String>((ref, uid) {
  return DashboardController(
    ref.watch(dashboardRepositoryProvider),
    ref.watch(_dashboardHealthRepositoryProvider),
    ref.watch(_dashboardPigRepositoryProvider),
    ref.watch(authRepositoryProvider),
    uid,
  );
});

/// Convenience: the signed-in user's uid, or '' if somehow unauthenticated
/// (routing should never actually let the Dashboard render in that case).
final currentUidProvider = Provider<String>((ref) {
  return ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
});
