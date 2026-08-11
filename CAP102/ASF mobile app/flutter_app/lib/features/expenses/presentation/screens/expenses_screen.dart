import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/domain/dashboard_calculations.dart'
    show ExpenseEntry, RoiResult, kMaxProductionDay;
import '../../../dashboard/presentation/widgets/dashboard_drawer.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/expense_calculations.dart';
import '../../domain/expense_export.dart';
import '../providers/expenses_providers.dart';
import '../theme/expense_palette.dart';
import 'roi_analytics_screen.dart';

// ══════════════════════════════════════════════════════════════════════
// Expense & ROI — UI-only redesign (v2) matching the reference mockup's
// exact layout: Day X of 120 + subtitle, a subtle farm illustration banner
// (sunrise/fields/barn/pig — decorative only, no financial data), the
// existing ROI/Financial Summary card (was a collapsible card buried at
// the bottom, now always expanded right under the banner), a 2-card
// Financial Statistics row (Feed Cost / Avg Daily Cost — Net Profit/ROI%
// already live in the Financial Summary card above, so they aren't
// repeated here), an animated fl_chart donut for the category breakdown
// (was a bar list) with the total centered inside the ring, a full-screen
// Add/Edit Expense flow (was a bottom sheet) with a Material 3 category
// grid, and a full-width "+ Add Expense" button at the end of the list
// (replacing the old round FAB, matching the mockup's single add entry
// point). Every figure still comes from ExpensesData
// (expensesControllerProvider) → ExpensesRepository/DashboardRepository —
// nothing here is a sample value, and addExpense()/updateExpense()/
// deleteExpense() are called exactly as before. The "Synced with mobile
// app" banner (ExpenseSyncBanner) has been removed per an explicit
// instruction — the underlying sync engine it referred to is untouched.
//
// New: a ROI Analytics screen (roi_analytics_screen.dart), reached via a
// "View ROI Analytics →" link on the Financial Summary card, built purely
// from the same computeRoi()/expenseTrendSeries() functions this slice
// already had available but wasn't rendering (see that file's header).
//
// Two standing scope notes carried over from the previous redesign: (1)
// the font stays the app's current default (no google_fonts dependency,
// to avoid a first-run network fetch on an offline-first app); (2) CSV/PDF
// export stays in the app bar's overflow (⋮) menu — see expenseAppBar() in
// expense_palette.dart.
// ══════════════════════════════════════════════════════════════════════
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key, required this.uid});
  final String uid;

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  // Entries mid-delete: kept visible but faded out for a beat before the
  // real deleteExpense() call removes them from the underlying data, so
  // removal reads as an animated exit instead of an instant disappearance.
  // Purely a screen-level presentation detail — no repository/controller
  // change.
  final Set<int> _removingIds = {};

  String get uid => widget.uid;

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesControllerProvider(uid));
    final controller = ref.read(expensesControllerProvider(uid).notifier);
    final fullName =
        ref.watch(userProfileProvider(uid)).valueOrNull?['fullName'] as String?;
    final lang = ref.watch(appLanguageProvider);

    ref.listen(expensesControllerProvider(uid), (previous, next) {
      final err = next.valueOrNull?.errorMessage;
      final prevErr = previous?.valueOrNull?.errorMessage;
      if (err != null && err != prevErr) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
        controller.clearError();
      }
    });

    final data = expensesAsync.valueOrNull;
    // A real (not invented) signal for the header's notification dot: at
    // least one expense was logged today, i.e. "something happened today".
    final hasTodayExpense = data != null &&
        data.expenses.any(
            (e) => e.date == DateTime.now().toIso8601String().split('T').first);

    return Scaffold(
      backgroundColor: ExpensePalette.background,
      drawer: DashboardDrawer(uid: uid, fullName: fullName),
      appBar: expenseAppBar(
        uid: uid,
        fullName: fullName,
        lang: lang,
        showNotificationBadge: hasTodayExpense,
        onExportCsv: () async {
          if (data != null) await shareExpensesCsv(data.expenses);
        },
        onExportPdf: () async {
          if (data != null) await shareExpensesPdf(data.expenses, data.roi);
        },
      ),
      body: expensesAsync.when(
        data: (data) => RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              ...expenseAnimatedChildren([
                _DayIntroHeader(currentDay: data.currentDay, lang: lang),
                const SizedBox(height: 14),
                const _FarmVisualBanner(),
                const SizedBox(height: 16),
                _RoiSummaryCard(
                  roi: data.roi,
                  lang: lang,
                  onViewAnalytics: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => RoiAnalyticsScreen(uid: uid)),
                  ),
                ),
                const SizedBox(height: 16),
                if (data.expenses.isEmpty)
                  _EmptyState(
                      onAddExpense: () => _openAddScreen(context, uid),
                      lang: lang)
                else ...[
                  Text(tr(lang, 'financialStatisticsSection'),
                      style: expenseSectionTitleStyle),
                  const SizedBox(height: 10),
                  _FinancialStatsGrid(data: data, lang: lang),
                  const SizedBox(height: 20),
                  Text(tr(lang, 'expenseBreakdownSection'),
                      style: expenseSectionTitleStyle),
                  const SizedBox(height: 10),
                  _ExpenseBreakdownDonutCard(data: data, lang: lang),
                  const SizedBox(height: 20),
                  Text(tr(lang, 'recentEntriesSection'),
                      style: expenseSectionTitleStyle),
                  const SizedBox(height: 10),
                ],
              ]),
              // Entry cards are keyed by expense id and built outside
              // expenseAnimatedChildren's index-based wrapping, so Flutter's
              // list reconciliation recognizes a genuinely new id (plays the
              // fade-slide entrance) versus an existing one that just moved
              // position (keeps its already-settled animation state, no
              // replay) — see ExpenseFadeSlideIn/_removingIds above.
              if (data.expenses.isNotEmpty)
                for (var i = 0; i < data.expenses.length; i++)
                  Padding(
                    key: ValueKey('expense_${data.expenses[i].id}'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity:
                          _removingIds.contains(data.expenses[i].id) ? 0 : 1,
                      child: ExpenseFadeSlideIn(
                        delayMs: i * 40,
                        child: _ExpenseEntryCard(
                          entry: data.expenses[i],
                          lang: lang,
                          onEdit: () => _openAddScreen(context, uid,
                              existing: data.expenses[i]),
                          onDelete: () =>
                              _confirmDelete(context, uid, data.expenses[i]),
                        ),
                      ),
                    ),
                  ),
              if (data.expenses.isNotEmpty) ...[
                const SizedBox(height: 10),
                ExpenseFadeSlideIn(
                  delayMs: data.expenses.length * 40,
                  child: _AddExpenseButton(
                      onTap: () => _openAddScreen(context, uid), lang: lang),
                ),
              ],
            ],
          ),
        ),
        loading: () => const _LoadingSkeleton(),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(lang, 'somethingWentWrongLoadingExpenses'),
                    style: const TextStyle(color: ExpensePalette.grayText)),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: ExpensePalette.primaryGreen),
                  onPressed: controller.load,
                  child: Text(tr(lang, 'retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAddScreen(BuildContext context, String uid,
      {ExpenseEntry? existing}) async {
    final lang = ref.read(appLanguageProvider);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AddExpenseScreen(uid: uid, existing: existing),
      ),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(existing != null
              ? tr(lang, 'expenseUpdatedSnackbar')
              : tr(lang, 'expenseAddedSnackbar'))));
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, String uid, ExpenseEntry entry) async {
    final lang = ref.read(appLanguageProvider);
    final confirmed = await showCustomConfirmDialog(
      context,
      title: tr(lang, 'deleteExpenseTitle'),
      message:
          '${tr(lang, 'deleteExpenseBodyPrefix')} "${entry.description.isEmpty ? entry.category : entry.description}" (₱${entry.amount.toStringAsFixed(2)})${tr(lang, 'deleteExpenseBodySuffix')}',
      confirmLabel: tr(lang, 'delete'),
      cancelLabel: tr(lang, 'cancel'),
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _removingIds.add(entry.id));
    await Future.delayed(const Duration(milliseconds: 220));
    if (!context.mounted) return;
    await ref
        .read(expensesControllerProvider(uid).notifier)
        .deleteExpense(entry);
    final err =
        ref.read(expensesControllerProvider(uid)).valueOrNull?.errorMessage;
    if (mounted) setState(() => _removingIds.remove(entry.id));
    if (err == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(lang, 'expenseDeletedSnackbar'))));
    }
  }
}

