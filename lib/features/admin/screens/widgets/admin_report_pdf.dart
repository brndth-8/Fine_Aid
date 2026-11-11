import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a one-table PDF for the Reports & Analytics downloads: a title, when
/// it was made and by whom, then the rows. Plain text only.
///
/// [columnFlex] sets the relative width of each column (equal by default).
Future<Uint8List> buildAdminReportPdf({
  required String title,
  String? subtitle,
  required List<String> headers,
  required List<List<String>> rows,
  required DateTime generatedAt,
  required String generatedBy,
  List<int>? columnFlex,
  String? note,
}) async {
  final doc = pw.Document(title: title, author: 'Fine Aid');
  final stamp = DateFormat('MMM d, y h:mm a').format(generatedAt);
  final widths = <int, pw.TableColumnWidth>{
    for (var i = 0; i < headers.length; i++)
      i: pw.FlexColumnWidth(
        (columnFlex != null && i < columnFlex.length ? columnFlex[i] : 1)
            .toDouble(),
      ),
  };
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
              pdfSafeText('Fine Aid - $title'),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              pw.Text(
                pdfSafeText(subtitle),
                style: const pw.TextStyle(fontSize: 9),
              ),
            pw.Text(
              'Created $stamp by ${pdfSafeText(generatedBy)}'
              '${note == null ? '' : ' - ${pdfSafeText(note)}'}',
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
          pw.Text('Nothing to report for these filters.')
        else
          pw.TableHelper.fromTextArray(
            headers: [for (final h in headers) pdfSafeText(h)],
            data: [
              for (final r in rows) [for (final cell in r) pdfSafeText(cell)],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: widths,
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
/// characters that appear in the data for plain ones and anything else outside
/// that range for "?", so nothing is silently dropped or fails to draw.
String pdfSafeText(String text) {
  final swapped = text
      .replaceAll(RegExp('[‘’]'), "'")
      .replaceAll(RegExp('[“”]'), '"')
      .replaceAll(RegExp('[–—]'), '-')
      .replaceAll('…', '...');
  return swapped.replaceAll(RegExp('[^ -~ -ÿ]'), '?');
}
