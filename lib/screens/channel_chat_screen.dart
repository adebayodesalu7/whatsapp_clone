import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/widgets/avatar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChannelChatScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  final bool isAdmin;

  const ChannelChatScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.isAdmin,
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

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showChannelInfo(themeProvider),
          child: Row(
            children: [
              Avatar(name: widget.channelName, size: 36),
              const SizedBox(width: 10),
              Text(widget.channelName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    return _buildChannelMessage(data, messages[index].id, themeProvider);
                  },
                );
              },
            ),
          ),
          if (widget.isAdmin)
            Container(
              padding: const EdgeInsets.all(8),
              color: isDark ? Colors.grey.shade900 : Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Broadcast to channel...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: themeProvider.getColor('scaffold'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: themeProvider.getColor('primary')),
                    onPressed: _sendMessage,
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
  }

  Widget _buildChannelMessage(Map<String, dynamic> data, String messageId, ScreenThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.getColor('card'),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['message'] ?? '', style: TextStyle(color: theme.getColor('text'), fontSize: 15)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Broadcast', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
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
    );
  }

  void _showEditMessageDialog(String messageId, String currentText, ScreenThemeProvider theme) {
    final controller = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.getColor('card'),
        title: Text('Edit Broadcast', style: TextStyle(color: theme.getColor('text'))),
        content: TextField(
          controller: controller,
          style: TextStyle(color: theme.getColor('text')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('channels')
                  .doc(widget.channelId)
                  .collection('messages')
                  .doc(messageId)
                  .update({'message': controller.text.trim()});
              if (mounted) Navigator.pop(context);
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  void _showChannelInfo(ScreenThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(name: widget.channelName, size: 80),
            const SizedBox(height: 16),
            Text(widget.channelName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.getColor('text'))),
            const SizedBox(height: 8),
            const Text('Official Channel', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (widget.isAdmin) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Edit Channel Info'),
                onPressed: () {
                  Navigator.pop(context);
                  _showEditChannelDialog(theme);
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

  void _showEditChannelDialog(ScreenThemeProvider theme) {
    final nameController = TextEditingController(text: widget.channelName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.getColor('card'),
        title: Text('Edit Channel', style: TextStyle(color: theme.getColor('text'))),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Channel Name'),
          style: TextStyle(color: theme.getColor('text')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _chatService.updateChannel(widget.channelId, {'name': nameController.text});
              if (mounted) Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
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
