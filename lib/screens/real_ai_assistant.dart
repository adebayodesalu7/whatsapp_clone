import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/widgets/theme_selector.dart';

class RealAIAssistantScreen extends StatefulWidget {
  const RealAIAssistantScreen({super.key});

  @override
  State<RealAIAssistantScreen> createState() => _RealAIAssistantScreenState();
}

class _RealAIAssistantScreenState extends State<RealAIAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  // Your Groq API Key
  final String _apiKey = 'gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'; // REPLACE THIS

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _messages.add({
          'text': 'Hello! 👋 I\'m your AI Business Assistant.\n\nI can help you with:\n• 💰 Product pricing strategies\n• 📦 Inventory management tips\n• 👥 Customer service advice\n• 📈 Business growth ideas\n\nHow can I help you today?',
          'isMe': 'false',
        });
      });
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add({'text': message, 'isMe': 'true'});
      _isLoading = true;
      _messageController.clear();
    });

    try {
      final requestBody = {
        'model': 'llama3-8b-8192',  // ✅ More reliable model
        'messages': [
          {
            'role': 'system',
            'content': 'You are an AI Business Assistant for small vendors in Nigeria. Help with pricing, inventory, customer service, and business growth. Be friendly and practical. Use local references like Naira and Lagos. Keep responses concise (2-3 short paragraphs).'
          },
          {'role': 'user', 'content': message},
        ],
        'max_tokens': 500,
        'temperature': 0.7,
      };

      print('📤 Sending request to Groq...');
      print('📤 Model: llama3-8b-8192');
      print('📤 Message: $message');

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data['choices'][0]['message']['content'];
        setState(() {
          _messages.add({'text': aiResponse, 'isMe': 'false'});
          _isLoading = false;
        });
      } else {
        final errorData = json.decode(response.body);
        String errorMsg = 'Unknown error';
        if (errorData['error'] != null) {
          errorMsg = errorData['error']['message'] ?? errorData['error']['type'] ?? 'Unknown error';
        }
        setState(() {
          _isLoading = false;
          _messages.add({
            'text': '⚠️ Error ${response.statusCode}: $errorMsg\n\nTry asking something else.',
            'isMe': 'false',
          });
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add({
          'text': '⚠️ Network Error: $e',
          'isMe': 'false',
        });
      });
      print('❌ Exception: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final screenColor = themeProvider.getColor('chat');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Powered by Groq',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: screenColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add({
                  'text': 'Hello! 👋 I\'m your AI Business Assistant.\n\nHow can I help you today?',
                  'isMe': 'false',
                });
              });
            },
          ),
          ThemeSelector(screenName: 'chat'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                final isMe = message['isMe'] == 'true';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.green,
                            size: 16,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? screenColor : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message['text']!,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AI is thinking...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask your business question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: screenColor),
                  onPressed: () {
                    if (_messageController.text.isNotEmpty) {
                      _sendMessage(_messageController.text);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}