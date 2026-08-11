import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../pigs/domain/pig.dart';
import '../../../pigs/presentation/providers/pig_providers.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/health_calculations.dart';
import '../../domain/health_status_colors.dart';
import '../providers/health_providers.dart';
import '../theme/health_monitor_palette.dart';
import '../widgets/health_monitor_widgets.dart';

// ══════════════════════════════════════════════════════════════════════
// Health Monitor Home hub — the independent entry point the ASF redesign
// spec calls for ("Health Monitor MUST BE ITS OWN FEATURE... DO NOT make
// the user access Health Monitor by pressing the Pig Growth button").
// Shows real Today's Overview counts, lets the farmer choose Specific Pig
// or Overall Herd monitoring, and surfaces Health Categories / 7-Day Trend
// / Last Health Check / Health Tips — all read-only summaries over the
// SAME HealthRepository/health_calculations.dart logic every other Health
// Monitor surface already uses. No new scoring, no new database.
// ══════════════════════════════════════════════════════════════════════
class HealthHomeScreen extends ConsumerWidget {
  const HealthHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    final lang = ref.watch(appLanguageProvider);
    final pigsAsync = ref.watch(pigListProvider(uid));
    final statusAsync = ref.watch(latestHealthLogPerPigProvider(uid));
    final logsAsync = ref.watch(healthLogsProvider(uid));

