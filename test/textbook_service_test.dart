import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fine_aid/i18n/textbook_strings.dart';
import 'package:fine_aid/services/firebase/textbook_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A pretend Firebase: a list of documents and files with known contents.
class _FakeRemote implements TextbookRemote {
  List<(String, Map<String, dynamic>)> docs = [];
  final Map<String, List<int>> files = {};
  final Map<String, int> updated = {};
  bool offline = false;
  bool dropDownload = false; // cut the connection half-way
  Completer<void>? infoGate; // holds info() until it is completed
  int downloads = 0;
  int infoCalls = 0;
  final List<double> progress = [];

  @override
  Future<List<(String, Map<String, dynamic>)>> listDocuments() async {
    if (offline) throw const SocketException('offline');
    return docs;
  }

  @override
  Future<RemoteFileInfo> info(String storagePath) async {
    infoCalls++;
    if (infoGate != null) await infoGate!.future;
    if (offline) throw const SocketException('offline');
    final bytes = files[storagePath];
    if (bytes == null) throw TextbookNotFoundException();
    return RemoteFileInfo(bytes.length, updated[storagePath] ?? 1);
  }

  @override
  Future<void> download(
    String storagePath,
    File to,
    void Function(double progress) onProgress,
  ) async {
    downloads++;
    final bytes = files[storagePath]!;
    if (dropDownload) {
      await to.writeAsBytes(bytes.sublist(0, bytes.length ~/ 2));
      throw const SocketException('connection lost');
    }
    onProgress(0.5);
    onProgress(1);
    await to.writeAsBytes(bytes);
  }
}