/// ₱ amount with thousands separators (e.g. ₱4,105) — the mockup's figures
/// are grouped like this; the rest of the
/// app formats plain (₱4105), so this is scoped to this screen only via a
/// local helper rather than changing shared formatting elsewhere.
String _peso(num value) => '₱${NumberFormat('#,##0').format(value)}';

/// Translated display label for an [ExpenseCategory] — presentation only.
/// [ExpenseCategory.label] itself (e.g. "Feed") stays untranslated because
/// it's the actual value stored/matched against in ExpenseEntry.category
/// (see ExpenseCategory.fromLabel) and read verbatim by CSV/PDF export —
/// same reasoning as the Health Monitor option catalogs. This helper only
/// changes what's shown on screen.
String _categoryLabel(AppLanguage lang, ExpenseCategory c) {
  final key = 'category${c.name[0].toUpperCase()}${c.name.substring(1)}';
  return tr(lang, key);
}

/// "Day X of 120" + "Live cost tracking for smarter farm decisions." — two
/// separate lines matching the mockup, replacing the old single-line
/// title/subtitle combo and the removed "Synced with mobile app" banner.
/// The bare screen title (expenseRoiTitle) still lives in the app bar
/// (see expenseAppBar()), so it isn't repeated here.
class _DayIntroHeader extends StatelessWidget {
  const _DayIntroHeader({required this.currentDay, required this.lang});
  final int currentDay;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            '${tr(lang, 'dayLabel')} $currentDay ${tr(lang, 'ofLabel')} $kMaxProductionDay',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ExpensePalette.darkText)),
        const SizedBox(height: 4),
        Text(tr(lang, 'liveCostTrackingSubtitle'),
            style: const TextStyle(
                fontSize: 12.5, color: ExpensePalette.grayText)),
      ],
    );
  }
}

