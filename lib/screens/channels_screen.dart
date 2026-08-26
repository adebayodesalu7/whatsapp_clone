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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Titan Elite Communities',
                style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -0.4),
              ),
              Icon(Icons.hub_outlined, color: themeProvider.getColor('primary'), size: 16),
            ],
          ),
        ),
        SizedBox(
          height: 120,
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
                      width: 90,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: themeProvider.getColor('primary').withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: themeProvider.getColor('primary').withOpacity(0.1)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Avatar(name: name, size: 55, isTitanElite: true),
                              Positioned(
                                bottom: -1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade800,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('TITAN', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name, 
                            style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold), 
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
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
          child: Text(
            'Trending Channels',
            style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Text(
            'Follow channels for updates.',
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('channels').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
            
            final channels = snapshot.data!.docs;
            
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: channels.length,
              separatorBuilder: (context, index) => Divider(indent: 64, height: 1, color: secondaryTextColor.withOpacity(0.05)),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  leading: Avatar(name: name, imageUrl: icon, size: 45),
                  title: Row(
                    children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
                      if (isAdmin) const SizedBox(width: 4),
                      if (isAdmin) Icon(Icons.verified, color: themeProvider.getColor('primary'), size: 14),
                    ],
                  ),
                  subtitle: Text('$followersCount followers', style: TextStyle(color: secondaryTextColor, fontSize: 11)),
                  trailing: ElevatedButton(
                    onPressed: () {
                      ChatService().toggleFollowChannel(channelId, !isFollowing);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.grey.withOpacity(0.1) : themeProvider.getColor('primary').withOpacity(0.1),
                      foregroundColor: isFollowing ? textColor : themeProvider.getColor('primary'),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text(isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
