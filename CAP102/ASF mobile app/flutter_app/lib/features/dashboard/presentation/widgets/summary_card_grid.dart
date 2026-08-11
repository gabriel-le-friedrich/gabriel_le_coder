import 'package:flutter/material.dart';

import '../../../../shared/widgets/shared_widgets.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../domain/daily_task.dart';
import '../../domain/dashboard_calculations.dart';
import '../providers/dashboard_providers.dart';
import '../theme/dashboard_palette.dart';

/// The Dashboard's 2x2 hero stat grid — Total Pigs / Average Weight /
/// Growth Progress / Today's Tasks, matching the latest premium-dashboard
/// mockup exactly. Every value is read straight off the same DashboardData
/// the rest of the screen uses — pigCount, currentWeight + the existing
/// _weeklyDelta calc, growthPct, and doneTaskCount/kDailyTaskDefs.length —
/// no new calculations.
///
/// Design note (v2 of this grid): the previous version showed Days on
/// Track / Tasks Today / Avg Weight / Herd Status. This pass swaps in
/// Total Pigs and Growth Progress per the newest mockup, and drops Herd
/// Status from this grid — it's now the whole HealthOverviewCard below,
/// which gives it far more room than a single stat tile. Days on Track
/// is still visible via the day-counter pill under the hero. Nothing
/// computed here is new: growthPct is the same getter HealthOverviewCard/
/// WeightProgressCard already read.
class SummaryCardGrid extends StatelessWidget {
  const SummaryCardGrid({super.key, required this.data, required this.lang});
  final DashboardData data;
  final AppLanguage lang;

  /// Real week-over-week delta from the already-recorded weight history
  /// (last two plotted points) — not a new formula, just a diff of two
  /// existing values, matching the mockup's "+2.1 kg this week" caption.
  double? get _weeklyDelta {
    final series = weightVsWeekSeries(data.weightLogs);
    if (series.length < 2) return null;
    return series.last.value - series[series.length - 2].value;
  }

  @override
  Widget build(BuildContext context) {
    final delta = _weeklyDelta;
    final doneCount = data.doneTaskCount;
    final totalTasks = kDailyTaskDefs.length;
    final growthPct = data.growthPct;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // On narrow screens (<360px), cards need more vertical height ratio to prevent overflow.
        final aspectRatio = width < 360 ? 1.12 : (width < 400 ? 1.22 : 1.35);

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: [
            StatCard(
              icon: Icons.pets_rounded,
              iconBg: DashboardPalette.lightGreen,
              iconColor: DashboardPalette.darkGreen,
              label: tr(lang, 'totalPigsLabel'),
              value: '${data.pigCount}',
              caption: tr(lang, 'activeAnimalsCaption'),
              captionColor: DashboardPalette.textGray,
            ),
            StatCard(
              icon: Icons.monitor_weight_rounded,
              iconBg: const Color(0xFFE3F2FD),
              iconColor: const Color(0xFF1976D2),
              label: tr(lang, 'avgWeightStat'),
              value: data.hasPigs
                  ? '${data.currentWeight.toStringAsFixed(1)} kg'
                  : '--',
              caption: !data.hasPigs
                  ? tr(lang, 'noPigsYet')
                  : delta == null
                      ? tr(lang, 'noWeeklyDataYet')
                      : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} ${tr(lang, 'thisWeekSuffix')}',
              captionColor: !data.hasPigs
                  ? DashboardPalette.textGray
                  : (delta ?? 0) >= 0
                      ? DashboardPalette.primaryGreen
                      : DashboardPalette.warningRed,
            ),
            StatCard(
              icon: Icons.trending_up_rounded,
              iconBg: DashboardPalette.lightGreen,
              iconColor: DashboardPalette.primaryGreen,
              label: tr(lang, 'growthProgressStat'),
              value: growthPct == null ? '--' : '${growthPct.round()}%',
              caption:
                  '${tr(lang, 'ofLabel')} ${kMarketWeightKg.toStringAsFixed(0)}${tr(lang, 'targetWeightSuffix')}',
              captionColor: DashboardPalette.textGray,
            ),
            StatCard(
              icon: Icons.checklist_rounded,
              iconBg: const Color(0xFFFFF3E0),
              iconColor: DashboardPalette.accentOrange,
              label: tr(lang, 'todaysTasksTitle'),
              value: '$doneCount / $totalTasks',
              caption: tr(lang, 'completedTasksLabel'),
              captionColor: doneCount == totalTasks
                  ? DashboardPalette.primaryGreen
                  : DashboardPalette.accentOrange,
            ),
          ],
        );
      },
    );
  }
}
