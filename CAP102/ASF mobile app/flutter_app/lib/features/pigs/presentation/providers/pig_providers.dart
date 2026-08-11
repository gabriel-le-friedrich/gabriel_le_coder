// ══════════════════════════════════════════════════════════════════════
// Riverpod state for Pig Management: the pig list, the add/edit form, and
// per-pig detail (weekly images timeline + the explicit Edit Starting
// Weight action).
// ══════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/image_compression_service.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/data/dashboard_repository.dart';
import '../../../dashboard/domain/dashboard_calculations.dart'
    show hasOfficialWeighIn, weekNumberForDay;
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../data/pig_repository.dart';
import '../../domain/pig.dart';
import '../../domain/weekly_pig_image.dart';

final pigRepositoryProvider = Provider<PigRepository>((ref) => PigRepository());

/// Result of an attempted weekly photo capture — lets the UI show the
/// correct message instead of always assuming a compression/size failure
/// (the previous plain-bool return conflated "week still locked" with
/// "picker cancelled/image too large" into the same false).
class CaptureImageResult {
  const CaptureImageResult.success()
      : lockedUntilDay = null,
        failed = false;
  const CaptureImageResult.failed()
      : lockedUntilDay = null,
        failed = true;
  const CaptureImageResult.locked(int day)
      : lockedUntilDay = day,
        failed = false;

  /// Non-null only when the requested week hasn't unlocked yet — the
  /// production day it becomes available on.
  final int? lockedUntilDay;
  final bool failed;
  bool get success => !failed && lockedUntilDay == null;
}

/// The full pig list for the signed-in user. Invalidate this provider after
/// any create/update/delete to refresh the list screen.
final pigListProvider =
    FutureProvider.autoDispose.family<List<Pig>, String>((ref, uid) {
  return ref.watch(pigRepositoryProvider).getPigs(uid);
});

final pigByIdProvider = FutureProvider.autoDispose
    .family<Pig?, ({String uid, String pigId})>((ref, args) {
  return ref.watch(pigRepositoryProvider).getPig(args.uid, args.pigId);
});

final weeklyImagesProvider = FutureProvider.autoDispose
    .family<List<WeeklyPigImage>, ({String uid, String pigId})>((ref, args) {
  return ref.watch(pigRepositoryProvider).getWeeklyImages(args.uid, args.pigId);
});

/// Every pig's weekly images, keyed by pig id — purely a convenience
/// aggregation over the same getWeeklyImages() calls [weeklyImagesProvider]
/// already makes per-pig, so the Pig Growth Dashboard's summary stat cards
/// (Weeks Recorded, Latest Upload, Completion, Growth Photos) can be
/// computed across the whole pig list without any new persistence or
/// calculation — just fetching the same real records for every pig at once.
final allWeeklyImagesProvider = FutureProvider.autoDispose
    .family<Map<String, List<WeeklyPigImage>>, String>((ref, uid) async {
  final pigs = await ref.watch(pigListProvider(uid).future);
  final repo = ref.watch(pigRepositoryProvider);
  final result = <String, List<WeeklyPigImage>>{};
  for (final pig in pigs) {
    result[pig.id] = await repo.getWeeklyImages(uid, pig.id);
  }
  return result;
});

// ── Add/Edit form ──

class PigFormState {
  const PigFormState({
    this.name = '',
    this.gender = 'Male',
    this.breed = '',
    this.birthDate = '',
    String? arrivalDate,
    this.startingWeight,
    this.penNumber = '',
    this.notes = '',
    this.photoLocalPath,
    this.isSaving = false,
    this.isCompressingPhoto = false,
    this.errorMessage,
    this.saved = false,
  }) : arrivalDate = arrivalDate ?? '';

  final String name;
  final String gender;
  final String breed;
  final String birthDate;
  final String arrivalDate;
  final double? startingWeight;
  final String penNumber;
  final String notes;
  final String? photoLocalPath;
  final bool isSaving;
  // True only while pickPhoto() is compressing the just-picked image — the
  // photo card shows a spinner overlay for this window so a multi-second
  // compression pass on a large photo can't be mistaken for the tap having
  // done nothing (same pattern as _ProfileAvatar's isUploadingAvatar).
  final bool isCompressingPhoto;
  final String? errorMessage;
  final bool saved;

