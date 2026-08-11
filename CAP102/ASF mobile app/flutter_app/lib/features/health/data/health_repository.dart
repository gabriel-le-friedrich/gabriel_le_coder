// ══════════════════════════════════════════════════════════════════════
// Health Monitoring data access — reads/writes the SQLite aggregate row
// healthLogs/main (the table already existed in sqlite_service.dart,
// unused until now), one JSON array per user, matching getHealthLogs()/
// setHealthLogs() in index.html exactly. Supabase mirror goes to
// health_records (see supabase_schema.sql): the four discrete observation
// fields + notes/status/day/date/time are packed into condition_notes as a
// JSON string, since that table only has a single free-text column for
// the observation payload — best-effort, same individually-wrapped
// pattern as every other repository here.
// ══════════════════════════════════════════════════════════════════════

import 'dart:convert';

import '../../../core/config/supabase_config.dart';
import '../../../core/database/safe_parse.dart';
import '../../../core/database/sqlite_service.dart';
import '../../../core/services/device_id_service.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../domain/health_calculations.dart';

/// Repository for the Health Monitor feature — SQLite is the source of
/// truth (offline-first), Supabase is a best-effort mirror only. Every
/// write goes through [_setHealthLogs]/[_mirrorHealthLogToSupabase], both
/// of which swallow Supabase errors so a save never fails just because
/// the device is offline.
class HealthRepository {
  final SqliteService _sqlite = SqliteService.instance;
  final DashboardRepository _dashboardRepo = DashboardRepository();

  /// All health observations for [uid], unsorted (callers that need
  /// newest-first, e.g. the History screen, sort locally).
  ///
  /// Parses each stored record independently and skips (rather than
  /// throws on) any single entry that fails to parse — e.g. a legacy or
  /// corrupted row from an interrupted write. Before this, one bad record
  /// anywhere in the array would throw out of the whole `.map()`, which
  /// took down every caller at once: History, the Dashboard's "Today's
  /// Health" card, and the health-gated Daily Tasks lock all went
  /// blank/error together even though every OTHER observation was fine.
  Future<List<HealthLogEntry>> getHealthLogs(String uid) async {
    final data = await _sqlite.getAggregate('healthLogs', uid, subkey: 'main');
    return parseJsonListSafely(data, HealthLogEntry.fromJson,
            repoName: 'HealthRepository.getHealthLogs')
        .entries;
  }

  /// Debug-only companion to [getHealthLogs] — how many stored records were
  /// skipped as corrupted on the most recent read. Used solely by the
  /// History screen's "Some invalid health records were ignored." notice,
  /// which only ever renders in debug builds. Re-parses the same raw data
  /// (cheap at this app's real scale — at most a few hundred records over a
  /// 120-day cycle) rather than mutating shared state on the repository,
  /// so concurrent callers of getHealthLogs() can never race each other's
  /// skipped-count.
  Future<int> getSkippedHealthLogCount(String uid) async {
    final data = await _sqlite.getAggregate('healthLogs', uid, subkey: 'main');
    return parseJsonListSafely(data, HealthLogEntry.fromJson,
            repoName: 'HealthRepository.getHealthLogs')
        .skipped;
  }

  /// Most recent log by real save timestamp (not array order) — matches
  /// getLatestHealthLog() in index.html, which powers the Dashboard's
  /// critical banner.
  Future<HealthLogEntry?> getLatestHealthLog(String uid) async {
    final logs = await getHealthLogs(uid);
    if (logs.isEmpty) return null;
    final sorted = [...logs]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted.last;
  }

  /// Whether a health observation has already been saved for [day] — this
  /// is the real behaviorLoggedToday/physicalLoggedToday gate the Dashboard
  /// task-lock system needs (one combined form covers both fields at once).
  /// Intentionally NOT pig-scoped — any health check that day (flock-level
  /// or for any one pig) unlocks the shared Daily Task, matching the
  /// pre-redesign behavior exactly.
  Future<bool> hasLoggedForDay(String uid, int day) async {
    final logs = await getHealthLogs(uid);
    return logs.any((h) => h.day == day);
  }

  /// Per-pig duplicate guard for the Health Monitor redesign's "Specific
  /// Pig"/"Overall Herd" flows — unlike [hasLoggedForDay], this only counts
  /// a check as already-done for [pigId] specifically, so checking Pig A
  /// today never blocks starting a check for Pig B the same day.
  Future<bool> hasLoggedForPigOnDay(String uid, int day, String pigId) async {
    final logs = await getHealthLogs(uid);
    return logs.any((h) => h.day == day && h.pigId == pigId);
  }

