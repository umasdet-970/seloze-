import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads a picked profile photo to `profile_photos/{uid}/{filename}` and
/// returns its public download URL — the same shape the rest of the app
/// already expects in `Profile.photoUrls` (a plain HTTPS URL), so nothing
/// downstream (discover cards, chat, matches) needs to know whether a URL
/// came from Storage or was pasted in during mock testing.
class FirebaseStorageUploader {
  FirebaseStorageUploader({FirebaseStorage? storage}) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadProfilePhoto(String uid, File file) async {
    final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref('profile_photos/$uid/$filename');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
