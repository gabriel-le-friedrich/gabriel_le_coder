// ══════════════════════════════════════════════════════════════════════
// Riverpod state for Expenses & ROI. Reads batch context (starting weight,
// current weight, pig count) via DashboardRepository so ROI/Cost-Per-Pig/
// Cost-Per-Kg stay consistent with the same numbers the Dashboard and
// Growth module already show, then writes expenses through
// ExpensesRepository — invalidating the Dashboard controller after every
// change so Total Expenses/ROI/Projected Net Profit update with no manual
// refresh, per the spec's "Dashboard Integration" requirement.
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/data/dashboard_repository.dart';
import '../../../dashboard/domain/dashboard_calculations.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../dashboard/domain/pig_batch_profile.dart';
import '../../data/expenses_repository.dart';
import '../../domain/expense_calculations.dart';

final expensesRepositoryProvider =
    Provider<ExpensesRepository>((ref) => ExpensesRepository());

class ExpensesData {
  const ExpensesData({
    required this.expenses,
    required this.weightLogs,
    required this.batchProfile,
    this.currentDay = 1,
    this.isSaving = false,
    this.errorMessage,
  });

  final List<ExpenseEntry> expenses;
  final List<WeightLogEntry> weightLogs;
  final PigBatchProfile? batchProfile;
  // The same manual production-day counter DashboardRepository.getCurrentDay()
  // already exposes to the Dashboard/Feeding Guide screens — reused here only
  // for the redesigned "Day X · Live cost tracking" subtitle, not a new
  // calculation.
  final int currentDay;
  final bool isSaving;
  final String? errorMessage;

  double get currentWeight {
    final latest = latestOfficialEntry(weightLogs);
    return latest?.weight ?? (batchProfile?.startWeight ?? 0);
  }

  RoiResult get roi =>
      computeRoi(currentWeight: currentWeight, expenses: expenses);

  double get totalExpenses => roi.totalInvested;
  double get feedCost => totalFeedCost(expenses);
  double? get perPig => costPerPig(
      totalExpenses: totalExpenses, numPigs: batchProfile?.numPigs ?? 0);
  double? get perKg =>
      costPerKg(totalExpenses: totalExpenses, currentWeight: currentWeight);

  List<MapEntry<ExpenseCategory, double>> get byCategory =>
      categoryBreakdown(expenses);
  List<ExpenseTrendPoint> get expenseTrend =>
      expenseTrendSeries(expenses, batchProfile?.startDate);
  List<ExpenseTrendPoint> get feedTrend =>
      feedCostTrendSeries(expenses, batchProfile?.startDate);

  ExpensesData copyWith({
    List<ExpenseEntry>? expenses,
    List<WeightLogEntry>? weightLogs,
    PigBatchProfile? batchProfile,
    int? currentDay,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExpensesData(
      expenses: expenses ?? this.expenses,
      weightLogs: weightLogs ?? this.weightLogs,
      batchProfile: batchProfile ?? this.batchProfile,
      currentDay: currentDay ?? this.currentDay,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ExpensesController extends StateNotifier<AsyncValue<ExpensesData>> {
  ExpensesController(
      this._repo, this._dashboardRepo, this._authRepo, this._ref, this._uid)
      : super(const AsyncValue.loading()) {
    load();
  }

  final ExpensesRepository _repo;
  final DashboardRepository _dashboardRepo;
  final AuthRepository _authRepo;
  final Ref _ref;
  final String _uid;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final results = await Future.wait([
        _repo.getExpenses(_uid),
        _dashboardRepo.getWeightLogs(_uid),
        _dashboardRepo.getPigBatchProfile(_uid),
        _dashboardRepo.getCurrentDay(_uid),
      ]);
      state = AsyncValue.data(ExpensesData(
        expenses: results[0] as List<ExpenseEntry>,
        weightLogs: results[1] as List<WeightLogEntry>,
        batchProfile: results[2] as PigBatchProfile?,
        currentDay: results[3] as int,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> addExpense({
    required String category,
    required String description,
    required double amount,
    required String date,
    String note = '',
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.isSaving) return false;
    if (amount <= 0) {
      state = AsyncValue.data(
          current.copyWith(errorMessage: 'Amount must be greater than 0.'));
      return false;
    }
    state = AsyncValue.data(current.copyWith(isSaving: true, clearError: true));
    try {
      final entry = await _repo.addExpense(
          uid: _uid,
          category: category,
          description: description,
          amount: amount,
          date: date,
          note: note);
      await _authRepo.recordActivityLog(
        uid: _uid,
        actionType: 'expense',
        description:
            'Expense Added: $category — ${entry.amount.toStringAsFixed(2)} ($description)',
      );
      await _afterChange();
      return true;
    } catch (_) {
      state = AsyncValue.data(current.copyWith(
          isSaving: false,
          errorMessage: 'Could not save this expense. Please try again.'));
      return false;
    }
  }

  Future<bool> updateExpense({
    required int id,
    required String category,
    required String description,
    required double amount,
    required String date,
    String note = '',
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.isSaving) return false;
    if (amount <= 0) {
      state = AsyncValue.data(
          current.copyWith(errorMessage: 'Amount must be greater than 0.'));
      return false;
    }
    state = AsyncValue.data(current.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.updateExpense(
          uid: _uid,
          id: id,
          category: category,
          description: description,
          amount: amount,
          date: date,
          note: note);
      await _authRepo.recordActivityLog(
          uid: _uid,
          actionType: 'expense',
          description:
              'Expense Edited: $category — ${amount.toStringAsFixed(2)} ($description)');
      await _afterChange();
      return true;
    } catch (_) {
      state = AsyncValue.data(current.copyWith(
          isSaving: false,
          errorMessage: 'Could not update this expense. Please try again.'));
      return false;
    }
  }

  Future<void> deleteExpense(ExpenseEntry entry) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(isSaving: true, clearError: true));
    try {
      await _repo.deleteExpense(uid: _uid, id: entry.id);
      await _authRepo.recordActivityLog(
        uid: _uid,
        actionType: 'expense',
        description:
            'Expense Deleted: ${entry.category} — ${entry.amount.toStringAsFixed(2)} (${entry.description})',
      );
      await _afterChange();
    } catch (_) {
      state = AsyncValue.data(current.copyWith(
          isSaving: false,
          errorMessage: 'Could not delete this expense. Please try again.'));
    }
  }

  Future<void> _afterChange() async {
    await load();
    final data = state.valueOrNull;
    if (data != null) {
      await _authRepo.recordActivityLog(
          uid: _uid,
          actionType: 'expense',
          description:
              'ROI Recalculated: ${data.roi.roiPercent.toStringAsFixed(1)}%');
      await _authRepo.recordActivityLog(
        uid: _uid,
        actionType: 'expense',
        description:
            'Projected Profit Recalculated: ${data.roi.netProfit.toStringAsFixed(2)}',
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

final expensesControllerProvider = StateNotifierProvider.autoDispose
    .family<ExpensesController, AsyncValue<ExpensesData>, String>((ref, uid) {
  return ExpensesController(
    ref.watch(expensesRepositoryProvider),
    ref.watch(dashboardRepositoryProvider),
    ref.watch(authRepositoryProvider),
    ref,
    uid,
  );
});
