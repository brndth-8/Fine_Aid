import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ExportService {
  /// Builds the log's PDF (no sharing), so the layout can be tested.
  Future<Uint8List> buildEntryPdf({
    required String title,
    required String description,
    required String classification,
    required DateTime createdAt,
    required int monitoredDays,
    bool referredForConsultation = false,
    // The Evaluation text as shown in the app (null/blank = none).
    String? evaluation,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      // MultiPage (not Page) so long text flows onto a second page instead of
      // overflowing the first.
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Text(
              'Fine Aid - Health Journal Export',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated on ${DateFormat('MMMM d, yyyy - h:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Divider(height: 24),
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              DateFormat('EEEE, MMMM d, yyyy').format(createdAt),
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 16),
            _fieldRow('Classification:', classification),
            pw.SizedBox(height: 8),
            _fieldRow(
              'Monitored:',
              '$monitoredDays Day${monitoredDays == 1 ? '' : 's'}',
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Description',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            // Paragraph (unlike Text) wraps AND can continue on the next page.
            pw.Paragraph(
              text: _pdfSafe(
                description.isEmpty ? '(No description provided)' : description,
              ),
              margin: pw.EdgeInsets.zero,
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Evaluation',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Paragraph(
              text: _pdfSafe(
                (evaluation == null || evaluation.trim().isEmpty)
                    ? '(No evaluation available)'
                    : evaluation.trim(),
              ),
              margin: pw.EdgeInsets.zero,
            ),
            if (referredForConsultation) ...[
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.red700),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Recommendation: Seek Medical Consultation',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'This entry was flagged because recovery had not progressed '
                      'as expected for the standard healing timeframe. A closer '
                      'look by a medical professional is advised to prevent '
                      'complications.',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.Text(
              'This export is for informational purposes only and is not a '
              'substitute for professional medical advice.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  Future<void> exportEntryAsPdf({
    required String title,
    required String description,
    required String classification,
    required DateTime createdAt,
    required int monitoredDays,
    bool referredForConsultation = false,
    String? evaluation,
  }) async {
    final bytes = await buildEntryPdf(
      title: title,
      description: description,
      classification: classification,
      createdAt: createdAt,
      monitoredDays: monitoredDays,
      referredForConsultation: referredForConsultation,
      evaluation: evaluation,
    );
    final dir = await getTemporaryDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final file = File(
      '${dir.path}/fine_aid_${safeTitle.isEmpty ? 'entry' : safeTitle}.pdf',
    );
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Fine Aid Health Journal entry: $title',
      ),
    );
  }

  /// The PDF's built-in font has no em/en dash (it drops them), so use a
  /// plain hyphen for those.
  static String _pdfSafe(String text) =>
      text.replaceAll('\u2014', ' - ').replaceAll('\u2013', '-');

  pw.Widget _fieldRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(width: 6),
        pw.Text(value),
      ],
    );
  }
}
