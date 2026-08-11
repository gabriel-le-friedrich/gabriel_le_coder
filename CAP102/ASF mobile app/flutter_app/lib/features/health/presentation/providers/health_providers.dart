// ══════════════════════════════════════════════════════════════════════
// Riverpod state for Health Monitoring — the observation form (Add/Edit)
// and the read providers the History screen and Dashboard both watch.
// ══════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/data/dashboard_repository.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../email/presentation/providers/email_providers.dart';
import '../../data/health_draft_repository.dart';
import '../../data/health_repository.dart';
import '../../domain/health_calculations.dart';

/// Names an unlocked daily task by its user-facing title, in the exact
/// order the post-save confirmation snackbar lists them — see
/// tasks_screen.dart's _healthGatedTaskIds for the matching task ids.
const List<String> kHealthUnlockedTaskTitles = [
  'Vitality Inspection',
  'Respiratory Check',
  'Temp & Ventilation'
];

/// Provides the singleton [HealthRepository] instance.
final healthRepositoryProvider =
    Provider<HealthRepository>((ref) => HealthRepository());

/// Provides the singleton [HealthDraftRepository] instance.
final healthDraftRepositoryProvider =
    Provider<HealthDraftRepository>((ref) => HealthDraftRepository());

/// All of [uid]'s health observations — watched by the History screen and
/// re-fetched (via invalidation) after every save/delete.
final healthLogsProvider =
    FutureProvider.autoDispose.family<List<HealthLogEntry>, String>((ref, uid) {
  return ref.watch(healthRepositoryProvider).getHealthLogs(uid);
});

/// [uid]'s single most recent health observation — powers the Dashboard's
/// "Today's Health" card and status banner.
final latestHealthLogProvider =
    FutureProvider.autoDispose.family<HealthLogEntry?, String>((ref, uid) {
  return ref.watch(healthRepositoryProvider).getLatestHealthLog(uid);
});

/// Debug-only diagnostic: how many stored health records were skipped as
/// corrupted on the most recent read. The History screen watches this
/// (only in kDebugMode) to show a small "Some invalid health records were
/// ignored." notice — never shown in release builds.
final healthLogsSkippedCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, uid) {
  return ref.watch(healthRepositoryProvider).getSkippedHealthLogCount(uid);
});

/// Checked once when the Add-Observation form opens (never while editing)
/// so the screen can offer "Restore your unfinished health assessment?" —
/// Round 3 item 4.
final healthDraftProvider =
    FutureProvider.autoDispose.family<HealthDraft?, String>((ref, uid) {
  return ref.watch(healthDraftRepositoryProvider).getDraft(uid);
});

/// Pig-scoped variant of [healthDraftProvider], for the Specific Pig /
/// Overall Herd flows — each real pig gets its own draft slot (see
/// HealthDraftRepository's doc).
final healthDraftForPigProvider = FutureProvider.autoDispose
    .family<HealthDraft?, ({String uid, String pigId})>((ref, args) {
  return ref
      .watch(healthDraftRepositoryProvider)
      .getDraft(args.uid, pigId: args.pigId);
});

/// Day-15-style duplicate guard (Round 3 item 6): whether uid already has
/// a health log for [day], and if so, that entry — so the form can offer
/// "Edit Today's Assessment" instead of silently creating a second entry
/// for the same production day.
final healthLogForDayProvider = FutureProvider.autoDispose
    .family<HealthLogEntry?, ({String uid, int day})>((ref, args) async {
  final logs = await ref.watch(healthLogsProvider(args.uid).future);
  for (final e in logs) {
    if (e.day == args.day) return e;
  }
  return null;
});

final _healthDashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) => DashboardRepository());

/// Checked once when a brand-new Add-Observation form opens: today's
/// production day, and whether an assessment already exists for it —
/// combined so the screen only needs to watch one provider to decide
/// whether to show the "already recorded for Day N" duplicate-guard
/// dialog.
final healthDuplicateGuardProvider = FutureProvider.autoDispose
    .family<({int day, HealthLogEntry? existing}), String>((ref, uid) async {
  final day =
      await ref.watch(_healthDashboardRepositoryProvider).getCurrentDay(uid);
  final existing =
      await ref.watch(healthLogForDayProvider((uid: uid, day: day)).future);
  return (day: day, existing: existing);
});