/// Subtle farm visual header — sunrise/fields/barn/pig, exactly as the
/// mockup's illustrated banner between the day intro and the financial
/// cards. Purely decorative (a soft gradient + a few low-opacity emoji
/// layers, no new asset/image dependency) and deliberately short so the
/// financial metrics below remain the primary focus, per spec.
class _FarmVisualBanner extends StatelessWidget {
  const _FarmVisualBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        height: 88,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE0B2), Color(0xFFC8E6C9)],
          ),
        ),
        child: const Stack(
          children: [
            Positioned(
                left: 14,
                top: 10,
                child: Opacity(
                    opacity: 0.9,
                    child: Text('🌅', style: TextStyle(fontSize: 26)))),
            Positioned(
                right: 60,
                bottom: 6,
                child: Opacity(
                    opacity: 0.85,
                    child: Text('🌾', style: TextStyle(fontSize: 28)))),
            Positioned(
                right: 14,
                bottom: 4,
                child: Opacity(
                    opacity: 0.9,
                    child: Text('🐖', style: TextStyle(fontSize: 34)))),
            Positioned(
                left: 70,
                bottom: 2,
                child: Opacity(
                    opacity: 0.85,
                    child: Text('🏚️', style: TextStyle(fontSize: 30)))),
          ],
        ),
      ),
    );
  }
}

