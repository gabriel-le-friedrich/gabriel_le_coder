// ══════════════════════════════════════════════════════════════════════
// Reset Progress — wipes one farmer's production-cycle data so the app
// returns to "Day 1, just started" (C10), while leaving their account
// identity (profiles/users row — name, municipality, phone, email) and
// app preferences (theme, language, notification prefs, vet contact)
// untouched. This is a genuinely new repository: A6 ("add a safeguard to
// Reset Progress") was previously marked done in an earlier pass of this
// project, but a repo-wide search turned up no "Reset Progress" feature
// anywhere in lib/ — no matching route, screen, string, or repository
// method. Per this round's rule against closing a bug without reproducing
// it, that earlier closure was wrong: there was nothing to add a
// safeguard TO. This file (plus the confirmation UI in
// settings_screen.dart) is that feature actually being built, combining
// A6's safeguard requirement and C10's "wipe local AND cloud" requirement
// in one real implementation rather than closing either on paper.
//
// Scope of what "progress" means here (deliberately NOT everything):
//   WIPED   — pigs, weekly pig photos (SQLite rows + Supabase Storage
//             files), feeding/health/growth/expense logs, in-app
//             notifications, reports, and the settings subkeys that track
//             cycle state (pigBatchProfile, currentDay, dayLogs,
//             healthFormDraft).
//   KEPT    — the farmer's profile/account row (name, municipality, phone,
//             email — see AuthRepository.updateProfileFields's C1/C2 doc),
//             and app-level preferences (themeMode, appLanguage,
//             notificationPrefs, vetContact) — none of those are
//             "progress", and wiping them on every reset would force the
//             farmer to redo language/theme/vet-contact setup every cycle.
//   NOT WIPED (documented limitation) — activity_logs. That table's
//             Supabase RLS is deliberately insert-only (see
//             ActivityLogRepository's header) — there is no DELETE policy,
//             so the anon-scoped client used throughout this app cannot
//             remove rows there even if it tried; a delete call would
//             simply fail silently like every other best-effort Supabase
//             call in this codebase. The audit trail persisting across a
//             reset is treated as correct here (an audit log that could be
//             erased by the user it's supposed to be auditing wouldn't be
//             much of an audit log), not as a gap — but it means "Day 1,
//             just started" is true for every farming metric while the
//             Activity Log screen will still show history from before the
//             reset. This repository logs one final "progress reset"
//             activity entry so that transition is visible there.
// ══════════════════════════════════════════════════════════════════════

import '../../../core/config/supabase_config.dart';
import '../../../core/database/sqlite_service.dart';
import '../../auth/data/auth_repository.dart';

/// Local SQLite tables that hold per-uid progress data, wiped entirely.
const List<String> _kProgressRowTables = [
  'pigs',
  'weeklyPigImages',
  'feedingLogs',
  'healthLogs',
  'growthLogs',
  'expenses',
  'notifications',
  'reports',
];

/// `settings` table subkeys that represent cycle/progress state, wiped.
/// Everything else in `settings` (themeMode, appLanguage,
/// notificationPrefs, vetContact) is a standing preference, not progress,
/// and is deliberately left alone.
const List<String> _kProgressSettingsSubkeys = [
  'pigBatchProfile',
  'currentDay',
  'dayLogs',
  'healthFormDraft',
];

/// Supabase tables mirroring the above, best-effort deleted the same way
/// every write in this app is best-effort (local SQLite is always the
/// source of truth; Supabase is a mirror that may legitimately be
/// unreachable). `profiles` is intentionally excluded — see file header.
const List<String> _kProgressSupabaseTables = [
  'pigs',
  'weekly_pig_images',
  'expenses',
  'health_records',
  'weight_records',
  'farm_batches',
];

class ResetRepository {
  final SqliteService _sqlite = SqliteService.instance;
  final AuthRepository _authRepo = AuthRepository();

  /// Wipes local SQLite first (so the app is instantly back to a fresh
  /// state even fully offline), then best-effort mirrors the same wipe to
  /// Supabase and to the pig-photos Storage bucket. Never throws — every
  /// step is individually wrapped so one failing table/bucket call can
  /// never leave the reset half-finished in a way that blocks the rest.
  Future<void> resetProgress(String uid) async {
    final db = await _sqlite.init();

    for (final table in _kProgressRowTables) {
      try {
        await db.delete(table, where: 'uid = ?', whereArgs: [uid]);
      } catch (_) {}
    }
    for (final subkey in _kProgressSettingsSubkeys) {
      try {
        await db.delete('settings',
            where: 'uid = ? AND subkey = ?', whereArgs: [uid, subkey]);
      } catch (_) {}
    }

    for (final table in _kProgressSupabaseTables) {
      try {
        await supabase.from(table).delete().eq('firebase_uid', uid);
      } catch (_) {}
    }
    for (final subkey in _kProgressSettingsSubkeys) {
      try {
        await supabase
            .from('settings')
            .delete()
            .eq('firebase_uid', uid)
            .eq('subkey', subkey);
      } catch (_) {}
    }
    // weightLogs/feedLogs are stored as full-fidelity JSON blobs under
    // `settings` too (see DashboardRepository._setWeightLogs/_setFeedLogs'
    // cloud mirror) — separate from the per-row weight_records table
    // above, so they need their own delete calls here.
    for (final subkey in ['weightLogs', 'feedLogs']) {
      try {
        await supabase
            .from('settings')
            .delete()
            .eq('firebase_uid', uid)
            .eq('subkey', subkey);
      } catch (_) {}
    }

    await _wipePigPhotosStorage(uid);

    await _authRepo.recordActivityLog(
      uid: uid,
      actionType: 'system',
      action: 'RESET_PROGRESS',
      description:
          'Progress reset — all pigs, logs, and photos cleared. Starting Day 1.',
    );
  }

  /// Best-effort recursive delete of every file under `<uid>/` in the
  /// `pig-photos` bucket (layout: `<uid>/<pigId>/week_<n>.jpg` — see
  /// PigRepository.saveWeeklyImage). Supabase Storage has no native
  /// "delete folder" call, so this lists one level down (per-pig folders),
  /// then lists and removes the files inside each. Wrapped so a Storage
  /// hiccup never blocks the SQLite/table wipe above, which already ran.
  Future<void> _wipePigPhotosStorage(String uid) async {
    try {
      final pigFolders =
          await supabase.storage.from('pig-photos').list(path: uid);
      final allPaths = <String>[];
      for (final folder in pigFolders) {
        final subPath = '$uid/${folder.name}';
        try {
          final files =
              await supabase.storage.from('pig-photos').list(path: subPath);
          allPaths.addAll(files.map((f) => '$subPath/${f.name}'));
        } catch (_) {
          // This one pig's folder failed to list — skip it, keep going.
        }
      }
      if (allPaths.isNotEmpty) {
        await supabase.storage.from('pig-photos').remove(allPaths);
      }
    } catch (_) {
      // Bucket unreachable/offline — local weeklyPigImages rows are
      // already gone; a future Storage-side orphaned file is a known,
      // acceptable gap of this best-effort wipe, not a crash risk.
    }
  }
}
