// ══════════════════════════════════════════════════════════════════════
// CSV/PDF export for the Health History screen — same read-only,
// never-touches-stored-data approach as expense_export.dart.
// ══════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'health_calculations.dart';
import 'health_status_colors.dart';

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String buildHealthCsv(List<HealthLogEntry> logs) {
  final buffer = StringBuffer(
    'ID,Day,Date,Time,Status,SeverityScore,HealthyCount,MonitorCount,RiskCount,CriticalCount,'
    'Behavior,Appetite,Physical,Waste,Notes,Recommendation,Batch,Pig,AssessedBy\n',
  );
  for (final h in logs) {
    buffer.writeln([
      h.id.toString(),
      h.day.toString(),
      h.date,
      h.time,
      kHealthStatusMeta[h.status]!.label,
      h.severityScore.toString(),
      h.healthyCount.toString(),
      h.monitorCount.toString(),
      h.riskCount.toString(),
      h.criticalCount.toString(),
      _csvEscape(
          findHealthOption(kBehaviorOptions, h.behavior)?.label ?? h.behavior),
      _csvEscape(
          findHealthOption(kAppetiteOptions, h.appetite)?.label ?? h.appetite),
      _csvEscape(h.physicalLabel),
      _csvEscape(findHealthOption(kWasteOptions, h.waste)?.label ?? h.waste),
      _csvEscape(h.notes),
      _csvEscape(h.statusRecommendation.title),
      _csvEscape(h.batchName),
      _csvEscape(h.pigName),
      _csvEscape(h.assessedBy),
    ].join(','));
  }
  return buffer.toString();
}

Future<void> shareHealthCsv(List<HealthLogEntry> logs) async {
  final csv = buildHealthCsv(logs);
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/asf-health-${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(csv);
  await Share.shareXFiles([XFile(file.path)],
      text: 'ASF Health History export');
}

/// Manually-built table (rather than TableHelper.fromTextArray) so the
/// Status column can be colored per-cell with the exact status hex
/// palette (health_status_colors.dart) — the same colors used by the
/// status badge, severity bar, history cards, and Dashboard summaries.
///
/// Landscape + every stored field represented (including SeverityScore,
/// the four tier counts as a compact "H/M/R/C" cell, Batch, Pig, and
/// Recommendation) so this export "exactly matches the stored data" —
/// the CSV and PDF should never silently disagree on what a log contains.
Future<Uint8List> buildHealthPdf(List<HealthLogEntry> logs) async {
  final doc = pw.Document();
  const headers = [
    'Date/Time',
    'Day',
    'Status',
    'Score',
    'H/M/R/C',
    'Behavior',
    'Appetite',
    'Physical',
    'Waste',
    'Notes',
    'Batch',
    'Pig',
    'Assessed By',
    'Recommendation',
  ];
  pw.Widget cell(String text, {pw.TextStyle? style}) => pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(text, style: style ?? const pw.TextStyle(fontSize: 7.5)));

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (context) => [
        pw.Header(level: 0, text: 'ASF — Health History Report'),
        pw.Paragraph(
            text:
                'Generated: ${DateTime.now().toIso8601String().split('T').first}'),
        pw.Paragraph(
          text:
              'H/M/R/C = Healthy / Needs Monitoring / At Risk / Critical severity counts for this assessment.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.3),
            1: pw.FlexColumnWidth(0.5),
            2: pw.FlexColumnWidth(1.0),
            3: pw.FlexColumnWidth(0.6),
            4: pw.FlexColumnWidth(0.9),
            5: pw.FlexColumnWidth(1.1),
            6: pw.FlexColumnWidth(1.1),
            7: pw.FlexColumnWidth(1.7),
            8: pw.FlexColumnWidth(1.0),
            9: pw.FlexColumnWidth(1.7),
            10: pw.FlexColumnWidth(1.0),
            11: pw.FlexColumnWidth(1.0),
            12: pw.FlexColumnWidth(1.0),
            13: pw.FlexColumnWidth(1.7),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: headers
                  .map((h) => cell(h,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 8)))
                  .toList(),
            ),
            for (final h in logs)
              pw.TableRow(
                children: [
                  cell('${h.date} ${h.time}'),
                  cell('${h.day}'),
                  cell(
                    kHealthStatusMeta[h.status]!.label,
                    style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(
                            kHealthStatusColorValue[h.status]!)),
                  ),
                  cell('${h.severityScore}'),
                  cell(
                      '${h.healthyCount}/${h.monitorCount}/${h.riskCount}/${h.criticalCount}'),
                  cell(findHealthOption(kBehaviorOptions, h.behavior)?.label ??
                      h.behavior),
                  cell(findHealthOption(kAppetiteOptions, h.appetite)?.label ??
                      h.appetite),
                  cell(h.physicalLabel),
                  cell(findHealthOption(kWasteOptions, h.waste)?.label ??
                      h.waste),
                  cell(h.notes),
                  cell(h.batchName),
                  cell(h.pigName),
                  cell(h.assessedBy),
                  cell(h.statusRecommendation.title),
                ],
              ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

Future<void> shareHealthPdf(List<HealthLogEntry> logs) async {
  final bytes = await buildHealthPdf(logs);
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/asf-health-${DateTime.now().millisecondsSinceEpoch}.pdf');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)],
      text: 'ASF Health History report');
}
