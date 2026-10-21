import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../i18n/textbook_strings.dart';
import '../../../services/firebase/textbook_service.dart';

class TextbookViewerScreen extends StatefulWidget {
  final String title;

  /// Where the PDF is in Firebase Storage, eg `textbooks/Some Book.pdf`.
  final String storagePath;

  const TextbookViewerScreen({
    super.key,
    required this.title,
    required this.storagePath,
  });

  @override
  State<TextbookViewerScreen> createState() => _TextbookViewerScreenState();
}

class _TextbookViewerScreenState extends State<TextbookViewerScreen> {
  String? _localPdfPath;
  // Download progress (0..1) while the book is being fetched.
  final ValueNotifier<double?> _progress = ValueNotifier(null);
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 0;
  int _totalPages = 0;
  final PdfViewerController _pdfController = PdfViewerController();

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  PdfTextSearchResult? _searchResult;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _searchResult?.removeListener(_onSearchResultChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pdfController.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _localPdfPath = null;
    });
    _progress.value = null;
    try {
      // Downloaded from Firebase the first time, then served from the copy
      // kept on the phone.
      final file = await TextbookService.instance.getFile(
        widget.storagePath,
        onProgress: (p) {
          if (mounted) _progress.value = p;
        },
      );
      if (mounted) setState(() => _localPdfPath = file.path);
    } on TextbookOfflineException {
      if (mounted) {
        setState(() {
          _errorMessage = TextbookStrings.of(context).needsInternet;
          _isLoading = false;
        });
      }
    } on TextbookNotFoundException {
      if (mounted) {
        setState(() {
          _errorMessage = TextbookStrings.of(context).notAvailable;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = TextbookStrings.of(context).couldNotLoad;
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchResultChanged() {
    if (mounted) setState(() {});
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _runSearch(String query) {
    if (query.trim().isEmpty) return;
    _searchResult?.removeListener(_onSearchResultChanged);
    final result = _pdfController.searchText(query.trim());
    result.addListener(_onSearchResultChanged);
    setState(() => _searchResult = result);
  }

  void _closeSearch() {
    _searchResult?.removeListener(_onSearchResultChanged);
    _searchResult?.clear();
    setState(() {
      _isSearching = false;
      _searchResult = null;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: const TextStyle(fontSize: 15, color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Find in this book...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
              )
            : Text(
                widget.title,
                style: theme.textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (_isSearching) ..._buildSearchActions() else _buildSearchButton(),
          if (!_isSearching && _totalPages > 0)
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
      body: Column(
        children: [
          if (_isSearching) _buildSearchStatusBar(theme),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchButton() {
    return IconButton(
      icon: const Icon(Icons.search),
      tooltip: 'Find in this book',
      onPressed: _localPdfPath == null ? null : _startSearch,
    );
  }

  List<Widget> _buildSearchActions() {
    final result = _searchResult;
    final hasMatches = result != null && result.totalInstanceCount > 0;
    return [
      IconButton(
        icon: const Icon(Icons.keyboard_arrow_up),
        tooltip: 'Previous match',
        onPressed: hasMatches ? () => result.previousInstance() : null,
      ),
      IconButton(
        icon: const Icon(Icons.keyboard_arrow_down),
        tooltip: 'Next match',
        onPressed: hasMatches ? () => result.nextInstance() : null,
      ),
      IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Close search',
        onPressed: _closeSearch,
      ),
    ];
  }

  Widget _buildSearchStatusBar(ThemeData theme) {
    final result = _searchResult;
    String? statusText;
    if (result != null) {
      if (result.isSearchCompleted && result.totalInstanceCount == 0) {
        statusText = 'No results found.';
      } else if (result.totalInstanceCount > 0) {
        final current = result.currentInstanceIndex == 0
            ? 1
            : result.currentInstanceIndex;
        statusText = '$current of ${result.totalInstanceCount} matches';
      } else {
        statusText = 'Searching...';
      }
    }

    if (statusText == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(statusText, style: theme.textTheme.bodySmall),
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPdf,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_localPdfPath == null) {
      return Center(
        child: ValueListenableBuilder<double?>(
          valueListenable: _progress,
          builder: (context, progress, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: progress),
              if (progress != null) ...[
                const SizedBox(height: 12),
                Text(
                  TextbookStrings.of(
                    context,
                  ).downloading((progress * 100).clamp(0, 100).round()),
                ),
              ],
            ],
          ),
        ),
      );
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
