import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/widgets/avatar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsapp_clone/services/cloudinary_service.dart';

class ChannelChatScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  final bool isAdmin;
  final String? iconUrl;

  const ChannelChatScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.isAdmin,
    this.iconUrl,
  });

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _chatService.sendChannelMessage(widget.channelId, _messageController.text.trim());
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.getColor('text');

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('channels').doc(widget.channelId).snapshots(),
      builder: (context, channelSnap) {
        final channelData = channelSnap.data?.data() as Map<String, dynamic>? ?? {};
        final channelName = channelData['name'] ?? widget.channelName;
        final channelIcon = channelData['iconUrl'] ?? widget.iconUrl;
        final currentUser = FirebaseAuth.instance.currentUser;
        final followers = List<String>.from(channelData['followers'] ?? []);
        final bool isFollowing = currentUser != null && followers.contains(currentUser.uid);
        final bool canInteract = widget.isAdmin || isFollowing;

        return Scaffold(
          backgroundColor: themeProvider.getColor('scaffold'),
          appBar: AppBar(
            title: GestureDetector(
              onTap: () => _showChannelInfo(themeProvider, channelName, channelIcon),
              child: Row(
                children: [
                  Avatar(name: channelName, imageUrl: channelIcon, size: 36),
                  const SizedBox(width: 10),
                  Text(channelName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            backgroundColor: themeProvider.getColor('appBar'),
            actions: [
              if (widget.isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDeleteChannel(context),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('channels')
                      .doc(widget.channelId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final messages = snapshot.data!.docs;
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final data = messages[index].data() as Map<String, dynamic>;
                        return _buildChannelMessage(data, messages[index].id, themeProvider, canInteract);
                      },
                    );
                  },
                ),
              ),
              if (widget.isAdmin)
                SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFormattingToolbar(),
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: isDark ? Colors.grey.shade900 : Colors.white,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxHeight: MediaQuery.of(context).size.height * 0.25,
                                ),
                                child: TextField(
                                  controller: _messageController,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    hintText: 'Broadcast to channel...',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                                    filled: true,
                                    fillColor: themeProvider.getColor('scaffold'),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            CircleAvatar(
                              backgroundColor: themeProvider.getColor('primary'),
                              child: IconButton(
                                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                                onPressed: _sendMessage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.black.withOpacity(0.05),
                  child: const Text(
                    'Only admins can post messages to this channel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChannelMessage(Map<String, dynamic> data, String messageId, ScreenThemeProvider theme, bool canInteract) {
    final Map<String, dynamic> reactions = data['reactions'] ?? {};
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.getColor('card'),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: data['message'] ?? '',
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(color: theme.getColor('text'), fontSize: 15),
              strong: const TextStyle(fontWeight: FontWeight.bold),
              em: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 8),
          if (reactions.isNotEmpty)
            Wrap(
              spacing: 8,
              children: reactions.entries.map((e) {
                final Map<String, dynamic> userEmojiMap = e.value is Map ? Map<String, dynamic>.from(e.value) : {};
                final int count = userEmojiMap.length;
                final bool hasReacted = userEmojiMap.containsKey(FirebaseAuth.instance.currentUser?.uid);

                return GestureDetector(
                  onTap: canInteract ? () => _toggleReaction(messageId, e.key, reactions) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasReacted 
                        ? theme.getColor('primary').withOpacity(0.2) 
                        : theme.getColor('primary').withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasReacted ? theme.getColor('primary') : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text('${e.key} $count', style: TextStyle(fontSize: 12, fontWeight: hasReacted ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timestamp != null ? DateFormat('HH:mm').format(timestamp) : 'Broadcast',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
              Row(
                children: [
                  if (canInteract)
                    IconButton(
                      icon: const Icon(Icons.add_reaction_outlined, size: 18, color: Colors.grey),
                      onPressed: () => _showReactionPicker(messageId, reactions),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  if (widget.isAdmin) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                      onPressed: () => _showEditMessageDialog(messageId, data['message'] ?? '', theme),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(right: 8),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      onPressed: () => _chatService.deleteChannelMessage(widget.channelId, messageId),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(String messageId, Map<String, dynamic> currentReactions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
            return InkWell(
              onTap: () {
                _toggleReaction(messageId, emoji, currentReactions);
                Navigator.pop(context);
              },
              child: Text(emoji, style: const TextStyle(fontSize: 30)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _toggleReaction(String messageId, String emoji, Map<String, dynamic> currentReactions) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final Map<String, dynamic> updated = Map<String, dynamic>.from(currentReactions);
    
    // We'll use a structure of { emoji: { uid: true } }
    // This makes it easy to handle migration and prevents duplicate reactions
    
    Map<String, dynamic> emojiMap = {};
    var existing = updated[emoji];
    
    if (existing is Map) {
      emojiMap = Map<String, dynamic>.from(existing);
    } else if (existing is List) {
      // Migrate from List to Map
      for (var id in existing) {
        emojiMap[id.toString()] = true;
      }
    } else if (existing is int) {
      // Migrate from int (cannot know UIDs, so start fresh or ignore)
      emojiMap = {};
    }

    if (emojiMap.containsKey(uid)) {
      emojiMap.remove(uid);
    } else {
      // Remove this user from any OTHER emoji reactions on this message
      updated.forEach((key, value) {
        if (value is Map) {
          final Map<String, dynamic> m = Map<String, dynamic>.from(value);
          if (m.containsKey(uid)) {
            m.remove(uid);
            updated[key] = m;
          }
        }
      });
      emojiMap[uid] = true;
    }

    // Update the map for this emoji
    if (emojiMap.isEmpty) {
      updated.remove(emoji);
    } else {
      updated[emoji] = emojiMap;
    }

    // Clean up empty reaction entries
    final Map<String, dynamic> finalUpdated = {};
    updated.forEach((key, value) {
       if (value is Map && value.isNotEmpty) {
         finalUpdated[key] = value;
       }
    });
    
    await FirebaseFirestore.instance
        .collection('channels')
        .doc(widget.channelId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions': finalUpdated});
  }

  Widget _buildFormattingToolbar({TextEditingController? controller}) {
    final target = controller ?? _messageController;
    return Container(
      color: Colors.black.withOpacity(0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _formatButton(Icons.format_bold, () => _applyFormat(target, '**', '**')),
          _formatButton(Icons.format_italic, () => _applyFormat(target, '*', '*')),
          _formatButton(Icons.format_list_bulleted, () => _applyFormat(target, '\n- ', '')),
          _formatButton(Icons.format_list_numbered, () => _applyFormat(target, '\n1. ', '')),
          _formatButton(Icons.title, () => _applyFormat(target, '### ', '')),
          _formatButton(Icons.format_quote, () => _applyFormat(target, '> ', '')),
        ],
      ),
    );
  }

  Widget _formatButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20, color: Colors.blue),
      onPressed: onPressed,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(8),
    );
  }

  void _applyFormat(TextEditingController controller, String prefix, String suffix) {
    final text = controller.text;
    final selection = controller.selection;
    
    if (selection.start == -1) {
      controller.text = text + prefix + suffix;
      return;
    }

    final selectedText = text.substring(selection.start, selection.end);
    final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
    
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + prefix.length + selectedText.length + suffix.length),
    );
  }

  void _showEditMessageDialog(String messageId, String currentText, ScreenThemeProvider theme) {
    final controller = TextEditingController(text: currentText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Broadcast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.getColor('text'))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 10),
            _buildFormattingToolbar(controller: controller),
            const SizedBox(height: 10),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.black.withOpacity(0.05),
              ),
              child: TextField(
                controller: controller,
                style: TextStyle(color: theme.getColor('text'), fontSize: 15),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                  hintText: 'Enter message...',
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('channels')
                      .doc(widget.channelId)
                      .collection('messages')
                      .doc(messageId)
                      .update({'message': controller.text.trim()});
                  if (mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.getColor('primary'),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChannelInfo(ScreenThemeProvider theme, String name, String? icon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(name: name, imageUrl: icon, size: 80),
            const SizedBox(height: 16),
            Text(name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.getColor('text'))),
            const SizedBox(height: 8),
            const Text('Official Channel', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (widget.isAdmin) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Edit Channel Info'),
                onPressed: () {
                  Navigator.pop(context);
                  _showEditChannelDialog(theme, name, icon);
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Manage Admins (Delegation)'),
                onPressed: () {
                   Navigator.pop(context);
                   _showManageAdminsDialog(theme);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditChannelDialog(ScreenThemeProvider theme, String currentName, String? currentIcon) {
    final nameController = TextEditingController(text: currentName);
    String? newIconUrl = currentIcon;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.getColor('card'),
          title: Text('Edit Channel', style: TextStyle(color: theme.getColor('text'))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setDialogState(() => isUploading = true);
                      final url = await CloudinaryService().uploadImage(image);
                      setDialogState(() {
                        newIconUrl = url;
                        isUploading = false;
                      });
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.getColor('primary').withOpacity(0.1),
                    backgroundImage: newIconUrl != null ? NetworkImage(newIconUrl!) : null,
                    child: isUploading 
                      ? const CircularProgressIndicator()
                      : (newIconUrl == null ? const Icon(Icons.add_a_photo, color: Colors.blue) : null),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'Channel Name'),
                  style: TextStyle(color: theme.getColor('text')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: isUploading ? null : () async {
                await _chatService.updateChannel(widget.channelId, {
                  'name': nameController.text,
                  'iconUrl': newIconUrl,
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageAdminsDialog(ScreenThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.getColor('card'),
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('channels').doc(widget.channelId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final followers = List<String>.from(data['followers'] ?? []);
          final admins = List<String>.from(data['admins'] ?? []);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Followers (Promote to Admin)', style: TextStyle(fontWeight: FontWeight.bold, color: theme.getColor('text'))),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: followers.length,
                  itemBuilder: (context, index) {
                    final uid = followers[index];
                    if (admins.contains(uid)) return const SizedBox.shrink();

                    return ListTile(
                      title: Text(uid, style: TextStyle(color: theme.getColor('text'))), // In real app, fetch name
                      trailing: TextButton(
                        onPressed: () => _chatService.promoteToAdmin(widget.channelId, uid),
                        child: const Text('Promote'),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteChannel(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Channel?'),
        content: const Text('This will permanently delete the channel and all its messages. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _chatService.deleteChannel(widget.channelId);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Exit channel
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
