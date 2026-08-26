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
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/services/ai_service.dart';
import 'package:whatsapp_clone/services/storage_service.dart';
import 'package:whatsapp_clone/services/business_service.dart';
import 'package:whatsapp_clone/services/crypto_service.dart';
import 'package:whatsapp_clone/services/escrow_service.dart';
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
import 'group_settings_screen.dart';
import 'games_screen.dart';
import 'titan_docs_screen.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AIService _aiService = AIService();
  final StorageService _storageService = StorageService();
  final BusinessService _businessService = BusinessService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  String? _replyTo;
  String? _replyText;
  List<String> _smartReplies = [];
  Map<String, dynamic>? _appointmentIntent;

  late RecorderController _recorderController;
  bool _isRecording = false;
  int _disappearingTimer = 0;
  bool _isGhostMode = false;
  bool _isLocked = false;
  bool _isAutoPilotEnabled = false;

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController();
    _loadChatSettings();
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
    _recorderController.dispose();
    _messageController.dispose();
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
      final audioUrl = await _storageService.uploadImage(path, 'chat_audio');
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
        _chatService.sendImageMessage(widget.receiverId, imageUrl, widget.isGroup);
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
      _chatService.sendImageMessage(widget.receiverId, gif.images!.original!.url, widget.isGroup);
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
                _chatService.sendInvoiceMessage(widget.receiverId, invoice);
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');
    final appBarColor = themeProvider.getColor('appBar');
    final currentBackground = themeProvider.getChatBackground();

    return Scaffold(
      extendBodyBehindAppBar: themeProvider.isGlassMode,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: themeProvider.isGlassMode ? 12.0 : 0.0,
              sigmaY: themeProvider.isGlassMode ? 12.0 : 0.0,
            ),
            child: AppBar(
              backgroundColor: themeProvider.isGlassMode ? appBarColor.withOpacity(0.7) : appBarColor,
              elevation: 0,
              leadingWidth: 70,
              leading: InkWell(
                onTap: () => Navigator.pop(context),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back),
                    const SizedBox(width: 2),
                    Avatar(name: widget.contactName, size: 36),
                  ],
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.contactName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text('online', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
                ],
              ),
              actions: [
                IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
                IconButton(icon: const Icon(Icons.call), onPressed: () {}),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'clear') _chatService.clearChat(widget.receiverId, isGroup: widget.isGroup);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view_contact', child: Text('View Contact')),
                    const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : const Color(0xFFE5DDD5),
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

                            final messages = snapshot.data!.docs;
                            return ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.all(12),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.push_pin, size: 18, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (pinnedDocs.first.data() as Map<String, dynamic>)['message'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                if (pinnedDocs.length > 1)
                  Text("${pinnedDocs.length} pinned", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmartRepliesBar() {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _smartReplies.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ActionChip(
            label: Text(_smartReplies[index]),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey), onPressed: () {}),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        hintStyle: TextStyle(color: secondaryTextColor),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: _showAttachmentMenu,
                  ),
                  IconButton(icon: const Icon(Icons.camera_alt, color: Colors.grey), onPressed: () => _pickImage(ImageSource.camera)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onLongPress: _startRecording,
            onLongPressUp: _stopRecording,
            child: CircleAvatar(
              backgroundColor: const Color(0xFF25D366),
              radius: 24,
              child: IconButton(
                icon: const Icon(Icons.mic, color: Colors.white),
                onPressed: _sendMessage,
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
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _buildAttachOption(Icons.description, Colors.indigo, 'Document', onTap: _pickDocument),
            _buildAttachOption(Icons.camera_alt, Colors.pink, 'Camera', onTap: () => _pickImage(ImageSource.camera)),
            _buildAttachOption(Icons.photo, Colors.purple, 'Gallery', onTap: () => _pickImage(ImageSource.gallery)),
            _buildAttachOption(Icons.videocam, Colors.red, 'Video', onTap: _pickVideo),
            _buildAttachOption(Icons.location_on, Colors.green, 'Location', onTap: _shareLocation),
            _buildAttachOption(Icons.person, Colors.blue, 'Contact', onTap: _pickContact),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 30, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 28)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String messageId, Map<String, dynamic> data, bool isDark, Color textColor, Color secondaryTextColor) {
    final bool isMe = data['senderId'] == _currentUserId;
    final String type = data['type'] ?? 'text';
    final String messageText = data['message'] ?? '';
    final String? imageUrl = data['imageUrl'];
    final bool isPinned = data['isPinned'] ?? false;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showReactionAndOptions(messageId, type, messageText, isMe, imageUrl, isPinned),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFDCF8C6) : (isDark ? Colors.grey.shade800 : Colors.white),
            borderRadius: BorderRadius.circular(10),
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (type == 'text') Text(messageText, style: TextStyle(color: isDark && !isMe ? Colors.white : Colors.black87)),
              if (type == 'image' && imageUrl != null) Image.network(imageUrl),
              if (type == 'voice') VoiceMessageWidget(audioUrl: data['audioUrl'], isMe: isMe, meColor: const Color(0xFFDCF8C6), otherColor: Colors.white),
              if (type == 'invoice') _buildInvoiceBubble(data['metadata'] ?? {}, isMe, messageId, const Color(0xFFDCF8C6), Colors.white, Colors.black87),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '10:00 AM',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
          Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('₦${NumberFormat('#,###').format(amount)}', style: const TextStyle(fontSize: 18, color: Colors.green)),
          Text('Status: $status', style: const TextStyle(fontSize: 12)),
          if (!isMe && status == 'Pending')
            ElevatedButton(onPressed: () {}, child: const Text('PAY NOW')),
        ],
      ),
    );
  }
}
