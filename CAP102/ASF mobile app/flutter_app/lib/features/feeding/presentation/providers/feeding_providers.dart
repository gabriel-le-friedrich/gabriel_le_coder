import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../dashboard/domain/dashboard_calculations.dart';

/// Read-only view over feed logs — reuses the EXISTING
/// DashboardRepository.getFeedLogs()/dashboardRepositoryProvider (no new
/// repository, no new SQLite table, no new Supabase table). Feed entries
/// are auto-recorded by DashboardRepository.advanceDay() based on the
/// pig's current growth stage (see stageForWeight in
/// dashboard_calculations.dart) — there is no manual "add feed" action in
/// this app, so this screen is intentionally list-only, matching the
/// data that actually exists.
final feedLogsProvider = FutureProvider.autoDispose
    .family<List<FeedLogEntry>, String>((ref, uid) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final logs = await repo.getFeedLogs(uid);
  return [...logs]..sort((a, b) => b.day.compareTo(a.day));
});
