import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../dashboard/domain/dashboard_calculations.dart' show RoiResult;
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/expense_calculations.dart';
import '../providers/expenses_providers.dart';
import '../theme/expense_palette.dart';

// ══════════════════════════════════════════════════════════════════════
// ROI Analytics — a new screen reached from the Expense & ROI screen's
// "View ROI Analytics →" link. Nothing here is a new calculation: the
// Total ROI hero and Profitability Overview card read the exact same
// RoiResult (computeRoi() in dashboard_calculations.dart) the main screen
// already showed, and the Cost vs Revenue Trend chart is built from
// expenseTrendSeries() (expense_calculations.dart) — a function that has
// existed in this codebase since the very first Expense & ROI redesign
// but was never rendered on screen (see the header comment history in
// expenses_screen.dart). Revenue itself is a single projected figure (it
// depends on the pig's *current* weight, not a per-week history), so the
// chart plots real week-by-week cumulative cost against a dashed
// reference line at that projected revenue value — the same
// "line vs. dashed target" technique already used by the Weight/Growth
// screens' charts — rather than inventing a fabricated week-by-week
// revenue series.
// ══════════════════════════════════════════════════════════════════════
class RoiAnalyticsScreen extends ConsumerWidget {
  const RoiAnalyticsScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesControllerProvider(uid));
    final lang = ref.watch(appLanguageProvider);
    return Scaffold(
      backgroundColor: ExpensePalette.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ExpensePalette.darkText,
        title: Text(tr(lang, 'roiAnalyticsTitle'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: ExpensePalette.darkText)),
      ),
      body: expensesAsync.when(
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _TotalRoiHero(roi: data.roi, lang: lang),
            const SizedBox(height: 16),
            _ProfitabilityOverviewCard(roi: data.roi, lang: lang),
            const SizedBox(height: 20),
            Text(tr(lang, 'costVsRevenueTrendSection'),
                style: expenseSectionTitleStyle),
            const SizedBox(height: 10),
            _CostVsRevenueTrendCard(
              trend: data.expenseTrend,
              projectedRevenue: data.roi.projectedRevenue,
              lang: lang,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(tr(lang, 'somethingWentWrongLoadingExpenses'),
              style: const TextStyle(color: ExpensePalette.grayText)),
        ),
      ),
    );
  }
}

String _peso(num value) => '₱${NumberFormat('#,##0').format(value)}';

class _TotalRoiHero extends StatelessWidget {
  const _TotalRoiHero({required this.roi, required this.lang});
  final RoiResult roi;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.darkGreen, AppColors.primaryGreen],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.query_stats_rounded,
                  size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(tr(lang, 'totalRoiLabel').toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6)),
            ]),
            const SizedBox(height: 12),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: roi.roiPercent),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text(
                    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(tr(lang, 'netProfitLabel'),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(lang, 'revenueLabel'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11.5)),
                      const SizedBox(height: 2),
                      Text(_peso(roi.projectedRevenue),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.white24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(tr(lang, 'costLabel'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11.5)),
                      const SizedBox(height: 2),
                      Text(_peso(roi.totalInvested),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfitabilityOverviewCard extends StatelessWidget {
  const _ProfitabilityOverviewCard({required this.roi, required this.lang});
  final RoiResult roi;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'profitabilityOverviewSection'),
              style: expenseSectionTitleStyle),
          const SizedBox(height: 14),
          _ProfitRow(
              label: tr(lang, 'projectedRevenueLabel'),
              value: _peso(roi.projectedRevenue)),
          const Divider(height: 22, color: ExpensePalette.border),
          _ProfitRow(
              label: tr(lang, 'totalExpensesLabel'),
              value: _peso(roi.totalInvested)),
          const Divider(height: 22, color: ExpensePalette.border),
          _ProfitRow(
            label: tr(lang, 'netProfitLabel'),
            value: _peso(roi.netProfit),
            valueColor: roi.profitable
                ? ExpensePalette.primaryGreen
                : ExpensePalette.red,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _ProfitRow extends StatelessWidget {
  const _ProfitRow(
      {required this.label,
      required this.value,
      this.valueColor,
      this.bold = false});
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: ExpensePalette.grayText)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? ExpensePalette.darkText)),
      ],
    );
  }
}

/// Cost vs Revenue Trend — real, cumulative per-week spend
/// (expenseTrendSeries()) plotted against a dashed reference line at the
/// current projected revenue. "Not enough data yet" once there are fewer
/// than two weeks of expense history to draw a trend from.
class _CostVsRevenueTrendCard extends StatelessWidget {
  const _CostVsRevenueTrendCard(
      {required this.trend,
      required this.projectedRevenue,
      required this.lang});
  final List<ExpenseTrendPoint> trend;
  final double projectedRevenue;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trend.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
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
            )
          else
            SizedBox(
              height: 200,
              child:
                  _TrendChart(trend: trend, projectedRevenue: projectedRevenue),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Container(
                width: 14,
                height: 3,
                decoration: BoxDecoration(
                    color: ExpensePalette.primaryGreen,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(tr(lang, 'costLabel'),
                style: const TextStyle(
                    fontSize: 11.5, color: ExpensePalette.grayText)),
            const SizedBox(width: 16),
            Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    3,
                    (i) => Padding(
                        padding: EdgeInsets.only(right: i == 2 ? 0 : 2),
                        child: Container(
                            width: 3,
                            height: 3,
                            color: ExpensePalette.grayText)))),
            const SizedBox(width: 6),
            Text(tr(lang, 'revenueLabel'),
                style: const TextStyle(
                    fontSize: 11.5, color: ExpensePalette.grayText)),
          ]),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.trend, required this.projectedRevenue});
  final List<ExpenseTrendPoint> trend;
  final double projectedRevenue;

  @override
  Widget build(BuildContext context) {
    // Running (cumulative) total per week — a plain sum of the already-real
    // per-week totals, not a new business calculation.
    double running = 0;
    final spots = <FlSpot>[];
    for (final p in trend) {
      running += p.total;
      spots.add(FlSpot(p.week.toDouble(), running));
    }
    final firstWeek = trend.first.week.toDouble();
    final lastWeek = trend.last.week.toDouble();
    final maxCost = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxY =
        [maxCost, projectedRevenue].reduce((a, b) => a > b ? a : b) * 1.15 + 1;
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxY,
      minX: firstWeek,
      maxX: lastWeek,
      gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: ExpensePalette.border, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                    NumberFormat.compact().format(value),
                    style: const TextStyle(
                        fontSize: 9.5, color: ExpensePalette.grayText)))),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text('W${value.toInt()}',
                    style: const TextStyle(
                        fontSize: 10, color: ExpensePalette.grayText)))),
      ),
      lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touched) => touched
                  .map((t) => LineTooltipItem(
                      _peso(t.y), const TextStyle(color: Colors.white)))
                  .toList())),
      lineBarsData: [
        LineChartBarData(
            spots: spots,
            isCurved: true,
            color: ExpensePalette.primaryGreen,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData:
                BarAreaData(show: true, color: const Color(0xFFE8F5E9))),
        LineChartBarData(
            spots: [
              FlSpot(firstWeek, projectedRevenue),
              FlSpot(lastWeek, projectedRevenue)
            ],
            isCurved: false,
            color: ExpensePalette.grayText,
            barWidth: 1.5,
            dashArray: const [6, 4],
            dotData: const FlDotData(show: false)),
      ],
    ));
  }
}
