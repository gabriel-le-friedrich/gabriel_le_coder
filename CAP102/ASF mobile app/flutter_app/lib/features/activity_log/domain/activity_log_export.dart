// ══════════════════════════════════════════════════════════════════════
// CSV export for the Activity Log Viewer — same read-only,
// never-touches-stored-data pattern as health_export.dart/expense_export.dart.
// No PDF export here: an audit trail is inherently a long, dense list, and
// CSV is the more useful format for it (spreadsheet filtering/sorting) —
// PDF can be added later if actually requested.
// ══════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'activity_log_entry.dart';

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String buildActivityLogCsv(List<ActivityLogEntry> logs) {
  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  final buffer = StringBuffer('Date,Time,Action Type,Description,Synced\n');
  for (final log in logs) {
    buffer.writeln([
      fmt.format(log.createdAt).split(' ').first,
      fmt.format(log.createdAt).split(' ').last,
      _csvEscape(log.actionType),
      _csvEscape(log.description),
      log.synced ? 'Yes' : 'No',
    ].join(','));
  }
  return buffer.toString();
}

Future<void> shareActivityLogCsv(List<ActivityLogEntry> logs) async {
  final csv = buildActivityLogCsv(logs);
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/asf-activity-log-${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(csv);
  await Share.shareXFiles([XFile(file.path)], text: 'ASF Activity Log export');
}
