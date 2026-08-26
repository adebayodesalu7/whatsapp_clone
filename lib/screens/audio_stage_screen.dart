import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/screen_theme_provider.dart';

class AudioStageScreen extends StatefulWidget {
  final String stageName;
  const AudioStageScreen({super.key, required this.stageName});

  @override
  State<AudioStageScreen> createState() => _AudioStageScreenState();
}

class _AudioStageScreenState extends State<AudioStageScreen> {
  bool _isMuted = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: const Text('Live Audio Stage 🎙️', style: TextStyle(fontSize: 16)),
        backgroundColor: themeProvider.getColor('appBar'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Leave Quietly', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(widget.stageName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              children: [
                _buildSpeaker("Host Admin", isHost: true),
                _buildSpeaker("Titan Bot"),
                _buildSpeaker("Top Seller"),
                _buildListener("Crypto King"),
                _buildListener("Tech Savvy"),
                _buildListener("Lagos Boy"),
                _buildListener("Abuja Diva"),
              ],
            ),
          ),
          _buildControls(themeProvider),
        ],
      ),
    );
  }

  Widget _buildSpeaker(String name, {bool isHost = false}) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(radius: 35, backgroundImage: NetworkImage("https://i.pravatar.cc/150?u=$name")),
            if (isHost)
              Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.star, color: Colors.white, size: 14))),
          ],
        ),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        const Text("SPEAKER", style: TextStyle(fontSize: 8, color: Colors.grey)),
      ],
    );
  }

  Widget _buildListener(String name) {
    return Column(
      children: [
        CircleAvatar(radius: 25, backgroundImage: NetworkImage("https://i.pravatar.cc/150?u=$name")),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildControls(ScreenThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: themeProvider.getColor('card'),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlCircle(Icons.front_hand, "Raise Hand"),
          GestureDetector(
            onTap: () => setState(() => _isMuted = !_isMuted),
            child: _controlCircle(_isMuted ? Icons.mic_off : Icons.mic, _isMuted ? "Unmute" : "Mute", active: !_isMuted),
          ),
          _controlCircle(Icons.emoji_emotions_outlined, "React"),
        ],
      ),
    );
  }

  Widget _controlCircle(IconData icon, String label, {bool active = false}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: active ? Colors.blue : Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: active ? Colors.white : Colors.blue),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
