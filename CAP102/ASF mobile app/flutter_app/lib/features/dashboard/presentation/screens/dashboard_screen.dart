import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../health/domain/health_calculations.dart';
import '../../../notifications/domain/notification_prefs.dart';
import '../../../notifications/domain/reminder_types.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../ota_update/presentation/providers/ota_update_providers.dart';
import '../../../ota_update/presentation/widgets/ota_update_dialog.dart';
import '../../../../shared/theme/app_design_system.dart'
    show ShimmerListSkeleton;
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../growth/presentation/providers/growth_providers.dart';
import '../../domain/dashboard_calculations.dart';
import '../providers/calendar_providers.dart';
import '../providers/dashboard_providers.dart';
import '../theme/dashboard_palette.dart';
import '../widgets/dashboard_drawer.dart';
import '../widgets/dashboard_hero_header.dart';
import '../widgets/greeting_header.dart';
import '../widgets/health_banner_card.dart';
import '../widgets/health_overview_card.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/summary_card_grid.dart';
import '../widgets/tip_of_day_card.dart';
import '../widgets/today_tasks_card.dart';
import '../widgets/weight_progress_card.dart';

/// The redesigned Dashboard — same DashboardController/DashboardData this
/// screen has always used (production day, tasks, weight/expense/feed logs,
/// health logs, ADG/FCR/ROI/growth%), presented as a modern card-based
/// layout matching the reference mockup. No business logic, provider, or
/// repository change lives in this file or any of the widgets it composes
/// — every value below is read from DashboardData/DashboardController,
/// which this redesign pass does not touch.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.uid, required this.fullName});

  final String uid;
  final String? fullName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardControllerProvider(uid));
    final controller = ref.read(dashboardControllerProvider(uid).notifier);
    final firstName = (fullName ?? '').trim().isEmpty
        ? null
        : fullName!.trim().split(' ').first;
    final lang = ref.watch(appLanguageProvider);
    // Farmer's saved province — the only thing the hero's weather card
    // needs. Read from the same userProfileProvider the retry-name
    // affordance already watches; a loading/error/missing value here just
    // means the weather card doesn't render (see DashboardHeroHeader),
    // never a Dashboard-wide error.
    final province =
        ref.watch(userProfileProvider(uid)).valueOrNull?['province'] as String?;

    // A12/C13 fix: every screen that derives "which production week is it"
    // from the currentDay counter (growthControllerProvider — feeds the Pig
    // Detail screen's weekly-photo lock check and Growth screen's week
    // display; calendarDataProvider — the Calendar view) caches that day the
    // moment it's first read and, being autoDispose, only refetches if
    // fully disposed and re-watched. DashboardController.advanceDay() bumps
    // the persisted day counter but had no way to tell those OTHER
    // providers their cached currentDay is now stale — so a week's photo
    // upload (or the Calendar's highlighted day) kept reading the day-old
    // value until something unrelated happened to dispose/recreate that
    // provider. That's the actual mechanism behind "Week N's photo stays
    // locked one day past its real unlock day": not the week-number formula
    // (weekNumberForDay, which is correct — Week 3 already maps to Day 15),
    // but this stale-cache gap. Invalidating both right after a successful
    // advance closes it, the same pattern already used for the profile
    // fields (see userProfileProvider invalidation in settings_providers.dart).
    Future<bool> advanceDayAndRefreshDependents() async {
      final advanced = await controller.advanceDay();
      if (advanced) {
        ref.invalidate(growthControllerProvider(uid));
        ref.invalidate(calendarDataProvider(uid));
      }
      return advanced;
    }

    ref.listen(dashboardControllerProvider(uid), (previous, next) {
      final err = next.valueOrNull?.errorMessage;
      final prevErr = previous?.valueOrNull?.errorMessage;
      if (err != null && err != prevErr) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
        controller.clearError();
      }
    });

    // OTA update check — unchanged from the previous Dashboard: only ever
    // reachable once auth has resolved, fires at most once per mount, and
    // the dialog itself re-checks "already dismissed this version" so it
    // never nags after Later is tapped.
    ref.listen(otaUpdateCheckProvider, (previous, next) {
      final release = next.valueOrNull;
      if (release != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) showOtaUpdateDialog(context, ref, release);
        });
      }
    });

    // The illustrated hero (hamburger + logo + notification/profile actions
    // + dynamic greeting) only needs uid/fullName/firstName/lang — none of
    // which come from dashboardAsync — so it's rendered unconditionally
    // above the async body. That keeps the hamburger, bell, and avatar
    // tappable even while the rest of the dashboard is loading or errored,
    // exactly as the old AppBar always was. Scaffold.of(context) still
    // resolves correctly for the Drawer since the hero lives inside this
    // same Scaffold's widget subtree.
    return Scaffold(
      backgroundColor: DashboardPalette.background,
      drawer: DashboardDrawer(uid: uid, fullName: fullName),
      body: Column(
        children: [
          DashboardHeroHeader(
            uid: uid,
            fullName: fullName,
            firstName: firstName,
            lang: lang,
            province: province,
            onRetryName: firstName == null
                ? () => ref.invalidate(userProfileProvider(uid))
                : null,
          ),
          Expanded(
            child: dashboardAsync.when(
              data: (data) => RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: _animatedChildren([
                    // Day-counter + Calendar/Log Today pills — the old
                    // GreetingHeader's non-greeting half. showGreetingLine:
                    // false hides the name/emoji line now shown in the hero
                    // above, so this renders only the pills, unchanged.
                    GreetingHeader(
                        showGreetingLine: false,
                        firstName: firstName,
                        data: data,
                        onAdvance: advanceDayAndRefreshDependents,
                        lang: lang,
                        onRetryName: firstName == null
                            ? () => ref.invalidate(userProfileProvider(uid))
                            : null),
                    const SizedBox(height: 4),
                    HealthBannerCard(data: data, lang: lang),
                    const SizedBox(height: 14),
                    SummaryCardGrid(data: data, lang: lang),
                    const SizedBox(height: 14),
                    WeightProgressCard(
                      weightLogs: data.weightLogs,
                      startWeight: data.batchProfile?.startWeight,
                      currentWeight: data.currentWeight,
                      hasPigs: data.hasPigs,
                      currentDay: data.currentDay,
                      growthPct: data.growthPct,
                    ),
                    const SizedBox(height: 14),
                    HealthOverviewCard(data: data, lang: lang),
                    const SizedBox(height: 14),
                    QuickActionsRow(lang: lang),
                    const SizedBox(height: 14),
                    _UpcomingRemindersCard(
                        uid: uid, currentDay: data.currentDay, lang: lang),
                    const SizedBox(height: 14),
                    _HealthTrendStrip(data: data, lang: lang),
                    const SizedBox(height: 14),
                    TodayTasksCard(data: data, lang: lang),
                    const SizedBox(height: 14),
                    TipOfDayCard(lang: lang),
                  ]),
                ),
              ),
              loading: () => Semantics(
                label: tr(lang, 'loading'),
                liveRegion: true,
                child: const ShimmerListSkeleton(count: 5, itemHeight: 110),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tr(lang, 'dashboardLoadError')),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: controller.load,
                          child: Text(tr(lang, 'retry'))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Wraps each top-level card in a staggered fade+slide entrance — purely
  /// cosmetic, driven by each widget's own index so cards appear one after
  /// another rather than all popping in at once. No effect on data loading
  /// or state.
  List<Widget> _animatedChildren(List<Widget> children) {
    return children.asMap().entries.map((e) {
      final i = e.key;
      final child = e.value;
      if (child is SizedBox) return child;
      return _FadeSlideIn(delayMs: i * 60, child: child);
    }).toList();
  }
}

class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.child, required this.delayMs});
  final Widget child;
  final int delayMs;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: Padding(
            padding: const EdgeInsets.only(bottom: 0), child: widget.child),
      ),
    );
  }
}

