import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../growth/presentation/providers/growth_providers.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/daily_task.dart';
import '../providers/calendar_providers.dart';
import '../providers/dashboard_providers.dart';
import '../theme/dashboard_palette.dart';
import '../widgets/dashboard_app_bar_actions.dart';
import '../widgets/dashboard_drawer.dart';

const _iconBgCycle = [
  Color(0xFFC8E6C9),
  Color(0xFFBBDEFB),
  Color(0xFFC8E6C9),
  Color(0xFFB3E5FC),
  Color(0xFFF8BBD0),
  Color(0xFFFFE0B2),
  Color(0xFFD7CCC8),
  Color(0xFFFFE0B2),
  Color(0xFFC8E6C9),
  Color(0xFFFFF9C4),
];

/// The IDs whose completion is gated behind today's Health Monitor
/// observation — matches taskLockMessage()'s id == '2' / '6' / '8' branches
/// in daily_task.dart exactly. Task 10 has its own, different lock rule
/// (depends on 2/6/8 being done, not directly on the Health Monitor) and
/// keeps its existing SnackBar-based lock message rather than the new
/// padlock/dialog treatment below, since its message and remedy are
/// different ("finish these other tasks first", not "go log your pigs'
/// health").
const _healthGatedTaskIds = {'2', '6', '8'};

