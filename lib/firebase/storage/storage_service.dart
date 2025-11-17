import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Dosya yükle
  Future<String?> uploadFile({
    required File file,
    required String path,
    Function(double)? onProgress,
  }) async {
    try {
      final fileName = file.path.split('/').last;
      final ref = _storage.ref().child('$path/$fileName');

      final uploadTask = ref.putFile(file);

      // Progress dinle
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ File uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading file: $e');
      return null;
    }
  }

  /// Dosya sil
  Future<bool> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
      debugPrint('✅ File deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
      return false;
    }
  }

  /// Dosya adını URL'den al
  String getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.last;
      return Uri.decodeComponent(path.split('?').first);
    } catch (e) {
      return 'file';
    }
  }
}