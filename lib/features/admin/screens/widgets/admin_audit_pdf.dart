import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds the audit-log PDF: a title, when it was made and by whom, then one
/// table row per entry (already in plain language). Only plain text is used,
/// so nothing technical or personal beyond what the log screen shows.
Future<Uint8List> buildAuditLogPdf({
  required List<List<String>> rows,
  required DateTime generatedAt,
  required String generatedBy,
  bool truncated = false,
}) async {
  final doc = pw.Document(title: 'Fine Aid audit log', author: 'Fine Aid');
  final stamp = DateFormat('MMM d, y h:mm a').format(generatedAt);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      header: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Fine Aid - Audit log',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Created $stamp by ${_ascii(generatedBy)}'
              '${truncated ? ' (newest entries only)' : ''}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        if (rows.isEmpty)
          pw.Text('No audit entries.')
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Date & time', 'Details', 'User', 'Action'],
            data: [
              for (final r in rows) [for (final cell in r) _ascii(cell)],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FixedColumnWidth(95),
              1: const pw.FlexColumnWidth(),
              2: const pw.FixedColumnWidth(90),
              3: const pw.FixedColumnWidth(70),
            },
            border: pw.TableBorder(
              horizontalInside: const pw.BorderSide(
                color: PdfColors.grey300,
                width: 0.5,
              ),
            ),
          ),
      ],
    ),
  );
  return doc.save();
}

/// The PDF's built-in fonts cover Latin text only; swap the few typographic
/// characters that appear in the log for plain ones and anything else outside
/// that range for "?", so nothing is silently dropped or fails to draw.
String _ascii(String text) {
  final swapped = text
      .replaceAll(RegExp('[\u2018\u2019]'), "'")
      .replaceAll(RegExp('[\u201C\u201D]'), '"')
      .replaceAll(RegExp('[\u2013\u2014]'), '-')
      .replaceAll('\u2026', '...');
  return swapped.replaceAll(RegExp('[^\u0020-\u007E\u00A0-\u00FF]'), '?');
}
