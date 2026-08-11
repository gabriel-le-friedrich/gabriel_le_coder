import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/health_calculations.dart';
import '../../domain/health_status_colors.dart';
import '../theme/health_monitor_palette.dart';
import '../widgets/health_monitor_widgets.dart';

// ══════════════════════════════════════════════════════════════════════
// Herd Health Summary — a pure AGGREGATION of the individual real
// HealthLogEntry rows just created for each selected pig during the
// Overall Herd run (see HealthHerdRunnerScreen). No new score is computed
// here; counts are grouped straight from each entry's own
// computeHealthAssessment() result, exactly like every other Health
// Monitor surface.
// ══════════════════════════════════════════════════════════════════════
class HealthHerdSummaryScreen extends ConsumerWidget {
  const HealthHerdSummaryScreen({super.key, required this.entries});
  final List<HealthLogEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final counts = <HealthStatus, int>{
      for (final s in HealthStatus.values) s: 0,
    };
    for (final e in entries) {
      counts[e.status] = (counts[e.status] ?? 0) + 1;
    }
    final total = entries.length;
    final criticalCount = counts[HealthStatus.critical] ?? 0;
    final riskCount = counts[HealthStatus.risk] ?? 0;

    return Scaffold(
      backgroundColor: HealthMonitorPalette.background,
      appBar: AppBar(
        backgroundColor: HealthMonitorPalette.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(tr(lang, 'herdHealthSummaryTitle'),
            style: const TextStyle(
                color: HealthMonitorPalette.darkText,
                fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: healthAnimatedChildren([
          Text('$total ${tr(lang, 'pigsMonitoredLabel')}',
              style: const TextStyle(
                  fontSize: 13, color: HealthMonitorPalette.grayText)),
          const SizedBox(height: 14),
          if (criticalCount > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kHealthStatusColor[HealthStatus.critical]!
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: kHealthStatusColor[HealthStatus.critical]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: kHealthStatusColor[HealthStatus.critical]),
                      const SizedBox(width: 8),
                      Text(tr(lang, 'attentionRequiredTitle'),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: kHealthStatusColor[HealthStatus.critical]!
                                  .withValues(alpha: 0.9))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                      '$criticalCount ${tr(lang, 'attentionRequiredBody')}',
                      style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 10),
                  CustomButton(
                    label: tr(lang, 'reviewCriticalPigsButton'),
                    backgroundColor: kHealthStatusColor[HealthStatus.critical]!,
                    onPressed: () => context.push(AppRoutes.health,
                        extra: HealthStatus.critical),
                  ),
                ],
              ),
            ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              for (final s in HealthStatus.values)
                HealthOverviewTile(
                  label: healthStatusLabel(lang, s),
                  count: counts[s] ?? 0,
                  color: kHealthStatusColor[s]!,
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (riskCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CustomButton(
                label: tr(lang, 'reviewAtRiskPigsButton'),
                outlined: true,
                backgroundColor: kHealthStatusColor[HealthStatus.risk]!,
                onPressed: () =>
                    context.push(AppRoutes.health, extra: HealthStatus.risk),
              ),
            ),
          CustomButton(
            label: tr(lang, 'viewHealthLogs'),
            outlined: true,
            backgroundColor: HealthMonitorPalette.primaryGreen,
            onPressed: () => context.push(AppRoutes.health),
          ),
          const SizedBox(height: 10),
          CustomButton(
            label: tr(lang, 'newHealthCheckButton'),
            backgroundColor: HealthMonitorPalette.primaryGreen,
            onPressed: () =>
                context.go(AppRoutes.healthHub),
          ),
        ]),
      ),
    );
  }
}
