import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadImage(String filePath, String folder) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ StorageService: File does not exist at path: $filePath');
        return null;
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${filePath.split('/').last}';
      final ref = _storage.ref().child(folder).child(fileName);

      print('⏳ StorageService: Starting upload to: ${ref.fullPath}');
      
      // Use putFile and wait for completion
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask.whenComplete(() => null);
      
      if (snapshot.state == TaskState.success) {
        final downloadUrl = await snapshot.ref.getDownloadURL();
        print('✅ StorageService: Upload successful: $downloadUrl');
        return downloadUrl;
      } else {
        print('❌ StorageService: Upload failed with state: ${snapshot.state}');
        return null;
      }
    } catch (e) {
      print('❌ StorageService Error: $e');
      if (e is FirebaseException) {
        print('   Code: ${e.code}');
        print('   Message: ${e.message}');
      }
      return null;
    }
  }

  Future<String?> uploadVideo(String filePath, String folder) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${filePath.split('/').last}';
      final ref = _storage.ref().child(folder).child(fileName);

      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'video/mp4'),
      );
      
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('❌ StorageService Video Error: $e');
      return null;
    }
  }
}
