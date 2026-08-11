import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ExportService {
  Future<void> exportEntryAsPdf({
    required String title,
    required String description,
    required String classification,
    required DateTime createdAt,
    required int monitoredDays,
    bool referredForConsultation = false,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Fine Aid — Health Journal Export',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated on ${DateFormat('MMMM d, yyyy – h:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Divider(height: 24),
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                DateFormat('EEEE, MMMM d, yyyy').format(createdAt),
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
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
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                description.isEmpty ? '(No description provided)' : description,
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
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
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
