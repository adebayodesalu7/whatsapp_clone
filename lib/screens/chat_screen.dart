import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_clone/services/cloudinary_service.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/services/ai_service.dart';
import 'package:whatsapp_clone/services/storage_service.dart';
import 'package:whatsapp_clone/services/business_service.dart';
import 'package:whatsapp_clone/services/crypto_service.dart';
import 'package:whatsapp_clone/services/escrow_service.dart';
import 'package:whatsapp_clone/services/security_service.dart';
import 'package:whatsapp_clone/models/enums.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/widgets/avatar.dart';
import 'package:whatsapp_clone/widgets/theme_selector.dart';
import 'package:whatsapp_clone/widgets/poll_widget.dart';
import 'package:whatsapp_clone/widgets/reaction_picker.dart';
import 'package:whatsapp_clone/widgets/voice_message_widget.dart';
import 'package:whatsapp_clone/widgets/pattern_painter.dart';
import 'package:whatsapp_clone/models/models.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'contact_info_screen.dart';
import 'active_call_screen.dart';
import 'catalog_screen.dart';
import 'contacts_screen.dart';
import 'ajo_dashboard_screen.dart';
import 'group_settings_screen.dart';
import 'games_screen.dart';
import 'titan_docs_screen.dart';
import 'chat_media_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String contactName;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.contactName,
    this.isGroup = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AIService _aiService = AIService();
  final StorageService _storageService = StorageService();
  final BusinessService _businessService = BusinessService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  String? _replyTo;
  String? _replyText;
  List<String> _smartReplies = [];
  Timer? _typingTimer;
  bool _isOtherUserTyping = false;

  late RecorderController _recorderController;
  bool _isRecording = false;
  int _disappearingTimer = 0;
  bool _isGhostMode = false;
  bool _isLocked = false;
  bool _isAutoPilotEnabled = false;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recorderController = RecorderController();
    _loadChatSettings();
    _updateUserStatus(true);
    _listenToOtherUserStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateUserStatus(true);
    } else {
      _updateUserStatus(false);
      _setTypingStatus(false);
    }
  }

  void _updateUserStatus(bool isOnline) {
    if (_currentUserId == null) return;
    FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  void _listenToOtherUserStatus() {
    if (widget.isGroup) return;
    final chatId = _chatService.getChatId(_currentUserId!, widget.receiverId);
    FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots().listen((snap) {
      if (snap.exists && mounted) {
        final data = snap.data() as Map<String, dynamic>;
        final typingMap = data['typing'] as Map<String, dynamic>? ?? {};
        setState(() {
          _isOtherUserTyping = typingMap[widget.receiverId] == true;
        });
      }
    });
  }

  void _setTypingStatus(bool isTyping) {
    if (widget.isGroup || _currentUserId == null) return;
    final chatId = _chatService.getChatId(_currentUserId!, widget.receiverId);
    FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'typing': { _currentUserId!: isTyping }
    }, SetOptions(merge: true));
  }

  void _onTextChanged(String text) {
    setState(() {}); // For mic/send switch
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    _setTypingStatus(true);
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _setTypingStatus(false);
    });
  }

  void _loadChatSettings() async {
    final chatId = widget.isGroup ? widget.receiverId : _chatService.getChatId(_currentUserId!, widget.receiverId);
    final doc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(() {
        _disappearingTimer = data['disappearingTimer'] ?? 0;
        _isGhostMode = data['isGhostMode'] ?? false;
        _isLocked = data['isLocked'] ?? false;
        _isAutoPilotEnabled = data['isAutoPilotEnabled'] ?? false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorderController.dispose();
    _messageController.dispose();
    _updateUserStatus(false);
    _setTypingStatus(false);
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    _chatService.sendMessage(
      widget.receiverId,
      _messageController.text.trim(),
      isGroup: widget.isGroup,
      replyTo: _replyTo,
      disappearingTimer: _disappearingTimer,
    );
    _messageController.clear();
    setState(() {
      _replyTo = null;
      _replyText = null;
      _smartReplies = [];
    });
  }

  void _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;
    await _recorderController.record();
    setState(() => _isRecording = true);
  }

  void _stopRecording() async {
    final path = await _recorderController.stop();
    setState(() => _isRecording = false);
    if (path != null) {
      final audioUrl = await _storageService.uploadAudio(path, 'chat_audio');
      if (audioUrl != null) {
        _chatService.sendVoiceMessage(widget.receiverId, audioUrl, widget.isGroup);
      }
    }
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image != null) {
      final imageUrl = await _storageService.uploadImage(image.path, 'chat_images');
      if (imageUrl != null) {
        _chatService.sendImageMessage(widget.receiverId, imageUrl, isGroup: widget.isGroup);
      }
    }
  }

  void _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      final videoUrl = await _storageService.uploadImage(video.path, 'chat_videos');
      if (videoUrl != null) {
        _chatService.sendVideoMessage(widget.receiverId, videoUrl, widget.isGroup);
      }
    }
  }

  void _pickDocument() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = result.files.single.name;
      final docUrl = await _storageService.uploadImage(path, 'chat_docs');
      if (docUrl != null) {
        _chatService.sendMessage(widget.receiverId, "📄 Document: $name\n$docUrl", isGroup: widget.isGroup);
      }
    }
  }

  void _pickGIF() async {
    final gif = await GiphyGet.getGif(context: context, apiKey: 'YOUR_GIPHY_API_KEY');
    if (gif != null && gif.images?.original?.url != null) {
      _chatService.sendImageMessage(widget.receiverId, gif.images!.original!.url, isGroup: widget.isGroup);
    }
  }

  void _shareLocation() async {
    final pos = await Geolocator.getCurrentPosition();
    _chatService.sendLocationMessage(widget.receiverId, pos.latitude, pos.longitude, widget.isGroup);
  }

  void _pickContact() async {
    Navigator.pop(context);
    final contact = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ContactsScreen(isPicker: true)),
    );

    if (contact != null && mounted) {
      _chatService.sendContactMessage(widget.receiverId, contact, widget.isGroup);
    }
  }

  void _createAIVideo() async {
    Navigator.pop(context); // Close attachment menu
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('Titan AI is generating video...', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
          ],
        ),
      ),
    );

    try {
      final cloudinary = CloudinaryService();
      final uploadResult = await cloudinary.uploadMarketplaceImage(image);
      
      if (uploadResult != null && uploadResult['publicId'] != null) {
        final videoUrl = cloudinary.getImageToVideoUrl(uploadResult['publicId']);
        _chatService.sendVideoMessage(widget.receiverId, videoUrl, widget.isGroup);
      }
    } catch (e) {
      print('❌ AI Video Error: $e');
    } finally {
      if (mounted) Navigator.pop(context); // Close loading
    }
  }

  void _showInvoiceDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Item Name')),
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                final invoice = {
                  'itemName': nameController.text,
                  'amount': double.parse(amountController.text),
                  'status': 'Pending',
                  'type': 'Standard',
                };
                _chatService.sendInvoiceMessage(widget.receiverId, invoice, isGroup: widget.isGroup);
                Navigator.pop(context);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _markMessagesAsRead() {
    _chatService.markMessagesAsRead(widget.receiverId, isGroup: widget.isGroup);
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('$feature Coming Soon'),
        content: Text('The $feature feature is currently under development.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.getColor('text');
    final appBarColor = themeProvider.getColor('appBar');
    final secondaryTextColor = themeProvider.getColor('textSecondary');
    final currentBackground = themeProvider.getChatBackground();

    return Scaffold(
      extendBodyBehindAppBar: themeProvider.isGlassMode,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection(widget.isGroup ? 'groups' : 'users').doc(widget.receiverId).snapshots(),
          builder: (context, snapshot) {
            String? photoUrl;
            bool isTitanElite = false;
            String statusText = widget.isGroup ? 'active' : 'offline';
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              photoUrl = data['photoUrl'] ?? data['iconUrl'];
              isTitanElite = data['isTitanElite'] ?? false;
              
              if (!widget.isGroup) {
                final isOnline = data['isOnline'] ?? false;
                if (_isOtherUserTyping) {
                  statusText = 'typing...';
                } else if (isOnline) {
                  statusText = 'online';
                } else if (data['lastSeen'] != null) {
                  final lastSeen = (data['lastSeen'] as Timestamp).toDate();
                  statusText = 'last seen ${DateFormat('HH:mm').format(lastSeen)}';
                }
              }
            }

            return ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: themeProvider.isGlassMode ? 12.0 : 0.0,
                  sigmaY: themeProvider.isGlassMode ? 12.0 : 0.0,
                ),
                child: AppBar(
                  backgroundColor: themeProvider.isGlassMode ? appBarColor.withOpacity(0.7) : appBarColor,
                  elevation: 0,
                  leadingWidth: 75,
                  leading: InkWell(
                    onTap: () {
                      if (_isSearching) {
                        setState(() {
                          _isSearching = false;
                          _searchQuery = "";
                          _searchController.clear();
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_back, size: 22),
                        if (!_isSearching) ...[
                          const SizedBox(width: 2),
                          Avatar(name: widget.contactName, imageUrl: photoUrl, size: 36, isTitanElite: isTitanElite),
                        ],
                      ],
                    ),
                  ),
                  titleSpacing: 0,
                  title: _isSearching
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: const TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                            suffixIcon: _searchQuery.isNotEmpty 
                                ? IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white70),
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = "";
                                        _searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                        )
                      : InkWell(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ContactInfoScreen(contactId: widget.receiverId, contactName: widget.contactName, isGroup: widget.isGroup)));
                          },
                          child: Container(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.contactName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.normal, color: statusText == 'typing...' ? Colors.greenAccent : Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                  actions: [
                    if (!_isSearching) ...[
                      IconButton(icon: const Icon(Icons.videocam, size: 22), onPressed: () => _showComingSoonDialog(context, 'Video Call')),
                      IconButton(icon: const Icon(Icons.call, size: 20), onPressed: () => _showComingSoonDialog(context, 'Voice Call')),
                    ],
                    PopupMenuButton<String>(
                      iconSize: 22,
                      onSelected: (value) {
                        switch (value) {
                          case 'view_contact':
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ContactInfoScreen(contactId: widget.receiverId, contactName: widget.contactName, isGroup: widget.isGroup)));
                            break;
                          case 'clear':
                            _chatService.clearChat(widget.receiverId, isGroup: widget.isGroup);
                            break;
                          case 'disappearing':
                            _showDisappearingMessagesDialog();
                            break;
                          case 'lock':
                            _toggleChatLock();
                            break;
                          case 'mute':
                            _showMuteDialog();
                            break;
                          case 'wallpaper':
                            _showWallpaperDialog();
                            break;
                          case 'search':
                            setState(() => _isSearching = true);
                            break;
                          case 'media':
                            _showMediaDocs();
                            break;
                          case 'more':
                            _showMoreOptions(context);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'view_contact', child: Text('View Contact')),
                        const PopupMenuItem(value: 'media', child: Text('Media, links, and docs')),
                        const PopupMenuItem(value: 'search', child: Text('Search')),
                        const PopupMenuItem(value: 'mute', child: Text('Mute notifications')),
                        const PopupMenuItem(value: 'disappearing', child: Text('Disappearing messages')),
                        const PopupMenuItem(value: 'wallpaper', child: Text('Wallpaper')),
                        const PopupMenuItem(value: 'lock', child: Text('Lock Chat')),
                        const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
                        const PopupMenuItem(value: 'more', child: Text('More')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : const Color(0xFFE5DDD5),
          image: themeProvider.wallpaperIndex > 0 ? DecorationImage(
            image: NetworkImage('https://res.cloudinary.com/ddvvinsdr/image/upload/v1/wallpapers/wp_${themeProvider.wallpaperIndex}.jpg'),
            fit: BoxFit.cover,
            opacity: 0.4,
          ) : null,
          gradient: currentBackground.gradient,
        ),
        child: Column(
          children: [
            if (themeProvider.isGlassMode) SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
            _buildPinnedMessagesBar(textColor),
            Expanded(
              child: Stack(
                children: [
                  if (currentBackground.patternType != BackgroundPatternType.none)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: PatternPainter(
                          type: currentBackground.patternType,
                          color: currentBackground.patternColor,
                          opacity: isDark ? 0.05 : 0.1,
                        ),
                      ),
                    ),
                  Column(
                    children: [
                      if (_replyTo != null)
                        Container(
                          color: Colors.black12,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text('Replying to: $_replyText', style: TextStyle(color: textColor, fontSize: 12))),
                              IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _replyTo = null)),
                            ],
                          ),
                        ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _chatService.getMessages(widget.receiverId, isGroup: widget.isGroup),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _markMessagesAsRead();
                            });

                            final messages = snapshot.data!.docs.where((doc) {
                              if (_searchQuery.isEmpty) return true;
                              final data = doc.data() as Map<String, dynamic>;
                              final type = data['type'] ?? 'text';
                              if (type == 'text') {
                                final text = data['message'] ?? '';
                                return text.toString().toLowerCase().contains(_searchQuery);
                              }
                              return false;
                            }).toList();
                            return ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final doc = messages[index];
                                final data = doc.data() as Map<String, dynamic>;
                                return _buildMessageBubble(doc.id, data, isDark, textColor, secondaryTextColor);
                              },
                            );
                          },
                        ),
                      ),
                      if (_smartReplies.isNotEmpty)
                        _buildSmartRepliesBar(),
                      _buildBottomBar(themeProvider, textColor, secondaryTextColor),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisappearingMessagesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Disappearing Messages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Off'), leading: Radio(value: 0, groupValue: _disappearingTimer, onChanged: (v)=>_setTimer(0))),
            ListTile(title: const Text('24 Hours'), leading: Radio(value: 86400, groupValue: _disappearingTimer, onChanged: (v)=>_setTimer(86400))),
            ListTile(title: const Text('7 Days'), leading: Radio(value: 604800, groupValue: _disappearingTimer, onChanged: (v)=>_setTimer(604800))),
            ListTile(title: const Text('90 Days'), leading: Radio(value: 7776000, groupValue: _disappearingTimer, onChanged: (v)=>_setTimer(7776000))),
          ],
        ),
      ),
    );
  }

  void _setTimer(int seconds) {
    setState(() => _disappearingTimer = seconds);
    final chatId = widget.isGroup ? widget.receiverId : _chatService.getChatId(_currentUserId!, widget.receiverId);
    FirebaseFirestore.instance.collection('chats').doc(chatId).update({'disappearingTimer': seconds});
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disappearing messages set to ${seconds == 0 ? "Off" : (seconds ~/ 3600).toString() + " hours"}')));
  }

  void _toggleChatLock() async {
    final security = SecurityService();
    final success = await security.authenticate();
    if (success) {
      final chatId = widget.isGroup ? widget.receiverId : _chatService.getChatId(_currentUserId!, widget.receiverId);
      setState(() => _isLocked = !_isLocked);
      _chatService.toggleChatLock(chatId, _isLocked);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isLocked ? 'Chat locked' : 'Chat unlocked')));
    }
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.report_problem_outlined), title: const Text('Report'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.block), title: const Text('Block'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.exit_to_app), title: const Text('Exit group'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.shortcut), title: const Text('Add shortcut'), onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _showMuteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mute Notifications'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('8 Hours'), onTap: () => _muteChat(8)),
            ListTile(title: const Text('1 Week'), onTap: () => _muteChat(168)),
            ListTile(title: const Text('Always'), onTap: () => _muteChat(87600)),
          ],
        ),
      ),
    );
  }

  void _muteChat(int hours) async {
    final chatId = widget.isGroup ? widget.receiverId : _chatService.getChatId(_currentUserId!, widget.receiverId);
    await _chatService.muteChat(chatId, hours);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notifications muted for $hours hours')));
  }

  void _showWallpaperDialog() {
    final themeProvider = Provider.of<ScreenThemeProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose Wallpaper', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: chatBackgrounds.length,
                itemBuilder: (context, index) {
                  final bg = chatBackgrounds[index];
                  return GestureDetector(
                    onTap: () {
                      themeProvider.setChatBackground(index);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: bg.gradient,
                        border: Border.all(color: themeProvider.chatBackgroundIndex == index ? Colors.green : Colors.transparent, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(bg.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaDocs() {
     Navigator.push(context, MaterialPageRoute(builder: (context) => ChatMediaScreen(chatId: widget.isGroup ? widget.receiverId : _chatService.getChatId(_currentUserId!, widget.receiverId))));
  }

  Widget _buildPinnedMessagesBar(Color textColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getPinnedMessages(widget.receiverId, widget.isGroup),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        final pinnedDocs = snapshot.data!.docs;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.push_pin, size: 16, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (pinnedDocs.first.data() as Map<String, dynamic>)['message'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                if (pinnedDocs.length > 1)
                  Text("${pinnedDocs.length} pinned", style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmartRepliesBar() {
    return Container(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _smartReplies.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ActionChip(
            label: Text(_smartReplies[index], style: const TextStyle(fontSize: 11)),
            padding: EdgeInsets.zero,
            onPressed: () {
              _messageController.text = _smartReplies[index];
              _sendMessage();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ScreenThemeProvider themeProvider, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: themeProvider.getColor('card'),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey, size: 22), onPressed: () {}),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: _onTextChanged,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey, size: 22),
                    onPressed: _showAttachmentMenu,
                  ),
                  IconButton(icon: const Icon(Icons.camera_alt, color: Colors.grey, size: 22), onPressed: () => _pickImage(ImageSource.camera)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onLongPress: _messageController.text.isEmpty ? _startRecording : null,
            onLongPressUp: _messageController.text.isEmpty ? _stopRecording : null,
            child: CircleAvatar(
              backgroundColor: const Color(0xFF25D366),
              radius: 22,
              child: IconButton(
                icon: Icon(
                  _messageController.text.isEmpty ? Icons.mic : Icons.send, 
                  color: Colors.white, 
                  size: 22
                ),
                onPressed: _messageController.text.isEmpty ? null : _sendMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _buildAttachOption(Icons.description, Colors.indigo, 'Document', onTap: _pickDocument),
            _buildAttachOption(Icons.camera_alt, Colors.pink, 'Camera', onTap: () => _pickImage(ImageSource.camera)),
            _buildAttachOption(Icons.photo, Colors.purple, 'Gallery', onTap: () => _pickImage(ImageSource.gallery)),
            _buildAttachOption(Icons.videocam, Colors.red, 'Video', onTap: _pickVideo),
            _buildAttachOption(Icons.location_on, Colors.green, 'Location', onTap: _shareLocation),
            _buildAttachOption(Icons.person, Colors.blue, 'Contact', onTap: _pickContact),
            _buildAttachOption(Icons.movie_creation, Colors.deepOrange, 'AI Video', onTap: _createAIVideo),
            _buildAttachOption(Icons.receipt_long, Colors.teal, 'Invoice', onTap: _showInvoiceDialog),
            _buildAttachOption(Icons.videogame_asset, Colors.deepPurple, 'Games', onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => GamesScreen(chatId: widget.receiverId)));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachOption(IconData icon, Color color, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () => Navigator.pop(context),
      child: Container(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 26, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 24)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String messageId, Map<String, dynamic> data, bool isDark, Color textColor, Color secondaryTextColor) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context, listen: false);
    final bool isMe = data['senderId'] == _currentUserId;
    final String type = data['type'] ?? 'text';
    final String messageText = data['message'] ?? '';
    final String? imageUrl = data['imageUrl'];
    final String? videoUrl = data['videoUrl'];
    final bool isPinned = data['isPinned'] ?? false;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showReactionAndOptions(messageId, type, messageText, isMe, imageUrl, isPinned),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFDCF8C6) : (isDark ? Colors.grey.shade800 : Colors.white),
            borderRadius: BorderRadius.circular(themeProvider.bubbleRadius),
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (type == 'text') Text(messageText, style: TextStyle(color: isDark && !isMe ? Colors.white : Colors.black87, fontSize: 13)),
              if (type == 'image' && imageUrl != null) 
                 ClipRRect(
                   borderRadius: BorderRadius.circular(themeProvider.bubbleRadius > 5 ? themeProvider.bubbleRadius - 5 : 0),
                   child: Image.network(imageUrl, loadingBuilder: (context, child, loadingProgress) {
                     if (loadingProgress == null) return child;
                     return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2));
                   }),
                 ),
              if (type == 'video' && videoUrl != null)
                _buildVideoThumbnail(videoUrl),
              if (type == 'voice') VoiceMessageWidget(audioUrl: data['audioUrl'], isMe: isMe, meColor: const Color(0xFFDCF8C6), otherColor: Colors.white),
              if (type == 'ajo_invitation') _buildAjoInvitationBubble(messageId, data['metadata'] ?? {}, isMe, themeProvider),
              if (type == 'invoice') _buildInvoiceBubble(data['metadata'] ?? {}, isMe, messageId, const Color(0xFFDCF8C6), Colors.white, Colors.black87),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '10:00 AM',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                  ),
                  if (isPinned) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.push_pin, size: 10, color: Colors.grey),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(String url) {
    return GestureDetector(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.movie_outlined, size: 50, color: Colors.grey),
          ),
          const CircleAvatar(
            backgroundColor: Colors.black54,
            child: Icon(Icons.play_arrow, color: Colors.white),
          ),
          const Positioned(
            bottom: 8,
            right: 8,
            child: Text('AI VIDEO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReactionAndOptions(String messageId, String type, String text, bool isMe, String? imageUrl, bool isPinned) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(isPinned ? 'Unpin Message' : 'Pin Message'),
              onTap: () {
                _chatService.pinMessage(widget.receiverId, messageId, !isPinned, widget.isGroup);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                // Delete logic
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAjoInvitationBubble(String messageId, Map<String, dynamic> data, bool isMe, ScreenThemeProvider theme) {
    final bool isExpired = data['isUsed'] ?? false;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('ajo_groups').doc(data['id']).snapshots(),
      builder: (context, snapshot) {
        bool isJoined = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final groupData = snapshot.data!.data() as Map<String, dynamic>;
          final members = List<String>.from(groupData['members'] ?? []);
          isJoined = members.contains(_currentUserId);
        }

        return Container(
          width: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFDCF8C6) : (isExpired ? Colors.grey.shade200 : Colors.blue.shade50),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isExpired ? Colors.grey : Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isExpired ? Icons.history : Icons.mail_outline, color: isExpired ? Colors.grey : Colors.blue),
                  const SizedBox(width: 8),
                  Text(isExpired ? 'Invitation Expired' : 'Ajo Invitation', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: isExpired ? Colors.grey : Colors.blue.shade800)),
                ],
              ),
              const SizedBox(height: 12),
              Text(isExpired ? 'This invitation has already been used.' : 'You have been invited to join ${data['name']}', 
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isExpired ? Colors.grey : Colors.black87)),
              if (!isExpired) ...[
                const SizedBox(height: 8),
                Text('Amount: ₦${data['contributionAmount']} / ${data['frequencyType']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
              const SizedBox(height: 16),
              if (!isMe)
                ElevatedButton(
                  onPressed: isExpired ? null : () => _acceptInvitation(messageId, data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isJoined ? Colors.green : (isExpired ? Colors.grey : Colors.blue),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 36),
                    elevation: 0,
                  ),
                  child: Text(isExpired ? 'Used' : (isJoined ? 'Open Dashboard' : 'Accept & Join')),
                ),
            ],
          ),
        );
      }
    );
  }

  void _acceptInvitation(String messageId, Map<String, dynamic> data) async {
    final groupId = data['id'];
    final doc = await FirebaseFirestore.instance.collection('ajo_groups').doc(groupId).get();
    if (!doc.exists) return;

    final members = List<String>.from(doc.data()?['members'] ?? []);
    
    if (!members.contains(_currentUserId)) {
      await FirebaseFirestore.instance.collection('ajo_groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([_currentUserId]),
        'payoutStatus.$_currentUserId': false,
      });
    }

    // Mark invitation message as used/expired
    final chatId = widget.isGroup ? widget.receiverId : _chatService.getChatId(_currentUserId!, widget.receiverId);
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'metadata.isUsed': true,
    });

    if (mounted) {
      if (!members.contains(_currentUserId)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined Ajo Group successfully!'), backgroundColor: Colors.green));
      }
      Navigator.push(context, MaterialPageRoute(builder: (context) => AjoDashboardScreen(groupId: groupId)));
    }
  }

  Widget _buildInvoiceBubble(Map<String, dynamic> data, bool isMe, String messageId, Color meColor, Color otherColor, Color textColor) {
    final amount = data['amount'] ?? 0.0;
    final itemName = data['itemName'] ?? 'Item';
    final status = data['status'] ?? 'Pending';
    final isEscrow = data['type'] == 'Escrow';

    return Container(
      width: 200,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? meColor : otherColor,
        borderRadius: BorderRadius.circular(10),
        border: isEscrow ? Border.all(color: Colors.blue) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isEscrow ? '🛡️ ESCROW INVOICE' : '🧾 INVOICE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
          Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text('₦${NumberFormat('#,###').format(amount)}', style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w900)),
          Text('Status: $status', style: const TextStyle(fontSize: 11)),
          if (!isMe && status == 'Pending')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton(
                onPressed: () {}, 
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 36)),
                child: const Text('PAY NOW', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