/// "+ Add Expense" — the large full-width green button that sits at the
/// bottom of the list (mockup's final visual-hierarchy element, right
/// above the bottom nav), reusing the exact same _openAddScreen() flow the
/// removed FAB used to trigger. Only shown once there's at least one
/// expense — the empty state already has its own "+ Add Expense" CTA.
class _AddExpenseButton extends StatelessWidget {
  const _AddExpenseButton({required this.onTap, required this.lang});
  final VoidCallback onTap;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 20),
        label: Text(tr(lang, 'addExpenseButton'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        style: FilledButton.styleFrom(
          backgroundColor: ExpensePalette.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

/// Financial Summary / ROI — the same computeRoi() figures the old
/// (bottom-of-list, collapsible) _FinancialSummaryCard showed, now always
/// expanded and positioned right under the hero, matching the mockup's
/// "ROI / Financial Summary" priority. A "View ROI Analytics →" link opens
/// the new roi_analytics_screen.dart, which reuses the same RoiResult plus
/// the expense/feed trend series that were already computed but unused.
class _RoiSummaryCard extends StatelessWidget {
  const _RoiSummaryCard(
      {required this.roi, required this.lang, required this.onViewAnalytics});
  final RoiResult roi;
  final AppLanguage lang;
  final VoidCallback onViewAnalytics;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined,
                  color: ExpensePalette.primaryGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(tr(lang, 'financialSummarySection'),
                      style: expenseSectionTitleStyle)),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onViewAnalytics,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tr(lang, 'viewRoiAnalyticsLabel'),
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: ExpensePalette.primaryGreen)),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 13, color: ExpensePalette.primaryGreen),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _FinFigure(
                      label: tr(lang, 'projectedRevenueLabel'),
                      value: roi.projectedRevenue)),
              Expanded(
                  child: _FinFigure(
                      label: tr(lang, 'totalExpensesLabel'),
                      value: roi.totalInvested)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FinFigure(
                  label: tr(lang, 'netProfitLabel'),
                  value: roi.netProfit,
                  color: roi.profitable
                      ? ExpensePalette.primaryGreen
                      : ExpensePalette.red,
                ),
              ),
              Expanded(
                child: _FinFigure(
                  label: tr(lang, 'roiPercentLabel'),
                  value: roi.roiPercent,
                  isPercent: true,
                  color: roi.profitable
                      ? ExpensePalette.primaryGreen
                      : ExpensePalette.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinFigure extends StatelessWidget {
  const _FinFigure(
      {required this.label,
      required this.value,
      this.isPercent = false,
      this.color});
  final String label;
  final double value;
  final bool isPercent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = isPercent
        ? '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%'
        : _peso(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: ExpensePalette.grayText)),
        const SizedBox(height: 2),
        Text(text,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color ?? ExpensePalette.darkText)),
      ],
    );
  }
}

/// Financial Statistics 2x2 grid — Feed Cost, Avg Daily Cost, Net Profit,
/// ROI%. Every value is an existing getter (data.feedCost/
/// data.totalExpenses/data.currentDay/data.roi); "Avg Daily Cost" is a
/// plain totalExpenses ÷ currentDay division of already-real numbers, not
/// a new business calculation — same category as the Growth screen's
/// week-over-week diff captions.
class _FinancialStatsGrid extends StatelessWidget {
  const _FinancialStatsGrid({required this.data, required this.lang});
  final ExpensesData data;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final avgDailyCost =
        data.totalExpenses / (data.currentDay < 1 ? 1 : data.currentDay);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: _FinancialStatCard(
            icon: Icons.grass_rounded,
            iconColor: ExpensePalette.primaryGreen,
            label: tr(lang, 'categoryFeed'),
            value: _peso(data.feedCost),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FinancialStatCard(
            icon: Icons.calendar_today_rounded,
            iconColor: AppColors.blue,
            label: tr(lang, 'avgDailyCostLabel'),
            value: _peso(avgDailyCost),
          ),
        ),
      ]),
    );
  }
}

class _FinancialStatCard extends StatelessWidget {
  const _FinancialStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(height: 10),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: ExpensePalette.grayText)),
        const SizedBox(height: 4),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: ExpensePalette.darkText)),
      ]),
    );
  }
}

