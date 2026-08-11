// ══════════════════════════════════════════════════════════════════════
// Riverpod state for the Growth module — weekly weigh-ins, the Starting
// Weight lock gate, and the derived chart series. Reads/writes go through
// DashboardRepository (see its file header) since weigh-ins are recorded at
// the batch level, same as Current Weight/ADG/FCR/ROI on the Dashboard —
// this controller is the single write path that keeps all of those in sync.
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/data/dashboard_repository.dart';
import '../../../dashboard/domain/dashboard_calculations.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../dashboard/domain/pig_batch_profile.dart';

class GrowthData {
  const GrowthData({
    required this.currentDay,
    required this.weightLogs,
    required this.feedLogs,
    required this.batchProfile,
    this.isSaving = false,
    this.errorMessage,
    this.pendingDuplicateWeek,
  });

  final int currentDay;
  final List<WeightLogEntry> weightLogs;
  final List<FeedLogEntry> feedLogs;
  final PigBatchProfile? batchProfile;
  final bool isSaving;
  final String? errorMessage;

  /// Set while the UI is asking "a weigh-in already exists for Week N —
  /// replace it?" — non-null only in that confirmation window.
  final int? pendingDuplicateWeek;

  bool get hasOfficialEntry => hasOfficialWeighIn(weightLogs);
  int get currentWeekNumber => weekNumberForDay(currentDay);

  double get currentWeight {
    final latest = latestOfficialEntry(weightLogs);
    return latest?.weight ?? (batchProfile?.startWeight ?? 0);
  }

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

  List<ChartPoint> get weightSeries => weightVsWeekSeries(weightLogs);
  List<ChartPoint> get adgSeries => adgTrendSeries(
      startWeight: batchProfile?.startWeight,
      startDateIso: batchProfile?.startDate,
      weightLogs: weightLogs);
  List<ChartPoint> get fcrSeries => fcrTrendSeries(
        startWeight: batchProfile?.startWeight,
        startDateIso: batchProfile?.startDate,
        weightLogs: weightLogs,
        feedLogs: feedLogs,
      );

  /// Cumulative feed consumed (kg) as of each official weigh-in — same
  /// weekNumber keys as [fcrSeries] (see feedConsumedTrendSeries's doc), so
  /// the Weight & ADG screen's FCR History rows can look up "Feed
  /// Consumed" for the same week its FCR badge shows.
  List<ChartPoint> get feedConsumedSeries => feedConsumedTrendSeries(
        startWeight: batchProfile?.startWeight,
        startDateIso: batchProfile?.startDate,
        weightLogs: weightLogs,
        feedLogs: feedLogs,
      );

  GrowthData copyWith({
    int? currentDay,
    List<WeightLogEntry>? weightLogs,
    List<FeedLogEntry>? feedLogs,
    PigBatchProfile? batchProfile,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    int? pendingDuplicateWeek,
    bool clearPendingDuplicate = false,
  }) {
    return GrowthData(
      currentDay: currentDay ?? this.currentDay,
      weightLogs: weightLogs ?? this.weightLogs,
      feedLogs: feedLogs ?? this.feedLogs,
      batchProfile: batchProfile ?? this.batchProfile,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingDuplicateWeek: clearPendingDuplicate
          ? null
          : (pendingDuplicateWeek ?? this.pendingDuplicateWeek),
    );
  }
}

class GrowthController extends StateNotifier<AsyncValue<GrowthData>> {
  GrowthController(this._repo, this._authRepo, this._ref, this._uid)
      : super(const AsyncValue.loading()) {
    load();
  }

  final DashboardRepository _repo;
  final AuthRepository _authRepo;
  final Ref _ref;
  final String _uid;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final day = await _repo.getCurrentDay(_uid);
      var weightLogs = await _repo.getWeightLogs(_uid);
      final feedLogs = await _repo.getFeedLogs(_uid);
      final batchProfile = await _repo.getPigBatchProfile(_uid);

      // Migration: If user has pigs/batchProfile but no official weigh-ins yet,
      // auto-seed Day 1 starting weight baseline.
      if (!hasOfficialWeighIn(weightLogs) &&
          batchProfile != null &&
          batchProfile.startWeight > 0) {
        try {
          await _repo.addWeighIn(
            uid: _uid,
            weight: batchProfile.startWeight,
            notes: 'Day 1 starting weight recorded.',
          );
          weightLogs = await _repo.getWeightLogs(_uid);
        } catch (_) {}
      }

