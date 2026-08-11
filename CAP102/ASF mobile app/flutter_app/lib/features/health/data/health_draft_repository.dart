// ══════════════════════════════════════════════════════════════════════
// Automatic draft recovery for unfinished Health Monitor assessments —
// Round 3 item 4. Purely local (SQLite aggregate row only, no Supabase
// mirror): a draft is transient in-progress data, not a record worth
// syncing across devices, so it follows the same one-row-per-(uid,subkey)
// pattern as VetContactRepository but skips the network mirror entirely.
// Only ever used for a NEW observation (never while editing an existing
// log — that already has its own saved data to fall back to).
// ══════════════════════════════════════════════════════════════════════

import '../../../core/database/safe_parse.dart';
import '../../../core/database/sqlite_service.dart';

class HealthDraft {
  const HealthDraft({
    this.behavior = 'normal',
    this.appetite = 'normal',
    this.physical = const [],
    this.waste = 'normal',
    this.notes = '',
    this.assessedBy = '',
  });

  final String behavior;
  final String appetite;
  final List<String> physical;
  final String waste;
  final String notes;
  final String assessedBy;

  /// A draft with nothing actually filled in isn't worth restoring/saving.
  bool get isBlank =>
      physical.isEmpty &&
      notes.trim().isEmpty &&
      assessedBy.trim().isEmpty &&
      behavior == 'normal' &&
      appetite == 'normal' &&
      waste == 'normal';

  factory HealthDraft.fromJson(Map<String, dynamic> json) => HealthDraft(
        behavior: (json['behavior'] as String?) ?? 'normal',
        appetite: (json['appetite'] as String?) ?? 'normal',
        physical:
            (json['physical'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        waste: (json['waste'] as String?) ?? 'normal',
        notes: (json['notes'] as String?) ?? '',
        assessedBy: (json['assessedBy'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'behavior': behavior,
        'appetite': appetite,
        'physical': physical,
        'waste': waste,
        'notes': notes,
        'assessedBy': assessedBy,
      };
}

/// Reads and writes the single in-progress Health Monitor draft for a
/// user — local-only, one row per uid (no per-draft history, no Supabase
/// mirror; see file header for why).
class HealthDraftRepository {
  final SqliteService _sqlite = SqliteService.instance;

  /// Health Monitor redesign: Specific Pig / Overall Herd checks each need
  /// their own draft slot, so starting a check for Pig B never clobbers an
  /// unfinished draft for Pig A. [pigId] omitted (null) keeps using the
  /// original single shared subkey — the exact behavior every pre-redesign
  /// (flock-level) caller already depends on.
  String _subkey(String? pigId) =>
      pigId == null || pigId.isEmpty ? 'healthFormDraft' : 'healthFormDraft_$pigId';

  /// Returns the saved draft, or null if there isn't one (or the saved one
  /// turned out to be blank — see [HealthDraft.isBlank]). A corrupted or
  /// unexpectedly-shaped draft row (e.g. a malformed write from an
  /// interrupted save) is treated the same as "no draft" rather than
  /// throwing — a bad draft should never block the farmer from opening a
  /// fresh Health Monitor form. The corrupted row is also cleared so it
  /// doesn't keep failing to parse on every future app open.
  Future<HealthDraft?> getDraft(String uid, {String? pigId}) async {
    final data = await _sqlite.getAggregate('settings', uid,
        subkey: _subkey(pigId));
    if (data == null) return null;
    final draft = parseJsonObjectSafely(data, HealthDraft.fromJson,
        repoName: 'HealthDraftRepository.getDraft');
    if (draft == null) {
      // Corrupted row — clear it so it doesn't keep failing to parse on
      // every future app open.
      await clearDraft(uid, pigId: pigId);
      return null;
    }
    return draft.isBlank ? null : draft;
  }

  /// Overwrites the saved draft with the form's current state. Cheap and
  /// idempotent, safe to call on every field change.
  Future<void> saveDraft(String uid, HealthDraft draft, {String? pigId}) async {
    await _sqlite.setAggregate(
        'settings', uid, _subkey(pigId), draft.toJson());
  }

  /// Clears the saved draft — called after a successful save, or when the
  /// farmer explicitly discards the restore prompt.
  Future<void> clearDraft(String uid, {String? pigId}) async {
    await _sqlite.setAggregate('settings', uid, _subkey(pigId), null);
  }
}
