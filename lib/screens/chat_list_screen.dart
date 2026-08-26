import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/widgets/avatar.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/screens/settings_screen.dart';
import 'package:whatsapp_clone/screens/contacts_screen.dart';
import 'package:whatsapp_clone/screens/groups_screen.dart';
import 'package:whatsapp_clone/services/security_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _showAdvancedSearch() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Provider.of<ScreenThemeProvider>(context, listen: false).getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        final theme = Provider.of<ScreenThemeProvider>(context);
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Advanced Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: theme.getColor('text'))),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.blue, Colors.purple]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.psychology, color: Colors.white),
                ),
                title: Text('Titan AI Search', style: TextStyle(fontWeight: FontWeight.bold, color: theme.getColor('text'))),
                subtitle: const Text('Search by context: "Find addresses", "Show receipts"', style: TextStyle(fontSize: 10)),
                onTap: () {
                  Navigator.pop(context);
                  _showAISearchDialog();
                },
              ),
              const Divider(),
              _searchOption(Icons.calendar_today, 'Search by Date', theme),
              _searchOption(Icons.image, 'Media, Links, and Docs', theme),
              _searchOption(Icons.person, 'Search by Sender', theme),
              _searchOption(Icons.mic, 'Voice Notes', theme),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search keywords...',
                  filled: true,
                  fillColor: theme.getColor('inputFill'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAISearchDialog() {
    final searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧠 Titan AI Search'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Ask Titan: "Show me the food photos from last week"',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🔎 Titan is analyzing your chats...')),
              );
            },
            child: const Text('SEARCH'),
          ),
        ],
      ),
    );
  }

  void _showChatOptions(String chatId, bool isPinned, bool isLocked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Provider.of<ScreenThemeProvider>(context, listen: false).getColor('card'),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: Colors.grey),
              title: Text(isPinned ? 'Unpin Chat' : 'Pin Chat'),
              onTap: () {
                Navigator.pop(context);
                final chatService = ChatService();
                chatService.pinChat(chatId, !isPinned);
              },
            ),
            ListTile(
              leading: Icon(isLocked ? Icons.lock_open : Icons.lock, color: Colors.grey),
              title: Text(isLocked ? 'Unlock Chat' : 'Lock Chat (Biometric)'),
              onTap: () async {
                Navigator.pop(context);
                final security = SecurityService();
                final success = await security.authenticate();
                if (success) {
                  final chatService = ChatService();
                  chatService.toggleChatLock(chatId, !isLocked);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                // Implementation for delete
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchOption(IconData icon, String label, ScreenThemeProvider theme) {
    return ListTile(
      leading: Icon(icon, color: theme.getColor('primary')),
      title: Text(label, style: TextStyle(color: theme.getColor('text'))),
      onTap: () => Navigator.pop(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final appBarColor = themeProvider.getColor('appBar');
    final scaffoldColor = themeProvider.getColor('scaffold');
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text('Chats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: themeProvider.getColor('appBarText'))),
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_outlined), 
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GroupsScreen()),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: _showAdvancedSearch),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _auth.currentUser == null 
        ? Center(child: Text('Please log in', style: TextStyle(color: textColor)))
        : ListView(
            children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'GROUPS',
              style: TextStyle(
                color: secondaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('groups')
                .where('members', arrayContains: _auth.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }
              final groups = snapshot.data!.docs;
              return SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final data = groups[index].data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Group';
                    final photoUrl = data['photoUrl'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 20.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                contactName: name,
                                receiverId: groups[index].id,
                                isGroup: true,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Avatar(name: name, imageUrl: photoUrl, size: 65),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 12, 
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          
          const SizedBox(height: 8),

          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('chats')
                .where('participants', arrayContains: _auth.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: textColor)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ));
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 80, color: secondaryTextColor.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No chats yet',
                          style: TextStyle(color: secondaryTextColor, fontSize: 16),
                        ),
                        Text(
                          'Start a conversation with your contacts',
                          style: TextStyle(color: secondaryTextColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final chats = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final doc = chats[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final participants = List<String>.from(data['participants'] ?? []);
                  final otherUserId = participants.firstWhere(
                    (id) => id != _auth.currentUser!.uid,
                    orElse: () => '',
                  );

                  final isPinned = data['isPinned'] ?? false;
                  final isLocked = data['isLocked'] ?? false;
                  final chatId = doc.id;

                  if (otherUserId.isEmpty) {
                    return ListTile(
                      leading: Avatar(name: 'You', size: 50),
                      title: Text('Note to Self', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      subtitle: Text(data['lastMessage'] ?? '', style: TextStyle(color: secondaryTextColor)),
                      onTap: () {
                         Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              contactName: 'Note to Self',
                              receiverId: _auth.currentUser!.uid,
                            ),
                          ),
                        );
                      },
                    );
                  }

                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('users').doc(otherUserId).get(),
                    builder: (context, userSnap) {
                      final userData = userSnap.data?.data() as Map<String, dynamic>?;
                      final name = userSnap.hasData ? (userData?['name'] ?? 'Contact') : 'Loading...';
                      final photoUrl = userSnap.hasData ? (userData?['photoUrl'] as String?) : null;
                      final isTitanElite = userData?['isTitanElite'] ?? false;
                      
                      if (isLocked) {
                        return ListTile(
                          leading: Stack(
                            children: [
                              Avatar(name: name, imageUrl: photoUrl, size: 50, isTitanElite: isTitanElite),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: const Icon(Icons.lock, size: 14, color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                          title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                          subtitle: Text('Locked Chat', style: TextStyle(color: secondaryTextColor, fontStyle: FontStyle.italic)),
                          onTap: () async {
                            final security = SecurityService();
                            final success = await security.authenticate();
                            if (success) {
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      contactName: name,
                                      receiverId: otherUserId,
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          onLongPress: () => _showChatOptions(chatId, isPinned, isLocked),
                        );
                      }

                      final lastMessage = data['lastMessage'] ?? '';
                      final lastSenderId = data['lastSenderId'];
                      final lastMessageRead = data['lastMessageRead'] ?? false;
                      final isMe = lastSenderId == _auth.currentUser!.uid;

                      final lastTime = (data['lastMessageTime'] as Timestamp?)?.toDate();
                      final timeStr = lastTime != null ? "${lastTime.hour.toString().padLeft(2, '0')}:${lastTime.minute.toString().padLeft(2, '0')}" : '';

                      return ListTile(
                        leading: Avatar(name: name, imageUrl: photoUrl, size: 50, isTitanElite: isTitanElite),
                        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        subtitle: Row(
                          children: [
                            if (isMe) ...[
                              Icon(
                                lastMessageRead ? Icons.done_all : Icons.done,
                                size: 16,
                                color: lastMessageRead ? Colors.blue : secondaryTextColor,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                lastMessage, 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis, 
                                style: TextStyle(color: secondaryTextColor),
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(timeStr, style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                            if (isPinned) const Icon(Icons.push_pin, size: 16, color: Colors.grey),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                contactName: name,
                                receiverId: otherUserId,
                              ),
                            ),
                          );
                        },
                        onLongPress: () => _showChatOptions(chatId, isPinned, isLocked),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ContactsScreen()),
          );
        },
        backgroundColor: themeProvider.getColor('primary'),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }
}
