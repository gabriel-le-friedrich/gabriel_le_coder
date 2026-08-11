import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../domain/daily_task.dart';
import '../providers/dashboard_providers.dart';
import '../theme/dashboard_palette.dart';

const _iconBgCycle = [
  Color(0xFFFFE0B2),
  Color(0xFFBBDEFB),
  Color(0xFFC8E6C9),
  Color(0xFFB3E5FC),
  Color(0xFFF8BBD0),
  Color(0xFFE1BEE7),
  Color(0xFFD7CCC8),
  Color(0xFFE1BEE7),
  Color(0xFFFFF9C4),
  Color(0xFFC8E6C9),
];

/// "Today's Tasks" summary card — split into a "Completed" column and a
/// "Pending" column, matching the mockup's two-column layout. Same
/// DashboardData.tasksToday/doneTaskCount as before — no new task logic, no
/// new lock rules, still a non-interactive summary (which column a task
/// appears in reflects its real done/not-done state; tapping "View All
/// Tasks" is still how a farmer actually toggles a task, on the Tasks tab).
/// Task titles already carry their own "N. " prefix (see daily_task.dart),
/// so no separate numbering is added here.
class TodayTasksCard extends StatelessWidget {
  const TodayTasksCard({super.key, required this.data, required this.lang});
  final DashboardData data;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final completed = <DailyTaskDef>[];
    final pending = <DailyTaskDef>[];
    for (final def in kDailyTaskDefs) {
      if (data.tasksToday[def.id] == true) {
        completed.add(def);
      } else {
        pending.add(def);
      }
    }
    final progress = kDailyTaskDefs.isEmpty
        ? 0.0
        : data.doneTaskCount / kDailyTaskDefs.length;

    return Container(
      decoration: dashboardCardDecoration(),
      padding: dashboardCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tr(lang, 'todaysTasksTitle'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: DashboardPalette.lightGreen,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${data.doneTaskCount} / ${kDailyTaskDefs.length}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: DashboardPalette.darkGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr(lang, 'progressLabel'),
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: DashboardPalette.textGray)),
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: DashboardPalette.primaryGreen)),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: "Today's tasks progress",
            value: '${data.doneTaskCount} of ${kDailyTaskDefs.length} complete',
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: DashboardPalette.background,
                  valueColor: const AlwaysStoppedAnimation(
                      DashboardPalette.primaryGreen),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TaskColumn(
                    icon: Icons.check_circle_rounded,
                    iconColor: DashboardPalette.primaryGreen,
                    title: tr(lang, 'completedTasksLabel'),
                    tasks: completed,
                    emptyLabel: tr(lang, 'noTasksCompletedYet'),
                    done: true,
                    lang: lang,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TaskColumn(
                    icon: Icons.hourglass_bottom_rounded,
                    iconColor: DashboardPalette.accentOrange,
                    title: tr(lang, 'pendingTasksLabel'),
                    tasks: pending,
                    emptyLabel: tr(lang, 'allDoneLabel'),
                    done: false,
                    lang: lang,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: DashboardPalette.darkGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => context.go(AppRoutes.tasks),
              child: Text(tr(lang, 'viewAllTasksLabel'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskColumn extends StatelessWidget {
  const _TaskColumn({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.tasks,
    required this.emptyLabel,
    required this.done,
    required this.lang,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<DailyTaskDef> tasks;
  final String emptyLabel;
  final bool done;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 5),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: DashboardPalette.textGray,
                      letterSpacing: 0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(emptyLabel,
                style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: DashboardPalette.textGray)),
          )
        else
          ...tasks.map((def) {
            final idx = kDailyTaskDefs.indexOf(def);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DashboardPalette.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _iconBgCycle[idx % _iconBgCycle.length],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          Text(def.icon, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dailyTaskTitle(lang, def.id, def.title),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            color: done
                                ? DashboardPalette.textGray
                                : Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
