import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/models/models.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/screens/audio_stage_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  String _selectedChannelId = 'general';

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').doc(widget.communityId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final community = Community.fromMap(data, widget.communityId);
        
        return Scaffold(
          appBar: AppBar(
            title: Text(community.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: themeProvider.getColor('appBar'),
          ),
          drawer: _buildCommunityDrawer(community, themeProvider),
          body: Column(
            children: [
              _buildLiveStageBar(community),
              Expanded(
                child: ChatScreen(
                  contactName: community.name,
                  receiverId: "${widget.communityId}_$_selectedChannelId",
                  isGroup: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveStageBar(Community community) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AudioStageScreen(stageName: "${community.name} Live Strategy")),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Live Audio Stage Active 🎙️", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text("3 speakers • 12 listeners", style: TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child: const Text("JOIN", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityDrawer(Community community, ScreenThemeProvider themeProvider) {
    return Drawer(
      backgroundColor: themeProvider.getColor('scaffold'),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: themeProvider.getColor('primary')),
            accountName: Text(community.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text("${community.groupIds.length} Groups • Titan Community"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(community.name[0], style: const TextStyle(fontSize: 40)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerHeader("CHANNELS"),
                ...community.channels.map((channel) => ListTile(
                  leading: Icon(_getChannelIcon(channel.type), color: themeProvider.getColor('primary')),
                  title: Text(channel.name, style: TextStyle(color: themeProvider.getColor('text'))),
                  selected: _selectedChannelId == channel.id,
                  onTap: () {
                    setState(() => _selectedChannelId = channel.id);
                    Navigator.pop(context);
                  },
                )),
                const Divider(),
                _drawerHeader("GROUPS"),
                ...community.groupIds.map((groupId) => ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: Text("Group $groupId", style: TextStyle(color: themeProvider.getColor('text'))),
                  onTap: () {},
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  IconData _getChannelIcon(String type) {
    switch (type) {
      case 'announcement': return Icons.campaign;
      case 'voice': return Icons.mic;
      default: return Icons.tag;
    }
  }
}