  PigFormState copyWith({
    String? name,
    String? gender,
    String? breed,
    String? birthDate,
    String? arrivalDate,
    double? startingWeight,
    String? penNumber,
    String? notes,
    String? photoLocalPath,
    bool? isSaving,
    bool? isCompressingPhoto,
    String? errorMessage,
    bool clearError = false,
    bool? saved,
  }) {
    return PigFormState(
      name: name ?? this.name,
      gender: gender ?? this.gender,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      startingWeight: startingWeight ?? this.startingWeight,
      penNumber: penNumber ?? this.penNumber,
      notes: notes ?? this.notes,
      photoLocalPath: photoLocalPath ?? this.photoLocalPath,
      isSaving: isSaving ?? this.isSaving,
      isCompressingPhoto: isCompressingPhoto ?? this.isCompressingPhoto,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      saved: saved ?? this.saved,
    );
  }

  factory PigFormState.fromPig(Pig pig) => PigFormState(
        name: pig.name,
        gender: pig.gender,
        breed: pig.breed,
        birthDate: pig.birthDate,
        arrivalDate: pig.arrivalDate,
        startingWeight: pig.initialWeight,
        penNumber: pig.penNumber,
        notes: pig.notes,
        photoLocalPath: pig.photoLocalPath,
      );

  factory PigFormState.blank() => PigFormState(
      arrivalDate: DateTime.now().toIso8601String().split('T').first);
}

class PigFormController extends StateNotifier<PigFormState> {
  PigFormController(this._repo, this._authRepo, this._dashboardRepo, this._uid,
      {Pig? editingPig})
      : _editingPig = editingPig,
        super(editingPig != null
            ? PigFormState.fromPig(editingPig)
            : PigFormState.blank());

  final PigRepository _repo;
  final AuthRepository _authRepo;
  final DashboardRepository _dashboardRepo;
  final String _uid;
  final Pig? _editingPig;

  bool get isEditing => _editingPig != null;

  void updateName(String v) => state = state.copyWith(name: v);
  void updateGender(String v) => state = state.copyWith(gender: v);
  void updateBreed(String v) => state = state.copyWith(breed: v);
  void updateBirthDate(String v) => state = state.copyWith(birthDate: v);
  void updateArrivalDate(String v) => state = state.copyWith(arrivalDate: v);
  void updatePenNumber(String v) => state = state.copyWith(penNumber: v);
  void updateNotes(String v) => state = state.copyWith(notes: v);

  /// Starting Weight is only settable here for a NEW pig — editing an
  /// existing pig's starting weight must go through PigDetailController's
  /// explicit updateStartingWeight() action instead (see file header).
  void updateStartingWeightForNewPig(double? v) {
    if (isEditing) return;
    state = state.copyWith(startingWeight: v);
  }

