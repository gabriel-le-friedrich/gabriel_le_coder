import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/theme/app_design_system.dart'
    show ShimmerListSkeleton, withStaggeredEntrance;
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/domain/dashboard_calculations.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../dashboard/presentation/theme/dashboard_palette.dart';
import '../../../dashboard/presentation/widgets/dashboard_app_bar_actions.dart';
import '../../../dashboard/presentation/widgets/dashboard_drawer.dart';
import '../../../health/domain/health_calculations.dart';
import '../../../health/domain/health_status_colors.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/feeding_providers.dart';

// ══════════════════════════════════════════════════════════════════════
// Feeding Guide — redesigned from a bare feed-log list into a full daily
// feeding dashboard: current stage + feed allowance, the AM/PM feeding
// schedule (two-way linked to Daily Tasks 3 & 9 — tapping a session here
// toggles the same task the Tasks screen shows, and vice versa), a feed
// cost calculator built on the real, already-persisted PigBatchProfile
// .feedPrice field, an improved Stage Guide table, and the original
// auto-recorded feed history preserved at the bottom.
//
// The Feed Recommendation card and a top-of-screen alert banner are also
// linked to the latest Health Monitor result (latestHealthLogProvider) —
// the guidance text and which supporting stats are shown adapt to
// Healthy/Needs Monitoring/At Risk/Critical, but the actual feed AMOUNT
// never changes automatically; that stays a human decision.
//
// Every figure here is derived from real, already-loaded DashboardData
// (currentWeight, feedLogs, batchProfile, adg) via dashboard_calculations
// .dart's stageForWeight()/kPigStages/etc — nothing on this screen is
// fabricated. The one deliberate simplification from the redesign brief:
// the ATI manual (and this app's existing stage table) only defines three
// feed-allowance bands — Early/Mid/Late Finisher, starting at 60kg — so the
// Growth Timeline below uses those three plus a trailing "Market Ready"
// milestone rather than inventing a Starter/Grower stage this app has never
// tracked.
// ══════════════════════════════════════════════════════════════════════
class FeedingScreen extends ConsumerWidget {
  const FeedingScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardControllerProvider(uid));
    final logsAsync = ref.watch(feedLogsProvider(uid));
    final latestHealth = ref.watch(latestHealthLogProvider(uid)).valueOrNull;
    final lang = ref.watch(appLanguageProvider);
    final fullName =
        ref.watch(userProfileProvider(uid)).valueOrNull?['fullName'] as String?;

    return Scaffold(
      backgroundColor: DashboardPalette.background,
      drawer: DashboardDrawer(uid: uid, fullName: fullName),
      appBar: AppBar(
        backgroundColor: DashboardPalette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            tooltip: tr(lang, 'openMenu'),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(tr(lang, 'feedingGuideTitle'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DashboardAppBarActions(uid: uid, fullName: fullName),
          ),
        ],
      ),
      body: dashAsync.when(
        data: (data) {
          if (!data.hasPigs) {
            // Same "No pigs yet" empty-state shape as the Tasks screen
            // (icon + heading + description + a direct CTA) rather than a
            // single bare line of gray text — this screen's empty state
            // used to be the odd one out.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🐷', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(tr(lang, 'noPigsYet'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      tr(lang, 'addPigToSeeFeedingPlan'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: DashboardPalette.textGray),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.pigs),
                      icon: const Icon(Icons.add),
                      label: Text(tr(lang, 'addPigButton')),
                    ),
                  ],
                ),
              ),
            );
          }

          final stage = stageForWeight(data.currentWeight);
          final next = nextStage(stage);
          final targetWeight = stageUpperBoundKg(stage);
          final daysToNext = daysUntilWeight(
              currentWeight: data.currentWeight,
              targetWeightKg: targetWeight,
              adg: data.adg);
          final feedPrice = data.batchProfile?.feedPrice ?? 0;
          final todaysCost = feedCostForDays(
              feedKgPerDay: stage.feedKgPerDay, feedPricePerKg: feedPrice);
          final amDone = data.tasksToday['3'] == true;
          final pmDone = data.tasksToday['9'] == true;
          final feedLogHistory = logsAsync.valueOrNull ?? const [];

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(dashboardControllerProvider(uid).notifier).load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: withStaggeredEntrance([
                if (latestHealth != null &&
                    (latestHealth.status == HealthStatus.critical ||
                        latestHealth.status == HealthStatus.risk)) ...[
                  _HealthAlertBanner(
                      status: latestHealth.status,
                      lang: lang,
                      onTap: () => context.push(AppRoutes.healthHub)),
                  const SizedBox(height: 16),
                ],
                _HeroCard(
                    stage: stage,
                    next: next,
                    data: data,
                    targetWeight: targetWeight,
                    daysToNext: daysToNext,
                    lang: lang),
                const SizedBox(height: 24),
                _SectionHeader(
                    icon: '🍽️',
                    title: tr(lang, 'todaysFeedingScheduleSection')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _FeedingSessionCard(
                        emoji: '🌅',
                        label: tr(lang, 'morning'),
                        timeHint: tr(lang, 'morningTimeHint'),
                        done: amDone,
                        lang: lang,
                        onTap: () => ref
                            .read(dashboardControllerProvider(uid).notifier)
                            .toggleTask('3'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FeedingSessionCard(
                        emoji: '🌇',
                        label: tr(lang, 'afternoon'),
                        timeHint: tr(lang, 'afternoonTimeHint'),
                        done: pmDone,
                        lang: lang,
                        onTap: () => ref
                            .read(dashboardControllerProvider(uid).notifier)
                            .toggleTask('9'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                    icon: '📊', title: tr(lang, 'todaysFeedingSection')),
                const SizedBox(height: 10),
                _FeedProgressCard(
                    amDone: amDone,
                    pmDone: pmDone,
                    feedKgPerDay: stage.feedKgPerDay,
                    lang: lang),
                const SizedBox(height: 24),
                _SectionHeader(
                    icon: '🎯', title: tr(lang, 'dailyFeedingProgressSection')),
                const SizedBox(height: 10),
                _DailyProgressRingCard(
                    amDone: amDone, pmDone: pmDone, lang: lang),
                const SizedBox(height: 24),
                _SectionHeader(
                    icon: '💰', title: tr(lang, 'feedCostCalculatorSection')),
                const SizedBox(height: 10),
                _FeedCostCard(
                  feedPrice: feedPrice,
                  feedKgPerDay: stage.feedKgPerDay,
                  todaysCost: todaysCost,
                  lang: lang,
                  onEditPrice: () =>
                      _showEditFeedPriceDialog(context, ref, feedPrice),
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                    icon: '📦', title: tr(lang, 'feedStatisticsSection')),
                const SizedBox(height: 10),
                _FeedStatsCard(
                  feedKgPerDay: stage.feedKgPerDay,
                  thisWeekKg: feedConsumedForWeek(
                      feedLogs: data.feedLogs, currentDay: data.currentDay),
                  lang: lang,
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                    icon: '📈', title: tr(lang, 'growthTimelineSection')),
                const SizedBox(height: 14),
                _GrowthTimeline(
                    currentWeight: data.currentWeight,
                    currentStageKey: stage.key,
                    lang: lang),
                const SizedBox(height: 24),
                _SectionHeader(
                    icon: '📋', title: tr(lang, 'stageGuideSection')),
                const SizedBox(height: 10),
                _StageGuideTable(currentStageKey: stage.key, lang: lang),
                const SizedBox(height: 24),
                _SectionHeader(
                    icon: '💡', title: tr(lang, 'feedRecommendationSection')),
                const SizedBox(height: 10),
                _FeedRecommendationCard(
                    stage: stage, latestHealth: latestHealth, lang: lang),
                const SizedBox(height: 24),
                _SectionHeader(
                    icon: '📝', title: tr(lang, 'feedingTipsSection')),
                const SizedBox(height: 10),
                _TipsCard(lang: lang),
                const SizedBox(height: 24),
                _SectionHeader(
                    icon: '✅', title: tr(lang, 'todaysSummarySection')),
                const SizedBox(height: 10),
                _TodaysSummaryCard(
                  currentWeight: data.currentWeight,
                  feedKgPerDay: stage.feedKgPerDay,
                  todaysCost: todaysCost,
                  amDone: amDone,
                  pmDone: pmDone,
                  lang: lang,
                ),
                if (feedLogHistory.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionHeader(
                      icon: '🌾', title: tr(lang, 'feedHistorySection')),
                  const SizedBox(height: 10),
                  ...feedLogHistory.take(10).map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CustomCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: DashboardPalette.lightGreen,
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Text('🌾',
                                    style: TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${tr(lang, 'dayLabel')} ${e.day}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(e.date,
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            color: DashboardPalette.textGray)),
                                  ],
                                ),
                              ),
                              Text('${e.feedKg.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      )),
                ],
              ]),
            ),
          );
        },
        loading: () => const ShimmerListSkeleton(count: 4, itemHeight: 130),
        error: (_, __) =>
            Center(child: Text(tr(lang, 'couldNotLoadFeedingPlan'))),
      ),
    );
  }

  Future<void> _showEditFeedPriceDialog(
      BuildContext context, WidgetRef ref, double currentPrice) async {
    // Plain showDialog (not a stateful widget) — mirrors
    // pig_detail_screen.dart's _showEditStartingWeightDialog: the
    // controller has no State.dispose() to live in, so it's disposed
    // explicitly in `finally` regardless of how the dialog closes.
    final lang = ref.read(appLanguageProvider);
    final ctrl = TextEditingController(text: currentPrice.toStringAsFixed(2));
    try {
      final result = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr(lang, 'editFeedPriceTitle')),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: tr(lang, 'feedPriceHint'), prefixText: '₱ '),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr(lang, 'cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
                child: Text(tr(lang, 'save'))),
          ],
        ),
      );
      if (result != null && result >= 0) {
        await ref
            .read(dashboardControllerProvider(uid).notifier)
            .updateFeedPrice(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr(lang, 'feedPriceUpdated'))));
        }
      }
    } finally {
      ctrl.dispose();
    }
  }
}

