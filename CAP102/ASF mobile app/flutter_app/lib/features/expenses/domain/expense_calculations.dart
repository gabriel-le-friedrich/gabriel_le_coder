// ══════════════════════════════════════════════════════════════════════
// Expense category catalog + the pure calculations the Expenses & ROI slice
// needs beyond what dashboard_calculations.dart already provides
// (computeRoi/RoiResult are reused as-is — this file only adds what's new:
// category breakdown, expense/feed-cost trends, and the per-pig/per-kg cost
// stats). No DB access here, matching the rest of this app's
// domain/data/presentation split.
// ══════════════════════════════════════════════════════════════════════

import '../../dashboard/domain/dashboard_calculations.dart';

enum ExpenseCategory {
  feed('Feed', '🌾'),
  medicine('Medicine', '💊'),
  vaccines('Vaccines', '💉'),
  vitamins('Vitamins', '🧪'),
  transportation('Transportation', '🚚'),
  labor('Labor', '👷'),
  utilities('Utilities', '💡'),
  equipment('Equipment', '🛠️'),
  other('Other', '📦');

  const ExpenseCategory(this.label, this.icon);
  final String label;
  final String icon;

  static ExpenseCategory fromLabel(String label) {
    return ExpenseCategory.values.firstWhere(
      (c) => c.label.toLowerCase() == label.toLowerCase(),
      orElse: () => ExpenseCategory.other,
    );
  }
}

/// Total amount spent per category — feeds the "Expenses by Category" chart.
/// Only categories with at least one expense are included, in
/// ExpenseCategory enum order (a stable, predictable chart axis order).
List<MapEntry<ExpenseCategory, double>> categoryBreakdown(
    List<ExpenseEntry> expenses) {
  final totals = <ExpenseCategory, double>{};
  for (final e in expenses) {
    final cat = ExpenseCategory.fromLabel(e.category);
    totals[cat] = (totals[cat] ?? 0) + e.amount;
  }
  return ExpenseCategory.values
      .where(totals.containsKey)
      .map((c) => MapEntry(c, totals[c]!))
      .toList();
}

/// One trend point — x is the production week number the expense's date
/// falls into (derived the same way as WeightLogEntry.weekNumber, but from
/// a batch start date rather than a stored production day).
class ExpenseTrendPoint {
  const ExpenseTrendPoint({required this.week, required this.total});
  final int week;
  final double total;
}

int _weekForDate(String dateIso, String? startDateIso) {
  if (startDateIso == null || startDateIso.isEmpty) return 1;
  final start = DateTime.tryParse(startDateIso);
  final d = DateTime.tryParse(dateIso);
  if (start == null || d == null) return 1;
  final dayNumber = d.difference(start).inDays + 1;
  if (dayNumber < 1) return 1;
  return ((dayNumber - 1) ~/ 7) + 1;
}

/// Total spend per production week, across every category — "Expense
/// Trend" chart.
List<ExpenseTrendPoint> expenseTrendSeries(
    List<ExpenseEntry> expenses, String? startDateIso) {
  final totals = <int, double>{};
  for (final e in expenses) {
    final week = _weekForDate(e.date, startDateIso);
    totals[week] = (totals[week] ?? 0) + e.amount;
  }
  final weeks = totals.keys.toList()..sort();
  return weeks
      .map((w) => ExpenseTrendPoint(week: w, total: totals[w]!))
      .toList();
}

/// Feed-category spend per production week — "Feed Cost Trend" chart.
List<ExpenseTrendPoint> feedCostTrendSeries(
    List<ExpenseEntry> expenses, String? startDateIso) {
  final feedOnly = expenses
      .where(
          (e) => ExpenseCategory.fromLabel(e.category) == ExpenseCategory.feed)
      .toList();
  return expenseTrendSeries(feedOnly, startDateIso);
}

double totalFeedCost(List<ExpenseEntry> expenses) {
  return expenses
      .where(
          (e) => ExpenseCategory.fromLabel(e.category) == ExpenseCategory.feed)
      .fold<double>(0, (sum, e) => sum + e.amount);
}

/// Total spend ÷ number of pigs in the batch. Null if there are no pigs on
/// record (avoids a division by zero rather than showing a misleading 0).
double? costPerPig({required double totalExpenses, required int numPigs}) {
  if (numPigs <= 0) return null;
  return totalExpenses / numPigs;
}

/// Total spend ÷ current (latest) live weight in kg. Null until a current
/// weight is known.
double? costPerKg(
    {required double totalExpenses, required double currentWeight}) {
  if (currentWeight <= 0) return null;
  return totalExpenses / currentWeight;
}
