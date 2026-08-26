import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/widgets/avatar.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_clone/screens/channel_chat_screen.dart';
import 'package:whatsapp_clone/screens/community_detail_screen.dart';

class ChannelsScreen extends StatelessWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final textColor = themeProvider.getColor('text');

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: const Text('Channels', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeProvider.getColor('appBar'),
        foregroundColor: themeProvider.getColor('appBarText'),
      ),
      body: Column(
        children: [
          _buildCommunitiesSection(context, themeProvider),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Trending Channels',
              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('channels').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final channels = snapshot.data!.docs;
                
                return ListView.builder(
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    final data = channels[index].data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Channel';
                    final followersCount = data['followersCount'] ?? 0;
                    final icon = data['iconUrl'];
                    final channelId = channels[index].id;
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final followers = List<String>.from(data['followers'] ?? []);
                    final admins = List<String>.from(data['admins'] ?? []);
                    final isFollowing = currentUser != null && followers.contains(currentUser.uid);
                    final isAdmin = currentUser != null && (admins.contains(currentUser.uid) || data['createdBy'] == currentUser.uid);

                    return ListTile(
                      leading: Avatar(name: name, imageUrl: icon, size: 50),
                      title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      subtitle: Text('$followersCount followers', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      trailing: isAdmin 
                        ? Icon(Icons.verified, color: themeProvider.getColor('primary'), size: 20)
                        : ElevatedButton(
                        onPressed: () {
                          ChatService().toggleFollowChannel(channelId, !isFollowing);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? Colors.grey.shade200 : themeProvider.getColor('primary'),
                          foregroundColor: isFollowing ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChannelChatScreen(
                              channelId: channelId,
                              channelName: name,
                              isAdmin: isAdmin,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateChannelDialog(context, themeProvider),
        backgroundColor: themeProvider.getColor('primary'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Channel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCommunitiesSection(BuildContext context, ScreenThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Titan Communities',
            style: TextStyle(color: themeProvider.getColor('text'), fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 120,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('communities').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final communities = snapshot.data!.docs;
              if (communities.isEmpty) return const Center(child: Text("No communities yet", style: TextStyle(fontSize: 10, color: Colors.grey)));
              
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: communities.length,
                itemBuilder: (context, index) {
                  final data = communities[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Community';
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CommunityDetailScreen(communityId: communities[index].id))),
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Avatar(name: name, size: 65, isTitanElite: true),
                          const SizedBox(height: 8),
                          Text(name, style: TextStyle(color: themeProvider.getColor('text'), fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Divider(),
      ],
    );
  }

  void _showCreateChannelDialog(BuildContext context, ScreenThemeProvider themeProvider) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.getColor('card'),
        title: Text('Create New Channel', style: TextStyle(color: themeProvider.getColor('text'))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Channel Name',
                hintStyle: TextStyle(color: themeProvider.getColor('textSecondary')),
              ),
              style: TextStyle(color: themeProvider.getColor('text')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                hintText: 'Description',
                hintStyle: TextStyle(color: themeProvider.getColor('textSecondary')),
              ),
              style: TextStyle(color: themeProvider.getColor('text')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
                final uid = FirebaseAuth.instance.currentUser!.uid;
                await FirebaseFirestore.instance.collection('channels').add({
                  'name': nameController.text,
                  'description': descController.text,
                  'followersCount': 1,
                  'followers': [uid],
                  'admins': [uid],
                  'createdBy': uid,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: themeProvider.getColor('primary')),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
