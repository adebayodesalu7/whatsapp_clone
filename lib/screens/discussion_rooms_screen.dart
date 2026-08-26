import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';

class DiscussionRoomsScreen extends StatefulWidget {
  const DiscussionRoomsScreen({super.key});

  @override
  State<DiscussionRoomsScreen> createState() => _DiscussionRoomsScreenState();
}

class _DiscussionRoomsScreenState extends State<DiscussionRoomsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _shareRoomLink(String roomId, String title) {
    final link = 'https://chatapp.com/join/room/$roomId';
    Clipboard.setData(ClipboardData(text: 'Join my discussion room "$title" on ChatApp: $link'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Join link copied to clipboard! Share it with your friends.')),
    );
  }

  void _showCreateRoomDialog(ScreenThemeProvider themeProvider) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.getColor('card'),
        title: Text('Create Discussion Room', style: TextStyle(color: themeProvider.getColor('text'), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: TextStyle(color: themeProvider.getColor('text')),
              decoration: InputDecoration(
                labelText: 'Room Title',
                labelStyle: TextStyle(color: themeProvider.getColor('textSecondary')),
              ),
            ),
            TextField(
              controller: descController,
              style: TextStyle(color: themeProvider.getColor('text')),
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: themeProvider.getColor('textSecondary')),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: themeProvider.getColor('textSecondary')))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeProvider.getColor('primary')),
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                await _firestore.collection('discussion_rooms').add({
                  'title': titleController.text,
                  'description': descController.text,
                  'createdAt': FieldValue.serverTimestamp(),
                  'participants': 1,
                  'creatorId': FirebaseAuth.instance.currentUser?.uid,
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final appBarColor = themeProvider.getColor('appBar');
    final scaffoldColor = themeProvider.getColor('scaffold');
    final cardColor = themeProvider.getColor('card');
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: const Text('Discussion Rooms', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: cardColor,
                title: Text('About Discussion Rooms', style: TextStyle(color: textColor)),
                content: Text('These rooms are temporary and will be automatically deleted 24 hours after creation.', style: TextStyle(color: secondaryTextColor)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
                ],
              ),
            );
          }),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('discussion_rooms').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final now = DateTime.now();
          final docs = snapshot.data?.docs ?? [];
          final rooms = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = data['createdAt'] as Timestamp?;
            if (createdAt == null) return true;
            return now.difference(createdAt.toDate()).inHours < 24;
          }).toList();

          if (rooms.isEmpty) {
            return Center(child: Text('No active discussion rooms.', style: TextStyle(color: secondaryTextColor)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final doc = rooms[index];
              final data = doc.data() as Map<String, dynamic>;
              final createdAt = data['createdAt'] as Timestamp?;
              final timeLeft = createdAt == null ? 24 : 24 - now.difference(createdAt.toDate()).inHours;

              return Card(
                color: cardColor,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(data['title'] ?? 'Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text('⏳ ${timeLeft}h left', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(data['description'] ?? '', style: TextStyle(color: secondaryTextColor)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${data['participants']} participants', style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.share_outlined, color: themeProvider.getColor('primary'), size: 20),
                                onPressed: () => _shareRoomLink(doc.id, data['title'] ?? 'Room'),
                                tooltip: 'Share Room Link',
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  // In a real app, this would add the user to the room's participant list
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Joined "${data['title']}"')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeProvider.getColor('primary'), 
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRoomDialog(themeProvider),
        backgroundColor: themeProvider.getColor('primary'),
        label: const Text('Create Room', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
