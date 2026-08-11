// ══════════════════════════════════════════════════════════════════════
// ASF — ConsultationRepository: local-first storage + Supabase mirror for
// Expert Consultation requests. Shape mirrors
// ActivityLogRepository (per-row, insert-only, app_entry_id-keyed upsert)
// since consultations are the same kind of append-only, farmer-authored
// record.
//
// Submitting a consultation is ALWAYS safe offline: the row is written to
// SQLite first (synced: 0), and the Supabase push + both emails are best-
// effort side effects that never block or fail the submission itself
// (spec item 11 — "If email fails, the consultation should still be saved
// locally. Sync later.").
// ══════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/database/sqlite_service.dart';
import '../../../core/services/device_id_service.dart';
import '../domain/consultation_entry.dart';

class ConsultationRepository {
  final SqliteService _sqlite = SqliteService.instance;

  /// Uploads the optional photo to the public `consultation-photos` bucket
  /// and returns its public URL, or null if the upload fails (offline,
  /// etc.) — the consultation is still submitted without a photo in that
  /// case rather than blocking the whole request on an image upload.
  Future<String?> uploadConsultationPhoto(String uid, String localPath) async {
    try {
      final bytes = await File(localPath).readAsBytes();
      final storagePath = '$uid/${SqliteService.nowMs()}.jpg';
      await supabase.storage.from('consultation-photos').uploadBinary(
            storagePath,
            bytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      return supabase.storage
          .from('consultation-photos')
          .getPublicUrl(storagePath);
    } catch (_) {
      return null;
    }
  }

  /// Generates a human-friendly reference number, e.g. ASF-20260803-7F3A2C.
  /// Uniqueness is enforced by the id suffix (last 6 chars of a
  /// timestamp+random-based local id) — collisions are effectively
  /// impossible for a single-farm app, and the Supabase table also has a
  /// unique index on reference_number as a backstop.
  static String _generateReferenceNumber(DateTime now, String localId) {
    final datePart =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final suffix = localId.replaceAll('_', '').toUpperCase();
    final shortSuffix = suffix.length >= 6
        ? suffix.substring(suffix.length - 6)
        : suffix.padLeft(6, '0');
    return 'ASF-$datePart-$shortSuffix';
  }

  /// Saves a new consultation request locally (always succeeds unless the
  /// device is completely out of storage) and attempts an immediate
  /// best-effort Supabase push. Returns the created entry (with its
  /// reference number) regardless of network state so the UI can show a
  /// confirmation immediately.
  Future<ConsultationEntry> submitConsultation(
    String uid, {
    required String farmerName,
    required String farmerEmail,
    String? pigBatch,
    double? currentWeight,
    required String issueCategory,
    required String problemDescription,
    String? photoUrl,
  }) async {
    final now = DateTime.now();
    final nowMs = SqliteService.nowMs();
    final localId = '${uid}_${nowMs}_${now.microsecondsSinceEpoch % 1000000}';
    final referenceNumber = _generateReferenceNumber(now, localId);

    final entry = ConsultationEntry(
      id: localId,
      referenceNumber: referenceNumber,
      farmerName: farmerName,
      farmerEmail: farmerEmail,
      pigBatch: pigBatch,
      currentWeight: currentWeight,
      issueCategory: issueCategory,
      problemDescription: problemDescription,
      photoUrl: photoUrl,
      status: 'pending',
      createdAt: now,
    );

    await _sqlite.upsertRow('consultations', {
      'id': localId,
      'uid': uid,
      'data': jsonEncode(entry.toJson()),
      'createdAt': nowMs,
      'synced': 0,
    });

    try {
      await supabase.from('consultations').upsert({
        'firebase_uid': uid,
        'app_entry_id': localId,
        'reference_number': referenceNumber,
        'farmer_name': farmerName,
        'farmer_email': farmerEmail,
        'pig_batch': pigBatch,
        'current_weight': currentWeight,
        'issue_category': issueCategory,
        'problem_description': problemDescription,
        'photo_url': photoUrl,
        'status': 'pending',
        'created_at': now.toUtc().toIso8601String(),
        ...DeviceIdService.supabaseSyncFields(nowMs),
      }, onConflict: 'firebase_uid,app_entry_id');
      await _sqlite.markRowSynced('consultations', localId);
    } catch (_) {
      // left synced:0 — retried by pushUnsynced() on the next sync pass
    }

    return entry;
  }

  Future<List<ConsultationEntry>> getConsultations(String uid) async {
    final rows = await _sqlite.getRows('consultations', uid);
    final entries = rows
        .map((r) {
          try {
            return ConsultationEntry.fromRow(r);
          } catch (_) {
            return null;
          }
        })
        .whereType<ConsultationEntry>()
        .toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  /// Retries pushing every not-yet-synced consultation for [uid]. Called by
  /// SyncEngine.syncNow(). Mirrors ActivityLogRepository.pushUnsynced()'s
  /// batched-upsert-with-per-row-fallback pattern.
  Future<void> pushUnsynced(String uid) async {
    List<Map<String, dynamic>> rows;
    try {
      rows = await _sqlite.getUnsyncedRows('consultations', uid);
    } catch (_) {
      return;
    }
    if (rows.isEmpty) return;

    final ids = <String>[];
    final payload = <Map<String, dynamic>>[];
    for (final row in rows) {
      try {
        final entry = ConsultationEntry.fromRow(row);
        final createdAtMs = row['createdAt'] as int;
        ids.add(entry.id);
        payload.add({
          'firebase_uid': uid,
          'app_entry_id': entry.id,
          'reference_number': entry.referenceNumber,
          'farmer_name': entry.farmerName,
          'farmer_email': entry.farmerEmail,
          'pig_batch': entry.pigBatch,
          'current_weight': entry.currentWeight,
          'issue_category': entry.issueCategory,
          'problem_description': entry.problemDescription,
          'photo_url': entry.photoUrl,
          'status': entry.status,
          'created_at': entry.createdAt.toUtc().toIso8601String(),
          ...DeviceIdService.supabaseSyncFields(createdAtMs),
        });
      } catch (_) {
        // one corrupt row skipped, rest of the batch still proceeds
      }
    }
    if (payload.isEmpty) return;

    try {
      await supabase
          .from('consultations')
          .upsert(payload, onConflict: 'firebase_uid,app_entry_id');
      await _sqlite.markRowsSynced('consultations', ids);
    } catch (_) {
      for (var i = 0; i < payload.length; i++) {
        try {
          await supabase
              .from('consultations')
              .upsert(payload[i], onConflict: 'firebase_uid,app_entry_id');
          await _sqlite.markRowSynced('consultations', ids[i]);
        } catch (_) {
          // left synced:0 — retried on the next resync pass
        }
      }
    }
  }
}