/// Per-pig duplicate guard for the Specific Pig / Overall Herd flows — same
/// "already recorded for Day N" shape as [healthDuplicateGuardProvider],
/// but scoped to one real pig so checking Pig A today never blocks starting
/// a check for Pig B.
final healthDuplicateGuardForPigProvider = FutureProvider.autoDispose
    .family<({int day, HealthLogEntry? existing}), ({String uid, String pigId})>(
        (ref, args) async {
  final day = await ref
      .watch(_healthDashboardRepositoryProvider)
      .getCurrentDay(args.uid);
  final logsForPig = await ref
      .watch(healthRepositoryProvider)
      .getHealthLogsForPig(args.uid, args.pigId);
  HealthLogEntry? existing;
  for (final e in logsForPig) {
    if (e.day == day) {
      existing = e;
      break;
    }
  }
  return (day: day, existing: existing);
});

/// Latest health status per real pig for [uid] — feeds the Health Monitor
/// Home hub's "Today's Overview" and the Herd Health Summary. A pig absent
/// from the returned map has never had a pig-linked check ("Not Yet
/// Checked" — never guessed).
final latestHealthLogPerPigProvider = FutureProvider.autoDispose
    .family<Map<String, HealthLogEntry>, String>((ref, uid) {
  return ref.watch(healthRepositoryProvider).getLatestHealthLogPerPig(uid);
});

/// All observations for one real pig — per-pig History filter / detail.
final healthLogsForPigProvider = FutureProvider.autoDispose
    .family<List<HealthLogEntry>, ({String uid, String pigId})>((ref, args) {
  return ref
      .watch(healthRepositoryProvider)
      .getHealthLogsForPig(args.uid, args.pigId);
});

/// Most recent observation for one real pig, or null if never checked.
final latestHealthLogForPigProvider = FutureProvider.autoDispose
    .family<HealthLogEntry?, ({String uid, String pigId})>((ref, args) {
  return ref
      .watch(healthRepositoryProvider)
      .getLatestHealthLogForPig(args.uid, args.pigId);
});

/// Immutable snapshot of the Add/Edit Health Observation form — every
/// field the farmer can edit, plus derived getters ([liveAssessment] and
/// friends) so the UI never has to call [computeHealthAssessment] itself.
class HealthFormState {
  const HealthFormState({
    this.behavior = 'normal',
    this.appetite = 'normal',
    this.physical = const {},
    this.waste = 'normal',
    this.notes = '',
    this.assessedBy = '',
    this.isSaving = false,
    this.errorMessage,
    this.savedEntry,
  });

  final String behavior;
  final String appetite;

  /// The set of every Physical symptom key currently ticked — Physical
  /// Condition is multiple-select, unlike Behavior/Appetite/Waste.
  final Set<String> physical;
  final String waste;
  final String notes;

  /// Optional free-text override for who performed the assessment — if
  /// left blank, submit() fills it in from the signed-in farmer's saved
  /// profile name at save time.
  final String assessedBy;
  final bool isSaving;
  final String? errorMessage;

  /// Set once, right after a successful save — the screen watches this to
  /// pop itself and, if the resulting status is Critical, show the Critical
  /// Alert dialog. Distinct object identity each save (never reused) so a
  /// ref.listen comparing previous/next always sees a real transition.
  final HealthLogEntry? savedEntry;

  HealthAssessment get liveAssessment => computeHealthAssessment(
      behavior: behavior,
      appetite: appetite,
      physical: physical.toList(),
      waste: waste);
  HealthStatus get liveStatus => liveAssessment.status;
  HealthRecommendation get liveRecommendation =>
      computeStatusRecommendation(liveStatus);
  HealthRecommendation? get liveDigestiveTip =>
      computeDigestiveTip(appetite: appetite, waste: waste);

  /// At least one Physical observation must be ticked before Save is
  /// enabled — an empty selection can't meaningfully contribute to the
  /// health assessment.
  bool get canSave => physical.isNotEmpty;

  HealthFormState copyWith({
    String? behavior,
    String? appetite,
    Set<String>? physical,
    String? waste,
    String? notes,
    String? assessedBy,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    HealthLogEntry? savedEntry,
  }) {
    return HealthFormState(
      behavior: behavior ?? this.behavior,
      appetite: appetite ?? this.appetite,
      physical: physical ?? this.physical,
      waste: waste ?? this.waste,
      notes: notes ?? this.notes,
      assessedBy: assessedBy ?? this.assessedBy,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      savedEntry: savedEntry ?? this.savedEntry,
    );
  }

