import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/domain/app_language.dart';
import '../../../settings/domain/settings_strings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/dashboard_calculations.dart';
import '../providers/calendar_providers.dart';
import '../theme/dashboard_palette.dart';

/// Full 120-Day Overview — a read-only grid of every production day,
/// highlighting the current day and shading completed ones. Reached from
/// the redesigned Dashboard's "Calendar" pill button.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calAsync = ref.watch(calendarDataProvider(uid));
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: DashboardPalette.background,
      appBar: AppBar(
        backgroundColor: DashboardPalette.background,
        elevation: 0,
        title: Text(tr(lang, 'fullOverviewTitle'),
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: calAsync.when(
        data: (cal) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: dashboardCardDecoration(),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        '${tr(lang, 'dayLabel')} ${cal.currentDay} ${tr(lang, 'ofLabel')} $kMaxProductionDay',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        '${cal.completedDays.length} ${tr(lang, 'daysCompletedSuffix')}',
                        style: const TextStyle(
                            color: DashboardPalette.primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _Legend(lang: lang),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  itemCount: kMaxProductionDay,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8),
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final isToday = day == cal.currentDay;
                    final isDone = cal.completedDays.contains(day);
                    final isFuture = day > cal.currentDay;
                    return Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday
                            ? DashboardPalette.primaryGreen
                            : isDone
                                ? DashboardPalette.lightGreen
                                : DashboardPalette.card,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            isFuture ? Border.all(color: Colors.black12) : null,
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.w500,
                          color: isToday
                              ? Colors.white
                              : (isFuture
                                  ? DashboardPalette.textGray
                                  : DashboardPalette.darkGreen),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(tr(lang, 'couldNotLoadCalendar'))),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.lang});

  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c) => Container(
        width: 12,
        height: 12,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)));
    return Row(
      children: [
        dot(DashboardPalette.primaryGreen),
        const SizedBox(width: 4),
        Text(tr(lang, 'todayLegend'),
            style: const TextStyle(
                fontSize: 11, color: DashboardPalette.textGray)),
        const SizedBox(width: 12),
        dot(DashboardPalette.lightGreen),
        const SizedBox(width: 4),
        Text(tr(lang, 'completedLegend'),
            style: const TextStyle(
                fontSize: 11, color: DashboardPalette.textGray)),
        const SizedBox(width: 12),
        dot(DashboardPalette.card),
        const SizedBox(width: 4),
        Text(tr(lang, 'upcomingLegend'),
            style: const TextStyle(
                fontSize: 11, color: DashboardPalette.textGray)),
      ],
    );
  }
}