/// Small icon+title header repeated above every section, per the redesign
/// brief's "icons per section" ask.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final String icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: DashboardPalette.lightGreen,
              borderRadius: BorderRadius.circular(10)),
          child: Text(icon, style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ),
      ],
    );
  }
}

/// Top-of-screen alert when the latest Health Monitor assessment is Critical
/// or At Risk — reuses the exact centralized status color
/// (kHealthStatusColor) rather than a bespoke red/orange, and taps through
/// to the Health Monitor. Only shown for these two statuses; Healthy/Needs
/// Monitoring don't warrant interrupting the feeding flow. Deliberately
/// informational only — it never changes the feeding schedule or amount
/// itself, just tells the farmer to review Health before proceeding.
class _HealthAlertBanner extends StatelessWidget {
  const _HealthAlertBanner(
      {required this.status, required this.onTap, required this.lang});
  final HealthStatus status;
  final VoidCallback onTap;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final color = kHealthStatusColor[status]!;
    final isCritical = status == HealthStatus.critical;
    final title = isCritical
        ? tr(lang, 'healthAlertTitle')
        : tr(lang, 'increasedMonitoringTitle');
    final message = isCritical
        ? tr(lang, 'healthAlertCriticalMsg')
        : tr(lang, 'healthAlertRiskMsg');
    return Semantics(
      button: true,
      label: '$title. $message',
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: color)),
                        const SizedBox(height: 4),
                        Text(message,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                height: 1.35)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "🐷 Current Feeding Plan" hero card — dark green, matches the app's