void main() {
  late Directory tmp;
  late _FakeRemote remote;
  late TextbookService service;
  const path = 'textbooks/Some Book.pdf';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('textbooks_test');
    remote = _FakeRemote()
      ..files[path] = utf8.encode('%PDF-1.4 pretend book contents')
      ..updated[path] = 100;
    service = TextbookService(
      remote: remote,
      cacheDirectory: () async => Directory('${tmp.path}/cache'),
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('the list', () {
    test('is read from the documents and put in order', () async {
      remote.docs = [
        (
          'b',
          {
            'title': 'Second',
            'fileName': 'b.pdf',
            'storagePath': 'textbooks/b.pdf',
            'sortOrder': 2,
          },
        ),
        (
          'a',
          {
            'title': 'First',
            'fileName': 'a.pdf',
            'storagePath': 'textbooks/a.pdf',
            'sortOrder': 1,
            'subject': 'First Aid',
            'fileSize': 1234,
          },
        ),
        (
          'c',
          {
            'title': 'Also second',
            'fileName': 'c.pdf',
            'storagePath': 'textbooks/c.pdf',
            'sortOrder': 2,
          },
        ),
      ];
      final books = await service.fetchList();
      expect(books.map((b) => b.title), ['First', 'Also second', 'Second']);
      expect(books.first.subject, 'First Aid');
      expect(books.first.fileSize, 1234);
      expect(books.first.storagePath, 'textbooks/a.pdf');
    });

    test('a document missing what is needed to open it is skipped', () async {
      remote.docs = [
        (
          'ok',
          {
            'title': 'Good',
            'fileName': 'g.pdf',
            'storagePath': 'textbooks/g.pdf',
          },
        ),
        ('no-title', {'fileName': 'x.pdf', 'storagePath': 'textbooks/x.pdf'}),
        ('no-path', {'title': 'Lost', 'fileName': 'y.pdf'}),
      ];
      final books = await service.fetchList();
      expect(books.map((b) => b.id), ['ok']);
    });

    test('a book with no sortOrder goes last', () async {
      remote.docs = [
        (
          'x',
          {
            'title': 'No order',
            'fileName': 'x.pdf',
            'storagePath': 'textbooks/x.pdf',
          },
        ),
        (
          'y',
          {
            'title': 'Ordered',
            'fileName': 'y.pdf',
            'storagePath': 'textbooks/y.pdf',
            'sortOrder': 3,
          },
        ),
      ];
      expect((await service.fetchList()).map((b) => b.title), [
        'Ordered',
        'No order',
      ]);
    });

    test('an unreadable list is just empty, never an error', () async {
      remote.offline = true;
      expect(await service.fetchList(), isEmpty);
    });

    test('uploadedAt is read from a Firestore timestamp', () {
      final book = Textbook.fromMap('id', {
        'title': 'T',
        'fileName': 'f.pdf',
        'storagePath': 'textbooks/f.pdf',
        'uploadedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 18)),
      })!;
      expect(
        book.uploadedAt!.isAtSameMomentAs(DateTime.utc(2026, 10, 18)),
        isTrue,
      );
    });
  });

  group('downloading and the local copy', () {
    test('the first open downloads the book and reports progress', () async {
      final seen = <double>[];
      final file = await service.getFile(path, onProgress: seen.add);
      expect(remote.downloads, 1);
      expect(seen, [0.5, 1]);
      expect(await file.readAsString(), contains('pretend book contents'));
      expect(file.path, endsWith('Some Book.pdf'));
    });

    test(
      'later opens use the copy on the phone - no second download',
      () async {
        await service.getFile(path);
        final again = await service.getFile(path);
        expect(remote.downloads, 1);
        expect(await again.exists(), isTrue);
      },
    );

    test('a book that changed in Storage is downloaded again', () async {
      await service.getFile(path);
      remote.files[path] = utf8.encode('%PDF-1.4 a newer edition of the book');
      remote.updated[path] = 200;
      final file = await service.getFile(path);
      expect(remote.downloads, 2);
      expect(await file.readAsString(), contains('newer edition'));
    });

    test(
      'same size but re-uploaded (new update time) is downloaded again',
      () async {
        await service.getFile(path);
        remote.updated[path] = 999;
        await service.getFile(path);
        expect(remote.downloads, 2);
      },
    );

    test('with no connection, the copy on the phone is used', () async {
      await service.getFile(path);
      remote.offline = true;
      final file = await service.getFile(path);
      expect(remote.downloads, 1);
      expect(await file.readAsString(), contains('pretend book contents'));
    });

    test(
      'with no connection and no copy: a clear "needs internet" error',
      () async {
        remote.offline = true;
        expect(service.getFile(path), throwsA(isA<TextbookOfflineException>()));
      },
    );

    test('a book missing in Storage is reported as not found', () async {
      expect(
        service.getFile('textbooks/Nope.pdf'),
        throwsA(isA<TextbookNotFoundException>()),
      );
    });

    test('a download that drops leaves no half-file behind', () async {
      remote.dropDownload = true;
      await expectLater(service.getFile(path), throwsA(isA<SocketException>()));
      final dir = Directory('${tmp.path}/cache');
      expect(
        dir.listSync().map((e) => e.path.split(Platform.pathSeparator).last),
        isEmpty,
        reason: 'no .part and no book',
      );
      // and the next try (connection back) works
      remote.dropDownload = false;
      final file = await service.getFile(path);
      expect(await file.exists(), isTrue);
    });

    test('a damaged copy (wrong size) is downloaded again', () async {
      final file = await service.getFile(path);
      await file.writeAsString('corrupted');
      await service.getFile(path);
      expect(remote.downloads, 2);
    });

    test('the cache survives a new service instance (app restart)', () async {
      await service.getFile(path);
      final restarted = TextbookService(
        remote: remote,
        cacheDirectory: () async => Directory('${tmp.path}/cache'),
      );
      await restarted.getFile(path);
      expect(remote.downloads, 1);
    });

    test('the file name comes from the storage path', () {
      expect(
        TextbookService.fileNameOf('textbooks/Some Book.pdf'),
        'Some Book.pdf',
      );
    });
  });

  group('opening a book already on the phone (refreshInBackground)', () {
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 80));

    test('opens at once, without waiting for the network', () async {
      await service.getFile(path); // first open: downloads it
      remote.infoGate = Completer<void>(); // the network is "slow"
      final file = await service
          .getFile(path, refreshInBackground: true)
          .timeout(const Duration(seconds: 1)); // would time out if it waited
      expect(await file.readAsString(), '%PDF-1.4 pretend book contents');
      remote.infoGate!.complete();
      await settle();
    });

    test('a newer copy is fetched in the background for next time', () async {
      await service.getFile(path);
      remote.files[path] = utf8.encode('%PDF-1.4 a newer edition of the book');
      remote.updated[path] = 200;
      final now = await service.getFile(path, refreshInBackground: true);
      // this open still shows the copy on the phone ...
      expect(await now.readAsString(), '%PDF-1.4 pretend book contents');
      await settle();
      // ... and the next one has the new edition
      final next = await service.getFile(path, refreshInBackground: true);
      expect(await next.readAsString(), '%PDF-1.4 a newer edition of the book');
    });

    test('an unchanged book is not downloaded again', () async {
      await service.getFile(path);
      expect(remote.downloads, 1);
      await service.getFile(path, refreshInBackground: true);
      await settle();
      expect(remote.downloads, 1);
    });

    test('offline: the copy on the phone is used and nothing throws', () async {
      await service.getFile(path);
      remote.offline = true;
      final file = await service.getFile(path, refreshInBackground: true);
      await settle();
      expect(await file.readAsString(), '%PDF-1.4 pretend book contents');
    });

    test('a dropped background download leaves the old copy intact', () async {
      await service.getFile(path);
      remote.files[path] = utf8.encode('%PDF-1.4 the newer edition');
      remote.updated[path] = 300;
      remote.dropDownload = true;
      await service.getFile(path, refreshInBackground: true);
      await settle();
      remote.dropDownload = false;
      remote.offline = true;
      final file = await service.getFile(path, refreshInBackground: true);
      expect(await file.readAsString(), '%PDF-1.4 pretend book contents');
    });

    test('with no copy yet it downloads as usual', () async {
      final file = await service.getFile(path, refreshInBackground: true);
      expect(await file.readAsString(), '%PDF-1.4 pretend book contents');
      expect(remote.downloads, 1);
    });
  });

  test('the messages exist in both languages', () {
    expect(
      TextbookStrings.tl.needsInternet,
      isNot(TextbookStrings.en.needsInternet),
    );
    expect(
      TextbookStrings.tl.notAvailable,
      isNot(TextbookStrings.en.notAvailable),
    );
    expect(
      TextbookStrings.tl.couldNotLoad,
      isNot(TextbookStrings.en.couldNotLoad),
    );
    expect(TextbookStrings.en.downloading(42), 'Downloading… 42%');
    expect(TextbookStrings.tl.downloading(42), 'Dina-download… 42%');
  });
}
