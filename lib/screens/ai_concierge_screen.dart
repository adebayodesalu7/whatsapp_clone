import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/screen_theme_provider.dart';
import '../services/ai_service.dart';

class AIConciergeScreen extends StatefulWidget {
  const AIConciergeScreen({super.key});

  @override
  State<AIConciergeScreen> createState() => _AIConciergeScreenState();
}

class _AIConciergeScreenState extends State<AIConciergeScreen> {
  final TextEditingController _controller = TextEditingController();
  final AIService _aiService = AIService();
  final List<Map<String, dynamic>> _messages = [
    {'isMe': false, 'text': 'Hello! I am your Titan AI Concierge. How can I help you find something in the Marketplace today?'},
  ];

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    
    final userText = _controller.text;
    setState(() {
      _messages.add({'isMe': true, 'text': userText});
      _controller.clear();
    });

    // Simulate AI interpreting the request
    final response = await _aiService.getBusinessAutoReply(userText);
    
    setState(() {
      _messages.add({'isMe': false, 'text': "🧠 [Titan interpretation]: Searching for products matching '$userText'...\n\n$response"});
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: const Text('💎 Titan AI Concierge'),
        backgroundColor: themeProvider.getColor('appBar'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: msg['isMe'] ? themeProvider.getColor('chatBubbleMe') : themeProvider.getColor('chatBubbleOther'),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(msg['text'], style: TextStyle(color: themeProvider.getColor('text'))),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: themeProvider.getColor('card'),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Search products...', border: InputBorder.none),
                    style: TextStyle(color: themeProvider.getColor('text')),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
