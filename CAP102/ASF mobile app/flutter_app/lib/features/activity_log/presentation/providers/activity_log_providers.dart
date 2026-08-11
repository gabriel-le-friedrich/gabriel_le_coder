import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/activity_log_repository.dart';
import '../../domain/activity_log_entry.dart';

final activityLogRepositoryProvider =
    Provider<ActivityLogRepository>((ref) => ActivityLogRepository());

/// Pushes any not-yet-synced rows first (best-effort, swallows failures),
/// then reads the full local history — newest first (see
/// SqliteService.getActivityLogs' orderBy). Re-fetch via
/// ref.invalidate(activityLogsProvider(uid)) after a push if the screen
/// wants a manual refresh affordance.
final activityLogsProvider = FutureProvider.autoDispose
    .family<List<ActivityLogEntry>, String>((ref, uid) async {
  final repo = ref.watch(activityLogRepositoryProvider);
  try {
    await repo.pushUnsynced(uid);
  } catch (_) {}
  return repo.getLogs(uid);
});