/// existing hero-card color from the Dashboard redesign (DashboardPalette
/// .darkGreen), per the "keep your current colors" instruction.
class _HeroCard extends StatelessWidget {
  const _HeroCard(
      {required this.stage,
      required this.next,
      required this.data,
      required this.targetWeight,
      required this.daysToNext,
      required this.lang});
  final PigStage stage;
  final PigStage? next;
  final DashboardData data;
  final double targetWeight;
  final int? daysToNext;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final lowerBound = stageLowerBoundKg(stage);
    final progress =
        ((data.currentWeight - lowerBound) / (targetWeight - lowerBound))
            .clamp(0.0, 1.0);
    final nextLabel = next?.name ?? tr(lang, 'marketReady');
    final remainingKg =
        (targetWeight - data.currentWeight).clamp(0.0, double.infinity);
    final adgKgPerDay = data.adg != null ? data.adg! / 1000 : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DashboardPalette.darkGreen,
              DashboardPalette.primaryGreen,
            ],
          ),
          boxShadow: [
            BoxShadow(
                color: DashboardPalette.darkGreen.withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          children: [
            // Subtle low-opacity farm accent — decorative only, no data.
            const Positioned(
              right: -14,
              top: -14,
              child: Opacity(
                opacity: 0.12,
                child: Text('🐷', style: TextStyle(fontSize: 100)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(tr(lang, 'currentFeedingPlan'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6)),
                  ),
                  const SizedBox(height: 8),
                  Text(stage.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text('${tr(lang, 'productionDayPrefix')} ${data.currentDay}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _HeroStat(
                              label: tr(lang, 'currentWeightLabel'),
                              value:
                                  '${data.currentWeight.toStringAsFixed(1)} kg')),
                      Expanded(
                          child: _HeroStat(
                              label: tr(lang, 'dailyFeedLabel'),
                              value:
                                  '${stage.feedKgPerDay.toStringAsFixed(1)} kg/day')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _HeroStat(
                              label: tr(lang, 'targetWeightLabel'),
                              value: '${targetWeight.toStringAsFixed(0)} kg')),
                      Expanded(
                          child: _HeroStat(
                              label: tr(lang, 'remainingLabel'),
                              value: '${remainingKg.toStringAsFixed(1)} kg')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _HeroStat(
                          label: tr(lang, 'expectedDailyGainLabel'),
                          value: adgKgPerDay != null
                              ? '${adgKgPerDay.toStringAsFixed(2)} kg/day'
                              : '—',
                        ),
                      ),
                      Expanded(
                        child: _HeroStat(
                          label: tr(lang, 'estimatedNextStageLabel'),
                          value: daysToNext != null
                              ? '$daysToNext ${tr(lang, 'daysRemainingSuffix')}'
                              : '—',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text('${tr(lang, 'nextStagePrefix')} $nextLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ),
                      Text('${(progress * 100).round()}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: 'Progress to $nextLabel',
                    value: '${(progress * 100).round()}%',
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 600),
                      builder: (context, value, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 8,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(
                              DashboardPalette.accentOrange),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// One Morning/Afternoon feeding session card — reflects (and toggles) the
/// exact same Daily Task (id '3' for AM, '9' for PM) the Tasks screen
/// shows, so the two stay in sync automatically with no separate state.
class _FeedingSessionCard extends StatelessWidget {
  const _FeedingSessionCard(
      {required this.emoji,
      required this.label,
      required this.timeHint,
      required this.done,
      required this.onTap,
      required this.lang});
  final String emoji;
  final String label;
  final String timeHint;
  final bool done;
  final VoidCallback onTap;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: done,
      label: '$label feeding, ${done ? "fed" : "not yet fed"}',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(18),
          decoration: dashboardCardDecoration(
              color: done ? DashboardPalette.lightGreen : DashboardPalette.card,
              radius: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: done
                        ? Colors.white.withValues(alpha: 0.6)
                        : DashboardPalette.lightGreen,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              Text(timeHint,
                  style: const TextStyle(
                      fontSize: 11.5, color: DashboardPalette.textGray)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16,
                      color: done
                          ? DashboardPalette.primaryGreen
                          : DashboardPalette.textGray),
                  const SizedBox(width: 6),
                  Text(
                    done ? tr(lang, 'fedLabel') : tr(lang, 'notYetFedLabel'),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: done
                            ? DashboardPalette.darkGreen
                            : DashboardPalette.textGray),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today's Feeding" completion summary — Morning/Afternoon status rows
/// (✅ Completed / ⏳ Pending) plus an overall Completion percentage, and a
/// celebration banner once both sessions are done. Each session is binary
/// (fed / not fed — this app has no partial-feeding tracking), so
/// Completion is simply 0%, 50%, or 100%, animated on change.
class _FeedProgressCard extends StatelessWidget {
  const _FeedProgressCard(
      {required this.amDone,
      required this.pmDone,
      required this.feedKgPerDay,
      required this.lang});
  final bool amDone;
  final bool pmDone;
  final double feedKgPerDay;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final bothDone = amDone && pmDone;
    final doneCount = (amDone ? 1 : 0) + (pmDone ? 1 : 0);
    final completion = doneCount / 2;
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(lang, 'totalFeedTodayLabel'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${feedKgPerDay.toStringAsFixed(1)} kg',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: DashboardPalette.darkGreen)),
            ],
          ),
          const SizedBox(height: 12),
          _FeedingStatusRow(
              label: tr(lang, 'morning'), done: amDone, lang: lang),
          const SizedBox(height: 12),
          _FeedingStatusRow(
              label: tr(lang, 'afternoon'), done: pmDone, lang: lang),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(lang, 'completionLabel'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${(completion * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 12, color: DashboardPalette.textGray)),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: tr(lang, 'completionLabel'),
            value: '${(completion * 100).round()}%',
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: completion),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  backgroundColor: DashboardPalette.background,
                  valueColor: const AlwaysStoppedAnimation(
                      DashboardPalette.primaryGreen),
                ),
              ),
            ),
          ),
          if (bothDone) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: DashboardPalette.lightGreen,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                tr(lang, 'dailyFeedingCompleteBanner'),
                style: const TextStyle(
                    color: DashboardPalette.darkGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedingStatusRow extends StatelessWidget {
  const _FeedingStatusRow(
      {required this.label, required this.done, required this.lang});
  final String label;
  final bool done;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Row(
          children: [
            Icon(done ? Icons.check_circle : Icons.hourglass_top,
                size: 15,
                color: done
                    ? DashboardPalette.primaryGreen
                    : DashboardPalette.accentOrange),
            const SizedBox(width: 6),
            Text(
              done ? tr(lang, 'completedLabel') : tr(lang, 'pendingLabel'),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: done
                      ? DashboardPalette.primaryGreen
                      : DashboardPalette.accentOrange),
            ),
          ],
        ),
      ],
    );
  }
}

/// Visual donut version of the exact same Morning/Afternoon completion
/// state _FeedProgressCard already shows as text/rows — no new data, just a
/// ring chart (fl_chart) so today's feeding progress reads at a glance, per
/// the mockup's "Daily Feeding Progress" ring. doneCount/2 is the same
/// completion fraction already computed above; this widget only renders it.
class _DailyProgressRingCard extends StatelessWidget {
  const _DailyProgressRingCard(
      {required this.amDone, required this.pmDone, required this.lang});
  final bool amDone;
  final bool pmDone;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final doneCount = (amDone ? 1 : 0) + (pmDone ? 1 : 0);
    final bothDone = doneCount == 2;
    final percent = (doneCount / 2 * 100).round();
    return CustomCard(
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Semantics(
              label: tr(lang, 'dailyFeedingProgressSection'),
              value: '$percent%',
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: doneCount.toDouble()),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, value, _) => PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: 0,
                        centerSpaceRadius: 32,
                        sections: [
                          PieChartSectionData(
                            value: value,
                            color: DashboardPalette.primaryGreen,
                            radius: 14,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: 2 - value,
                            color: DashboardPalette.background,
                            radius: 14,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text('$percent%',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: DashboardPalette.darkGreen)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(lang, 'feedingsCompletedLabel'),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DashboardPalette.textGray)),
                const SizedBox(height: 4),
                Text('$doneCount / 2',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                if (bothDone) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: DashboardPalette.lightGreen,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(tr(lang, 'goalAchievedLabel'),
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: DashboardPalette.darkGreen)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Editable feed price (persisted via DashboardController.updateFeedPrice)
/// plus today's cost and a 30-day estimate, both computed from the real
/// stage feed allowance — matches the legacy web app's Feed Price/Today's
/// Feed Cost fields, now with a 30-day projection added for budgeting.
class _FeedCostCard extends StatelessWidget {
  const _FeedCostCard(
      {required this.feedPrice,
      required this.feedKgPerDay,
      required this.todaysCost,
      required this.onEditPrice,
      required this.lang});
  final double feedPrice;
  final double feedKgPerDay;
  final double todaysCost;
  final VoidCallback onEditPrice;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final estimate30Day = feedCostForDays(
        feedKgPerDay: feedKgPerDay, feedPricePerKg: feedPrice, days: 30);
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(lang, 'feedPricePerKgLabel'),
                  style: const TextStyle(
                      fontSize: 13, color: DashboardPalette.textGray)),
              Semantics(
                button: true,
                label:
                    '${tr(lang, 'editFeedPriceTitle')}, ₱${feedPrice.toStringAsFixed(2)}',
                child: InkWell(
                  onTap: onEditPrice,
                  borderRadius: BorderRadius.circular(10),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: DashboardPalette.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: DashboardPalette.lightGreen, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('₱${feedPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: DashboardPalette.darkGreen)),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit,
                              size: 14, color: DashboardPalette.darkGreen),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                  child: _CostStat(
                      label: tr(lang, 'todaysFeedLabel'),
                      value: '${feedKgPerDay.toStringAsFixed(1)} kg')),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: DashboardPalette.lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _CostStat(
                      label: tr(lang, 'todaysCostLabel'),
                      value: '₱${todaysCost.toStringAsFixed(2)}',
                      emphasize: true),
                ),
              ),
              Expanded(
                  child: _CostStat(
                      label: tr(lang, 'thirtyDayEstLabel'),
                      value: '₱${estimate30Day.toStringAsFixed(0)}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CostStat extends StatelessWidget {
  const _CostStat(
      {required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  // Visually highlights Today's Cost inside _FeedCostCard's stat row — same
  // value, just larger/bolder so the figure the user checks most often (what
  // today's feeding actually costs) stands out among the three stats.
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: emphasize
                    ? DashboardPalette.darkGreen
                    : DashboardPalette.textGray)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: emphasize ? 17 : 14,
                fontWeight: FontWeight.bold,
                color: DashboardPalette.darkGreen)),
      ],
    );
  }
}

/// Feed Consumption Statistics — Today's Feed and Estimated This Month are
/// the same real daily allowance shown throughout this screen (planned/
/// recorded feed, not fabricated), while This Week is a genuine sum of
/// feedLogs entries actually recorded so far this production week (see
/// feedConsumedForWeek in dashboard_calculations.dart) — so this card never
/// claims a historical total the app hasn't actually logged.
class _FeedStatsCard extends StatelessWidget {
  const _FeedStatsCard(
      {required this.feedKgPerDay,
      required this.thisWeekKg,
      required this.lang});
  final double feedKgPerDay;
  final double thisWeekKg;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final estimatedMonthKg = feedKgPerDay * 30;
    return CustomCard(
      child: Row(
        children: [
          Expanded(
              child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(
                border: Border(
                    right: BorderSide(
                        color: DashboardPalette.background, width: 1.5))),
            child: _CostStat(
                label: tr(lang, 'todaysFeedLabel'),
                value: '${feedKgPerDay.toStringAsFixed(1)} kg'),
          )),
          Expanded(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
                border: Border(
                    right: BorderSide(
                        color: DashboardPalette.background, width: 1.5))),
            child: _CostStat(
                label: tr(lang, 'thisWeekLabel'),
                value: '${thisWeekKg.toStringAsFixed(1)} kg'),
          )),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _CostStat(
                label: tr(lang, 'estThisMonthLabel'),
                value: '${estimatedMonthKg.toStringAsFixed(0)} kg'),
          )),
        ],
      ),
    );
  }
}