/// Full-page "Daily Activities" — the Tasks tab in the bottom nav.
///
/// This is a presentation-only redesign: every value rendered below still
/// comes from the same DashboardData/DashboardController this screen
/// already used (tasksToday, doneTaskCount, currentDay, cycleComplete,
/// hasHealthLogToday, hasPigs). No task was added, removed, renumbered,
/// renamed, or re-gated — see _buildTiles/_healthGatedTaskIds below, which
/// are byte-for-byte the same lock computation as before. Only the widgets
/// that render those values changed (header layout, section header, card
/// styling, button styling, and a couple of small entrance/press
/// animations).
///
/// Lock state itself is NOT new logic: DashboardData.hasHealthLogToday
/// (healthLogs.any((h) => h.day == currentDay)) already flips true the
/// moment HealthController.submit() saves an observation for today — see
/// health_providers.dart, which already invalidates
/// dashboardControllerProvider(uid) on a successful save. Tasks/health logs
/// are both fetched per-currentDay already, so a new production day
/// naturally starts with an empty tasksToday map and no health log for that
/// day — the "daily reset" is just how this data was already shaped,
/// nothing added here. This screen only adds the locked *presentation*
/// (padlock, dimmed card, confirmation dialog) on top of that existing
/// signal.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardControllerProvider(uid));
    final controller = ref.read(dashboardControllerProvider(uid).notifier);
    final lang = ref.watch(appLanguageProvider);
    final fullName =
        ref.watch(userProfileProvider(uid)).valueOrNull?['fullName'] as String?;

    ref.listen(dashboardControllerProvider(uid), (previous, next) {
      final err = next.valueOrNull?.errorMessage;
      final prevErr = previous?.valueOrNull?.errorMessage;
      if (err != null && err != prevErr) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
        controller.clearError();
      }
    });

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
        title: Text(tr(lang, 'dailyActivitiesTitle'),
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
      body: dashboardAsync.when(
        data: (data) {
          final healthLoggedToday = data.hasHealthLogToday;
          final amTasks =
              kDailyTaskDefs.where((d) => d.period == 'am').toList();
          final pmTasks =
              kDailyTaskDefs.where((d) => d.period == 'pm').toList();
          final amDone =
              amTasks.where((d) => data.tasksToday[d.id] == true).length;
          final pmDone =
              pmTasks.where((d) => data.tasksToday[d.id] == true).length;
          final progress = kDailyTaskDefs.isEmpty
              ? 0.0
              : data.doneTaskCount / kDailyTaskDefs.length;

          // Bug A5 fix: daily tasks are meaningless with zero pigs on the
          // account (there's nothing to feed/weigh/observe yet) — show a
          // friendly prompt to add a pig first instead of a checklist that
          // can be freely ticked off with nothing behind it.
          if (!data.hasPigs) {
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
                    Text(tr(lang, 'addPigToLogTasks'),
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: DashboardPalette.textGray)),
                    const SizedBox(height: 20),
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

          return RefreshIndicator(
            onRefresh: controller.load,
            child: _FadeSlideIn(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  // ── Day / progress header ────────────────────────────
                  Text(
                    '${tr(lang, 'dayLabel')} ${data.currentDay}',
                    style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tr(lang, 'completeAllTasksSuffix'),
                    style: const TextStyle(
                        fontSize: 12.5, color: DashboardPalette.textGray),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: DashboardPalette.lightGreen,
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.task_alt_rounded,
                            size: 15, color: DashboardPalette.darkGreen),
                        const SizedBox(width: 6),
                        Text(
                          '${data.doneTaskCount} / ${kDailyTaskDefs.length} ${tr(lang, 'doneSuffix')}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: DashboardPalette.darkGreen),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    label: "Today's tasks progress",
                    value:
                        '${data.doneTaskCount} of ${kDailyTaskDefs.length} complete',
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      builder: (context, value, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 8,
                          backgroundColor: DashboardPalette.darkGreen
                              .withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation(
                              DashboardPalette.primaryGreen),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Health Monitor (premium outlined button) ─────────
                  // Routes to the independent Health Monitor Home hub
                  // (Specific Pig / Overall Herd mode selection) rather
                  // than straight into the flock-level form — either mode's
                  // resulting check still has today's production day and
                  // satisfies DashboardData.hasHealthLogToday exactly the
                  // same way, so the daily-task unlock keeps working.
                  _PressScale(
                    borderRadius: 20,
                    onTap: () => context.push(AppRoutes.healthHub),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: DashboardPalette.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: DashboardPalette.primaryGreen, width: 1.4),
                      ),
                      child: Row(
                        children: [
                          const Text('🩺', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(tr(lang, 'navHealthMonitor'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: DashboardPalette.darkGreen)),
                          ),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 18, color: DashboardPalette.darkGreen),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // C4: "+ Log Today" is now reachable directly from the
                  // Tasks screen too — previously this action existed only
                  // on the Dashboard's GreetingHeader, so a farmer working
                  // through today's checklist here had to navigate back to
                  // the Dashboard just to log the day once finished. Same
                  // confirm-then-advance flow (and the same C8 "go to
                  // Tasks" dialog for incomplete tasks, and the same
                  // A12/C13 dependent-provider invalidation) as the
                  // Dashboard button — no separate/parallel advance-day
                  // path.
                  if (!data.cycleComplete)
                    _PressScale(
                      borderRadius: 20,
                      onTap: () => _confirmAdvance(context, ref, data, lang),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: DashboardPalette.darkGreen,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: DashboardPalette.darkGreen
                                    .withValues(alpha: 0.28),
                                blurRadius: 14,
                                offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 6),
                            Text(tr(lang, 'logTodayLabel'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),

                  // ── Routine sections ──────────────────────────────────
                  if (amTasks.isNotEmpty) ...[
                    _RoutineSectionHeader(
                      icon: Icons.wb_sunny_rounded,
                      iconColor: DashboardPalette.accentOrange,
                      title: tr(lang, 'morningRoutine'),
                      done: amDone,
                      total: amTasks.length,
                      lang: lang,
                    ),
                    const SizedBox(height: 10),
                    ..._buildTiles(amTasks, data, healthLoggedToday, controller,
                        context, lang),
                  ],
                  if (pmTasks.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _RoutineSectionHeader(
                      icon: Icons.nights_stay_rounded,
                      iconColor: const Color(0xFF7E57C2),
                      title: tr(lang, 'eveningRoutine'),
                      done: pmDone,
                      total: pmTasks.length,
                      lang: lang,
                    ),
                    const SizedBox(height: 10),
                    ..._buildTiles(pmTasks, data, healthLoggedToday, controller,
                        context, lang),
                  ],
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr(lang, 'somethingWentWrongTasks')),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: controller.load, child: Text(tr(lang, 'retry'))),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTiles(
    List<DailyTaskDef> defs,
    DashboardData data,
    bool healthLoggedToday,
    DashboardController controller,
    BuildContext context,
    AppLanguage lang,
  ) {
    return defs.map((def) {
      final idx = kDailyTaskDefs.indexOf(def);
      final isHealthGated = _healthGatedTaskIds.contains(def.id);
      final requiresPriorTasks = def.id == '10' &&
          !['2', '6', '8'].every((r) => data.tasksToday[r] == true);
      final locked =
          (isHealthGated && !healthLoggedToday) || requiresPriorTasks;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _TaskTile(
          def: def,
          lang: lang,
          iconBg: _iconBgCycle[idx % _iconBgCycle.length],
          done: data.tasksToday[def.id] == true,
          locked: locked,
          onTap: () {
            if (requiresPriorTasks) {
              _showTaskLockedDialog(
                  context, lang, tr(lang, 'lockTask10Message'));
            } else if (locked) {
              _showTaskLockedDialog(context, lang, tr(lang, 'taskLockedBody'));
            } else {
              controller.toggleTask(def.id);
            }
          },
        ),
      );
    }).toList();
  }

  /// Mirrors GreetingHeader._confirmAdvance() exactly (same copy, same
  /// gates) so there is exactly one user-facing behavior for "log today,"
  /// reachable from two entry points rather than two divergent
  /// implementations that could drift apart.
  Future<void> _confirmAdvance(BuildContext context, WidgetRef ref,
      DashboardData data, AppLanguage lang) async {
    final controller = ref.read(dashboardControllerProvider(uid).notifier);
    if (!data.allTasksDone) {
      // Already on the Tasks screen — "Go to Tasks" here is a no-op beyond
      // dismissing the dialog, so the tasks themselves stay visible right
      // where the user already is; still shown for copy consistency with
      // the Dashboard's identical dialog.
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr(lang, 'completeTasksFirstSnackbar')),
          content: Text(tr(lang, 'incompleteTasksDialogBody')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr(lang, 'cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr(lang, 'goToTasks'))),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            '${tr(lang, 'dayLabel')} ${data.currentDay} ${tr(lang, 'completeExclaim')}'),
        content:
            Text('${tr(lang, 'proceedToDayPrefix')} ${data.currentDay + 1}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr(lang, 'cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
                '${tr(lang, 'proceedToDayPrefix')} ${data.currentDay + 1} →'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final advanced = await controller.advanceDay();
      if (advanced) {
        ref.invalidate(growthControllerProvider(uid));
        ref.invalidate(calendarDataProvider(uid));
      }
    }
  }

  Future<void> _showTaskLockedDialog(
      BuildContext context, AppLanguage lang, String message) async {
    final goToHealthMonitor = await showCustomConfirmDialog(
      context,
      title: tr(lang, 'taskLockedTitle'),
      message: message,
      confirmLabel: tr(lang, 'goToHealthMonitor'),
      cancelLabel: tr(lang, 'cancel'),
    );
    // Dialog only ever navigates the user TO the Health Monitor hub — it
    // never marks the task done and never unlocks anything itself. The
    // actual unlock happens later, reactively, once a Specific Pig or
    // Overall Herd check saves an observation for today (see the class doc
    // above; any real health log for today's production day unlocks this,
    // regardless of which pig it's attributed to).
    if (goToHealthMonitor && context.mounted) {
      context.push(AppRoutes.healthHub);
    }
  }
}

/// One-shot fade + slide-up entrance for the task list, matching the
/// premium feel requested for screen opening. Runs once per build of the
/// loaded state (e.g. on first load and after pull-to-refresh) — purely
/// cosmetic, wraps the same ListView with no change to its content.
class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.child});
  final Widget child;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
            offset: Offset(0, (1 - value) * 14), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Lightweight press-scale wrapper (~98%) used on the Health Monitor and
/// Log Today CTAs, matching the premium button feel requested — purely a
/// visual transform around the caller's existing [onTap].
class _PressScale extends StatefulWidget {
  const _PressScale(
      {required this.onTap, required this.child, this.borderRadius = 16});
  final VoidCallback onTap;
  final Widget child;
  final double borderRadius;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        child: widget.child,
      ),
    );
  }
}

/// Routine section header — icon + label + an optional "done/total" count
/// for that routine, computed from data this screen already has (the same
/// tasksToday map/period split used to build the tiles below it). No new
/// completion concept is introduced; this is just a sum over existing
/// per-task done flags.
class _RoutineSectionHeader extends StatelessWidget {
  const _RoutineSectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.done,
    required this.total,
    required this.lang,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final int done;
  final int total;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: DashboardPalette.textGray),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$done/$total ${tr(lang, 'doneSuffix')}',
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: DashboardPalette.textGray),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile(
      {required this.def,
      required this.lang,
      required this.iconBg,
      required this.done,
      required this.locked,
      required this.onTap});
  final DailyTaskDef def;
  final AppLanguage lang;
  final Color iconBg;
  final bool done;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = locked
        ? const Color(0xFFF2F2F2)
        : (done ? DashboardPalette.lightGreen : DashboardPalette.card);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          decoration: dashboardCardDecoration(color: cardColor, radius: 20),
          padding: const EdgeInsets.all(16),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 350),
            opacity: locked ? 0.6 : 1.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: locked
                        ? DashboardPalette.textGray.withValues(alpha: 0.2)
                        : iconBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(def.icon, style: const TextStyle(fontSize: 19)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dailyTaskTitle(lang, def.id, def.title),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: locked
                              ? DashboardPalette.textGray
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(dailyTaskSubtitle(lang, def.id, def.subtitle),
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: DashboardPalette.textGray)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: locked
                      ? Container(
                          key: const ValueKey('locked'),
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: DashboardPalette.textGray
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.lock_outline_rounded,
                              color: DashboardPalette.textGray, size: 17),
                        )
                      : Icon(
                          done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          key: const ValueKey('unlocked'),
                          color: done
                              ? DashboardPalette.primaryGreen
                              : DashboardPalette.textGray,
                          size: 28,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
