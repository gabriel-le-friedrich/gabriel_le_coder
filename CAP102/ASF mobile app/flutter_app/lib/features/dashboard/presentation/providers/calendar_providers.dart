import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_providers.dart';

/// Read-only 120-day overview data — reuses the EXISTING
/// DashboardRepository.getDayLogs()/getCurrentDay() (no new repository
/// method, no new SQLite/Supabase table). Ports the legacy web app's
/// "Full 120-Day Overview" Calendar view (index.html's `cal-h1`) to Flutter,
/// which had not been migrated yet — this is read-only, so it can't
/// diverge from or duplicate the actual production-day advance logic that
/// still lives solely in DashboardRepository.advanceDay().
class CalendarData {
  const CalendarData({required this.currentDay, required this.completedDays});
  final int currentDay;
  final Set<int> completedDays;
}

final calendarDataProvider =
    FutureProvider.autoDispose.family<CalendarData, String>((ref, uid) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final results =
      await Future.wait([repo.getCurrentDay(uid), repo.getDayLogs(uid)]);
  final currentDay = results[0] as int;
  final dayLogs = results[1] as Map<String, dynamic>;
  final completed = <int>{};
  for (final entry in dayLogs.entries) {
    final day = int.tryParse(entry.key);
    final isComplete = (entry.value as Map?)?['isComplete'] == true;
    if (day != null && isComplete) completed.add(day);
  }
  return CalendarData(currentDay: currentDay, completedDays: completed);
});
