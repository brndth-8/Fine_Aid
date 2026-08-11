import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfilePhoto(String localPath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final file = File(localPath);
    final ref = _storage.ref().child('users/${user.uid}/profile/photo.jpg');

    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await uploadTask.ref.getDownloadURL();
  }

  Future<String> uploadJournalImage(String localPath, String entryId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final file = File(localPath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(
      'users/${user.uid}/journal/$entryId/$fileName',
    );

    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await uploadTask.ref.getDownloadURL();
  }

  Future<String?> getProfilePhotoUrl() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final ref = _storage.ref().child('users/${user.uid}/profile/photo.jpg');
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Deletes a file from Storage by its full URL.
  Future<void> deleteByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {}
  }
}
