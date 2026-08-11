// ══════════════════════════════════════════════════════════════════════
// Activity Log Viewer — read-only over the `activityLogs` SQLite table
// that every feature's recordActivityLog() call already writes to.
//
// This is also where the "later slice" flagged in
// AuthRepository.recordActivityLog()'s doc comment finally gets built:
// pushUnsynced() is the SQLite -> Supabase push for this table, matching
// the web app's push-only sync-engine.js pattern and the activity_logs
// table's insert-only RLS (no update policy — see supabase_schema.sql).
//
// Logging system audit fix #4 (bulk upload): this pushes every unsynced
// row for a user in a single request via `upsert(List<Map>, ...,
// ignoreDuplicates: true)` instead of one `insert()` per row. Using
// upsert+ignoreDuplicates rather than a plain bulk insert still respects
// the table's insert-only nature (`ignoreDuplicates: true` compiles to
// `ON CONFLICT DO NOTHING`, never `DO UPDATE` — no row already in
// Supabase is ever modified) while preventing one stray duplicate
// (e.g. a row whose earlier push succeeded but whose local `synced` flag
// failed to persist before an app crash) from aborting the whole batch,
// which a plain bulk `insert()` would do on the first unique-constraint
// hit against `uniq_activity_logs_entry`.
// ══════════════════════════════════════════════════════════════════════

import '../../../core/config/supabase_config.dart';
import '../../../core/database/sqlite_service.dart';
import '../../../core/services/device_id_service.dart';
import '../../../core/services/sync_time_utils.dart';
import '../domain/activity_log_entry.dart';

class ActivityLogRepository {
  final SqliteService _sqlite = SqliteService.instance;

  Future<List<ActivityLogEntry>> getLogs(String uid) async {
    final rows = await _sqlite.getActivityLogs(uid);
    return rows.map(ActivityLogEntry.fromRow).toList();
  }

  /// Best-effort bulk push of every not-yet-synced row for this uid in one
  /// request. Never throws — a failed push (offline, RLS hiccup, etc.)
  /// leaves every row in the batch `synced: 0` for the next attempt,
  /// exactly like every other repository's Supabase mirror in this app;
  /// nothing is marked synced unless Supabase actually accepted the batch.
  Future<void> pushUnsynced(String uid) async {
    List<Map<String, dynamic>> rows;
    try {
      rows = await _sqlite.getUnsyncedRows('activityLogs', uid);
    } catch (_) {
      return;
    }
    if (rows.isEmpty) return;

    final ids = <String>[];
    final payload = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = row['id'] as String;
      // sync_version is stamped from this row's own createdAt (not "now")
      // — activity_logs is insert-only/immutable (no UPDATE policy, see
      // supabase_schema.sql), so its version should reflect when the
      // entry was created, never a later resync attempt.
      final createdAtMs = row['createdAt'] as int;
      ids.add(id);
      payload.add({
        'firebase_uid': uid,
        'app_entry_id': id,
        'username': (row['username'] as String?)?.isNotEmpty == true
            ? row['username']
            : null,
        'action_type': (row['actionType'] as String?) ?? '',
        'description': (row['description'] as String?) ?? '',
        'action': row['action'] as String?,
        'status': row['status'] as String?,
        'created_at': SyncTimeUtils.toIsoUtc(createdAtMs),
        ...DeviceIdService.supabaseSyncFields(createdAtMs),
      });
    }

    try {
      await supabase.from('activity_logs').upsert(payload,
          onConflict: 'firebase_uid,app_entry_id', ignoreDuplicates: true);
      await _sqlite.markRowsSynced('activityLogs', ids);
    } catch (_) {
      // whole batch left synced:0 — retried on the next pushUnsynced() call
    }
  }

  /// Production audit finding: this repository only ever PUSHED local rows
  /// to Supabase — there was no path back down, so a fresh device/reinstall
  /// (empty local `activityLogs` table) never saw history recorded on any
  /// other device, even though that history was sitting in Supabase the
  /// whole time. Mirrors the exact "pull only when local is empty" pattern
  /// every other repository already uses (see e.g.
  /// ExpensesRepository.pullFromCloudIfEmpty/
  /// DashboardRepository.pullWeightLogsFromCloudIfEmpty) so an existing
  /// device's own not-yet-synced local rows are never overwritten — this
  /// only ever runs when there is nothing local to lose yet.
  Future<void> pullFromCloudIfEmpty(String uid) async {
    try {
      final local = await getLogs(uid);
      if (local.isNotEmpty) return;
      final rows = await supabase
          .from('activity_logs')
          .select()
          .eq('firebase_uid', uid)
          .order('created_at');
      if ((rows as List).isEmpty) return;
      for (final map in rows) {
        final id = map['app_entry_id'] as String?;
        if (id == null) continue;
        int createdAtMs;
        try {
          createdAtMs = DateTime.parse(map['created_at'] as String)
              .millisecondsSinceEpoch;
        } catch (_) {
          createdAtMs = SqliteService.nowMs();
        }
        await _sqlite.upsertRow('activityLogs', {
          'id': id,
          'uid': uid,
          'actionType': map['action_type'] as String? ?? '',
          'description': map['description'] as String? ?? '',
          'username': map['username'] as String? ?? '',
          'createdAt': createdAtMs,
          'synced': 1,
          'action': map['action'] as String?,
          'status': map['status'] as String?,
        });
      }
    } catch (_) {
      // Offline/unreachable — the local table just stays empty for now;
      // this is retried on every SyncEngine.syncNow() pass same as every
      // other pull-if-empty path.
    }
  }
}
