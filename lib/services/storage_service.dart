import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadFile(String filePath, String folder, String contentType) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${filePath.split('/').last}';
      final ref = _storage.ref().child(folder).child(fileName);

      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );
      
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('❌ StorageService Error: $e');
      return null;
    }
  }

  Future<String?> uploadImage(String filePath, String folder) async {
    return uploadFile(filePath, folder, 'image/jpeg');
  }

  Future<String?> uploadAudio(String filePath, String folder) async {
    return uploadFile(filePath, folder, 'audio/mpeg');
  }

  Future<String?> uploadVideo(String filePath, String folder) async {
    return uploadFile(filePath, folder, 'video/mp4');
  }
}
