import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class TextbookViewerScreen extends StatefulWidget {
  final String title;
  final String assetPdfPath;

  const TextbookViewerScreen({
    super.key,
    required this.title,
    required this.assetPdfPath,
  });

  @override
  State<TextbookViewerScreen> createState() => _TextbookViewerScreenState();
}

class _TextbookViewerScreenState extends State<TextbookViewerScreen> {
  String? _localPdfPath;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 0;
  int _totalPages = 0;
  final PdfViewerController _pdfController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _loadPdfFromAssets();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _loadPdfFromAssets() async {
    try {
      final byteData = await rootBundle.load(widget.assetPdfPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.assetPdfPath.split('/').last;
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      if (mounted) setState(() => _localPdfPath = tempFile.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load PDF. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (_localPdfPath == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        SfPdfViewer.file(
          File(_localPdfPath!),
          controller: _pdfController,
          onDocumentLoaded: (details) {
            if (mounted) {
              setState(() {
                _totalPages = details.document.pages.count;
                _isLoading = false;
              });
            }
          },
          onPageChanged: (details) {
            if (mounted) {
              setState(() => _currentPage = details.newPageNumber - 1);
            }
          },
          onDocumentLoadFailed: (details) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Failed to render PDF.';
                _isLoading = false;
              });
            }
          },
        ),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
