import 'dart:io';

/// One row per (pig, week) weekly progress photo — matches the
/// `weeklyPigImages` SQLite table (see SqliteService) and Supabase's
/// `weekly_pig_images` table 1:1.
class WeeklyPigImage {
  const WeeklyPigImage({
    required this.id,
    required this.pigId,
    required this.weekNumber,
    this.localUri,
    this.remoteUrl,
    required this.captureDate,
    this.notes = '',
    required this.updatedAt,
    this.synced = false,
    this.uploadAttempts = 0,
  });

  final String id;
  final String pigId;
  final int weekNumber;
  final String? localUri;
  final String? remoteUrl;
  final String captureDate; // yyyy-MM-dd
  final String notes;
  final int updatedAt; // epoch ms
  final bool synced;
  // Incremented by SyncEngine.resyncPendingImages() each time a retry of an
  // offline-failed upload is attempted — capped there so a permanently
  // broken row (e.g. its local file was later deleted) doesn't get retried
  // forever. Was previously written but never read anywhere (dead column) —
  // see the Offline Sync / Image Handling audit this was built to fix.
  final int uploadAttempts;

  String? get displayPath {
    if (localUri != null && localUri!.isNotEmpty) {
      if (localUri!.startsWith('http')) return localUri;
      try {
        final file = File(localUri!);
        if (file.existsSync()) return localUri;
      } catch (_) {}
    }
    return remoteUrl;
  }

  Map<String, dynamic> toRow(String uid) => {
        'id': id,
        'uid': uid,
        'pigId': pigId,
        'weekNumber': weekNumber,
        'localUri': localUri,
        'remoteUrl': remoteUrl,
        'captureDate': captureDate,
        'notes': notes,
        'updatedAt': updatedAt,
        'synced': synced ? 1 : 0,
        'uploadAttempts': uploadAttempts,
        'deleted': 0,
      };

  factory WeeklyPigImage.fromRow(Map<String, dynamic> row) => WeeklyPigImage(
        id: row['id'] as String,
        pigId: (row['pigId'] as String?) ?? '',
        weekNumber: (row['weekNumber'] as num?)?.toInt() ?? 1,
        localUri: row['localUri'] as String?,
        remoteUrl: row['remoteUrl'] as String?,
        captureDate: (row['captureDate'] as String?) ?? '',
        notes: (row['notes'] as String?) ?? '',
        updatedAt: (row['updatedAt'] as num?)?.toInt() ?? 0,
        synced: row['synced'] == 1,
        uploadAttempts: (row['uploadAttempts'] as num?)?.toInt() ?? 0,
      );
}