/// Early Finisher → Mid Finisher → Late Finisher → Market Ready, built from
/// the real weight-based stage progression (kPigStages) rather than an
/// invented 5-stage model — see the file header for why. Fully dynamic: the
/// Current/Next/Upcoming/Final Goal label under each node, and the overall
/// progress bar beneath, both recompute from the batch's live weight on
/// every rebuild rather than being fixed at any point in the cycle.
class _GrowthTimeline extends StatelessWidget {
  const _GrowthTimeline(
      {required this.currentWeight,
      required this.currentStageKey,
      required this.lang});
  final double currentWeight;
  final String currentStageKey;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final currentIndex = kPigStages.indexWhere((s) => s.key == currentStageKey);
    final marketReady = currentWeight >= kMarketWeightKg;
    final nodes = <_TimelineNodeData>[
      for (var i = 0; i < kPigStages.length; i++)
        _TimelineNodeData(
          label: kPigStages[i].name,
          state: i < currentIndex
              ? _NodeState.done
              : (i == currentIndex
                  ? _NodeState.current
                  : (i == currentIndex + 1
                      ? _NodeState.next
                      : _NodeState.upcoming)),
          caption: i < currentIndex
              ? tr(lang, 'doneCaption')
              : (i == currentIndex
                  ? tr(lang, 'currentCaption')
                  : (i == currentIndex + 1
                      ? tr(lang, 'nextCaption')
                      : tr(lang, 'upcomingCaption'))),
        ),
      _TimelineNodeData(
        label: tr(lang, 'marketReady'),
        state: marketReady
            ? _NodeState.done
            : (currentIndex == kPigStages.length - 1
                ? _NodeState.next
                : _NodeState.upcoming),
        caption: marketReady
            ? tr(lang, 'reachedCaption')
            : tr(lang, 'finalGoalCaption'),
      ),
    ];
    // Overall progress across the whole cycle (60kg start → 120kg market
    // weight), not just within the current band — the "progress indicator
    // between stages" the timeline itself asked for, distinct from the hero
    // card's within-stage progress bar.
    final overallProgress =
        ((currentWeight - stageLowerBoundKg(kPigStages.first)) /
                (kMarketWeightKg - stageLowerBoundKg(kPigStages.first)))
            .clamp(0.0, 1.0);

