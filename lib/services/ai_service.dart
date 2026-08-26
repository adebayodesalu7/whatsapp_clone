import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class AIService {
  // ⚠️ Replace with your actual Gemini API Key
  static const String _apiKey = 'YOUR_GEMINI_API_KEY';
  
  final GenerativeModel _model;

  AIService() : _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);

  Future<String> summarizeChat(List<String> messages) async {
    if (messages.isEmpty) return "No messages to summarize.";
    
    final prompt = "Summarize the following chat conversation briefly and highlight the main points:\n\n${messages.join('\n')}";
    
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "Could not generate summary.";
    } catch (e) {
      return "Error generating summary: $e";
    }
  }

  Future<List<String>> generateSmartReplies(String lastMessage) async {
    if (lastMessage.isEmpty) return [];
    
    final prompt = "Given this message: '$lastMessage', provide 3 short, helpful, and natural-sounding chat replies. Return ONLY the replies separated by newlines.";
    
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final text = response.text ?? "";
      return text.split('\n').where((s) => s.trim().isNotEmpty).take(3).toList();
    } catch (e) {
      print("Error generating smart replies: $e");
      return ["Okay", "Thanks!", "Got it"];
    }
  }

  Future<String> translateMessage(String text, String language) async {
    if (text.isEmpty) return text;
    
    final prompt = "Translate the following text to $language. Provide ONLY the translated text:\n\n$text";
    
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "Translation failed.";
    } catch (e) {
      return "Translation error: $e";
    }
  }

  Future<bool> isOffensiveOrSpam(String message) async {
    if (message.isEmpty) return false;

    final prompt = "Analyze this message for a group chat: '$message'. Is it offensive, highly inappropriate, or clear spam? Respond with ONLY the word 'true' or 'false'.";

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final result = response.text?.trim().toLowerCase() ?? 'false';
      return result.contains('true');
    } catch (e) {
      print("Error checking message moderation: $e");
      return false;
    }
  }

  Future<String> transcribeAudio(String placeholder) async {
    // In a real app, this would send audio bytes to Gemini or Whisper
    final prompt = "Simulate a transcription for an African user's voice note about: '$placeholder'. Keep it natural and include common local slangs if appropriate.";
    
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "Transcription unavailable.";
    } catch (e) {
      return "Transcription error: $e";
    }
  }

  Future<Map<String, dynamic>?> detectAppointmentIntent(String message) async {
    final prompt = "Analyze this message: '$message'. Does the user express an intent to meet, call, or have an appointment? If yes, extract the title and suggested time. Respond ONLY with a JSON object like {\"intent\": true, \"title\": \"...\", \"time\": \"...\"}. If no intent, respond with {\"intent\": false}.";
    
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      // Logic to parse JSON from response
      if (response.text?.contains('"intent": true') == true) {
        return {"intent": true, "title": "Meeting", "time": "Tomorrow"}; // Placeholder for parsed JSON
      }
    } catch (e) {
      print("Appointment Detection Error: $e");
    }
    return null;
  }

  Future<String> getBusinessAutoReply(String message, String businessCategory) async {
    final prompt = "You are an automated AI assistant for a $businessCategory business on WhatsApp. A customer says: '$message'. Provide a professional, helpful, and concise auto-reply. Include a greeting and ask how you can help further.";
    
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "Thank you for contacting us. We will get back to you shortly.";
    } catch (e) {
      return "Thank you for your message. How can we assist you today?";
    }
  }

  // TITAN: AI Sticker Creator (Mock logic for text-to-image integration)
  Future<String?> generateSticker(String prompt) async {
    final aiPrompt = "Imagine a unique WhatsApp sticker based on this description: '$prompt'. Describe the visual elements of this sticker in 50 words.";
    try {
      final response = await _model.generateContent([Content.text(aiPrompt)]);
      // In production, you would pass this description to DALL-E or Stable Diffusion API
      // For now, we'll return a placeholder sticker URL based on the description
      return "https://api.dicebear.com/7.x/bottts/png?seed=${prompt.hashCode}"; 
    } catch (e) {
      print("Sticker Gen Error: $e");
      return null;
    }
  }

  // TITAN: Live Translation
  Future<String> liveTranslate(String text, TranslateLanguage targetLang) async {
    final modelManager = OnDeviceTranslatorModelManager();
    final bool isDownloaded = await modelManager.isModelDownloaded(targetLang.bcpCode);
    
    if (!isDownloaded) {
      await modelManager.downloadModel(targetLang.bcpCode);
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: targetLang,
    );

    try {
      final translation = await translator.translateText(text);
      await translator.close();
      return translation;
    } catch (e) {
      print("Translation Error: $e");
      return text;
    }
  }

  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      return recognizedText.text.isEmpty ? "No text detected in image." : recognizedText.text;
    } catch (e) {
      print("OCR Error: $e");
      return "Failed to extract text: $e";
    }
  }

  // TITAN: AI Voice Synthesis (Mock)
  Future<String?> synthesizeSpeech(String text) async {
    // In production, integrate with Google Cloud TTS or ElevenLabs
    print("🔊 Synthesizing speech for: $text");
    // Return a dummy URL for now
    return "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";
  }

  // TITAN: Universal Voice Translator (Mock)
  Future<String?> dubVoiceNote(String audioUrl, TranslateLanguage targetLang) async {
    print("🌍 Dubbing voice note from $audioUrl to ${targetLang.bcpCode}");
    // Simulate pipeline: Transcribe -> Translate -> Synthesize
    await Future.delayed(const Duration(seconds: 2));
    return "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3";
  }

  // TITAN: Voice Morphing (Mock)
  Future<String?> morphVoice(String audioUrl, String persona) async {
    print("🎭 Morphing voice note to: $persona");
    await Future.delayed(const Duration(seconds: 1));
    // Return a dummy morphed URL
    return "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3";
  }

  // TITAN: Image Enhancement (Mock)
  Future<String?> enhanceImage(String imageUrl) async {
    print("✨ Enhancing image: $imageUrl");
    await Future.delayed(const Duration(seconds: 2));
    // In production, return an AI-enhanced image URL
    return imageUrl; // Returning original for mock logic
  }

  // TITAN: Real-time Video Dubbing (Mock)
  Future<String> realTimeDubbing(String text, TranslateLanguage targetLang) async {
    print("🌍 Real-time dubbing: $text to ${targetLang.bcpCode}");
    // Simulate translation latency
    return "Translated: $text"; 
  }

  // TITAN: News Engine (Mock)
  Future<List<Map<String, String>>> getTitanNews() async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      {"title": "Titan Economy Surges", "summary": "New marketplace data shows 40% growth in peer-to-peer trades."},
      {"title": "Whot Championship Announced", "summary": "The first national Titan Whot Elite tournament starts next month."},
      {"title": "Global Tech Trends", "summary": "AI integration in social apps reaching new heights in Africa."},
    ];
  }
}
