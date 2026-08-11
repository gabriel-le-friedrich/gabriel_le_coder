import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../domain/dashboard_calculations.dart';
import '../theme/dashboard_palette.dart';

/// "Weight Progress" hero card — a gradient-filled line chart over the same
/// weightVsWeekSeries() points the Pig Growth module already charts, plus
/// Start/Current/Target badges. "View Details" opens the merged Pig Growth
/// tab (formerly the separate Weight & ADG screen) for the full weigh-in
/// history, edit, and the ADG/FCR trend cards — this card is a summary, not
/// a replacement.
class WeightProgressCard extends StatelessWidget {
  const WeightProgressCard({
    super.key,
    required this.weightLogs,
    required this.startWeight,
    required this.currentWeight,
    required this.hasPigs,
    required this.currentDay,
    this.growthPct,
  });

  final List<WeightLogEntry> weightLogs;
  final double? startWeight;
  final double currentWeight;
  final bool hasPigs;

  /// The persisted production-day counter (DashboardRepository.getCurrentDay)
  /// — used only to derive "has this week's official weigh-in been
  /// recorded yet," via the same weekNumberForDay() every other week
  /// calculation in the app reads from.
  final int currentDay;

  /// DashboardData.growthPct — the same getter HealthOverviewCard and the
  /// old combined Herd Overview card already used for their progress ring.
  /// Passed in (rather than recomputed here) so this card has no
  /// calculation of its own — just a different place to show the same
  /// number, per the mockup's "ring next to Current Weight" layout.
  final double? growthPct;

  @override
  Widget build(BuildContext context) {
    final series = weightVsWeekSeries(weightLogs);
    final currentWeek = weekNumberForDay(currentDay);
    final hasThisWeeksWeighIn =
        weightLogs.any((e) => e.isOfficial && e.weekNumber == currentWeek);
    final remaining = hasPigs
        ? (kMarketWeightKg - currentWeight).clamp(0.0, kMarketWeightKg)
        : null;

    return Container(
      decoration: dashboardCardDecoration(),
      padding: dashboardCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Expanded (not a bare Text) — matches the pattern the shared
              // ChartCard widget already uses for this exact "title +
              // trailing action link" shape. Without it, this title and the
              // "View Details" link were laid out at their natural
              // (unconstrained) widths and could exceed the card's content
              // width, overflowing the RenderFlex on the right — a real bug
              // this test/dashboard_responsive_test.dart's small/medium/
              // large viewport sweep caught (it reproduced at every one of
              // the three tested phone widths).
              const Expanded(
                child: Text(
                  'Weight Progress',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Semantics(
                button: true,
                label: 'Open full weight tracker',
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.pigs),
                  child: const Text(
                    'View Details',
                    style: TextStyle(
                        color: DashboardPalette.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Weight',
                        style: TextStyle(
                            fontSize: 11.5, color: DashboardPalette.textGray)),
                    const SizedBox(height: 2),
                    Text(
                      hasPigs ? '${currentWeight.toStringAsFixed(1)} kg' : '--',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ],
                ),
              ),
              _GrowthRing(growthPct: growthPct),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            label: !hasPigs || series.length < 2
                ? 'Weight progress chart: not enough data yet'
                : 'Weight progress chart. Start ${startWeight?.toStringAsFixed(1) ?? '--'} kilograms, '
                    'now ${currentWeight.toStringAsFixed(1)} kilograms',
            image: true,
            child: SizedBox(
              height: 140,
              child: !hasPigs
                  ? const _ChartEmptyState(
                      message: 'Add your first pig to start tracking weight.')
                  : series.length < 2
                      ? const _ChartEmptyState()
                      : _Chart(series: series),
            ),
          ),
          if (hasPigs && !hasThisWeeksWeighIn) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: DashboardPalette.accentOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 15, color: DashboardPalette.accentOrange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "This week's weight has not been recorded.",
                      style: TextStyle(
                          fontSize: 11.5,
                          color: DashboardPalette.accentOrange,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: DashboardPalette.lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                // Both sides Expanded (not one Expanded + one natural-width
                // child) — same "give every side a bounded, ellipsis-safe
                // slot" pattern used throughout this file (see the header
                // row's comment above). One fixed-width side here was
                // exactly the kind of thing test/dashboard_responsive_
                // test.dart's small-phone sweep exists to catch: at 320px
                // width the "Remaining" side's natural (unconstrained)
                // width could push the "Target Weight" side into overflow.
                Expanded(
                  child: _TargetStat(
                    icon: Icons.flag_rounded,
                    label: 'Target Weight',
                    value: '${kMarketWeightKg.toStringAsFixed(0)} kg',
                    alignEnd: false,
                  ),
                ),
                Expanded(
                  child: _TargetStat(
                    icon: Icons.trending_flat_rounded,
                    label: 'Remaining',
                    value: remaining == null
                        ? '--'
                        : '${remaining.toStringAsFixed(1)} kg',
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small circular growth-percent ring — reused verbatim (same visuals) from
/// the card that used to combine this with the Herd Overview panel. Now
/// lives next to "Current Weight" per the newest mockup; HealthOverviewCard
/// no longer renders its own copy of this ring.
class _GrowthRing extends StatelessWidget {
  const _GrowthRing({required this.growthPct});
  final double? growthPct;

  @override
  Widget build(BuildContext context) {
    final clamped =
        growthPct == null ? 0.0 : (growthPct! / 100).clamp(0.0, 1.0).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (context, value, _) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 7,
                    backgroundColor: DashboardPalette.lightGreen,
                    valueColor: const AlwaysStoppedAnimation(
                        DashboardPalette.primaryGreen),
                  ),
                ),
                Text(
                  growthPct == null
                      ? '--'
                      : '${growthPct!.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: DashboardPalette.darkGreen),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('of ${kMarketWeightKg.toStringAsFixed(0)} kg',
            style: const TextStyle(
                fontSize: 10, color: DashboardPalette.textGray)),
      ],
    );
  }
}

class _TargetStat extends StatelessWidget {
  const _TargetStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.alignEnd,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!alignEnd) ...[
              Icon(icon, size: 13, color: DashboardPalette.darkGreen),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: DashboardPalette.darkGreen),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (alignEnd) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 13, color: DashboardPalette.darkGreen),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.series});
  final List<ChartPoint> series;

  @override
  Widget build(BuildContext context) {
    final spots = series
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    final minY = series.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final maxY = series.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY).abs() * 0.2 + 1;

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= series.length) return const SizedBox.shrink();
                final isLast = i == series.length - 1;
                if (i != 0 && !isLast && i != series.length ~/ 2)
                  return const SizedBox.shrink();
                final label = isLast ? 'Today' : 'D${series[i].week * 7 - 6}';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 10, color: DashboardPalette.textGray)),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: DashboardPalette.primaryGreen,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 4,
                  color: DashboardPalette.primaryGreen,
                  strokeWidth: 2,
                  strokeColor: Colors.white),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  DashboardPalette.primaryGreen.withValues(alpha: 0.25),
                  DashboardPalette.primaryGreen.withValues(alpha: 0.0)
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState(
      {this.message = 'Add a weekly weigh-in to see your progress chart.'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message,
          style:
              const TextStyle(color: DashboardPalette.textGray, fontSize: 12)),
    );
  }
}
