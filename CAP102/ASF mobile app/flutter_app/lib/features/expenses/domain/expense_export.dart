// ══════════════════════════════════════════════════════════════════════
// CSV/PDF export for Expenses & ROI. Both builders are pure — they read the
// already-loaded expenses/ROI data and return bytes/text; nothing here ever
// writes back to SQLite or Supabase, matching the spec's "exports must
// never modify stored data."
// ══════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../dashboard/domain/dashboard_calculations.dart';

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Builds a CSV of every expense row — id, category, description, amount,
/// date, notes.
String buildExpensesCsv(List<ExpenseEntry> expenses) {
  final buffer = StringBuffer('ID,Category,Description,Amount,Date,Notes\n');
  for (final e in expenses) {
    buffer.writeln([
      e.id.toString(),
      _csvEscape(e.category),
      _csvEscape(e.description),
      e.amount.toStringAsFixed(2),
      e.date,
      _csvEscape(e.note),
    ].join(','));
  }
  return buffer.toString();
}

Future<void> shareExpensesCsv(List<ExpenseEntry> expenses) async {
  final csv = buildExpensesCsv(expenses);
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/asf-expenses-${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(csv);
  await Share.shareXFiles([XFile(file.path)], text: 'ASF Expenses export');
}

/// Builds a one-page PDF: an Expenses table plus an ROI Summary (Revenue,
/// Expenses, Profit, ROI%) — matches the spec's "Expenses" + "ROI Summary"
/// export scope.
Future<Uint8List> buildExpensesPdf(
    List<ExpenseEntry> expenses, RoiResult roi) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(level: 0, text: 'ASF — Expenses & ROI Report'),
        pw.Paragraph(
            text:
                'Generated: ${DateTime.now().toIso8601String().split('T').first}'),
        pw.SizedBox(height: 12),
        pw.Header(level: 1, text: 'ROI Summary'),
        pw.TableHelper.fromTextArray(
          headers: ['Revenue', 'Expenses', 'Profit', 'ROI %'],
          data: [
            [
              roi.projectedRevenue.toStringAsFixed(2),
              roi.totalInvested.toStringAsFixed(2),
              roi.netProfit.toStringAsFixed(2),
              '${roi.roiPercent.toStringAsFixed(1)}%',
            ],
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Header(level: 1, text: 'Expenses'),
        pw.TableHelper.fromTextArray(
          headers: ['Category', 'Description', 'Amount', 'Date', 'Notes'],
          data: expenses
              .map((e) => [
                    e.category,
                    e.description,
                    e.amount.toStringAsFixed(2),
                    e.date,
                    e.note
                  ])
              .toList(),
        ),
      ],
    ),
  );
  return doc.save();
}

Future<void> shareExpensesPdf(
    List<ExpenseEntry> expenses, RoiResult roi) async {
  final bytes = await buildExpensesPdf(expenses, roi);
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/asf-expenses-roi-${DateTime.now().millisecondsSinceEpoch}.pdf');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)],
      text: 'ASF Expenses & ROI report');
}
