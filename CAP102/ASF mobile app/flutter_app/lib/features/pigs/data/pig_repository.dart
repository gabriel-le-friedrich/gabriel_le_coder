// ══════════════════════════════════════════════════════════════════════
// Pig Management data access — Flutter port of the pig CRUD + weekly-image
// logic in index.html (getPigs/setPigs/savePig/deletePigCascade,
// getPigImages/savePhoto). Local SQLite is the source of truth for
// instant, offline-safe reads; Supabase writes are best-effort (wrapped
// individually, same pattern as OnboardingRepository/DashboardRepository)
// so the pig-photos bucket or a flaky connection never blocks a local save.
// ══════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/database/safe_parse.dart';
import '../../../core/database/sqlite_service.dart';
import '../../../core/services/device_id_service.dart';
import '../domain/pig.dart';
import '../domain/weekly_pig_image.dart';

/// Thrown by [PigRepository.saveWeeklyImage] when the requested week is
/// still locked — the direct enforcement of "one photo unlocks per
/// completed production week," mirroring DashboardRepository's
/// DuplicateWeighInException for weekly weigh-ins. [unlockDay] is the
/// production day the requested week actually becomes available on (Week
/// N unlocks on day ((N-1)*7)+1) — the caller uses it to build the
/// "Week N photo becomes available on Day D" message.
class FutureWeekPhotoException implements Exception {
  FutureWeekPhotoException(this.weekNumber, this.unlockDay);
  final int weekNumber;
  final int unlockDay;
}

class PigRepository {
  final SqliteService _sqlite = SqliteService.instance;

  /// Reads every pig row for [uid], decoding each row's `data` column
  /// independently — a single corrupted or unexpectedly-shaped row (e.g.
  /// an interrupted write) is skipped rather than allowed to fail the
  /// whole Pig List.
  Future<List<Pig>> getPigs(String uid) async {
    final rows = await _sqlite.getRows('pigs', uid);
    final pigs = mapSafely(
      rows,
      (r) =>
          Pig.fromJson(jsonDecode(r['data'] as String) as Map<String, dynamic>),
      repoName: 'PigRepository.getPigs',
    ).entries;
    pigs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return pigs;
  }

  Future<Pig?> getPig(String uid, String pigId) async {
    final pigs = await getPigs(uid);
    for (final p in pigs) {
      if (p.id == pigId) return p;
    }
    return null;
  }

