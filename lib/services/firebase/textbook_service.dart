import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// One textbook: a document in the Firestore `textbooks` collection that
/// points at a PDF in Firebase Storage.
class Textbook {
  final String id;
  final String title;
  final String subject;
  final String fileName;
  final String storagePath;
  final int fileSize;
  final DateTime? uploadedAt;
  final int sortOrder;

  const Textbook({
    required this.id,
    required this.title,
    required this.subject,
    required this.fileName,
    required this.storagePath,
    this.fileSize = 0,
    this.uploadedAt,
    this.sortOrder = 1000,
  });

  /// Reads a document's fields; null when it is missing what is needed to
  /// open the book (a title, a file name and a storage path).
  static Textbook? fromMap(String id, Map<String, dynamic> data) {
    final title = (data['title'] as String?)?.trim() ?? '';
    final fileName = (data['fileName'] as String?)?.trim() ?? '';
    final storagePath = (data['storagePath'] as String?)?.trim() ?? '';
    if (title.isEmpty || fileName.isEmpty || storagePath.isEmpty) return null;
    final uploaded = data['uploadedAt'];
    return Textbook(
      id: id,
      title: title,
      subject: (data['subject'] as String?)?.trim() ?? '',
      fileName: fileName,
      storagePath: storagePath,
      fileSize: data['fileSize'] is num ? (data['fileSize'] as num).toInt() : 0,
      uploadedAt: uploaded is Timestamp ? uploaded.toDate() : null,
      sortOrder: data['sortOrder'] is num
          ? (data['sortOrder'] as num).toInt()
          : 1000,
    );
  }
}

/// Size and last-changed time of a file in Storage — what tells the cache
/// whether its copy is still the current one.
class RemoteFileInfo {
  final int size;
  final int updatedMs;
  const RemoteFileInfo(this.size, this.updatedMs);
}

/// The book is not in Storage (the document points at a missing file).
class TextbookNotFoundException implements Exception {
  @override
  String toString() => 'TextbookNotFoundException';
}

/// No copy on the phone yet and Storage can't be reached (no connection).
class TextbookOfflineException implements Exception {
  @override
  String toString() => 'TextbookOfflineException';
}

/// The Firebase side of [TextbookService], separate so the caching logic can
/// be tested without Firebase.
abstract class TextbookRemote {
  /// Every document of the `textbooks` collection: (id, fields).
  Future<List<(String, Map<String, dynamic>)>> listDocuments();

  Future<RemoteFileInfo> info(String storagePath);

  /// Downloads [storagePath] into [to], reporting progress 0..1.
  Future<void> download(
    String storagePath,
    File to,
    void Function(double progress) onProgress,
  );
}

class FirebaseTextbookRemote implements TextbookRemote {
  @override
  Future<List<(String, Map<String, dynamic>)>> listDocuments() async {
    final snap = await FirebaseFirestore.instance.collection('textbooks').get();
    return [for (final d in snap.docs) (d.id, d.data())];
  }

  @override
  Future<RemoteFileInfo> info(String storagePath) async {
    try {
      final meta = await FirebaseStorage.instance
          .ref(storagePath)
          .getMetadata();
      return RemoteFileInfo(
        meta.size ?? 0,
        meta.updated?.millisecondsSinceEpoch ?? 0,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') throw TextbookNotFoundException();
      rethrow;
    }
  }

  @override
  Future<void> download(
    String storagePath,
    File to,
    void Function(double progress) onProgress,
  ) async {
    final task = FirebaseStorage.instance.ref(storagePath).writeToFile(to);
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress(s.bytesTransferred / s.totalBytes);
    });
    try {
      await task;
    } finally {
      await sub.cancel();
    }
  }
}

/// Loads the textbook list from Firestore and the PDFs from Firebase
/// Storage, keeping every downloaded book on the phone so it isn't fetched
/// again each time it is opened.
class TextbookService {
  TextbookService({
    TextbookRemote? remote,
    Future<Directory> Function()? cacheDirectory,
  }) : _remote = remote ?? FirebaseTextbookRemote(),
       _cacheDirectory = cacheDirectory ?? _defaultCacheDirectory;

  static final TextbookService instance = TextbookService();

  final TextbookRemote _remote;
  final Future<Directory> Function() _cacheDirectory;

  // The app's own persistent folder, not the temporary one — the system is
  // free to empty temporary folders, which would force a re-download.
  static Future<Directory> _defaultCacheDirectory() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/textbooks');
  }

  /// The textbooks, in their `sortOrder` (then by title). Empty when the list
  /// can't be read — callers keep whatever they already show. Firestore's own
  /// offline cache serves the last list seen without a connection.
  Future<List<Textbook>> fetchList() async {
    try {
      final docs = await _remote.listDocuments().timeout(
        const Duration(seconds: 10),
      );
      final books = [for (final d in docs) ?Textbook.fromMap(d.$1, d.$2)]
        ..sort((a, b) {
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          return byOrder != 0 ? byOrder : a.title.compareTo(b.title);
        });
      return books;
    } catch (e) {
      debugPrint('[Textbooks] could not load the list: $e');
      return const [];
    }
  }

  /// The file name at the end of a storage path.
  static String fileNameOf(String storagePath) => storagePath.split('/').last;

  /// A local copy of the book at [storagePath], downloading it only when
  /// there is no copy yet or the one in Storage has changed. Without a
  /// connection, an existing copy is used as it is.
  ///
  /// Throws [TextbookOfflineException] when there is no copy and no
  /// connection, and [TextbookNotFoundException] when the file is missing in
  /// Storage.
  Future<File> getFile(
    String storagePath, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _cacheDirectory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/${fileNameOf(storagePath)}');
    final metaFile = File('${file.path}.meta');

    final cached = await _readCachedInfo(file, metaFile);

    RemoteFileInfo? remote;
    try {
      remote = await _remote
          .info(storagePath)
          .timeout(const Duration(seconds: 8));
    } on TextbookNotFoundException {
      rethrow;
    } catch (e) {
      debugPrint('[Textbooks] could not check $storagePath: $e');
    }

    if (remote == null) {
      if (cached != null) return file; // offline: use what is on the phone
      throw TextbookOfflineException();
    }
    if (cached != null &&
        cached.size == remote.size &&
        cached.updatedMs == remote.updatedMs) {
      return file; // already the current copy
    }

    // Download beside the real file and swap it in only when complete, so a
    // dropped connection never leaves a half-file that looks like a book.
    final part = File('${file.path}.part');
    if (await part.exists()) await part.delete();
    try {
      await _remote.download(storagePath, part, onProgress ?? (_) {});
      if (await part.length() != remote.size) {
        throw const FileSystemException('Incomplete download');
      }
    } catch (e) {
      if (await part.exists()) await part.delete();
      rethrow;
    }
    if (await file.exists()) await file.delete();
    await part.rename(file.path);
    await metaFile.writeAsString(
      jsonEncode({'size': remote.size, 'updatedMs': remote.updatedMs}),
    );
    return file;
  }

  /// What the saved copy was when it was downloaded — null if there is no
  /// copy, or the file no longer matches what was recorded.
  Future<RemoteFileInfo?> _readCachedInfo(File file, File metaFile) async {
    try {
      if (!await file.exists() || !await metaFile.exists()) return null;
      final meta = jsonDecode(await metaFile.readAsString()) as Map;
      final size = (meta['size'] as num).toInt();
      if (await file.length() != size) return null;
      return RemoteFileInfo(size, (meta['updatedMs'] as num).toInt());
    } catch (_) {
      return null;
    }
  }
}