/// "Upcoming Reminder" + Market Day countdown — unchanged logic from the
/// previous Dashboard, wrapped in the new rounded-card look for visual
/// consistency with the rest of this redesign.
class _UpcomingRemindersCard extends ConsumerWidget {
  const _UpcomingRemindersCard(
      {required this.uid, required this.currentDay, required this.lang});
  final String uid;
  final int currentDay;
  final AppLanguage lang;

  static const _dashboardKeys = ['feeding', 'health', 'weighin', 'photo'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPrefsProvider(uid));
    final daysToMarket = kMaxProductionDay - currentDay;

    return Container(
      decoration: dashboardCardDecoration(),
      padding: dashboardCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'upcomingReminders'),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            daysToMarket <= 0
                ? tr(lang, 'marketDayArrived')
                : '🐷 Market Day in $daysToMarket day${daysToMarket == 1 ? '' : 's'}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          prefsAsync.when(
            data: (prefs) {
              final now = DateTime.now();
              final rows = _dashboardKeys.map((key) {
                final def = findReminderType(key)!;
                final next = nextOccurrence(prefs, key, now);
                return _ReminderRow(
                    title: reminderTitle(lang, def.key, def.title),
                    next: next,
                    lang: lang);
              }).toList();
              return Column(children: rows);
            },
            loading: () => const SizedBox(
                height: 20,
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => Text(tr(lang, 'couldNotLoadReminders')),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow(
      {required this.title, required this.next, required this.lang});
  final String title;
  final DateTime? next;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final label = next == null
        ? tr(lang, 'off')
        : '${next!.month}/${next!.day} ${next!.hour.toString().padLeft(2, '0')}:${next!.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${tr(lang, 'nextReminderPrefix')} $title',
              style: const TextStyle(fontSize: 12)),
          Text(
            label,
            style: TextStyle(
                color: next == null ? DashboardPalette.textGray : null,
                fontWeight: FontWeight.w600,
                fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Last-10-observations trend strip — unchanged logic, restyled card.
class _HealthTrendStrip extends StatelessWidget {
  const _HealthTrendStrip({required this.data, required this.lang});
  final DashboardData data;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final trend = data.healthTrend;
    if (trend.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: dashboardCardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'healthTrend'),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: trend
                .map((h) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Tooltip(
                        message:
                            '${h.date}: ${kHealthStatusMeta[h.status]!.label}',
                        child: Text(kHealthStatusMeta[h.status]!.emoji,
                            style: const TextStyle(fontSize: 18)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
