import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  final String _cloudName = 'ddvvinsdr';
  final String _uploadPreset = 'chat_app_uploads';

  /// Basic upload for profile pictures
  Future<String?> uploadImage(XFile image) async {
    try {
      final cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(image.path, resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } catch (e) {
      print('❌ Cloudinary Upload Error: $e');
      return null;
    }
  }

  /// Uploads an image and triggers AI features (Tagging & Moderation)
  Future<Map<String, dynamic>?> uploadMarketplaceImage(XFile image) async {
    try {
      print('☁️ Starting AI-powered Cloudinary upload...');
      
      final cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
      
      // Cloudinary SDK for Flutter is limited. Advanced AI features like Google Tagging 
      // and AWS Rekognition are best configured directly on the "Upload Preset" 
      // in your Cloudinary Dashboard under "Upload" settings.
      
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path, 
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      print('✅ AI Upload successful: ${response.secureUrl}');
      
      return {
        'url': response.secureUrl,
        'publicId': response.publicId,
        'tags': response.tags, 
      };
    } catch (e) {
      print('❌ Cloudinary AI Upload Error: $e');
      return null; 
    }
  }

  /// Generates an AI-modified version of an image (e.g., Background Removal or Generative Fill)
  String getAIEnhancedUrl(String publicId, {bool removeBackground = false, bool improveClarity = true}) {
    String transformations = 'f_auto,q_auto'; 
    
    if (removeBackground) {
      transformations += ',e_background_removal'; 
    }
    if (improveClarity) {
      transformations += ',e_improve'; 
    }

    return 'https://res.cloudinary.com/$_cloudName/image/upload/$transformations/$publicId';
  }

  /// Image to Video: Cloudinary can auto-generate a video from a static image
  String getImageToVideoUrl(String publicId) {
    return 'https://res.cloudinary.com/$_cloudName/image/upload/e_zoompan/$publicId.mp4';
  }
}