  Future<void> pickPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
      if (picked == null) return;
      state = state.copyWith(isCompressingPhoto: true, clearError: true);
      final compressedPath = await ImageCompressionService.compressToPath(
        sourcePath: picked.path,
        subfolder: 'pig_profile_photos',
        fileName: '${_uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (compressedPath == null) {
        state = state.copyWith(
            isCompressingPhoto: false,
            errorMessage: 'Image exceeds 3 MB. Please choose another image.');
        return;
      }
      state = state.copyWith(
          isCompressingPhoto: false,
          photoLocalPath: compressedPath,
          clearError: true);
    } catch (_) {
      state = state.copyWith(
          isCompressingPhoto: false,
          errorMessage: 'Could not load that image. Please try another.');
    }
  }

  Future<bool> submit() async {
    final name = state.name.trim();
    final weight = state.startingWeight;
    if (name.isEmpty || weight == null || weight.isNaN) {
      state =
          state.copyWith(errorMessage: 'Please fill in the required fields');
      return false;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      if (isEditing) {
        final updated = _editingPig!.copyWith(
          name: name,
          gender: state.gender,
          breed: state.breed.trim(),
          birthDate: state.birthDate,
          arrivalDate: state.arrivalDate,
          penNumber: state.penNumber.trim(),
          notes: state.notes.trim(),
          photoLocalPath: state.photoLocalPath,
        );
        await _repo.updatePig(_uid, updated);
        await _authRepo.recordActivityLog(
            uid: _uid,
            actionType: 'pig',
            description: 'updated pig ${updated.name} (${updated.id})');
      } else {
        final id = await _repo.nextAvailablePigId(_uid, name);
        final pig = Pig(
          id: id,
          name: name,
          gender: state.gender,
          breed: state.breed.trim(),
          birthDate: state.birthDate,
          arrivalDate: state.arrivalDate,
          initialWeight: weight,
          penNumber: state.penNumber.trim(),
          notes: state.notes.trim(),
          photoLocalPath: state.photoLocalPath,
          createdAt: DateTime.now().toIso8601String(),
        );
        await _repo.createPig(_uid, pig);
        await _authRepo.recordActivityLog(
            uid: _uid,
            actionType: 'pig',
            description: 'added pig ${pig.name} (${pig.id})');

        // ROOT-CAUSE FIX: the Starting Weight entered here was previously
        // only ever written to the pigs table's static initial_weight_kg
        // field — it never became a row in the weightLogs table that the
        // Growth/Weight screen and the "this week's weight has not been
        // recorded" gate actually read from (DashboardRepository.
        // getWeightLogs/addWeighIn). Before onboarding was removed (pigs
        // used to only be created via a "Set Up Your Pig" wizard), that
        // wizard seeded this Day-1 entry itself; when pig creation moved
        // to this Add Pig form, that seeding step was never carried over,
        // so a brand-new account's Growth/Weight screen showed nothing
        // until the user manually logged a separate weigh-in later.
        // Weigh-ins are recorded at the BATCH level (one shared weightLogs
        // list per account, not per pig — see addWeighIn's doc comment),
        // so this should only ever seed once: the very first time an
        // account has a pig and no official weigh-in yet. Every later
        // pig added to an already-started batch must NOT re-seed (the
        // batch's weekly cadence is already running).
        try {
          final hasAnyOfficialWeighIn =
              hasOfficialWeighIn(await _dashboardRepo.getWeightLogs(_uid));
          if (!hasAnyOfficialWeighIn) {
            await _dashboardRepo.addWeighIn(
              uid: _uid,
              weight: weight,
              notes: 'Starting weight recorded when ${pig.name} was added.',
            );
          }
        } catch (_) {
          // Never let this best-effort seed block pig creation from
          // succeeding — addWeighIn's own duplicate guard, or any
          // transient sync hiccup, should not surface as a failed Add Pig.
        }
      }
      state = state.copyWith(isSaving: false, saved: true);
      return true;
    } catch (e) {
      state = state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to save pig. Please try again.');
      return false;
    }
  }
}

final pigFormControllerProvider = StateNotifierProvider.autoDispose
    .family<PigFormController, PigFormState, Pig?>((ref, editingPig) {
  return PigFormController(
    ref.watch(pigRepositoryProvider),
    ref.watch(authRepositoryProvider),
    ref.watch(dashboardRepositoryProvider),
    ref.watch(authRepositoryProvider).currentUser?.uid ?? '',
    editingPig: editingPig,
  );
});

// ── Pig detail: weekly images + starting weight edit ──

class PigDetailController extends StateNotifier<AsyncValue<Pig?>> {
  PigDetailController(this._repo, this._authRepo, this._dashboardRepo,
      this._ref, this._uid, this._pigId)
      : super(const AsyncValue.loading()) {
    load();
  }