/// Expense Breakdown — an animated fl_chart donut (PieChart with
/// centerSpaceRadius, same technique as the Dashboard's Health donut in
/// health_overview_card.dart) plus a legend, replacing the old vertical
/// progress-bar list. Still fed by data.byCategory (categoryBreakdown() —
/// real per-category totals), with an honest "Not enough expense data yet"
/// state if that list is somehow empty.
class _ExpenseBreakdownDonutCard extends StatelessWidget {
  const _ExpenseBreakdownDonutCard({required this.data, required this.lang});
  final ExpensesData data;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final breakdown = data.byCategory;
    final total = data.totalExpenses;
    if (breakdown.isEmpty || total <= 0) {
      return CustomCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              Text(tr(lang, 'notEnoughExpenseDataYet'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ExpensePalette.grayText)),
              const SizedBox(height: 4),
              Text(tr(lang, 'notEnoughExpenseDataBody'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: ExpensePalette.grayText)),
            ]),
          ),
        ),
      );
    }
    return CustomCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                    sections: breakdown
                        .map((e) => PieChartSectionData(
                              value: e.value,
                              color: ExpensePalette.categoryColors[e.key.index %
                                  ExpensePalette.categoryColors.length],
                              showTitle: false,
                              radius: 18,
                            ))
                        .toList(),
                  ),
                  duration: const Duration(milliseconds: 600),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr(lang, 'totalLabel'),
                        style: const TextStyle(
                            fontSize: 10.5, color: ExpensePalette.grayText)),
                    Text(_peso(total),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: ExpensePalette.darkText)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < breakdown.length; i++) ...[
                  _DonutLegendRow(
                    category: breakdown[i].key,
                    amount: breakdown[i].value,
                    percent: total <= 0 ? 0 : (breakdown[i].value / total),
                    color: ExpensePalette.categoryColors[
                        breakdown[i].key.index %
                            ExpensePalette.categoryColors.length],
                    lang: lang,
                  ),
                  if (i != breakdown.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutLegendRow extends StatelessWidget {
  const _DonutLegendRow(
      {required this.category,
      required this.amount,
      required this.percent,
      required this.color,
      required this.lang});
  final ExpenseCategory category;
  final double amount;
  final double percent;
  final Color color;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _categoryLabel(lang, category),
      value: '${(percent * 100).round()}%',
      child: Row(
        children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(_categoryLabel(lang, category),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ExpensePalette.darkText)),
          ),
          Text('${(percent * 100).round()}%',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _ExpenseEntryCard extends StatelessWidget {
  const _ExpenseEntryCard(
      {required this.entry,
      required this.onEdit,
      required this.onDelete,
      required this.lang});
  final ExpenseEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final cat = ExpenseCategory.fromLabel(entry.category);
    final catLabel = _categoryLabel(lang, cat);
    final color = ExpensePalette
        .categoryColors[cat.index % ExpensePalette.categoryColors.length];
    final entryLabel =
        '${entry.description.isEmpty ? catLabel : entry.description}, $catLabel, ${_peso(entry.amount)}, ${entry.date}';
    return Material(
      color: ExpensePalette.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showMoreOptions(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: entryLabel,
                  container: true,
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: Text(cat.icon,
                              style: const TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.description.isEmpty
                                    ? catLabel
                                    : entry.description,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: ExpensePalette.darkText),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text('$catLabel · ${entry.date}',
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: ExpensePalette.grayText)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_peso(entry.amount),
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: ExpensePalette.darkText)),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.more_vert, color: ExpensePalette.grayText),
                tooltip: tr(lang, 'moreOptionsTitle'),
                onPressed: () => _showMoreOptions(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    // showGeneralDialog (rather than plain showDialog) so the barrier can
    // carry a BackdropFilter blur behind the modal, plus a custom
    // scale+fade transitionBuilder — the mockup's "blurred background" /
    // "Material animation" requirements.
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: tr(lang, 'moreOptionsTitle'),
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secondaryAnim) => _MoreOptionsDialog(
        lang: lang,
        onEdit: () {
          Navigator.pop(ctx);
          onEdit();
        },
        onDelete: () {
          Navigator.pop(ctx);
          onDelete();
        },
      ),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter:
              ImageFilter.blur(sigmaX: 3 * anim.value, sigmaY: 3 * anim.value),
          child: FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: curved, child: child),
          ),
        );
      },
    );
  }
}

