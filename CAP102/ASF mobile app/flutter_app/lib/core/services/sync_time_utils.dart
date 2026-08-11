// ══════════════════════════════════════════════════════════════════════
// Centralized epoch-ms -> ISO-8601 UTC conversion for Supabase writes.
//
// Local SQLite storage deliberately keeps its existing epoch-millisecond
// INTEGER columns (createdAt/updatedAt/etc.) — changing that format would
// touch every repository's read/write path and every existing on-device
// row for no functional benefit, since epoch-ms is already unambiguous
// and sorts/compares correctly. What was inconsistent before this file
// existed is that each repository that pushes to Supabase re-wrote its
// own inline `DateTime.fromMillisecondsSinceEpoch(ms).toUtc()
// .toIso8601String()` conversion. This is that one canonical
// implementation — Supabase's timestamptz columns always receive a
// consistent, unambiguous UTC ISO-8601 string, no matter which repository
// is writing.
// ══════════════════════════════════════════════════════════════════════
class SyncTimeUtils {
  SyncTimeUtils._();

  /// Converts a local epoch-millisecond timestamp (as stored in every
  /// SQLite table's createdAt/updatedAt column) into the UTC ISO-8601
  /// string Supabase's timestamptz columns expect.
  static String toIsoUtc(int epochMs) {
    return DateTime.fromMillisecondsSinceEpoch(epochMs)
        .toUtc()
        .toIso8601String();
  }
}
