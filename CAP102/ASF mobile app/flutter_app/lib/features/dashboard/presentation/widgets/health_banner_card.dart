import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../health/domain/health_calculations.dart';
import '../../../health/domain/health_status_colors.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../providers/dashboard_providers.dart';
import '../theme/dashboard_palette.dart';

/// "Today's Health" — Round 3 item 8 (⭐⭐⭐ biggest requested feature):
/// surfaces today's latest health assessment right on the Dashboard —
/// status, a compact summary of every field, and a veterinarian
/// recommendation when applicable — so a farmer never has to open Health
/// Logs just to see today's result. Falls back to a "log it now" prompt
/// when nothing has been recorded for the current production day yet.
class HealthBannerCard extends StatelessWidget {
  const HealthBannerCard({super.key, required this.data, required this.lang});
  final DashboardData data;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final latest = data.latestHealthLog;
    if (latest == null) {
      return _PromptCard(
        title: tr(lang, 'noHealthObservationsYet'),
        subtitle: tr(lang, 'logTodayHealthCheckSubtitle'),
        onTap: () => context.push(AppRoutes.healthHub),
      );
    }
    if (!data.hasHealthLogToday) {
      final meta = kHealthStatusMeta[latest.status]!;
      final statusLabel = healthStatusLabel(lang, latest.status);
      return _PromptCard(
        title: tr(lang, 'healthNotLoggedYetTitle'),
        subtitle:
            '${tr(lang, 'lastRecordedPrefix')} ${meta.emoji} $statusLabel ${tr(lang, 'onDayLabel')} ${latest.day}. ${tr(lang, 'logTodayCheckToStayOnTrack')}',
        onTap: () => context.push(AppRoutes.healthHub),
      );
    }
    return _TodaysHealthCard(
        entry: latest,
        onTap: () => context.push(AppRoutes.healthHub),
        lang: lang);
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard(
      {required this.title, required this.subtitle, required this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: DashboardPalette.background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('🩺', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: DashboardPalette.textGray)),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 11.5, color: Colors.black54)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: DashboardPalette.textGray),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Joins the non-zero physical severity counts, e.g. "6 Healthy, 1 Needs
/// Monitoring" — omits tiers with zero selections so the summary stays
/// short, matching the Dashboard mockup exactly.
String _physicalCountsSummary(HealthLogEntry e, AppLanguage lang) {
  final parts = <String>[
    if (e.healthyCount > 0) '${e.healthyCount} ${tr(lang, 'healthyChip')}',
    if (e.monitorCount > 0) '${e.monitorCount} ${tr(lang, 'needsMonitoring')}',
    if (e.riskCount > 0) '${e.riskCount} ${tr(lang, 'atRiskSection')}',
    if (e.criticalCount > 0)
      '${e.criticalCount} ${tr(lang, 'criticalSection')}',
  ];
  return parts.isEmpty ? tr(lang, 'noneRecorded') : parts.join(', ');
}

class _TodaysHealthCard extends StatelessWidget {
  const _TodaysHealthCard(
      {required this.entry, required this.onTap, required this.lang});
  final HealthLogEntry entry;
  final VoidCallback onTap;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final meta = kHealthStatusMeta[entry.status]!;
    final statusLabel = healthStatusLabel(lang, entry.status);
    final color = kHealthStatusColor[entry.status]!;
    final isCritical = entry.status == HealthStatus.critical;
    final beh = healthOptionLabel(
        lang,
        'behavior',
        entry.behavior,
        findHealthOption(kBehaviorOptions, entry.behavior)?.label ??
            entry.behavior);
    final app = healthOptionLabel(
        lang,
        'appetite',
        entry.appetite,
        findHealthOption(kAppetiteOptions, entry.appetite)?.label ??
            entry.appetite);
    final waste = healthOptionLabel(lang, 'waste', entry.waste,
        findHealthOption(kWasteOptions, entry.waste)?.label ?? entry.waste);

    final semanticsLabel = "${tr(lang, 'todaysHealthLabel')}: $statusLabel."
        '${isCritical ? ' ${tr(lang, 'criticalHealthAlert')}, ${tr(lang, 'vetRecommendedSuffix')}.' : ''} '
        '${tr(lang, 'behaviorLabel')} $beh, ${tr(lang, 'appetiteLabel')} $app, ${tr(lang, 'physicalLabel')} ${_physicalCountsSummary(entry, lang)}, ${tr(lang, 'wasteLabel')} $waste.';

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(tr(lang, 'todaysHealthLabel'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: DashboardPalette.textGray)),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: color),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(meta.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(statusLabel,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: color)),
                    ],
                  ),
                  if (isCritical) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Text('🚨', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${tr(lang, 'criticalHealthAlert')} · ${tr(lang, 'vetRecommendedSuffix')}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(tr(lang, 'lastAssessmentLabel'),
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: DashboardPalette.textGray)),
                  Text('${tr(lang, 'todayAtLabel')} • ${entry.time}',
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.black54)),
                  const SizedBox(height: 8),
                  _InfoLine(label: tr(lang, 'behaviorLabel'), value: beh),
                  _InfoLine(label: tr(lang, 'appetiteLabel'), value: app),
                  _InfoLine(
                      label: tr(lang, 'physicalLabel'),
                      value: _physicalCountsSummary(entry, lang)),
                  _InfoLine(label: tr(lang, 'wasteLabel'), value: waste),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: DashboardPalette.textGray)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