    return Scaffold(
      backgroundColor: HealthMonitorPalette.background,
      appBar: AppBar(
        backgroundColor: HealthMonitorPalette.background,
        elevation: 0,
        title: Text(tr(lang, 'healthMonitorNavLabel'),
            style: const TextStyle(
                color: HealthMonitorPalette.darkText,
                fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: HealthMonitorPalette.darkText),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: tr(lang, 'viewHealthLogs'),
            onPressed: () => context.push(AppRoutes.health),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pigListProvider(uid));
          ref.invalidate(latestHealthLogPerPigProvider(uid));
          ref.invalidate(healthLogsProvider(uid));
        },
        child: pigsAsync.when(
          loading: () => const _HomeSkeleton(),
          error: (e, st) => _HomeErrorView(
            lang: lang,
            onRetry: () {
              ref.invalidate(pigListProvider(uid));
              ref.invalidate(latestHealthLogPerPigProvider(uid));
              ref.invalidate(healthLogsProvider(uid));
            },
          ),
          data: (pigs) {
            final statusMap = statusAsync.valueOrNull ?? const {};
            final logs = logsAsync.valueOrNull ?? const [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: healthAnimatedChildren([
                Text(tr(lang, 'healthMonitorSubtitle'),
                    style: const TextStyle(
                        fontSize: 13, color: HealthMonitorPalette.grayText)),
                const SizedBox(height: 18),
                HealthSectionLabel(tr(lang, 'todaysOverviewTitle')),
                _TodaysOverviewRow(pigs: pigs, statusMap: statusMap, lang: lang),
                const SizedBox(height: 22),
                HealthSectionLabel(tr(lang, 'startHealthMonitoringTitle')),
                if (pigs.isEmpty)
                  _NoPigsCard(lang: lang)
                else ...[
                  Text(tr(lang, 'howWouldYouLikeToMonitor'),
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: HealthMonitorPalette.darkText)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: MonitoringModeCard(
                          icon: Icons.pets,
                          title: tr(lang, 'specificPigLabel'),
                          subtitle: tr(lang, 'specificPigSubtitle'),
                          selected: false,
                          onTap: () =>
                              context.push(AppRoutes.healthSelectPig),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MonitoringModeCard(
                          icon: Icons.groups,
                          title: tr(lang, 'overallHerdLabel'),
                          subtitle: tr(lang, 'overallHerdSubtitle'),
                          selected: false,
                          onTap: () =>
                              context.push(AppRoutes.healthHerdSetup),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                HealthSectionLabel(tr(lang, 'healthCategoriesTitle')),
                _HealthCategoriesRow(lang: lang),
                const SizedBox(height: 22),
                HealthSectionLabel(tr(lang, 'sevenDayTrendTitle')),
                _SevenDayTrend(logs: logs, lang: lang),
                const SizedBox(height: 22),
                HealthSectionLabel(tr(lang, 'lastHealthCheckTitle')),
                _LastHealthCheckCard(logs: logs, lang: lang),
                const SizedBox(height: 22),
                HealthSectionLabel(tr(lang, 'healthTipsTitle')),
                _HealthTipsList(lang: lang),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _TodaysOverviewRow extends StatelessWidget {
  const _TodaysOverviewRow(
      {required this.pigs, required this.statusMap, required this.lang});
  final List<Pig> pigs;
  final Map<String, HealthLogEntry> statusMap;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    int healthy = 0, monitor = 0, risk = 0, critical = 0, notChecked = 0;
    for (final pig in pigs) {
      final entry = statusMap[pig.id];
      if (entry == null) {
        notChecked++;
        continue;
      }
      switch (entry.status) {
        case HealthStatus.healthy:
          healthy++;
          break;
        case HealthStatus.monitor:
          monitor++;
          break;
        case HealthStatus.risk:
          risk++;
          break;
        case HealthStatus.critical:
          critical++;
          break;
      }
    }
    final tiles = [
      HealthOverviewTile(
          label: healthStatusLabel(lang, HealthStatus.healthy),
          count: healthy,
          color: kHealthStatusColor[HealthStatus.healthy]!),
      HealthOverviewTile(
          label: healthStatusLabel(lang, HealthStatus.monitor),
          count: monitor,
          color: kHealthStatusColor[HealthStatus.monitor]!),
      HealthOverviewTile(
          label: healthStatusLabel(lang, HealthStatus.risk),
          count: risk,
          color: kHealthStatusColor[HealthStatus.risk]!),
      HealthOverviewTile(
          label: healthStatusLabel(lang, HealthStatus.critical),
          count: critical,
          color: kHealthStatusColor[HealthStatus.critical]!),
      HealthOverviewTile(
          label: tr(lang, 'notYetCheckedLabel'),
          count: notChecked,
          color: HealthMonitorPalette.grayText),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: tiles,
    );
  }
}

class _NoPigsCard extends StatelessWidget {
  const _NoPigsCard({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: healthCardDecoration(),
      padding: healthCardPadding,
      child: Column(
        children: [
          const Icon(Icons.pets_outlined,
              size: 34, color: HealthMonitorPalette.grayText),
          const SizedBox(height: 10),
          Text(tr(lang, 'noPigsAvailableMessage'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5, color: HealthMonitorPalette.grayText)),
          const SizedBox(height: 12),
          CustomButton(
            label: tr(lang, 'addPigButton'),
            backgroundColor: HealthMonitorPalette.primaryGreen,
            onPressed: () => context.push('${AppRoutes.pigs}/new'),
          ),
        ],
      ),
    );
  }
}

class _HealthCategoriesRow extends StatelessWidget {
  const _HealthCategoriesRow({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final categories = [
      (icon: '🧠', label: tr(lang, 'behaviorLabel')),
      (icon: '🍽', label: tr(lang, 'appetiteLabel')),
      (icon: '🩺', label: tr(lang, 'physicalLabel')),
      (icon: '💩', label: tr(lang, 'wasteLabel')),
    ];
    return Container(
      decoration: healthCardDecoration(),
      padding: healthCardPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final c in categories)
            Expanded(
              child: Column(
                children: [
                  Text(c.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(c.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: HealthMonitorPalette.darkText)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SevenDayTrend extends StatelessWidget {
  const _SevenDayTrend({required this.logs, required this.lang});
  final List<HealthLogEntry> logs;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final windowStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    // Latest observation per calendar day within the last 7 days — real
    // recorded data only, never a fabricated point.
    final byDay = <String, HealthLogEntry>{};
    for (final e in logs) {
      final parsed = DateTime.tryParse(e.date);
      if (parsed == null || parsed.isBefore(windowStart)) continue;
      final key = e.date;
      final existing = byDay[key];
      if (existing == null || e.timestamp.compareTo(existing.timestamp) > 0) {
        byDay[key] = e;
      }
    }
    final days = byDay.keys.toList()..sort();
    if (days.length < 2) {
      return Container(
        decoration: healthCardDecoration(),
        padding: healthCardPadding,
        child: Text(tr(lang, 'notEnoughTrendDataMessage'),
            style: const TextStyle(
                fontSize: 12.5, color: HealthMonitorPalette.grayText)),
      );
    }
    return Container(
      decoration: healthCardDecoration(),
      padding: healthCardPadding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final day in days)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kHealthStatusColor[byDay[day]!.status],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(day.substring(5),
                        style: const TextStyle(
                            fontSize: 10, color: HealthMonitorPalette.grayText)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LastHealthCheckCard extends StatelessWidget {
  const _LastHealthCheckCard({required this.logs, required this.lang});
  final List<HealthLogEntry> logs;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Container(
        decoration: healthCardDecoration(),
        padding: healthCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(lang, 'noHealthChecksMessage'),
                style: const TextStyle(
                    fontSize: 12.5, color: HealthMonitorPalette.grayText)),
            const SizedBox(height: 4),
            Text(tr(lang, 'startFirstHealthCheckMessage'),
                style: const TextStyle(
                    fontSize: 12.5, color: HealthMonitorPalette.grayText)),
          ],
        ),
      );
    }
    final sorted = [...logs]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final latest = sorted.first;
    final who = latest.pigId != null
        ? latest.pigName
        : (latest.pigName.isNotEmpty
            ? latest.pigName
            : (latest.batchName.isNotEmpty ? latest.batchName : null));
    return Container(
      decoration: healthCardDecoration(),
      padding: healthCardPadding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${latest.date} · ${latest.time}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: HealthMonitorPalette.darkText)),
                    const SizedBox(width: 8),
                    HealthStatusChip(status: latest.status, dense: true),
                  ],
                ),
                if (who != null) ...[
                  const SizedBox(height: 4),
                  Text('${tr(lang, 'pigLabel')}: $who',
                      style: const TextStyle(
                          fontSize: 11.5, color: HealthMonitorPalette.grayText)),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.health),
            child: Text(tr(lang, 'viewHealthLogs')),
          ),
        ],
      ),
    );
  }
}

class _HealthTipsList extends StatelessWidget {
  const _HealthTipsList({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final tips = [
      tr(lang, 'healthTip1'),
      tr(lang, 'healthTip2'),
      tr(lang, 'healthTip3'),
    ];
    return Column(
      children: [
        for (final tip in tips)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: healthCardDecoration(radius: 14),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 18, color: HealthMonitorPalette.secondaryGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(tip,
                      style: const TextStyle(
                          fontSize: 12.5, color: HealthMonitorPalette.darkText)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double h, {double w = double.infinity}) => Container(
          width: w,
          height: h,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: HealthMonitorPalette.border.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        bar(14, w: 220),
        bar(90),
        bar(14, w: 180),
        bar(120),
        bar(14, w: 160),
        bar(70),
      ],
    );
  }
}

class _HomeErrorView extends StatelessWidget {
  const _HomeErrorView({required this.lang, required this.onRetry});
  final AppLanguage lang;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(tr(lang, 'unableToLoadHealthMessage'), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            CustomButton(
              label: tr(lang, 'tryAgainButton'),
              backgroundColor: HealthMonitorPalette.primaryGreen,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