    return CustomCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < nodes.length; i++) ...[
                Expanded(child: _TimelineNode(data: nodes[i])),
                if (i != nodes.length - 1)
                  Container(
                    width: 20,
                    height: 2,
                    color: nodes[i].state == _NodeState.done
                        ? DashboardPalette.primaryGreen
                        : DashboardPalette.background,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            label: tr(lang, 'growthTimelineSection'),
            value: '${(overallProgress * 100).round()}%',
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: overallProgress),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  backgroundColor: DashboardPalette.background,
                  valueColor: const AlwaysStoppedAnimation(
                      DashboardPalette.primaryGreen),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _NodeState { done, current, next, upcoming }

class _TimelineNodeData {
  const _TimelineNodeData(
      {required this.label, required this.state, required this.caption});
  final String label;
  final _NodeState state;
  final String caption;
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.data});
  final _TimelineNodeData data;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (data.state) {
      _NodeState.done => DashboardPalette.primaryGreen,
      _NodeState.current => DashboardPalette.accentOrange,
      _NodeState.next => DashboardPalette.accentOrange,
      _NodeState.upcoming => DashboardPalette.textGray,
    };
    final Widget icon = switch (data.state) {
      _NodeState.done => Icon(Icons.check_circle, color: color, size: 22),
      _NodeState.current => Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      _NodeState.next => Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2)),
        ),
      _NodeState.upcoming => Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2)),
        ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 6),
        Text(
          data.label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 10,
              fontWeight: data.state == _NodeState.current
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: color),
        ),
        Text(data.caption,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: color)),
      ],
    );
  }
}