  /// Auto-generated Pig ID — computed fresh from pigs actually saved so far
  /// (highest existing numeric suffix + 1), never from a mutable counter
  /// that increments just by opening the Add Pig form. This is the direct
  /// fix for "Pig ID increases when the form is opened then cancelled":
  /// there is no counter to consume until a real save happens — see
  /// generatePigId()/nextAvailablePigSeq() in index.html for the original.
  Future<String> nextAvailablePigId(String uid, String name) async {
    final pigs = await getPigs(uid);
    int max = 0;
    final suffixRe = RegExp(r'-(\d+)$');
    for (final p in pigs) {
      final m = suffixRe.firstMatch(p.id);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > max) max = n;
      }
    }
    final prefixRaw =
        name.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final prefix = prefixRaw.isEmpty
        ? 'PIG'
        : prefixRaw.substring(0, prefixRaw.length > 6 ? 6 : prefixRaw.length);
    return '$prefix-${(max + 1).toString().padLeft(2, '0')}';
  }

  Future<bool> idInUse(String uid, String id, {String? excludingId}) async {
    final pigs = await getPigs(uid);
    return pigs.any((p) => p.id == id && p.id != excludingId);
  }

  /// Creates a new pig. Callers must have already resolved a fresh id via
  /// [nextAvailablePigId] at the moment of THIS call (not when the form was
  /// opened) — see the file header.
  Future<void> createPig(String uid, Pig pig) async {
    await _sqlite.upsertRow('pigs', {
      'id': pig.id,
      'uid': uid,
      'data': jsonEncode(pig.toJson()),
      'updatedAt': SqliteService.nowMs(),
      'synced': 0,
      'deleted': 0,
    });
    try {
      await supabase.from('pigs').upsert({
        'id': pig.id,
        'firebase_uid': uid,
        'name': pig.name,
        'breed': pig.breed,
        'gender': pig.gender,
        'birth_date': pig.birthDate.isEmpty ? null : pig.birthDate,
        'arrival_date': pig.arrivalDate,
        'initial_weight_kg': pig.initialWeight,
        'current_weight_kg': pig.initialWeight,
        'pen_number': pig.penNumber,
        'notes': pig.notes,
        'photo_url': pig.photoRemoteUrl,
        'status': 'active',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'id');
    } catch (_) {}
  }

  Future<void> updatePig(String uid, Pig pig) async {
    await _sqlite.upsertRow('pigs', {
      'id': pig.id,
      'uid': uid,
      'data': jsonEncode(pig.toJson()),
      'updatedAt': SqliteService.nowMs(),
      'synced': 0,
      'deleted': 0,
    });
    try {
      await supabase.from('pigs').upsert({
        'id': pig.id,
        'firebase_uid': uid,
        'name': pig.name,
        'breed': pig.breed,
        'gender': pig.gender,
        'birth_date': pig.birthDate.isEmpty ? null : pig.birthDate,
        'arrival_date': pig.arrivalDate,
        'initial_weight_kg': pig.initialWeight,
        'pen_number': pig.penNumber,
        'notes': pig.notes,
        'photo_url': pig.photoRemoteUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'id');
    } catch (_) {}
  }

  /// Cascading delete — pig profile + weekly photos all live off pig_id, so
  /// removing the pig record and its child rows is enough. Matches
  /// deletePigCascade() in index.html.
  Future<void> deletePig(String uid, String pigId) async {
    await _sqlite.softDeleteRow('pigs', pigId);
    final images = await getWeeklyImages(uid, pigId);
    for (final img in images) {
      await _sqlite.softDeleteRow('weeklyPigImages', img.id);
    }
    try {
      await supabase
          .from('pigs')
          .delete()
          .eq('id', pigId)
          .eq('firebase_uid', uid);
    } catch (_) {}
  }

  // ── Weekly progress images ──

  Future<List<WeeklyPigImage>> getWeeklyImages(String uid, String pigId) async {
    final rows = await _sqlite.getRows('weeklyPigImages', uid);
    final images = mapSafely(
      rows.where((r) => r['pigId'] == pigId),
      WeeklyPigImage.fromRow,
      repoName: 'PigRepository.getWeeklyImages',
    ).entries;
    images.sort((a, b) => a.weekNumber.compareTo(b.weekNumber));
    return images;
  }

  Future<WeeklyPigImage?> getWeeklyImageForWeek(
      String uid, String pigId, int week) async {
    final images = await getWeeklyImages(uid, pigId);
    for (final img in images) {
      if (img.weekNumber == week) return img;
    }
    return null;
  }

  /// Updates just the free-text `notes` field on an EXISTING weekly image
  /// row (identified by [imageId]) — the Growth History screen's Notes
  /// card writes through here. Deliberately does not create a new row: a
  /// note with no photo has nowhere meaningful to attach in this schema
  /// (see WeeklyPigImage's file header — one row per pig+week, always tied
  /// to a captured photo), so the UI only offers "Add Note" for weeks that
  /// already have an image.
  Future<void> updateWeeklyImageNotes(
      {required String uid,
      required String imageId,
      required String notes}) async {
    final rows = await _sqlite.getRows('weeklyPigImages', uid);
    Map<String, dynamic>? row;
    for (final r in rows) {
      if (r['id'] == imageId) {
        row = r;
        break;
      }
    }
    if (row == null) return;
    final image = WeeklyPigImage.fromRow(row);
    final updated = WeeklyPigImage(
      id: image.id,
      pigId: image.pigId,
      weekNumber: image.weekNumber,
      localUri: image.localUri,
      remoteUrl: image.remoteUrl,
      captureDate: image.captureDate,
      notes: notes,
      updatedAt: SqliteService.nowMs(),
      synced: false,
      uploadAttempts: image.uploadAttempts,
    );
    await _sqlite.upsertRow('weeklyPigImages', updated.toRow(uid));
    try {
      await supabase
          .from('weekly_pig_images')
          .update({'notes': notes})
          .eq('id', imageId)
          .eq('firebase_uid', uid);
    } catch (_) {}
  }

  /// Saves (or replaces) the week's photo locally, then best-effort
  /// uploads to the `pig-photos` Supabase Storage bucket and mirrors the
  /// row into `weekly_pig_images`. Matches savePhoto() in index.html:
  /// local write always happens first and is never blocked by the network.
  Future<WeeklyPigImage> saveWeeklyImage({
    required String uid,
    required String pigId,
    required int weekNumber,
    required String localPath,
    required int currentWeekNumber,
    String notes = '',
    String? replacingId,
  }) async {
    if (weekNumber > currentWeekNumber) {
      throw FutureWeekPhotoException(weekNumber, ((weekNumber - 1) * 7) + 1);
    }
    final id =
        replacingId ?? '${pigId}_w${weekNumber}_${SqliteService.nowMs()}';
    final captureDate = DateTime.now().toIso8601String().split('T').first;
    var image = WeeklyPigImage(
      id: id,
      pigId: pigId,
      weekNumber: weekNumber,
      localUri: localPath,
      captureDate: captureDate,
      notes: notes,
      updatedAt: SqliteService.nowMs(),
      synced: false,
    );
    await _sqlite.upsertRow('weeklyPigImages', image.toRow(uid));

    try {
      final bytes = await File(localPath).readAsBytes();
      final storagePath = '$uid/$pigId/week_$weekNumber.jpg';
      await supabase.storage.from('pig-photos').uploadBinary(
            storagePath,
            bytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final publicUrl =
          supabase.storage.from('pig-photos').getPublicUrl(storagePath);
      image = WeeklyPigImage(
        id: id,
        pigId: pigId,
        weekNumber: weekNumber,
        localUri: localPath,
        remoteUrl: publicUrl,
        captureDate: captureDate,
        notes: notes,
        updatedAt: SqliteService.nowMs(),
        synced: true,
      );
      await _sqlite.upsertRow('weeklyPigImages', image.toRow(uid));
      await supabase.from('weekly_pig_images').upsert({
        'id': id,
        'firebase_uid': uid,
        'pig_id': pigId,
        'week_number': weekNumber,
        'image_url': publicUrl,
        'capture_date': captureDate,
        'notes': notes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
      }, onConflict: 'id');
    } catch (_) {
      // Offline/upload failure — the local row above already has
      // synced:false; SyncEngine.resyncPendingImages() (below) retries it.
    }
    return image;
  }

  // ── Sync engine support — retries writes that failed while offline.
  // Both loops are best-effort per-row: one row failing never stops the
  // rest, and every branch is wrapped so a single bad row can't crash the
  // whole resync pass. ──

  static const int kMaxImageUploadAttempts = 5;

  /// Retries every weekly photo that never made it to Supabase Storage —
  /// this is the concrete fix for the Image Handling audit's biggest
  /// finding: uploads failed offline were never retried, and the
  /// `uploadAttempts` column existed but was always hardcoded to 0.
  Future<void> resyncPendingImages(String uid) async {
    final rows = await _sqlite.getUnsyncedRows('weeklyPigImages', uid);
    // Storage uploads are inherently one-request-per-file (Supabase Storage
    // has no bulk-binary-upload endpoint), so that part of the loop stays
    // per-row. The `weekly_pig_images` table mirror doesn't have that
    // constraint though, so every image whose upload succeeds this pass
    // gets queued into `payload` and pushed in a single batched upsert
    // after the loop, instead of one table request per image — mirrors
    // ActivityLogRepository.pushUnsynced()'s batching pattern. A local row
    // is only ever flipped to synced:true after its table upsert actually
    // succeeds (batch or per-row fallback below), never optimistically.
    final ids = <String>[];
    final payload = <Map<String, dynamic>>[];
    final syncedLocals = <WeeklyPigImage>[];

    for (final row in rows) {
      if (row['deleted'] == 1) continue;
      final image = WeeklyPigImage.fromRow(row);
      if (image.uploadAttempts >= kMaxImageUploadAttempts) continue;
      final localUri = image.localUri;
      if (localUri == null || !await File(localUri).exists()) {
        // Nothing left to (re)upload — bump the counter once so this dead
        // row eventually stops being picked up, without a special "give up"
        // flag of its own.
        await _sqlite.upsertRow(
            'weeklyPigImages',
            image.toRow(uid)
              ..['uploadAttempts'] =
                  image.uploadAttempts + kMaxImageUploadAttempts);
        continue;
      }
      try {
        final bytes = await File(localUri).readAsBytes();
        final storagePath = '$uid/${image.pigId}/week_${image.weekNumber}.jpg';
        await supabase.storage.from('pig-photos').uploadBinary(
              storagePath,
              bytes,
              fileOptions:
                  const FileOptions(upsert: true, contentType: 'image/jpeg'),
            );
        final publicUrl =
            supabase.storage.from('pig-photos').getPublicUrl(storagePath);
        payload.add({
          'id': image.id,
          'firebase_uid': uid,
          'pig_id': image.pigId,
          'week_number': image.weekNumber,
          'image_url': publicUrl,
          'capture_date': image.captureDate,
          'notes': image.notes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
        });
        ids.add(image.id);
        syncedLocals.add(WeeklyPigImage(
          id: image.id,
          pigId: image.pigId,
          weekNumber: image.weekNumber,
          localUri: localUri,
          remoteUrl: publicUrl,
          captureDate: image.captureDate,
          notes: image.notes,
          updatedAt: SqliteService.nowMs(),
          synced: true,
          uploadAttempts: image.uploadAttempts,
        ));
      } catch (_) {
        final retried = WeeklyPigImage(
          id: image.id,
          pigId: image.pigId,
          weekNumber: image.weekNumber,
          localUri: image.localUri,
          remoteUrl: image.remoteUrl,
          captureDate: image.captureDate,
          notes: image.notes,
          updatedAt: image.updatedAt,
          synced: false,
          uploadAttempts: image.uploadAttempts + 1,
        );
        await _sqlite.upsertRow('weeklyPigImages', retried.toRow(uid));
      }
    }

    if (payload.isEmpty) return;

    try {
      await supabase
          .from('weekly_pig_images')
          .upsert(payload, onConflict: 'id');
      for (final local in syncedLocals) {
        await _sqlite.upsertRow('weeklyPigImages', local.toRow(uid));
      }
    } catch (_) {
      // Whole-batch table upsert failed even though the storage uploads
      // already succeeded — fall back to per-row upserts so one bad row
      // can't block every other already-uploaded image from being marked
      // synced (same "one bad row never stops the rest" guarantee this
      // loop has always had).
      for (var i = 0; i < payload.length; i++) {
        try {
          await supabase
              .from('weekly_pig_images')
              .upsert(payload[i], onConflict: 'id');
          await _sqlite.upsertRow(
              'weeklyPigImages', syncedLocals[i].toRow(uid));
        } catch (_) {
          // left synced:false — retried on the next resync pass
        }
      }
    }
  }

  /// Retries every pig profile edit that failed to reach Supabase's `pigs`
  /// table while offline (create/update both write the same shape, so one
  /// upsert covers both).
  Future<void> resyncPendingPigs(String uid) async {
    final rows = await _sqlite.getUnsyncedRows('pigs', uid);
    // Builds every pending pig's payload first, then pushes them all in one
    // batched upsert instead of one request per pig — mirrors
    // ActivityLogRepository.pushUnsynced()'s batching pattern. A row whose
    // JSON can't even be decoded is skipped while building the batch (never
    // aborts the others); if the batched call itself fails (offline/RLS/one
    // bad row rejected by Postgres), falls back to per-row upserts so one
    // bad row still can't stop the rest from syncing — same guarantee this
    // loop always had.
    final ids = <String>[];
    final payload = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row['deleted'] == 1) continue;
      try {
        final pig = Pig.fromJson(
            jsonDecode(row['data'] as String) as Map<String, dynamic>);
        payload.add({
          'id': pig.id,
          'firebase_uid': uid,
          'name': pig.name,
          'breed': pig.breed,
          'gender': pig.gender,
          'birth_date': pig.birthDate.isEmpty ? null : pig.birthDate,
          'arrival_date': pig.arrivalDate,
          'initial_weight_kg': pig.initialWeight,
          'pen_number': pig.penNumber,
          'notes': pig.notes,
          'photo_url': pig.photoRemoteUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          ...DeviceIdService.supabaseSyncFields(SqliteService.nowMs()),
        });
        ids.add(pig.id);
      } catch (_) {
        // malformed local row — skip it, never let it block the rest of the batch
      }
    }
    if (payload.isEmpty) return;

    try {
      await supabase.from('pigs').upsert(payload, onConflict: 'id');
      await _sqlite.markRowsSynced('pigs', ids);
    } catch (_) {
      for (var i = 0; i < payload.length; i++) {
        try {
          await supabase.from('pigs').upsert(payload[i], onConflict: 'id');
          await _sqlite.markRowSynced('pigs', ids[i]);
        } catch (_) {
          // left synced:0 — retried on the next resync pass
        }
      }
    }
  }

  /// First-login-on-a-new-device support. getPigs()/getWeeklyImages() only
  /// ever read local SQLite rows, which start out completely empty on a
  /// fresh install/reinstall — even for an account whose pigs and weekly
  /// photos already exist in the cloud from a different phone. The old
  /// sync engine only ever pushed local->cloud, never pulled cloud->local,
  /// which is exactly why pig data never showed up after switching phones.
  /// Only pulls when the local pig table is empty for this uid, so an
  /// existing device's own not-yet-synced edits are never overwritten.
  Future<void> pullPigsFromCloudIfEmpty(String uid) async {
    try {
      final localPigs = await getPigs(uid);
      if (localPigs.isNotEmpty) return;
      final rows = await supabase.from('pigs').select().eq('firebase_uid', uid);
      if ((rows as List).isEmpty) return;
      for (final map in rows) {
        final pig = Pig(
          id: map['id'] as String,
          name: (map['name'] as String?) ?? '',
          gender: (map['gender'] as String?) ?? 'Male',
          breed: (map['breed'] as String?) ?? '',
          birthDate: (map['birth_date'] as String?) ?? '',
          arrivalDate: (map['arrival_date'] as String?) ?? '',
          initialWeight: (map['initial_weight_kg'] as num?)?.toDouble() ?? 0,
          penNumber: (map['pen_number'] as String?) ?? '',
          notes: (map['notes'] as String?) ?? '',
          photoRemoteUrl: map['photo_url'] as String?,
          createdAt: (map['created_at'] as String?) ??
              DateTime.now().toIso8601String(),
        );
        await _sqlite.upsertRow('pigs', {
          'id': pig.id,
          'uid': uid,
          'data': jsonEncode(pig.toJson()),
          'updatedAt': SqliteService.nowMs(),
          'synced': 1,
          'deleted': 0,
        });
      }
      // Weekly photos ride along with the pigs they belong to — pulling
      // them in the same pass means Growth screens aren't left showing
      // pigs with no photo history on a freshly-restored device.
      final imageRows = await supabase
          .from('weekly_pig_images')
          .select()
          .eq('firebase_uid', uid);
      for (final r in (imageRows as List)) {
        final map = r as Map<String, dynamic>;
        final image = WeeklyPigImage(
          id: map['id'] as String,
          pigId: (map['pig_id'] as String?) ?? '',
          weekNumber: (map['week_number'] as num?)?.toInt() ?? 1,
          remoteUrl: map['image_url'] as String?,
          captureDate: (map['capture_date'] as String?) ?? '',
          notes: (map['notes'] as String?) ?? '',
          updatedAt: SqliteService.nowMs(),
          synced: true,
        );
        await _sqlite.upsertRow('weeklyPigImages', image.toRow(uid));
      }
    } catch (_) {
      // Offline or Supabase unreachable — local (empty) cache stays as-is;
      // this runs again on the next bootstrap/reconnect.
    }
  }

  /// Continuous cross-device sync — the fix for "a weekly photo (or pig
  /// edit) uploaded on Device A never appears on Device B." Unlike
  /// [pullPigsFromCloudIfEmpty] above (which only ever runs once, the very
  /// first time a device's local `pigs` table is completely empty),
  /// this runs on EVERY SyncEngine.syncNow() pass regardless of whether
  /// this device already has pigs — that "if empty" guard was exactly why
  /// a device that already synced at least one pig never saw anything
  /// newer from another device again.
  ///
  /// Conflict-safe merge: a remote row only overwrites the local copy when
  /// (a) the remote `updated_at` is strictly newer than the local row's
  /// `updatedAt`, AND (b) the local row has no pending unsynced edit of its
  /// own (`synced == 1`) — an offline edit in progress on this device is
  /// never clobbered by an older or racing remote write; it wins locally
  /// and gets pushed by resyncPendingPigs/resyncPendingImages in the same
  /// sync pass instead. A locally soft-deleted row (`deleted == 1`) is
  /// never resurrected by a remote row that hasn't caught up to the
  /// deletion yet.
  Future<void> pullRemoteChanges(String uid) async {
    try {
      final remotePigs =
          await supabase.from('pigs').select().eq('firebase_uid', uid);
      final localPigRows =
          await _sqlite.getRows('pigs', uid, includeDeleted: true);
      final localPigsById = {
        for (final r in localPigRows) r['id'] as String: r
      };
      for (final r in (remotePigs as List)) {
        final map = r as Map<String, dynamic>;
        final id = map['id'] as String;
        final local = localPigsById[id];
        if (local != null && local['deleted'] == 1) continue;
        final remoteUpdatedMs =
            _parseSupabaseTimestampMs(map['updated_at'] as String?);
        if (local != null) {
          final localSynced = (local['synced'] as int? ?? 1) == 1;
          final localUpdatedMs = (local['updatedAt'] as num?)?.toInt() ?? 0;
          if (!localSynced ||
              remoteUpdatedMs == null ||
              remoteUpdatedMs <= localUpdatedMs) continue;
        }
        final pig = Pig(
          id: id,
          name: (map['name'] as String?) ?? '',
          gender: (map['gender'] as String?) ?? 'Male',
          breed: (map['breed'] as String?) ?? '',
          birthDate: (map['birth_date'] as String?) ?? '',
          arrivalDate: (map['arrival_date'] as String?) ?? '',
          initialWeight: (map['initial_weight_kg'] as num?)?.toDouble() ?? 0,
          penNumber: (map['pen_number'] as String?) ?? '',
          notes: (map['notes'] as String?) ?? '',
          photoRemoteUrl: map['photo_url'] as String?,
          createdAt: (map['created_at'] as String?) ??
              DateTime.now().toIso8601String(),
        );
        await _sqlite.upsertRow('pigs', {
          'id': pig.id,
          'uid': uid,
          'data': jsonEncode(pig.toJson()),
          'updatedAt': remoteUpdatedMs ?? SqliteService.nowMs(),
          'synced': 1,
          'deleted': 0,
        });
      }

      final remoteImages = await supabase
          .from('weekly_pig_images')
          .select()
          .eq('firebase_uid', uid);
      final localImageRows =
          await _sqlite.getRows('weeklyPigImages', uid, includeDeleted: true);
      final localImagesById = {
        for (final r in localImageRows) r['id'] as String: r
      };
      for (final r in (remoteImages as List)) {
        final map = r as Map<String, dynamic>;
        final id = map['id'] as String;
        final local = localImagesById[id];
        if (local != null && local['deleted'] == 1) continue;
        final remoteUpdatedMs =
            _parseSupabaseTimestampMs(map['updated_at'] as String?);
        if (local != null) {
          final localSynced = (local['synced'] as int? ?? 1) == 1;
          final localUpdatedMs = (local['updatedAt'] as num?)?.toInt() ?? 0;
          if (!localSynced ||
              remoteUpdatedMs == null ||
              remoteUpdatedMs <= localUpdatedMs) continue;
        }
        final image = WeeklyPigImage(
          id: id,
          pigId: (map['pig_id'] as String?) ?? '',
          weekNumber: (map['week_number'] as num?)?.toInt() ?? 1,
          remoteUrl: map['image_url'] as String?,
          captureDate: (map['capture_date'] as String?) ?? '',
          notes: (map['notes'] as String?) ?? '',
          updatedAt: remoteUpdatedMs ?? SqliteService.nowMs(),
          synced: true,
        );
        await _sqlite.upsertRow('weeklyPigImages', image.toRow(uid));
      }
    } catch (_) {
      // Offline/unreachable — retried on the next sync pass.
    }
  }

  int? _parseSupabaseTimestampMs(String? iso) {
    if (iso == null) return null;
    return DateTime.tryParse(iso)?.millisecondsSinceEpoch;
  }
}
