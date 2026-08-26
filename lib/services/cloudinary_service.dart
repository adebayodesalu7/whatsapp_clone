import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  // Replace these with your actual Cloudinary credentials from the dashboard
  final String _cloudName = 'ddvvinsdr';
  final String _uploadPreset = 'chat_app_uploads';

  Future<String?> uploadImage(XFile image) async {
    try {
      print('☁️ Starting Cloudinary upload for: ${image.path}');
      
      final cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
      
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(image.path, resourceType: CloudinaryResourceType.Image),
      );

      print('✅ Cloudinary Upload successful: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      print('❌ Cloudinary Upload Error: $e');
      // If upload fails, return null or local path for debug? 
      // For now, return the local path so it doesn't break the flow on your device
      return image.path; 
    }
  }
}
