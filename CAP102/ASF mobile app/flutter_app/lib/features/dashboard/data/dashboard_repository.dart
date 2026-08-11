// ══════════════════════════════════════════════════════════════════════
// Dashboard data access — reads/writes the same SQLite aggregate rows the
// Onboarding slice seeds (settings/currentDay, settings/dayLogs,
// growthLogs/weightLogs, expenses/main) plus feedingLogs/main (auto-logged
// feed given, per the ATI manual's "feed given must be recorded" rule).
// Supabase writes here are the same best-effort, individually-wrapped
// pattern as OnboardingRepository — a failure never blocks the local,
// offline-first read/write path.
// ══════════════════════════════════════════════════════════════════════

import '../../../core/config/supabase_config.dart';
import '../../../core/database/safe_parse.dart';
import '../../../core/database/sqlite_service.dart';
import '../../../core/services/device_id_service.dart';
import '../../pigs/data/pig_repository.dart';
import '../domain/dashboard_calculations.dart';
import '../domain/pig_batch_profile.dart';

/// Fallback pig id used ONLY when a weigh-in needs to be mirrored to
/// Supabase's weight_records table (a required foreign key column) but the
/// user has no pigs yet — a real, if unusual, path now that pig creation
/// happens solely through Pig Management's Add Pig form rather than being
/// guaranteed by an onboarding wizard. Matches the legacy onboarding
/// sentinel id's value for continuity, but is no longer tied to onboarding
/// in any way.
const String kUnassignedPigId = 'BIGAS-01';

/// Thrown by addWeighIn when an official weigh-in already exists for the
/// requested production week and the caller isn't explicitly editing it —
/// the direct enforcement of "one official weigh-in per production week."
class DuplicateWeighInException implements Exception {
  DuplicateWeighInException(this.weekNumber, this.existingDay);
  final int weekNumber;
  final int existingDay;
}

/// Thrown by addWeighIn when attempting to record a Week 2+ weigh-in before
/// Week 1 has an official weigh-in.
class MissingWeek1Exception implements Exception {
  MissingWeek1Exception();
}

/// Result of a successful addWeighIn() call — isFirstOfficial tells the
/// Growth controller whether this was the entry that just activated the
/// Starting Weight lock, so it can log that transition once.
class WeighInResult {
  const WeighInResult({required this.entry, required this.isFirstOfficial});
  final WeightLogEntry entry;
  final bool isFirstOfficial;
}

class DashboardRepository {
  final SqliteService _sqlite = SqliteService.instance;
  final PigRepository _pigRepo = PigRepository();