  factory HealthFormState.fromEntry(HealthLogEntry e) => HealthFormState(
        behavior: e.behavior,
        appetite: e.appetite,
        physical: e.physical.toSet(),
        waste: e.waste,
        notes: e.notes,
        assessedBy: e.assessedBy,
      );
}

/// Owns [HealthFormState] mutations, draft autosave/restore, and the
/// save/submit flow for one Add/Edit Health Observation session. A new
/// instance is created per [healthFormControllerProvider] family key
/// (i.e. per editing target), so state never leaks between an "Add new"
/// session and an "Edit log #N" session.
class HealthFormController extends StateNotifier<HealthFormState> {
  HealthFormController(
      this._repo, this._draftRepo, this._authRepo, this._ref, this._uid,
      {HealthLogEntry? editing, String? pigId, String? pigName, String? sessionId})
      : _editing = editing,
        _pigId = pigId,
        _pigName = pigName,
        _sessionId = sessionId,
        super(editing != null
            ? HealthFormState.fromEntry(editing)
            : const HealthFormState());

  final HealthRepository _repo;
  final HealthDraftRepository _draftRepo;
  final AuthRepository _authRepo;
  final Ref _ref;
  final String _uid;
  final HealthLogEntry? _editing;

  /// When set, this check belongs to one real pig (Specific Pig / Overall
  /// Herd modes) rather than the pre-redesign flock-level form.
  final String? _pigId;
  final String? _pigName;
  final String? _sessionId;

  bool get isEditing => _editing != null;

  /// Persists the in-progress form as a draft — only for a brand-new
  /// observation (an edit already has its own saved row to fall back on).
  /// Fire-and-forget: a failed draft write should never block typing.
  void _autosaveDraft() {
    if (isEditing) return;
    unawaited(_draftRepo.saveDraft(
      _uid,
      HealthDraft(
        behavior: state.behavior,
        appetite: state.appetite,
        physical: state.physical.toList(),
        waste: state.waste,
        notes: state.notes,
        assessedBy: state.assessedBy,
      ),
      pigId: _pigId,
    ));
  }

  /// Applies a recovered draft after the farmer confirms "Restore" in the
  /// "Restore your unfinished health assessment?" prompt.
  void applyDraft(HealthDraft draft) {
    state = state.copyWith(
      behavior: draft.behavior,
      appetite: draft.appetite,
      physical: draft.physical.toSet(),
      waste: draft.waste,
      notes: draft.notes,
      assessedBy: draft.assessedBy,
    );
  }

  /// Discards a stale draft — either the farmer chose "Discard" or a save
  /// just completed successfully.
  void discardDraft() => unawaited(_draftRepo.clearDraft(_uid, pigId: _pigId));

  void updateBehavior(String v) {
    state = state.copyWith(behavior: v);
    _autosaveDraft();
  }

  void updateAppetite(String v) {
    state = state.copyWith(appetite: v);
    _autosaveDraft();
  }

  /// Toggles a single Physical symptom on/off — Physical Condition is
  /// multiple-select, so this adds/removes from the set rather than
  /// replacing a single selected key.
  void togglePhysical(String key) {
    final next = {...state.physical};
    if (!next.remove(key)) next.add(key);
    state = state.copyWith(physical: next);
    _autosaveDraft();
  }

  void updateWaste(String v) {
    state = state.copyWith(waste: v);
    _autosaveDraft();
  }

  void updateNotes(String v) {
    state = state.copyWith(notes: v);
    _autosaveDraft();
  }

  void updateAssessedBy(String v) {
    state = state.copyWith(assessedBy: v);
    _autosaveDraft();
  }