  final PigRepository _repo;
  final AuthRepository _authRepo;
  final DashboardRepository _dashboardRepo;
  final Ref _ref;
  final String _uid;
  final String _pigId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repo.getPig(_uid, _pigId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// The explicit "Edit Starting Weight" action. Only touches the pig's
  /// initialWeight field — historical weightLogs are untouched, so
  /// ADG/FCR/Growth charts/ROI (all pure functions of startWeight +
  /// weightLogs, recomputed fresh on every read) update automatically the
  /// next time the Dashboard/Growth screens load. Matches the spec's
  /// "Recalculate ADG/FCR/Growth/ROI, preserve historical weight records."
  ///
  /// Re-checks the lock here too (not just in the UI) — once a real weekly
  /// weigh-in exists, Starting Weight can never be edited again, matching
  /// the Growth module's "Starting Weight Lock" rule.
  Future<bool> updateStartingWeight(double newWeight) async {
    final pig = state.valueOrNull;
    if (pig == null) return false;
    final locked = hasOfficialWeighIn(await _dashboardRepo.getWeightLogs(_uid));
    if (locked) return false;
    try {
      final updated = pig.copyWith(initialWeight: newWeight);
      await _repo.updatePig(_uid, updated);
      // Bridges to the batch-level startWeight that ADG/FCR/ROI actually
      // read — see DashboardRepository.updateBatchStartWeight's doc.
      await _dashboardRepo.updateBatchStartWeight(_uid, newWeight);
      await _authRepo.recordActivityLog(
        uid: _uid,
        actionType: 'pig',
        description:
            'updated starting weight for ${pig.name} (${pig.id}) to $newWeight kg',
      );
      state = AsyncValue.data(updated);
      _ref.invalidate(dashboardControllerProvider(_uid));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CaptureImageResult> captureWeeklyImage(
      {required int weekNumber,
      required ImageSource source,
      String? replacingId}) async {
    try {
      // Checked BEFORE ever opening the camera/gallery picker, so a locked
      // week fails fast with a clear message instead of making the farmer
      // pick/compress a photo that then gets rejected.
      final currentDay = await _dashboardRepo.getCurrentDay(_uid);
      final currentWeek = weekNumberForDay(currentDay);
      if (weekNumber > currentWeek) {
        return CaptureImageResult.locked(((weekNumber - 1) * 7) + 1);
      }
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1280, maxHeight: 1280);
      if (picked == null) return const CaptureImageResult.failed();
      final compressedPath = await ImageCompressionService.compressToPath(
        sourcePath: picked.path,
        subfolder: 'weekly_pig_images',
        fileName:
            '${_pigId}_w${weekNumber}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (compressedPath == null) return const CaptureImageResult.failed();
      await _repo.saveWeeklyImage(
        uid: _uid,
        pigId: _pigId,
        weekNumber: weekNumber,
        localPath: compressedPath,
        currentWeekNumber: currentWeek,
        replacingId: replacingId,
      );
      await _authRepo.recordActivityLog(
        uid: _uid,
        actionType: 'pig',
        description:
            '${replacingId != null ? 'replaced' : 'uploaded'} weekly pig image (week $weekNumber) for $_pigId',
      );
      return const CaptureImageResult.success();
    } on FutureWeekPhotoException catch (e) {
      // Defense-in-depth path (repository re-checks the same rule) — same
      // message as the early check above.
      return CaptureImageResult.locked(e.unlockDay);
    } catch (_) {
      return const CaptureImageResult.failed();
    }
  }

  /// Growth History's Notes card — attaches a note to an existing weekly
  /// image row (a note can't exist without a photo in this schema, see
  /// PigRepository.updateWeeklyImageNotes's doc, so this is only offered
  /// for weeks that already have one).
  Future<bool> saveWeeklyImageNotes(
      {required String imageId, required String notes}) async {
    try {
      await _repo.updateWeeklyImageNotes(
          uid: _uid, imageId: imageId, notes: notes);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final pigDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<PigDetailController, AsyncValue<Pig?>, String>((ref, pigId) {
  return PigDetailController(
    ref.watch(pigRepositoryProvider),
    ref.watch(authRepositoryProvider),
    ref.watch(dashboardRepositoryProvider),
    ref,
    ref.watch(authRepositoryProvider).currentUser?.uid ?? '',
    pigId,
  );
});
