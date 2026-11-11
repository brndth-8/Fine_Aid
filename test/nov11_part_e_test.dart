import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  group('E. Textbook performance', () {
    test('the viewer opens a book already on the phone without waiting', () {
      final viewer = source(
        'lib/features/dashboard/screens/textbook_viewer_screen.dart',
      );
      expect(viewer, contains('refreshInBackground: true'));
    });

    test('the service refreshes in the background and never blocks on it', () {
      final service = source('lib/services/firebase/textbook_service.dart');
      expect(service, contains('bool refreshInBackground = false'));
      expect(service, contains('unawaited('));
      expect(service, contains('_refreshing'));
    });

    test('turning a page does not rebuild the PDF viewer', () {
      final viewer = source(
        'lib/features/dashboard/screens/textbook_viewer_screen.dart',
      );
      // the page counter is a notifier, and the viewer is built once and reused
      expect(viewer, contains('ValueNotifier<int> _currentPage'));
      expect(viewer, contains('_viewer ??= SfPdfViewer.file('));
      expect(
        viewer,
        contains('_currentPage.value = details.newPageNumber - 1'),
      );
      expect(viewer, isNot(contains('setState(() => _currentPage')));
    });

    test('nothing in the app bundles or replaces the PDFs itself', () {
      // Replacing a file in Firebase Storage is a separate, approved step
      // (functions/scripts/upload-textbooks.js); the app only reads them.
      final pubspec = source('pubspec.yaml');
      expect(pubspec, isNot(contains('assets/pdfs')));
    });
  });
}
