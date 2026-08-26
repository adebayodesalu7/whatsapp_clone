import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart' as wp;
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';

enum CallState { calling, ringing, connected, ended }

class ActiveCallScreen extends StatefulWidget {
  final String contactName;
  final String contactId;
  final bool isVideoCall;
  final bool isIncomingCall;
  final String? channelName;
  final bool isGroupCall;

  const ActiveCallScreen({
    super.key,
    required this.contactName,
    required this.contactId,
    this.isVideoCall = false,
    this.isIncomingCall = false,
    this.channelName,
    this.isGroupCall = false,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  final ChatService _chatService = ChatService();
  RtcEngine? _engine;
  final List<int> _remoteUids = [];
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isInitializing = true;
  bool _isJoining = false;
  bool _isDisposed = false;
  bool _isCallConnected = false;
  bool _isScreenSharing = false;
  bool _isRecording = false;
  bool _isBlurred = false;
  bool _isLiveDubbingEnabled = false;
  String _liveSubtitle = '';
  String _errorMessage = '';

  CallState _callState = CallState.calling;
  Duration _callDuration = Duration.zero;
  Timer? _timer;
  StreamSubscription<DocumentSnapshot>? _statusSubscription;
  String? _callLogId;

  // 🔑 Agora Credentials
  final String _appId = '5c6a35a04bbc44d983c4790b70eb8c5b';
  final String _channelName = 'AppChat';
  final String _tempToken = '007eJxTYDggr5hQOuHb1E9TVwkWLZWwaT3jeTJFwP10YOxHqYrogMkKDInJqWYGKYaWRkkGSSbmJqmWKanJxgaWRuZmFqbJlkbGZ9w6shoCGRmES/YxMzJAIIjPzuBYUOCckVjCwAAAd7MfZw==';

  @override
  void initState() {
    super.initState();
    if (widget.isVideoCall) {
      _isSpeakerOn = true;
    }
    _startCallWorkflow();
  }

  @override
  void dispose() {
    _isDisposed = true;
    wp.WakelockPlus.disable();
    _timer?.cancel();
    _statusSubscription?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  Future<void> _startCallWorkflow() async {
    try {
      wp.WakelockPlus.enable();

      await [
        Permission.microphone,
        Permission.camera,
        if (Platform.isAndroid) Permission.bluetoothConnect,
      ].request();

      if (!widget.isIncomingCall) {
        await _createCallDocument();
      }

      await _initAgora();
      _listenForCallStatus();
      _startCallTimer();

      setState(() {
        _isInitializing = false;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start call: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _initAgora() async {
    try {
      _engine = createAgoraRtcEngine();

      await _engine!.initialize(RtcEngineContext(
        appId: _appId.trim(),
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableAudio();

      if (widget.isVideoCall) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      }

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() {
            _isJoined = true;
            _isJoining = false;
            _errorMessage = '';
          });
          _applySpeakerState();
          if (widget.isIncomingCall) {
            _updateCallStatus('ringing');
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _isCallConnected = true;
          setState(() {
            if (!_remoteUids.contains(remoteUid)) {
              _remoteUids.add(remoteUid);
            }
            _callState = CallState.connected;
            _errorMessage = '';
          });
          _updateCallStatus('connected');
        },
        onUserOffline: (connection, remoteUid, reason) {
          setState(() {
            _remoteUids.remove(remoteUid);
          });
          if (_remoteUids.isEmpty && !widget.isGroupCall) {
            _endCallInternal();
          }
        },
        onLeaveChannel: (connection, stats) {
          setState(() { _isJoined = false; _callState = CallState.ended; });
        },
      ));

      setState(() { _isJoining = true; });

      await _engine!.joinChannel(
        token: _tempToken.trim(),
        channelId: widget.channelName ?? _channelName.trim(),
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: widget.isVideoCall,
          autoSubscribeAudio: true,
          autoSubscribeVideo: widget.isVideoCall,
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  void _applySpeakerState() async {
    if (_isDisposed || _engine == null || !_isJoined) return;
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      await _engine!.setEnableSpeakerphone(_isSpeakerOn);
    } catch (e) {
      print('Speaker error: $e');
    }
  }

  void _toggleSpeaker() async {
    if (_engine == null || !_isJoined) return;
    _isSpeakerOn = !_isSpeakerOn;
    await _engine!.setEnableSpeakerphone(_isSpeakerOn);
    if (mounted) setState(() {});
  }

  Future<void> _createCallDocument() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.contactId.isEmpty) return;

    String callerName = user.displayName ?? 'User';
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) callerName = userDoc.data()?['name'] ?? callerName;

    final logData = {
      'callerId': user.uid,
      'callerName': callerName,
      'receiverId': widget.contactId,
      'receiverName': widget.contactName,
      'callType': widget.isVideoCall ? 'video' : 'audio',
      'isVideo': widget.isVideoCall,
      'status': 'calling',
      'channelName': widget.channelName ?? _channelName,
      'timestamp': FieldValue.serverTimestamp(),
      'isMissed': true,
      'isGroup': widget.isGroupCall,
      'participants': [user.uid, widget.contactId],
    };

    final docRef = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.contactId);

    final ref = await FirebaseFirestore.instance.collection('call_logs').add(logData);
    _callLogId = ref.id;

    // Update signaling doc with the log ID so the receiver can update it too
    await docRef.set({...logData, 'callLogId': _callLogId});
  }

  void _listenForCallStatus() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final docId = widget.isIncomingCall ? currentUid : widget.contactId;

    _statusSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(docId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] ?? '';
      
      if (_callLogId == null && data['callLogId'] != null) {
        _callLogId = data['callLogId'];
      }

      if (status == 'ringing' && _callState == CallState.calling) {
        setState(() { _callState = CallState.ringing; });
      } else if (status == 'connected' && _callState != CallState.connected) {
        _isCallConnected = true;
        setState(() { _callState = CallState.connected; });
      } else if (status == 'ended' && _callState != CallState.ended) {
        _endCallInternal();
      }
    });
  }

