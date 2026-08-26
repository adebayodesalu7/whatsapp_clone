import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../services/ai_service.dart';

class VoiceMessageWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final Color meColor;
  final Color otherColor;

  const VoiceMessageWidget({
    super.key,
    required this.audioUrl,
    required this.isMe,
    required this.meColor,
    required this.otherColor,
  });

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  late PlayerController _playerController;
  bool _isPlaying = false;
  String? _transcription;
  bool _isTranscribing = false;
  final AIService _aiService = AIService();

  @override
  void initState() {
    super.initState();
    _playerController = PlayerController();
    _initPlayer();
  }

  void _initPlayer() async {
    await _playerController.preparePlayer(path: widget.audioUrl, shouldExtractWaveform: true);
    _playerController.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped || state == PlayerState.paused) {
        if (mounted) setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe ? widget.meColor : widget.otherColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (_isPlaying) {
                await _playerController.pausePlayer();
              } else {
                await _playerController.startPlayer();
              }
              setState(() => _isPlaying = !_isPlaying);
            },
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.isMe ? Colors.white : Colors.green,
              size: 30,
            ),
          ),
          Expanded(
            child: AudioFileWaveforms(
              size: const Size(double.infinity, 40),
              playerController: _playerController,
              enableSeekGesture: true,
              waveformType: WaveformType.fitWidth,
              playerWaveStyle: PlayerWaveStyle(
                fixedWaveColor: widget.isMe ? Colors.white38 : Colors.grey.shade300,
                liveWaveColor: widget.isMe ? Colors.white : Colors.green,
                spacing: 6,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.translate, 
              size: 18, 
              color: widget.isMe ? Colors.white70 : Colors.grey
            ),
            onPressed: _transcribe,
          ),
        ],
      ),
    );
  }

  void _transcribe() async {
    if (_transcription != null) {
      _showTranscriptionDialog();
      return;
    }

    setState(() => _isTranscribing = true);
    
    // Simulate audio-to-text using AI
    final result = await _aiService.transcribeAudio("voice message");
    
    if (mounted) {
      setState(() {
        _transcription = result;
        _isTranscribing = false;
      });
      _showTranscriptionDialog();
    }
  }

  void _showTranscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Transcription (AI)'),
        content: Text(_transcription ?? "Transcription failed."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}