  /// The batch-level anchor (starting weight/date, pig count) ADG/FCR/ROI/
  /// Growth% are computed from. Prefers an explicitly saved
  /// settings/pigBatchProfile row — the only thing the now-removed
  /// onboarding wizard ever wrote, still there and unmodified for any user
  /// who already completed it, and also (re)written today whenever
  /// updateBatchStartWeight()/updateFeedPrice() persist an edit. When that
  /// row doesn't exist (every new user from here on, since pigs are now
  /// created solely via Pig Management's Add Pig form), this synthesizes an
  /// equivalent profile from the oldest real pig on file instead:
  /// startWeight/startDate come straight from that pig's own
  /// initialWeight/arrivalDate (exactly what the user typed into the Add Pig
  /// form — never a fabricated placeholder). Returns null only when the user
  /// genuinely has no saved profile AND no pigs yet — the real "nothing to
  /// show" case the Dashboard's empty/"--" states key off of.
  ///
  /// A4/C5 root cause (confirmed by trace, not theorized): numPigs used to
  /// be read straight out of the saved settings/pigBatchProfile row when one
  /// existed, and that row is ONLY ever rewritten by
  /// updateBatchStartWeight()/updateFeedPrice() — never by PigRepository
  /// when a pig is added. So the very first time a user touched Starting
  /// Weight or Feed Price (or the legacy onboarding wizard), numPigs froze
  /// at whatever the pig count was that moment. Every pig added after that
  /// point was correctly saved in Pig Management (visible there) but
  /// invisible to Dashboard/Tasks/Feeding/Growth/Expense, which all key off
  /// this numPigs for their per-pig math (feed portions, total feed cost,
  /// ROI) — the exact "existing pig has no Tasks/Feeding" symptom reported.
  /// Fix: numPigs is now ALWAYS re-derived from the live pig count on every
  /// call, in both branches, never frozen from the saved row.
  Future<PigBatchProfile?> getPigBatchProfile(String uid) async {
    final data =
        await _sqlite.getAggregate('settings', uid, subkey: 'pigBatchProfile');
    final livePigs = await _pigRepo.getPigs(uid);
    if (data != null) {
      final saved =
          PigBatchProfile.fromJson(Map<String, dynamic>.from(data as Map));
      return saved.copyWith(
          numPigs: livePigs.isEmpty ? saved.numPigs : livePigs.length);
    }
    try {
      if (livePigs.isEmpty) return null;
      final sorted = [...livePigs]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final oldest = sorted.first;
      return PigBatchProfile(
        pigName: oldest.name,
        batchName: '',
        numPigs: livePigs.length,
        startWeight: oldest.initialWeight,
        startDate: oldest.arrivalDate,
        feedPrice: 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Persisted, decoupled-from-the-calendar production day counter. Falls
  /// back to (and seeds) computeProductionDayFallback() only if genuinely
  /// missing — matches getCurrentDay() in index.html exactly, including the
  /// one-time migration comment: from that point on the stored counter,
  /// never the calendar, is the sole source of truth.
  Future<int> getCurrentDay(String uid) async {
    final raw =
        await _sqlite.getAggregate('settings', uid, subkey: 'currentDay');
    if (raw is num) return raw.toInt().clamp(1, kMaxProductionDay);
    final profile = await getPigBatchProfile(uid);
    final seeded = computeProductionDayFallback(profile?.startDate);
    await _sqlite.setAggregate('settings', uid, 'currentDay', seeded);
    return seeded;
  }

  /// Raw dayLogs blob: { "<day>": { "tasks": {"1": true, ...}, "isComplete": bool } }
  Future<Map<String, dynamic>> getDayLogs(String uid) async {
    final data = await _sqlite.getAggregate('settings', uid, subkey: 'dayLogs');
    if (data == null) return {};
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> _setDayLogs(String uid, Map<String, dynamic> logs) {
    return _sqlite.setAggregate('settings', uid, 'dayLogs', logs);
  }

  Future<List<WeightLogEntry>> getWeightLogs(String uid) async {
    final data =
        await _sqlite.getAggregate('growthLogs', uid, subkey: 'weightLogs');
    return parseJsonListSafely(data, WeightLogEntry.fromJson,
            repoName: 'DashboardRepository.getWeightLogs')
        .entries;
  }

  Future<void> _setWeightLogs(String uid, List<WeightLogEntry> logs) async {
    final nowMs = SqliteService.nowMs();
    await _sqlite.setAggregate(
        'growthLogs', uid, 'weightLogs', logs.map((e) => e.toJson()).toList());
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'weightLogs',
        'data': logs.map((e) => e.toJson()).toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(nowMs),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}
  }

  /// Best-effort mirror of one weigh-in into Supabase's weight_records table
  /// (see OnboardingRepository.completeOnboarding's Day-1 seed row for the
  /// exact column shape this matches). Since weigh-ins are recorded at the
  /// batch level rather than per individual pig, this attaches every entry
  /// to the oldest pig on file (falling back to the onboarding sentinel id
  /// if the pig list can't be read) purely so the row has a valid foreign
  /// key — it never blocks or alters the local write.
  Future<void> _mirrorWeighInToSupabase(
      String uid, WeightLogEntry entry) async {
    try {
      String pigId = kUnassignedPigId;
      try {
        final pigs = await _pigRepo.getPigs(uid);
        if (pigs.isNotEmpty) pigId = pigs.first.id;
      } catch (_) {}
      await supabase.from('weight_records').upsert({
        'firebase_uid': uid,
        'pig_id': pigId,
        'sync_key': '$uid:day-${entry.day}',
        'day_number': entry.day,
        'weight_kg': entry.weight,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid,sync_key');
    } catch (_) {}
  }

  /// Adds an official weekly weigh-in for the CURRENT production day/week,
  /// or — via [forWeekNumber] — backfills a MISSED past week's weigh-in
  /// while the farmer is already further along.
  ///
  /// C9 fix: previously this always resolved to `weekNumberForDay(await
  /// getCurrentDay(uid))` with no way to target any other week, so a
  /// farmer who reached Week 4 without ever recording Week 2's weigh-in had
  /// no path to go back and add it — "Record New Weight" could only ever
  /// write today's week. That's the actual mechanism behind the reported
  /// "locked sequence" bug (A11): it wasn't a deliberate lock rejecting
  /// out-of-order entries, it was simply that no code path could ever ask
  /// for a week other than the current one. [forWeekNumber] must be between
  /// 1 and the current week (inclusive) — never a future week, which would
  /// let the farmer record a weigh-in for a week that hasn't happened yet.
  ///
  /// Throws DuplicateWeighInException if an official entry already exists
  /// for that week and allowEditIfDuplicate is false — the caller (Growth
  /// controller) uses this to prompt "edit the existing entry?" instead of
  /// silently overwriting or silently rejecting. Matches saveWeight() in
  /// index.html plus the new duplicate-week + isOfficial rules.
  Future<WeighInResult> addWeighIn({
    required String uid,
    required double weight,
    String notes = '',
    bool allowEditIfDuplicate = false,
    int? forWeekNumber,
  }) async {
    final currentDay = await getCurrentDay(uid);
    final currentWeek = weekNumberForDay(currentDay);
    if (forWeekNumber != null &&
        (forWeekNumber < 1 || forWeekNumber > currentWeek)) {
      throw ArgumentError(
          'forWeekNumber ($forWeekNumber) must be between 1 and the current week ($currentWeek).');
    }
    final weekNumber = forWeekNumber ?? currentWeek;
    // Backfilled entries record the week's first day as their production
    // day (the same day every other unlock/lock calculation in this app
    // already treats as that week's canonical day — see
    // weekNumberForDay()'s doc) since there's no "today" to attach a past
    // week's entry to. A same-week entry keeps using the real currentDay.
    final day =
        forWeekNumber == null ? currentDay : ((forWeekNumber - 1) * 7) + 1;
    final logs = await getWeightLogs(uid);
    if (weekNumber > 1 && !logs.any((e) => e.isOfficial && e.weekNumber == 1)) {
      throw MissingWeek1Exception();
    }
    final dup =
        logs.where((e) => e.isOfficial && e.weekNumber == weekNumber).toList();
    if (dup.isNotEmpty && !allowEditIfDuplicate) {
      throw DuplicateWeighInException(weekNumber, dup.first.day);
    }
    final todayIso = DateTime.now().toIso8601String().split('T').first;
    final entry = WeightLogEntry(
      day: day,
      weight: weight,
      date: todayIso,
      weekNumber: weekNumber,
      notes: notes,
      isOfficial: true,
    );
    final isFirstOfficial = !hasOfficialWeighIn(logs);
    final updated = [...logs];
    if (dup.isNotEmpty) {
      final idx = updated.indexWhere((e) => e.day == dup.first.day);
      updated[idx] = entry;
    } else {
      updated.add(entry);
    }
    await _setWeightLogs(uid, updated);
    await _mirrorWeighInToSupabase(uid, entry);
    return WeighInResult(entry: entry, isFirstOfficial: isFirstOfficial);
  }

  /// Edits an existing official weigh-in in place (identified by production
  /// day) — never creates a new entry. Used from the Weight History
  /// timeline's Edit action.
  Future<void> updateWeighIn(
      {required String uid,
      required int day,
      required double weight,
      String? notes}) async {
    final logs = await getWeightLogs(uid);
    final idx = logs.indexWhere((e) => e.day == day && e.isOfficial);
    if (idx == -1) return;
    final updatedEntry = logs[idx].copyWith(weight: weight, notes: notes);
    final updated = [...logs]..[idx] = updatedEntry;
    await _setWeightLogs(uid, updated);
    await _mirrorWeighInToSupabase(uid, updatedEntry);
  }

  /// Deletes an official weigh-in (identified by production day). The Day-1
  /// baseline entry is never deletable through this path — callers only
  /// ever offer Delete on isOfficial rows in the UI.
  Future<void> deleteWeighIn({required String uid, required int day}) async {
    final logs = await getWeightLogs(uid);
    final updated = logs.where((e) => !(e.day == day && e.isOfficial)).toList();
    await _setWeightLogs(uid, updated);
    try {
      await supabase
          .from('weight_records')
          .delete()
          .eq('sync_key', '$uid:day-$day');
    } catch (_) {}
  }

  /// Bridges Pig Management's per-pig "Edit Starting Weight" action to the
  /// batch-level startWeight that ADG/FCR/ROI actually read
  /// (pigBatchProfile.startWeight) — so editing a pig's starting weight
  /// (only reachable before the Growth lock activates) keeps those
  /// calculations consistent, per the Growth module spec's "starting weight
  /// changes (before the lock)" refresh rule.
  Future<void> updateBatchStartWeight(String uid, double newWeight) async {
    final profile = await getPigBatchProfile(uid);
    if (profile == null) return;
    final updated = profile.copyWith(startWeight: newWeight);
    await _sqlite.setAggregate(
        'settings', uid, 'pigBatchProfile', updated.toJson());
    try {
      await supabase.from('farm_batches').upsert({
        'firebase_uid': uid,
        'starting_weight': newWeight,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid');
    } catch (_) {}
  }

  /// Persists an edited feed price (₱/kg) onto the batch profile — same
  /// read-modify-write-plus-best-effort-mirror shape as
  /// updateBatchStartWeight(). Used by the Feeding Guide's editable "Feed
  /// Price" field; feedPrice itself already existed on PigBatchProfile
  /// (mirrored from index.html's FEED_PRICE setting) but had no Flutter
  /// write path until now.
  Future<void> updateFeedPrice(String uid, double newPrice) async {
    final profile = await getPigBatchProfile(uid);
    if (profile == null) return;
    final updated = profile.copyWith(feedPrice: newPrice);
    await _sqlite.setAggregate(
        'settings', uid, 'pigBatchProfile', updated.toJson());
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'pigBatchProfile',
        'data': updated.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}
  }

  /// Sync engine support — re-pushes every weigh-in unconditionally.
  /// `weight_records` upserts are keyed by (firebase_uid, sync_key), so
  /// resending already-synced entries is harmless, same rationale as
  /// ExpensesRepository.resyncPending().
  Future<void> resyncPendingWeighIns(String uid) async {
    final logs = await getWeightLogs(uid);
    for (final e in logs) {
      await _mirrorWeighInToSupabase(uid, e);
    }
  }

  /// First-login-on-a-new-device support — see ExpensesRepository's
  /// pullFromCloudIfEmpty() for the full rationale. Pulls from the
  /// `settings`/`weightLogs` mirror (a full-fidelity JSON copy of exactly
  /// what _setWeightLogs() already writes there) rather than the
  /// per-row `weight_records` table, which only carries a subset of
  /// fields (no notes/isOfficial) and would lose data on the way back.
  /// Only pulls when the local cache is empty, so an existing device's
  /// own unsynced edits are never overwritten.
  Future<void> pullWeightLogsFromCloudIfEmpty(String uid) async {
    try {
      final local = await getWeightLogs(uid);
      if (local.isNotEmpty) return;
      final res = await supabase
          .from('settings')
          .select('data')
          .eq('firebase_uid', uid)
          .eq('subkey', 'weightLogs')
          .maybeSingle();
      if (res == null) return;
      final entries = parseJsonListSafely(res['data'], WeightLogEntry.fromJson,
              repoName: 'DashboardRepository.pullWeightLogsFromCloudIfEmpty')
          .entries;
      if (entries.isNotEmpty) {
        await _sqlite.setAggregate('growthLogs', uid, 'weightLogs',
            entries.map((e) => e.toJson()).toList(),
            synced: true);
      }
    } catch (_) {
      // Offline or Supabase unreachable — retried on the next bootstrap.
    }
  }

  Future<List<ExpenseEntry>> getExpenses(String uid) async {
    final data = await _sqlite.getAggregate('expenses', uid, subkey: 'main');
    return parseJsonListSafely(data, ExpenseEntry.fromJson,
            repoName: 'DashboardRepository.getExpenses')
        .entries;
  }

  Future<List<FeedLogEntry>> getFeedLogs(String uid) async {
    final data = await _sqlite.getAggregate('feedingLogs', uid, subkey: 'main');
    return parseJsonListSafely(data, FeedLogEntry.fromJson,
            repoName: 'DashboardRepository.getFeedLogs')
        .entries;
  }

  Future<void> _addFeedLogEntry(String uid, FeedLogEntry entry) async {
    final logs = await getFeedLogs(uid);
    logs.add(entry);
    await _sqlite.setAggregate(
        'feedingLogs', uid, 'main', logs.map((e) => e.toJson()).toList());
  }

  /// Today's {taskId: done} map for the currently persisted production day.
  Future<Map<String, bool>> getTasksForDay(String uid, int day) async {
    final logs = await getDayLogs(uid);
    final dayEntry = logs['$day'];
    if (dayEntry == null) return {};
    final tasks = (dayEntry as Map)['tasks'];
    if (tasks == null) return {};
    return Map<String, bool>.from(
        (tasks as Map).map((k, v) => MapEntry(k as String, v == true)));
  }

  /// Toggles one task's done state for today. Caller is responsible for the
  /// lock check (see daily_task.dart's taskLockMessage) — this just persists
  /// the flip, same division of responsibility as toggleCheck()/
  /// showTaskLockedMessage() in index.html.
  Future<void> toggleTask(String uid, int day, String taskId) async {
    final logs = await getDayLogs(uid);
    final dayKey = '$day';
    final dayEntry = Map<String, dynamic>.from((logs[dayKey] as Map?) ?? {});
    final tasks = Map<String, dynamic>.from((dayEntry['tasks'] as Map?) ?? {});
    tasks[taskId] = !(tasks[taskId] == true);
    dayEntry['tasks'] = tasks;
    logs[dayKey] = dayEntry;
    await _setDayLogs(uid, logs);
  }

  /// Force-marks one task done (never toggles it back off) for the given
  /// day — used by HealthRepository right after a health observation is
  /// saved, matching index.html's saveHealth() which does
  /// `logs[day].tasks['health']=true` as a side effect of every save.
  Future<void> setTaskDone(String uid, int day, String taskId) async {
    final logs = await getDayLogs(uid);
    final dayKey = '$day';
    final dayEntry = Map<String, dynamic>.from((logs[dayKey] as Map?) ?? {});
    final tasks = Map<String, dynamic>.from((dayEntry['tasks'] as Map?) ?? {});
    tasks[taskId] = true;
    dayEntry['tasks'] = tasks;
    logs[dayKey] = dayEntry;
    await _setDayLogs(uid, logs);
  }

  /// "Proceed to Next Day" — the actual production-day advance. Marks today
  /// historically complete, auto-records today's feed-given entry (guarded
  /// against double-recording), then moves the persisted counter forward by
  /// exactly one, capped at 120. Mirrors confirmAdvanceDay() in index.html.
  /// Returns the new current day.
  Future<int> advanceDay(String uid) async {
    final day = await getCurrentDay(uid);
    final logs = await getDayLogs(uid);
    final dayKey = '$day';
    final dayEntry = Map<String, dynamic>.from((logs[dayKey] as Map?) ?? {});
    dayEntry['isComplete'] = true;
    logs[dayKey] = dayEntry;
    await _setDayLogs(uid, logs);

    final weightLogs = await getWeightLogs(uid);
    final feedLogs = await getFeedLogs(uid);
    if (weightLogs.isNotEmpty && !feedLogs.any((f) => f.day == day)) {
      final st = stageForWeight(weightLogs.last.weight);
      final todayIso = DateTime.now().toIso8601String().split('T').first;
      await _addFeedLogEntry(
          uid, FeedLogEntry(day: day, date: todayIso, feedKg: st.feedKgPerDay));
    }

    int nextDay = day;
    if (day < kMaxProductionDay) {
      nextDay = day + 1;
      await _sqlite.setAggregate('settings', uid, 'currentDay', nextDay);
    }

    // Best-effort Supabase mirror (settings table: one row per subkey).
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'currentDay',
        'data': nextDay,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}
    try {
      await supabase.from('settings').upsert({
        'firebase_uid': uid,
        'subkey': 'dayLogs',
        'data': logs,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'firebase_uid,subkey');
    } catch (_) {}

    return nextDay;
  }
}