  Future<void> submit() async {
    if (state.isSaving || !state.canSave) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      HealthLogEntry? saved;
      final physicalList = state.physical.toList();
      // If the farmer didn't type an override, default to their own saved
      // profile name — traceability metadata only, never blocks a save.
      var assessedBy = state.assessedBy.trim();
      if (assessedBy.isEmpty) {
        final profile = await _ref.read(userProfileProvider(_uid).future);
        assessedBy = (profile?['fullName'] as String?)?.trim() ?? '';
      }
      if (isEditing) {
        saved = await _repo.updateHealthLog(
          uid: _uid,
          id: _editing!.id,
          behavior: state.behavior,
          appetite: state.appetite,
          physical: physicalList,
          waste: state.waste,
          notes: state.notes,
          assessedBy: assessedBy,
        );
        if (saved != null) {
          await _authRepo.recordActivityLog(
            uid: _uid,
            actionType: 'health',
            description:
                'edited health monitoring log #${saved.id} (${kHealthStatusMeta[saved.status]!.label})',
          );
        }
      } else {
        saved = await _repo.addHealthLog(
          uid: _uid,
          behavior: state.behavior,
          appetite: state.appetite,
          physical: physicalList,
          waste: state.waste,
          notes: state.notes,
          assessedBy: assessedBy,
          pigId: _pigId,
          pigName: _pigName,
          sessionId: _sessionId,
        );
        await _authRepo.recordActivityLog(
          uid: _uid,
          actionType: 'health',
          description:
              'created health monitoring log #${saved.id} (${kHealthStatusMeta[saved.status]!.label})',
        );
      }
      _ref.invalidate(healthLogsProvider(_uid));
      _ref.invalidate(latestHealthLogProvider(_uid));
      _ref.invalidate(dashboardControllerProvider(_uid));
      if (_pigId != null) {
        _ref.invalidate(latestHealthLogPerPigProvider(_uid));
        _ref.invalidate(healthLogsForPigProvider((uid: _uid, pigId: _pigId)));
        _ref.invalidate(
            latestHealthLogForPigProvider((uid: _uid, pigId: _pigId)));
      }
      if (!isEditing) discardDraft();
      if (saved != null && saved.status == HealthStatus.critical) {
        // Brevo admin alert (spec item 6) — fire-and-forget, same
        // never-throws/queues-on-failure guarantee as every other
        // EmailRepository call; a failed/offline send never blocks the
        // health log save the farmer is waiting on.
        unawaited(_ref.read(emailRepositoryProvider).sendAdminNotification(
          _uid,
          title: 'Critical Health Alert',
          message:
              'A pig health assessment was just logged with CRITICAL status and needs urgent review. '
              'Behavior: ${state.behavior} · Appetite: ${state.appetite} · Waste: ${state.waste}.',
          category: 'health_alert',
          meta: {
            'Assessed By': assessedBy.isEmpty ? 'Not specified' : assessedBy,
            'Log ID': saved.id,
            'Physical Symptoms': physicalList.isEmpty
                ? 'None selected'
                : physicalList.join(', '),
          },
        ));
      }
      state = state.copyWith(isSaving: false, savedEntry: saved);
    } catch (_) {
      state = state.copyWith(
          isSaving: false,
          errorMessage:
              'Could not save this health observation. Please try again.');
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

/// Family key for [healthFormControllerProvider]. [pigId]/[pigName]/
/// [sessionId] are only set for the redesigned Specific Pig / Overall Herd
/// flows — a plain `(editing: x, pigId: null, pigName: null, sessionId:
/// null)` is exactly the pre-redesign flock-level form. Records get
/// structural `==`/`hashCode` for free, which is all a Riverpod family key
/// needs.
typedef HealthFormParams = ({
  HealthLogEntry? editing,
  String? pigId,
  String? pigName,
  String? sessionId,
});

final healthFormControllerProvider = StateNotifierProvider.autoDispose
    .family<HealthFormController, HealthFormState, HealthFormParams>(
        (ref, params) {
  return HealthFormController(
    ref.watch(healthRepositoryProvider),
    ref.watch(healthDraftRepositoryProvider),
    ref.watch(authRepositoryProvider),
    ref,
    ref.watch(authRepositoryProvider).currentUser?.uid ?? '',
    editing: params.editing,
    pigId: params.pigId,
    pigName: params.pigName,
    sessionId: params.sessionId,
  );
});

/// Delete is simple enough not to need its own controller class — a plain
/// function provider the History screen calls directly.
final healthDeleteActionProvider =
    Provider<Future<void> Function(String uid, HealthLogEntry entry)>((ref) {
  return (uid, entry) async {
    await ref
        .read(healthRepositoryProvider)
        .deleteHealthLog(uid: uid, id: entry.id);
    await ref.read(authRepositoryProvider).recordActivityLog(
          uid: uid,
          actionType: 'health',
          description:
              'deleted health monitoring log #${entry.id} (${kHealthStatusMeta[entry.status]!.label})',
        );
    ref.invalidate(healthLogsProvider(uid));
    ref.invalidate(latestHealthLogProvider(uid));
    ref.invalidate(dashboardControllerProvider(uid));
  };
});
