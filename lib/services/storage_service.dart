import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadImage(String filePath, String folder) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File does not exist at path: $filePath');
        return null;
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${filePath.split('/').last}';
      final ref = _storage.ref().child(folder).child(fileName);

      print('⏳ Starting upload to Firebase Storage: $folder/$fileName');
      
      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      print('✅ Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Firebase Storage Error: $e');
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
      print('❌ Video Upload Error: $e');
      return null;
    }
  }
}