/// Centered "More Options" modal (Edit / Delete / Cancel), matching the
/// reference screenshot's rounded card with a small drag-handle dot row at
/// top — a Dialog rather than a bottom sheet since the mockup shows it
/// vertically centered, not anchored to the bottom edge.
class _MoreOptionsDialog extends StatelessWidget {
  const _MoreOptionsDialog(
      {required this.onEdit, required this.onDelete, required this.lang});
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // Explicit light surface + tint override: this screen's ExpensePalette
      // is a fixed light palette (not dark-mode reactive), but the bare
      // Dialog() widget otherwise inherits the app ColorScheme's dialog
      // surface, which is dark under the app's dark theme. Without pinning
      // this, the hardcoded dark-on-light text/icon colors below become
      // near-invisible on a dark card. Pin both so this modal always renders
      // as the same light, on-brand card regardless of system theme.
      backgroundColor: ExpensePalette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag-handle affordance dot row, in place of the plain "..."
            // glyph — reads as a proper bottom-sheet-style handle instead of
            // stray typography.
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: ExpensePalette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(tr(lang, 'moreOptionsTitle'),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: ExpensePalette.darkText)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: ExpensePalette.primaryGreen),
                label: Text(tr(lang, 'edit'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ExpensePalette.darkText)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: ExpensePalette.background,
                  side: const BorderSide(color: ExpensePalette.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.white),
                label: Text(tr(lang, 'delete'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: ExpensePalette.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: ExpensePalette.grayText,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(tr(lang, 'cancel'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddExpense, required this.lang});
  final VoidCallback onAddExpense;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          const Text('📦', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(tr(lang, 'noExpensesYetTitle'),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ExpensePalette.darkText)),
          const SizedBox(height: 6),
          Text(
            tr(lang, 'tapAddFirstExpense'),
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 12.5, color: ExpensePalette.grayText),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAddExpense,
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr(lang, 'addExpenseButton')),
            style: OutlinedButton.styleFrom(
              foregroundColor: ExpensePalette.primaryGreen,
              side: const BorderSide(color: ExpensePalette.primaryGreen),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer loading state — a lightweight, dependency-free sweeping
// gradient (no `shimmer` package added, matching the "no new dependency
// unless necessary" call made for the font) shaped like the real layout:
// hero, ROI card, breakdown card, and a few entry-card placeholders. ──

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox(
      {required this.height, this.width = double.infinity, this.radius = 14});
  final double height;
  final double width;
  final double radius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: SizedBox(
            height: widget.height,
            width: widget.width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + t * 3, 0),
                  end: Alignment(0 + t * 3, 0),
                  colors: const [
                    Color(0xFFEDEDED),
                    Color(0xFFF7F7F7),
                    Color(0xFFEDEDED)
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        const _ShimmerBox(height: 34, width: 160),
        const SizedBox(height: 16),
        const _ShimmerBox(height: 150, radius: 22),
        const SizedBox(height: 16),
        const _ShimmerBox(height: 110, radius: 20),
        const SizedBox(height: 16),
        CustomCard(
          child: Column(
            children: List.generate(4, (i) {
              return Padding(
                padding: EdgeInsets.only(bottom: i == 3 ? 0 : 18),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(height: 14, width: 140),
                    SizedBox(height: 8),
                    _ShimmerBox(height: 7, radius: 6),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(
            3,
            (i) => const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: _ShimmerBox(height: 66, radius: 18))),
      ],
    );
  }
}

/// Add/Edit Expense — a full screen (was a bottom sheet) matching the
/// mockup's dedicated Add/Edit panels. Same fields/validation/controller
/// calls as before (category, description, amount, date, note →
/// addExpense()/updateExpense()) — only the container and the category
/// picker's visual style changed (Material 3 selection grid instead of a
/// ChoiceChip Wrap).
class _AddExpenseScreen extends ConsumerStatefulWidget {
  const _AddExpenseScreen({required this.uid, this.existing});
  final String uid;
  final ExpenseEntry? existing;

  @override
  ConsumerState<_AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<_AddExpenseScreen> {
  late ExpenseCategory _category;
  late final TextEditingController _descCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  final _descFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _noteFocus = FocusNode();
  late DateTime _date;
  String? _localError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _category = e != null
        ? ExpenseCategory.fromLabel(e.category)
        : ExpenseCategory.feed;
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _amountCtrl = TextEditingController(text: e?.amount.toString() ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _date = e != null
        ? (DateTime.tryParse(e.date) ?? DateTime.now())
        : DateTime.now();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _descFocus.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref
            .watch(expensesControllerProvider(widget.uid))
            .valueOrNull
            ?.isSaving ??
        false;
    final lang = ref.watch(appLanguageProvider);
    return Scaffold(
      backgroundColor: ExpensePalette.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ExpensePalette.darkText,
        title: Text(
            _isEdit
                ? tr(lang, 'editExpenseTitle')
                : tr(lang, 'addExpenseButton'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: ExpensePalette.darkText)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _isEdit
                            ? tr(lang, 'editExpenseScreenSubtitle')
                            : tr(lang, 'addExpenseScreenSubtitle'),
                        style: const TextStyle(
                            fontSize: 12.5, color: ExpensePalette.grayText)),
                    const SizedBox(height: 18),
                    Text(tr(lang, 'categorySectionLabel').toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: ExpensePalette.grayText,
                            letterSpacing: 0.3)),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.05,
                      children: ExpenseCategory.values.map((c) {
                        final selected = _category == c;
                        return _CategoryGridCard(
                          icon: c.icon,
                          label: _categoryLabel(lang, c),
                          selected: selected,
                          onTap: () => setState(() => _category = c),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    _SheetField(
                      label: tr(lang, 'descriptionLabel'),
                      controller: _descCtrl,
                      hint: tr(lang, 'descriptionHint'),
                      focusNode: _descFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_amountFocus),
                    ),
                    const SizedBox(height: 12),
                    _SheetField(
                      label: tr(lang, 'amountPesoLabel'),
                      controller: _amountCtrl,
                      hint: '0.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      focusNode: _amountFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_noteFocus),
                    ),
                    const SizedBox(height: 12),
                    Text(tr(lang, 'dateUpperLabel'),
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: ExpensePalette.grayText,
                            letterSpacing: 0.3)),
                    const SizedBox(height: 6),
                    Semantics(
                      button: true,
                      label:
                          '${tr(lang, 'dateUpperLabel')}: ${_date.toIso8601String().split('T').first}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100));
                          if (picked != null) setState(() => _date = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                              color: ExpensePalette.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: ExpensePalette.border)),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      _date.toIso8601String().split('T').first,
                                      style: const TextStyle(
                                          fontSize: 14.5,
                                          color: ExpensePalette.darkText))),
                              const Icon(Icons.calendar_today,
                                  size: 16, color: ExpensePalette.grayText),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SheetField(
                      label: tr(lang, 'notesOptional'),
                      controller: _noteCtrl,
                      hint: tr(lang, 'additionalRemarksHint'),
                      maxLines: 2,
                      focusNode: _noteFocus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                    ),
                    if (_localError != null) ...[
                      const SizedBox(height: 10),
                      Text(_localError!,
                          style: const TextStyle(
                              fontSize: 12.5, color: ExpensePalette.red)),
                    ],
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    button: true,
                    label: isSaving
                        ? tr(lang, 'saving')
                        : (_isEdit
                            ? tr(lang, 'saveChanges')
                            : tr(lang, 'saveExpense')),
                    liveRegion: isSaving,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ExpensePalette.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isSaving ? null : _save,
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isEdit
                                  ? tr(lang, 'saveChanges')
                                  : tr(lang, 'saveExpense'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final lang = ref.read(appLanguageProvider);
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _localError = tr(lang, 'amountMustBeGreaterThanZero'));
      return;
    }
    setState(() => _localError = null);
    final controller =
        ref.read(expensesControllerProvider(widget.uid).notifier);
    final dateIso = _date.toIso8601String().split('T').first;
    final ok = _isEdit
        ? await controller.updateExpense(
            id: widget.existing!.id,
            category: _category.label,
            description: _descCtrl.text.trim(),
            amount: amount,
            date: dateIso,
            note: _noteCtrl.text.trim(),
          )
        : await controller.addExpense(
            category: _category.label,
            description: _descCtrl.text.trim(),
            amount: amount,
            date: dateIso,
            note: _noteCtrl.text.trim(),
          );
    if (ok && mounted) Navigator.pop(context, true);
  }
}

/// Material 3 category selection card — selected state uses the ASF green
/// with a check indicator and slight elevation; unselected is a white
/// surface with a soft border, matching the mockup's category grid.
class _CategoryGridCard extends StatelessWidget {
  const _CategoryGridCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ExpensePalette.primaryGreen : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: selected ? 3 : 0,
      shadowColor: ExpensePalette.primaryGreen.withValues(alpha: 0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected
                    ? ExpensePalette.primaryGreen
                    : ExpensePalette.border),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : ExpensePalette.darkText)),
                ],
              ),
              if (selected)
                const Positioned(
                  right: 0,
                  top: 0,
                  child:
                      Icon(Icons.check_circle, size: 14, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: ExpensePalette.grayText,
                letterSpacing: 0.3)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
              color: ExpensePalette.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ExpensePalette.border)),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            maxLines: maxLines,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                filled: true,
                fillColor: ExpensePalette.background),
          ),
        ),
      ],
    );
  }
}