  /// All observations linked to one real pig (newest last) — used by the
  /// Specific Pig detail views, per-pig History filter, and the "already
  /// checked today" edit path.
  Future<List<HealthLogEntry>> getHealthLogsForPig(
      String uid, String pigId) async {
    final logs = await getHealthLogs(uid);
    final forPig = logs.where((h) => h.pigId == pigId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return forPig;
  }

  /// Most recent observation for one real pig, or null if it's never been
  /// checked. Used by the Specific Pig picker/result screens.
  Future<HealthLogEntry?> getLatestHealthLogForPig(
      String uid, String pigId) async {
    final logs = await getHealthLogsForPig(uid, pigId);
    return logs.isEmpty ? null : logs.last;
  }

  /// Latest health status per real pig, across every pig that has at least
  /// one pig-linked check — the source of truth for the Health Monitor
  /// Home hub's "Today's Overview" and the Herd Health Summary. Pigs with
  /// no entry here simply have no key, which callers must treat as "Not Yet
  /// Checked" rather than guessing a status — legacy flock-level entries
  /// (pigId == null, saved before this field existed) are excluded, since
  /// they were never attributed to one real pig.
  Future<Map<String, HealthLogEntry>> getLatestHealthLogPerPig(
      String uid) async {
    final logs = await getHealthLogs(uid);
    final ascending = [...logs]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final byPig = <String, HealthLogEntry>{};
    for (final e in ascending) {
      final pid = e.pigId;
      if (pid == null || pid.isEmpty) continue;
      byPig[pid] = e; // later entries overwrite earlier -> latest wins
    }
    return byPig;
  }

  /// Overwrites the entire healthLogs/main SQLite row for [uid], then
  /// best-effort mirrors the whole list to the `settings` table in
  /// Supabase (a secondary, coarser mirror alongside the per-record
  /// `health_records` mirror in [_mirrorHealthLogToSupabase]).
  Future<void> _setHealthLogs(String uid, List<HealthLogEntry> logs) async {
    final nowMs = SqliteService.nowMs();
    await _sqlite.setAggregate(
        'healthLogs', uid, 'main', logs.map((e) => e.toJson()).toList());
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'healthLogs',
        'data': logs.map((e) => e.toJson()).toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(nowMs),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}
  }