/// Same 3-band Stage Guide as before, now with a Status column and the
/// current stage's row highlighted, per the redesign brief.
class _StageGuideTable extends StatelessWidget {
  const _StageGuideTable({required this.currentStageKey, required this.lang});
  final String currentStageKey;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final currentIdx = kPigStages.indexWhere((e) => e.key == currentStageKey);
    return CustomCard(
      padding: const EdgeInsets.all(4),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.3),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1.1)
        },
        children: [
          TableRow(
            children: [
              _StageCell(tr(lang, 'stageColHeader'), header: true),
              _StageCell(tr(lang, 'weightColHeader'), header: true),
              _StageCell(tr(lang, 'feedPerDayColHeader'), header: true),
              _StageCell(tr(lang, 'statusColHeader'), header: true),
            ],
          ),
          ...kPigStages.map((s) {
            final idx = kPigStages.indexOf(s);
            final isCurrent = idx == currentIdx;
            final status = idx < currentIdx
                ? tr(lang, 'passedStatus')
                : (isCurrent
                    ? tr(lang, 'currentCaption')
                    : (idx == currentIdx + 1
                        ? tr(lang, 'nextCaption')
                        : tr(lang, 'upcomingCaption')));
            return TableRow(
              decoration: isCurrent
                  ? const BoxDecoration(color: DashboardPalette.lightGreen)
                  : null,
              children: [
                _StageCell(s.name, bold: isCurrent),
                _StageCell(s.range),
                _StageCell('${s.feedKgPerDay.toStringAsFixed(1)} kg'),
                _StageCell(status,
                    bold: isCurrent,
                    color: isCurrent ? DashboardPalette.darkGreen : null),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _StageCell extends StatelessWidget {
  const _StageCell(this.text,
      {this.header = false, this.bold = false, this.color});
  final String text;
  final bool header;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: header ? 11 : 12.5,
          fontWeight: header || bold ? FontWeight.bold : FontWeight.normal,
          color: header ? DashboardPalette.textGray : (color ?? Colors.black87),
        ),
      ),
    );
  }
}

/// Smart Feeding Recommendation — adaptive to the latest Health Monitor
/// assessment. Deliberately never changes the actual feed amount (Feed
/// Allowance shown here is always the same real stage.feedKgPerDay used
/// everywhere else on this screen) — only the accompanying guidance text
/// and which supporting stats are worth showing change per status, per the
/// "safer for a livestock app" framing this was requested with. Falls back
/// to the original static, stage-appropriate advisory copy when no health
/// log exists yet, since there's nothing to adapt to.
class _FeedRecommendationCard extends StatelessWidget {
  const _FeedRecommendationCard(
      {required this.stage, required this.latestHealth, required this.lang});
  final PigStage stage;
  final HealthLogEntry? latestHealth;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final feedType = switch (stage.key) {
      'early' => tr(lang, 'feedTypeEarly'),
      'mid' => tr(lang, 'feedTypeMid'),
      _ => tr(lang, 'feedTypeLate'),
    };

    if (latestHealth == null) {
      return CustomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RecoRow(
                icon: '🌾', label: tr(lang, 'feedTypeLabel'), value: feedType),
            const SizedBox(height: 12),
            _RecoRow(
                icon: '💧',
                label: tr(lang, 'waterLabel'),
                value: tr(lang, 'waterAdLibitum')),
            const SizedBox(height: 12),
            _RecoRow(
                icon: '📈',
                label: tr(lang, 'expectedDailyGainLabel'),
                value: '$adgTargetMin–$adgTargetMax g/day'),
          ],
        ),
      );
    }

    final status = latestHealth!.status;
    final meta = kHealthStatusMeta[status]!;
    final color = kHealthStatusColor[status]!;
    final bullets = switch (status) {
      HealthStatus.healthy => [tr(lang, 'recoHealthyBullet')],
      HealthStatus.monitor => [
          tr(lang, 'recoMonitorBullet1'),
          tr(lang, 'recoMonitorBullet2'),
        ],
      HealthStatus.risk => [
          tr(lang, 'recoRiskBullet1'),
          tr(lang, 'recoRiskBullet2'),
          tr(lang, 'recoRiskBullet3'),
        ],
      HealthStatus.critical => [
          tr(lang, 'recoCriticalBullet1'),
          tr(lang, 'recoCriticalBullet2'),
          tr(lang, 'recoCriticalBullet3'),
          tr(lang, 'recoCriticalBullet4'),
        ],
    };
    // Healthy and Needs Monitoring keep the full supporting stats; At Risk
    // keeps just Feed Allowance (the guidance text explicitly references
    // "maintain the recommended feed amount"); Critical shows none — the
    // guidance itself is the whole point at that severity.
    final showWater =
        status == HealthStatus.healthy || status == HealthStatus.monitor;
    final showAdg = status == HealthStatus.healthy;
    final showFeedAllowance = status != HealthStatus.critical;
    final waterText = status == HealthStatus.healthy
        ? tr(lang, 'waterUnlimited')
        : tr(lang, 'waterEnsureConstant');

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(meta.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr(lang, 'todaysRecommendation'),
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child:
                  Text(b, style: const TextStyle(fontSize: 12.5, height: 1.4)),
            ),
          if (showFeedAllowance || showWater || showAdg) ...[
            const Divider(height: 20),
            if (showFeedAllowance) ...[
              _RecoRow(
                  icon: '🌾',
                  label: tr(lang, 'feedAllowanceLabel'),
                  value: '${stage.feedKgPerDay.toStringAsFixed(1)} kg/day'),
              if (showWater || showAdg) const SizedBox(height: 12),
            ],
            if (showWater) ...[
              _RecoRow(
                  icon: '💧', label: tr(lang, 'waterLabel'), value: waterText),
              if (showAdg) const SizedBox(height: 12),
            ],
            if (showAdg)
              _RecoRow(
                  icon: '📈',
                  label: tr(lang, 'expectedDailyGainLabel'),
                  value: '$adgTargetMin–$adgTargetMax g/day'),
          ],
        ],
      ),
    );
  }
}

