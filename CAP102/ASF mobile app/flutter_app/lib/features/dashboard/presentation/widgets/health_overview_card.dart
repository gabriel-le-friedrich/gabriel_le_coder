import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../health/domain/health_calculations.dart';
import '../../../health/domain/health_status_colors.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../providers/dashboard_providers.dart';
import '../theme/dashboard_palette.dart';

/// "Health Overview" — a donut chart + legend + status banner built from
/// the exact same data HealthBannerCard and the old combined Herd Overview
/// card already used: the latest health assessment's healthyCount/
/// monitorCount/riskCount/criticalCount (per-tier counts from that
/// assessment's physical-symptom selections) and its overall `status`.
/// No new calculation exists in this file — this is a different
/// presentation of numbers the Dashboard already had. The growth-percent
/// ring that used to live in this card has moved to WeightProgressCard
/// (see that file), and the total-pigs/batch-name panel moved to
/// SummaryCardGrid's "Total Pigs" tile, so this card can give the health
/// breakdown the full width the mockup gives it.
class HealthOverviewCard extends StatelessWidget {
  const HealthOverviewCard({super.key, required this.data, required this.lang});
  final DashboardData data;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final latest = data.latestHealthLog;

    return Container(
      decoration: dashboardCardDecoration(),
      padding: dashboardCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'healthOverviewTitle'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (latest == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(tr(lang, 'noHerdDataYetCaption'),
                  style: const TextStyle(
                      fontSize: 12.5, color: DashboardPalette.textGray)),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 4, child: _HealthDonut(latest: latest)),
                Expanded(
                  flex: 6,
                  child: _HealthLegend(latest: latest, lang: lang),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StatusBanner(latest: latest, lang: lang),
          ],
        ],
      ),
    );
  }
}

class _HealthDonut extends StatelessWidget {
  const _HealthDonut({required this.latest});
  final HealthLogEntry latest;

  @override
  Widget build(BuildContext context) {
    final counts = {
      HealthStatus.healthy: latest.healthyCount,
      HealthStatus.monitor: latest.monitorCount,
      HealthStatus.risk: latest.riskCount,
      HealthStatus.critical: latest.criticalCount,
    };
    final total = counts.values.fold(0, (a, b) => a + b);

    return SizedBox(
      width: 118,
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              centerSpaceRadius: 34,
              sectionsSpace: total == 0 ? 0 : 2,
              sections: total == 0
                  ? [
                      PieChartSectionData(
                        value: 1,
                        color: DashboardPalette.lightGreen,
                        showTitle: false,
                        radius: 20,
                      ),
                    ]
                  : counts.entries
                      .where((e) => e.value > 0)
                      .map((e) => PieChartSectionData(
                            value: e.value.toDouble(),
                            color: kHealthStatusColor[e.key],
                            showTitle: false,
                            radius: 20,
                          ))
                      .toList(),
            ),
            duration: const Duration(milliseconds: 600),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$total',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const Text('Total',
                  style: TextStyle(
                      fontSize: 10.5, color: DashboardPalette.textGray)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthLegend extends StatelessWidget {
  const _HealthLegend({required this.latest, required this.lang});
  final HealthLogEntry latest;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final counts = {
      HealthStatus.healthy: latest.healthyCount,
      HealthStatus.monitor: latest.monitorCount,
      HealthStatus.risk: latest.riskCount,
      HealthStatus.critical: latest.criticalCount,
    };
    final total = counts.values.fold(0, (a, b) => a + b);
    final labels = {
      HealthStatus.healthy: tr(lang, 'healthyChip'),
      HealthStatus.monitor: tr(lang, 'needsMonitoring'),
      HealthStatus.risk: tr(lang, 'atRiskSection'),
      HealthStatus.critical: tr(lang, 'criticalSection'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: counts.entries.map((e) {
        final pct = total == 0 ? 0 : (e.value / total * 100).round();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                    color: kHealthStatusColor[e.key], shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(labels[e.key]!,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                '${e.value} ($pct%)',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: DashboardPalette.textGray),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.latest, required this.lang});
  final HealthLogEntry latest;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final color = kHealthStatusColor[latest.status]!;
    final caption = switch (latest.status) {
      HealthStatus.healthy => tr(lang, 'allGoodCaption'),
      HealthStatus.monitor => tr(lang, 'herdCaptionMonitor'),
      HealthStatus.risk => tr(lang, 'herdCaptionRisk'),
      HealthStatus.critical => tr(lang, 'herdCaptionCritical'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_rounded, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(lang, 'overallStatusLabel'),
                    style: const TextStyle(
                        fontSize: 10.5, color: DashboardPalette.textGray)),
                Text(healthStatusLabel(lang, latest.status),
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
          Expanded(
            child: Text(caption,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 11.5, color: DashboardPalette.textGray),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
