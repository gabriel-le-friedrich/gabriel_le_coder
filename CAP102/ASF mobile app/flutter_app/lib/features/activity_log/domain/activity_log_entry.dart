/// Read-only model over the `activityLogs` SQLite table (immutable audit
/// trail — every write anywhere in the app calls
/// AuthRepository.recordActivityLog(), never an update/delete).
///
/// [action]/[status] are the structured fields added by the logging
/// system audit's fix #1 (e.g. action='LOGIN', status='FAILED') —
/// nullable because rows written before that migration have neither
/// column populated. [actionType]/[description] are unchanged and still
/// always present, so nothing that already reads this model breaks; code
/// that wants the new structured view should prefer [action]/[status]
/// when non-null and fall back to parsing [description] otherwise.
class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.uid,
    required this.actionType,
    required this.description,
    required this.username,
    required this.createdAt,
    required this.synced,
    this.action,
    this.status,
  });

  final String id;
  final String uid;
  final String actionType;
  final String description;
  final String username;
  final DateTime createdAt;
  final bool synced;
  final String? action;
  final String? status;

  factory ActivityLogEntry.fromRow(Map<String, dynamic> row) {
    return ActivityLogEntry(
      id: row['id'] as String,
      uid: row['uid'] as String,
      actionType: (row['actionType'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      username: (row['username'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
      synced: (row['synced'] as int? ?? 0) == 1,
      action: row['action'] as String?,
      status: row['status'] as String?,
    );
  }
}