class _RecoRow extends StatelessWidget {
  const _RecoRow(
      {required this.icon, required this.label, required this.value});
  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11.5, color: DashboardPalette.textGray)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Four general, static feeding tips — informational only, no per-farm data.
class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.lang});
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final tips = [
      tr(lang, 'feedTip1'),
      tr(lang, 'feedTip2'),
      tr(lang, 'feedTip3'),
      tr(lang, 'feedTip4'),
    ];
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.circle,
                          size: 6, color: DashboardPalette.primaryGreen)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(tip,
                          style: const TextStyle(fontSize: 12.5, height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom "Today's Summary" recap — Weight / Feed / Cost / Next Feeding /
/// Status, all pulled from the same figures already shown above.
class _TodaysSummaryCard extends StatelessWidget {
  const _TodaysSummaryCard({
    required this.currentWeight,
    required this.feedKgPerDay,
    required this.todaysCost,
    required this.amDone,
    required this.pmDone,
    required this.lang,
  });
  final double currentWeight;
  final double feedKgPerDay;
  final double todaysCost;
  final bool amDone;
  final bool pmDone;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final nextFeeding = !amDone
        ? tr(lang, 'morningFeeding')
        : (!pmDone ? tr(lang, 'afternoonFeeding') : tr(lang, 'noneBothDone'));
    final status = (amDone && pmDone)
        ? tr(lang, 'completeStatus')
        : (amDone || pmDone)
            ? tr(lang, 'inProgressStatus')
            : tr(lang, 'notStartedStatus');
    return CustomCard(
      child: Column(
        children: [
          _SummaryLine(
              label: tr(lang, 'weightLabel'),
              value: '${currentWeight.toStringAsFixed(1)} kg'),
          _SummaryLine(
              label: tr(lang, 'feedLabel'),
              value: '${feedKgPerDay.toStringAsFixed(1)} kg/day'),
          _SummaryLine(
              label: tr(lang, 'costLabel'),
              value: '₱${todaysCost.toStringAsFixed(2)}'),
          _SummaryLine(label: tr(lang, 'nextFeedingLabel'), value: nextFeeding),
          _SummaryLine(
              label: tr(lang, 'statusLabel'),
              value: status,
              valueColor: (amDone && pmDone)
                  ? DashboardPalette.primaryGreen
                  : DashboardPalette.accentOrange,
              last: true),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(
      {required this.label,
      required this.value,
      this.valueColor,
      this.last = false});
  final String label;
  final String value;
  final Color? valueColor;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: DashboardPalette.textGray)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