  Future<void> _updateCallStatus(String status) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final docId = widget.isIncomingCall ? currentUid : widget.contactId;

    await FirebaseFirestore.instance
        .collection('calls')
        .doc(docId)
        .update({'status': status});

    if (_callLogId != null) {
      Map<String, dynamic> updates = {'status': status};
      if (status == 'connected') {
        updates['isMissed'] = false;
      }
      await FirebaseFirestore.instance
          .collection('call_logs')
          .doc(_callLogId)
          .update(updates);
    }
  }

  void _startCallTimer() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_callState == CallState.connected && mounted) {
        setState(() { _callDuration += const Duration(seconds: 1); });
      } else if (!mounted) {
        timer.cancel();
      }
    });
  }

  void _endCall() async {
    await _updateCallStatus('ended');
    
    // Delete signaling doc
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      final docId = widget.isIncomingCall ? currentUid : widget.contactId;
      FirebaseFirestore.instance.collection('calls').doc(docId).delete();
    }
    
    _endCallInternal();
  }

  void _endCallInternal() {
    if (_callState == CallState.ended) return;

    if (_isCallConnected && mounted) {
      setState(() {
        _callState = CallState.ended;
      });
      
      // Update duration in log
      if (_callLogId != null) {
        FirebaseFirestore.instance.collection('call_logs').doc(_callLogId).update({
          'duration': _callDuration.inSeconds,
          'status': 'ended',
        });
      }

      // Send call stamp to chat
      _chatService.sendCallLogMessage(
        receiverId: widget.contactId,
        callType: widget.isVideoCall ? 'video' : 'voice',
        isMissed: false,
        duration: _callDuration.inSeconds,
      );

      _engine?.leaveChannel();
      return;
    }

    if (mounted) {
      setState(() => _callState = CallState.ended);
    }
    
    // Send missed call stamp if not connected
    if (!_isCallConnected) {
       _chatService.sendCallLogMessage(
        receiverId: widget.contactId,
        callType: widget.isVideoCall ? 'video' : 'voice',
        isMissed: true,
        duration: 0,
      );
    }

    // Cleanup signaling
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      final docId = widget.isIncomingCall ? currentUid : widget.contactId;
      FirebaseFirestore.instance.collection('calls').doc(docId).delete();
    }

    _engine?.leaveChannel();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !_isCallConnected) Navigator.pop(context);
    });
  }

  void _toggleScreenSharing() async {
    if (_engine == null || !_isJoined) return;

    try {
      if (_isScreenSharing) {
        await _engine!.stopScreenCapture();
        await _engine!.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishCameraTrack: true,
            publishMicrophoneTrack: true,
            publishScreenCaptureVideo: false,
            publishScreenCaptureAudio: false,
          ),
        );
      } else {
        await _engine!.startScreenCapture(
          const ScreenCaptureParameters2(
            captureVideo: true,
            captureAudio: true,
          ),
        );
        await _engine!.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishCameraTrack: false,
            publishMicrophoneTrack: true,
            publishScreenCaptureVideo: true,
            publishScreenCaptureAudio: true,
          ),
        );
      }
      setState(() {
        _isScreenSharing = !_isScreenSharing;
      });
    } catch (e) {
      print("Screen Share Error: $e");
    }
  }

  void _toggleMute() {
    setState(() { _isMuted = !_isMuted; });
    _engine?.muteLocalAudioStream(_isMuted);
  }

  void _toggleRecording() async {
    if (_engine == null || !_isJoined) return;

    try {
      if (_isRecording) {
        await _engine!.stopAudioRecording();
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⏹️ Recording saved to vault')),
        );
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final path = "${directory.path}/call_recording_${DateTime.now().millisecondsSinceEpoch}.wav";
        
        await _engine!.startAudioRecording(AudioRecordingConfiguration(
          filePath: path,
          quality: AudioRecordingQualityType.audioRecordingQualityHigh,
        ));
        
        setState(() => _isRecording = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⏺️ Recording started')),
        );
      }
    } catch (e) {
      print("Recording Error: $e");
    }
  }

  void _toggleBlur() async {
    if (_engine == null || !_isJoined) return;

    try {
      _isBlurred = !_isBlurred;
      
      final VirtualBackgroundSource source = VirtualBackgroundSource(
        backgroundSourceType: BackgroundSourceType.backgroundBlur,
        blurDegree: BackgroundBlurDegree.blurDegreeHigh,
      );

      await _engine!.enableVirtualBackground(
        enabled: _isBlurred,
        backgroundSource: source,
        segproperty: const SegmentationProperty(
          modelType: SegModelType.segModelAi,
          greenCapacity: 0.5,
        ),
      );

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isBlurred ? '✨ Background blur enabled' : '✨ Background blur disabled')),
      );
    } catch (e) {
      print("Blur Error: $e");
    }
  }

  void _toggleLiveDubbing() {
    setState(() {
      _isLiveDubbingEnabled = !_isLiveDubbingEnabled;
      if (_isLiveDubbingEnabled) {
        _liveSubtitle = "Titan AI: Live translation active...";
      } else {
        _liveSubtitle = "";
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isLiveDubbingEnabled ? '🌍 Live Dubbing Enabled' : '🌍 Live Dubbing Disabled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final screenColor = themeProvider.getColor('chat');

    if (_isInitializing || _isJoining) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text('Connecting...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Videos Grid
            if (widget.isVideoCall && _isJoined)
              _buildVideoGrid()
            else
              _buildAudioBg(screenColor),

            // Top Info
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    widget.contactName,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _callState == CallState.calling ? 'Calling...' :
                    _callState == CallState.ringing ? 'Ringing...' :
                    _callState == CallState.connected ? '${_callDuration.inMinutes}:${(_callDuration.inSeconds % 60).toString().padLeft(2, '0')}' : 'Call ended',
                    style: TextStyle(color: _callState == CallState.connected ? Colors.green : Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),

            // Subtitles
            if (_isLiveDubbingEnabled && _liveSubtitle.isNotEmpty)
              Positioned(
                bottom: 150,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
                  child: Text(
                    _liveSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),

            // Bottom Controls
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (widget.isVideoCall) ...[
                          _buildControlButton(
                            icon: _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share, 
                            color: _isScreenSharing ? Colors.blue : Colors.white, 
                            onPressed: _toggleScreenSharing
                          ),
                          _buildControlButton(
                            icon: Icons.auto_fix_high, 
                            color: _isBlurred ? Colors.amber : Colors.white, 
                            onPressed: _toggleBlur
                          ),
                        ],
                        _buildControlButton(
                          icon: _isRecording ? Icons.radio_button_checked : Icons.radio_button_off, 
                          color: _isRecording ? Colors.red : Colors.white, 
                          onPressed: _toggleRecording
                        ),
                        _buildControlButton(
                          icon: Icons.translate, 
                          color: _isLiveDubbingEnabled ? Colors.blue : Colors.white, 
                          onPressed: _toggleLiveDubbing
                        ),
                        _buildControlButton(icon: _isMuted ? Icons.mic_off : Icons.mic, color: _isMuted ? Colors.red : Colors.white, onPressed: _toggleMute),
                        _buildControlButton(icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off, color: _isSpeakerOn ? Colors.green : Colors.white, onPressed: _toggleSpeaker),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 70, height: 70,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoGrid() {
    List<Widget> views = [];
    // Local view
    views.add(AgoraVideoView(
      controller: VideoViewController(rtcEngine: _engine!, canvas: const VideoCanvas(uid: 0)),
    ));
    // Remote views
    for (var uid in _remoteUids) {
      views.add(AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: uid),
          connection: RtcConnection(channelId: widget.channelName ?? _channelName),
        ),
      ));
    }

    if (views.length == 1) return views[0];
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: views.length <= 2 ? 1 : 2,
        childAspectRatio: views.length <= 2 ? 0.5 : 1,
      ),
      itemCount: views.length,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade900)),
        child: views[index],
      ),
    );
  }

  Widget _buildAudioBg(Color screenColor) => Container(
    width: double.infinity, height: double.infinity,
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [screenColor.withOpacity(0.3), Colors.black])),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(radius: 60, backgroundColor: Colors.grey.shade800, child: Text(widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 40, color: Colors.white))),
          const SizedBox(height: 20),
          Text(widget.contactName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_remoteUids.isNotEmpty)
            Text('${_remoteUids.length + 1} participants', style: const TextStyle(color: Colors.green, fontSize: 14)),
        ],
      ),
    ),
  );

  Widget _buildControlButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(color: Colors.grey.shade800.withOpacity(0.6), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