      state = AsyncValue.data(GrowthData(
        currentDay: day,
        weightLogs: weightLogs,
        feedLogs: feedLogs,
        batchProfile: batchProfile,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Set only while a duplicate-week confirmation is pending, so
  /// [confirmOverwriteDuplicate] knows whether the in-flight attempt was a
  /// plain current-week save or a [forWeekNumber] backfill — see that
  /// method's doc for why this matters.
  int? _pendingForWeekNumber;

  /// Attempts to add a weigh-in for the current week, or — via
  /// [forWeekNumber] — backfills a specific MISSED past week (C9: a farmer
  /// further along than a week they never recorded can now go back and add
  /// it, rather than that week staying permanently blank). If an official
  /// entry already exists for the target week, sets pendingDuplicateWeek
  /// instead of saving — the UI should show a confirm dialog and call
  /// confirmOverwriteDuplicate() (or cancelDuplicate()) next, matching
  /// "prevent duplicate official weigh-ins for the same week (unless the
  /// user explicitly edits the existing entry)."
  Future<void> addWeighIn(
      {required double weight, String notes = '', int? forWeekNumber}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(isSaving: true, clearError: true));
    try {
      final result = await _repo.addWeighIn(
          uid: _uid,
          weight: weight,
          notes: notes,
          forWeekNumber: forWeekNumber);
      _pendingForWeekNumber = null;
      await _afterSave(result);
    } on MissingWeek1Exception {
      _pendingForWeekNumber = null;
      state = AsyncValue.data(current.copyWith(
        isSaving: false,
        errorMessage:
            'Please record Week 1 weight before proceeding to Week 2.',
      ));
    } on DuplicateWeighInException catch (e) {
      _pendingForWeekNumber = forWeekNumber;
      state = AsyncValue.data(current.copyWith(
          isSaving: false, pendingDuplicateWeek: e.weekNumber));
    } catch (_) {
      _pendingForWeekNumber = null;
      state = AsyncValue.data(current.copyWith(
          isSaving: false,
          errorMessage: 'Could not save this weigh-in. Please try again.'));
    }
  }

  Future<void> confirmOverwriteDuplicate(
      {required double weight, String notes = ''}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final forWeekNumber = _pendingForWeekNumber;
    state = AsyncValue.data(current.copyWith(
        isSaving: true, clearError: true, clearPendingDuplicate: true));
    try {
      final result = await _repo.addWeighIn(
          uid: _uid,
          weight: weight,
          notes: notes,
          allowEditIfDuplicate: true,
          forWeekNumber: forWeekNumber);
      _pendingForWeekNumber = null;
      await _afterSave(result, isEdit: true);
    } catch (_) {
      state = AsyncValue.data(current.copyWith(
          isSaving: false,
          errorMessage: 'Could not save this weigh-in. Please try again.'));
    }
  }

  void cancelDuplicate() {
    final current = state.valueOrNull;
    if (current != null)
      state = AsyncValue.data(current.copyWith(clearPendingDuplicate: true));
  }

  Future<void> editWeighIn(
      {required int day, required double weight, String? notes}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.updateWeighIn(
          uid: _uid, day: day, weight: weight, notes: notes);
      await _authRepo.recordActivityLog(
          uid: _uid,
          actionType: 'growth',
          description: 'edited weekly weigh-in (day $day) to $weight kg');
      await load();
      _ref.invalidate(dashboardControllerProvider(_uid));
    } catch (_) {
      state = AsyncValue.data(current.copyWith(
          isSaving: false,
          errorMessage: 'Could not update this weigh-in. Please try again.'));
    }
  }

  Future<void> deleteWeighIn(int day) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.deleteWeighIn(uid: _uid, day: day);
      await _authRepo.recordActivityLog(
          uid: _uid,
          actionType: 'growth',
          description: 'deleted weekly weigh-in (day $day)');
      await load();
      _ref.invalidate(dashboardControllerProvider(_uid));
    } catch (_) {
      state = AsyncValue.data(current.copyWith(
          isSaving: false,
          errorMessage: 'Could not delete this weigh-in. Please try again.'));
    }
  }

  Future<void> _afterSave(WeighInResult result, {bool isEdit = false}) async {
    await _authRepo.recordActivityLog(
      uid: _uid,
      actionType: 'growth',
      description:
          '${isEdit ? 'edited' : 'recorded'} weekly weigh-in (week ${result.entry.weekNumber}): ${result.entry.weight} kg',
    );
    // Reload BEFORE computing ADG/FCR for the log lines below, so they
    // reflect the just-saved entry.
    await load();
    final data = state.valueOrNull;
    if (data != null) {
      if (data.adg != null) {
        await _authRepo.recordActivityLog(
            uid: _uid,
            actionType: 'growth',
            description:
                'ADG recalculated: ${data.adg!.toStringAsFixed(0)} g/day');
      }
      if (data.fcr != null) {
        await _authRepo.recordActivityLog(
            uid: _uid,
            actionType: 'growth',
            description: 'FCR recalculated: ${data.fcr!.toStringAsFixed(2)}');
      }
    }
    if (result.isFirstOfficial) {
      await _authRepo.recordActivityLog(
        uid: _uid,
        actionType: 'growth',
        description:
            'starting weight locked — first official weekly weigh-in recorded',
      );
    }
    _ref.invalidate(dashboardControllerProvider(_uid));
  }

  void clearError() {
    final current = state.valueOrNull;
    if (current != null)
      state = AsyncValue.data(current.copyWith(clearError: true));
  }
}

final growthControllerProvider = StateNotifierProvider.autoDispose
    .family<GrowthController, AsyncValue<GrowthData>, String>((ref, uid) {
  return GrowthController(ref.watch(dashboardRepositoryProvider),
      ref.watch(authRepositoryProvider), ref, uid);
});

/// Lightweight, dashboard-agnostic read of just the lock gate — used by the
/// Pig Detail screen so it doesn't need to depend on the full Growth
/// controller just to decide whether to show the Edit Starting Weight
/// button.
final hasOfficialWeighInProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, uid) async {
  final logs = await ref.watch(dashboardRepositoryProvider).getWeightLogs(uid);
  return hasOfficialWeighIn(logs);
});