  /// Best-effort per-record mirror to `health_records`, keyed by
  /// (firebase_uid, app_entry_id) so re-sending an already-synced entry
  /// (see [resyncPending]) is a harmless no-op upsert rather than a
  /// duplicate row.
  Future<void> _mirrorHealthLogToSupabase(
      String uid, HealthLogEntry entry) async {
    try {
      await supabase.from('health_records').upsert({
        'firebase_uid': uid,
        'app_entry_id': '${entry.id}',
        'pig_id': entry.pigId,
        'condition_notes': jsonEncode(entry.toJson()),
        'recorded_at': entry.timestamp,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid,app_entry_id');
    } catch (_) {}
  }

  /// Saves a new health observation for TODAY's production day, computes
  /// its status, and marks the shared "health" day-task done (unlocking
  /// Vitality Inspection / Respiratory Check / Temp & Ventilation) — all
  /// three side effects of a single save, matching saveHealth() exactly.
  Future<HealthLogEntry> addHealthLog({
    required String uid,
    required String behavior,
    required String appetite,
    required List<String> physical,
    required String waste,
    String notes = '',
    String assessedBy = '',
    String? pigId,
    String? pigName,
    String? sessionId,
  }) async {
    final day = await _dashboardRepo.getCurrentDay(uid);
    final logs = await getHealthLogs(uid);
    final nextId = logs.fold<int>(0, (max, e) => e.id > max ? e.id : max) + 1;
    final now = DateTime.now();
    final assessment = computeHealthAssessment(
        behavior: behavior,
        appetite: appetite,
        physical: physical,
        waste: waste);
    // Best-effort snapshot of the batch/pig identity at save time — this
    // is traceability metadata (see HealthLogEntry's doc), so a missing
    // profile just leaves these blank rather than blocking the save. When a
    // real [pigId] is supplied (Specific Pig / Overall Herd modes), the
    // caller's own [pigName] (the real Pig.name) takes priority over the
    // flock-level batch snapshot, since it's the more accurate label for
    // that individual entry.
    final batchProfile = await _dashboardRepo.getPigBatchProfile(uid);
    final entry = HealthLogEntry(
      id: nextId,
      day: day,
      date:
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      time:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      timestamp: now.toIso8601String(),
      behavior: behavior,
      appetite: appetite,
      physical: physical,
      waste: waste,
      notes: notes,
      status: assessment.status,
      severityScore: assessment.severityScore,
      healthyCount: assessment.healthyCount,
      monitorCount: assessment.monitorCount,
      riskCount: assessment.riskCount,
      criticalCount: assessment.criticalCount,
      batchName: batchProfile?.batchName ?? '',
      pigName: pigName ?? batchProfile?.pigName ?? '',
      assessedBy: assessedBy,
      pigId: pigId,
      sessionId: sessionId,
    );
    final invalidReason = validateHealthLogEntry(entry);
    if (invalidReason != null)
      throw InvalidHealthLogEntryException(invalidReason);
    final updated = [...logs, entry];
    await _setHealthLogs(uid, updated);
    await _mirrorHealthLogToSupabase(uid, entry);
    await _dashboardRepo.setTaskDone(uid, day, 'health');
    return entry;
  }

  /// Re-scores and overwrites an existing observation by [id] — used both
  /// for a farmer-initiated edit from History and for the duplicate-guard
  /// "Edit Today's Assessment" flow. Returns null if [id] no longer
  /// exists (e.g. deleted from another device since the form opened).
  Future<HealthLogEntry?> updateHealthLog({
    required String uid,
    required int id,
    required String behavior,
    required String appetite,
    required List<String> physical,
    required String waste,
    String notes = '',
    String assessedBy = '',
  }) async {
    final logs = await getHealthLogs(uid);
    final idx = logs.indexWhere((e) => e.id == id);
    if (idx == -1) return null;
    final assessment = computeHealthAssessment(
        behavior: behavior,
        appetite: appetite,
        physical: physical,
        waste: waste);
    final updatedEntry = logs[idx].copyWith(
      behavior: behavior,
      appetite: appetite,
      physical: physical,
      waste: waste,
      notes: notes,
      status: assessment.status,
      severityScore: assessment.severityScore,
      healthyCount: assessment.healthyCount,
      monitorCount: assessment.monitorCount,
      riskCount: assessment.riskCount,
      criticalCount: assessment.criticalCount,
      assessedBy: assessedBy,
      updatedAt: DateTime.now().toIso8601String(),
    );
    final invalidReason = validateHealthLogEntry(updatedEntry);
    if (invalidReason != null)
      throw InvalidHealthLogEntryException(invalidReason);
    final updated = [...logs]..[idx] = updatedEntry;
    await _setHealthLogs(uid, updated);
    await _mirrorHealthLogToSupabase(uid, updatedEntry);
    return updatedEntry;
  }

  /// Removes an observation from both the local SQLite row and the
  /// Supabase mirror (best-effort — a failed remote delete doesn't block
  /// the local one, matching this repository's offline-first stance).
  Future<void> deleteHealthLog({required String uid, required int id}) async {
    final logs = await getHealthLogs(uid);
    final updated = logs.where((e) => e.id != id).toList();
    await _setHealthLogs(uid, updated);
    try {
      await supabase
          .from('health_records')
          .delete()
          .eq('firebase_uid', uid)
          .eq('app_entry_id', '$id');
    } catch (_) {}
  }

  /// Sync engine support — same idempotent full-re-push rationale as
  /// ExpensesRepository.resyncPending() (see its comment): every
  /// health_records upsert is keyed by (firebase_uid, app_entry_id), so
  /// resending already-synced entries is harmless.
  ///
  /// Bug B3 fix: pushes every entry in ONE batched upsert instead of one
  /// Supabase request per health log — mirrors the batching already applied
  /// to PigRepository.resyncPendingImages/resyncPendingPigs. Falls back to
  /// per-row upserts only if the whole-batch call itself fails, so one bad
  /// row can't block every other entry from syncing.
  Future<void> resyncPending(String uid) async {
    final logs = await getHealthLogs(uid);
    await _setHealthLogs(uid, logs);
    if (logs.isEmpty) return;
    final nowMs = SqliteService.nowMs();
    final payload = logs
        .map((e) => {
              'firebase_uid': uid,
              'app_entry_id': '${e.id}',
              'pig_id': e.pigId,
              'condition_notes': jsonEncode(e.toJson()),
              'recorded_at': e.timestamp,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
              ...DeviceIdService.supabaseSyncFields(nowMs),
            })
        .toList();
    try {
      await supabase
          .from('health_records')
          .upsert(payload, onConflict: 'firebase_uid,app_entry_id');
    } catch (_) {
      for (final e in logs) {
        await _mirrorHealthLogToSupabase(uid, e);
      }
    }
  }

  /// First-login-on-a-new-device support — see ExpensesRepository's
  /// pullFromCloudIfEmpty() for the full rationale (the old sync engine
  /// only ever pushed local->cloud). Each health_records row's whole entry
  /// lives in condition_notes as the same JSON this app already writes via
  /// HealthLogEntry.toJson(), so decoding it back is exact, not a
  /// reconstruction from partial columns. Only pulls when the local cache
  /// is empty, so an existing device's own unsynced edits are never
  /// overwritten.
  Future<void> pullFromCloudIfEmpty(String uid) async {
    try {
      final local = await getHealthLogs(uid);
      if (local.isNotEmpty) return;
      final rows = await supabase
          .from('health_records')
          .select()
          .eq('firebase_uid', uid);
      if ((rows as List).isEmpty) return;
      final entries = <HealthLogEntry>[];
      for (final map in rows) {
        try {
          final decoded = jsonDecode(map['condition_notes'] as String)
              as Map<String, dynamic>;
          entries.add(HealthLogEntry.fromJson(decoded));
        } catch (_) {
          // Skip a single corrupted/legacy row rather than aborting the
          // whole pull — same defensive stance as getHealthLogs() itself.
        }
      }
      if (entries.isNotEmpty) {
        await _setHealthLogs(uid, entries);
      }
    } catch (_) {
      // Offline or Supabase unreachable — retried on the next bootstrap.
    }
  }
}
