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
    final scaffoldColor = themeProvider.getColor('scaffold');

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: const Text('Updates', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeProvider.getColor('appBar'),
        foregroundColor: themeProvider.getColor('appBarText'),
        actions: [
          IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitanEliteSection(context, themeProvider),
            const Divider(height: 1),
            _buildChannelsSection(context, themeProvider),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'create-channel',
            onPressed: () => _showCreateChannelDialog(context, themeProvider),
            backgroundColor: themeProvider.getColor('primary'),
            mini: true,
            child: const Icon(Icons.edit, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'camera',
            onPressed: () {},
            backgroundColor: themeProvider.getColor('primary'),
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTitanEliteSection(BuildContext context, ScreenThemeProvider themeProvider) {
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Titan Elite Communities',
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              Icon(Icons.hub_outlined, color: themeProvider.getColor('primary'), size: 20),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('communities').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final communities = snapshot.data!.docs;
              
              if (communities.isEmpty) {
                return Center(
                  child: Text("Join exclusive Titan communities", 
                    style: TextStyle(fontSize: 12, color: secondaryTextColor.withOpacity(0.5))),
                );
              }
              
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
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          Avatar(name: name, size: 75, isTitanElite: true),
                          const SizedBox(height: 10),
                          Text(
                            name, 
                            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold), 
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Communities are interactive hubs for real-time collaboration, networking, and exclusive Titan benefits.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelsSection(BuildContext context, ScreenThemeProvider themeProvider) {
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Trending Channels',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Follow channels to get the latest updates from your favorite creators and businesses.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('channels').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
            
            final channels = snapshot.data!.docs;
            
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: channels.length,
              separatorBuilder: (context, index) => Divider(indent: 80, height: 1, color: secondaryTextColor.withOpacity(0.05)),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Avatar(name: name, imageUrl: icon, size: 55),
                  title: Row(
                    children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                      if (isAdmin) const SizedBox(width: 4),
                      if (isAdmin) Icon(Icons.verified, color: themeProvider.getColor('primary'), size: 16),
                    ],
                  ),
                  subtitle: Text('$followersCount followers', style: TextStyle(color: secondaryTextColor, fontSize: 13)),
                  trailing: ElevatedButton(
                    onPressed: () {
                      ChatService().toggleFollowChannel(channelId, !isFollowing);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.grey.withOpacity(0.1) : themeProvider.getColor('primary').withOpacity(0.1),
                      foregroundColor: isFollowing ? textColor : themeProvider.getColor('primary'),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontWeight: FontWeight.bold)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Create New Channel', style: TextStyle(color: themeProvider.getColor('text'), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Channel Name',
                hintStyle: TextStyle(color: themeProvider.getColor('textSecondary')),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: TextStyle(color: themeProvider.getColor('text')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                hintText: 'Description',
                hintStyle: TextStyle(color: themeProvider.getColor('textSecondary')),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 3,
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
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.getColor('primary'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Create Channel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
