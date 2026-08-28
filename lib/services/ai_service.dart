import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  // ⚠️ Replace with your actual Gemini API Key
  static const String _defaultApiKey = 'YOUR_GEMINI_API_KEY';
  
  final GenerativeModel _model;

  AIService({String? apiKey}) : _model = GenerativeModel(
    model: 'gemini-1.5-flash', 
    apiKey: apiKey ?? _defaultApiKey
  );

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
    final prompt = "Simulate a transcription for an African user's voice note about: '$placeholder'. Keep it natural and include common local slangs if appropriate.";
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "Transcription unavailable.";
    } catch (e) {
      return "Transcription error: $e";
    }
  }

  Future<String> getBusinessAdvice(String query) async {
    final prompt = "You are an AI Business Assistant for small vendors in Nigeria and Africa. Provide practical, culturally-aware, and helpful business advice for this query: '$query'. Keep it concise and actionable.";
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "I couldn't generate advice right now. Try again later.";
    } catch (e) {
      return "Business Assistant Error: $e";
    }
  }

  Future<String> getBusinessAutoReply(String message) async {
    final prompt = "You are a professional business assistant. Generate a polite and helpful auto-reply for this customer message: '$message'. If it's a greeting, acknowledge it. If it's an inquiry, say someone will be with them shortly.";
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "Thank you for your message. We will get back to you shortly.";
    } catch (e) {
      return "Auto-reply Error: $e";
    }
  }
}
