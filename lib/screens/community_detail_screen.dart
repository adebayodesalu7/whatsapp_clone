import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/models/models.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/screens/audio_stage_screen.dart';
import 'package:whatsapp_clone/widgets/avatar.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  String _selectedChannelId = 'general';
  String _selectedChannelName = 'General Chat';

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final appBarColor = themeProvider.getColor('appBar');
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').doc(widget.communityId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text("Community not found")));
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final community = Community.fromMap(data, widget.communityId);
        
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AppBar(
                  backgroundColor: appBarColor.withOpacity(0.8),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(community.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("#$_selectedChannelName", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                    ],
                  ),
                  elevation: 0,
                  actions: [
                    IconButton(icon: const Icon(Icons.info_outline, size: 20), onPressed: () {}),
                  ],
                ),
              ),
            ),
          ),
          drawer: _buildCommunityDrawer(community, themeProvider),
          body: Container(
            color: themeProvider.getColor('scaffold'),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
                _buildLiveStageBar(community),
                Expanded(
                  key: ValueKey("${widget.communityId}_$_selectedChannelId"), // Force reload chat on channel switch
                  child: ChatScreen(
                    contactName: "$_selectedChannelName",
                    receiverId: "${widget.communityId}_$_selectedChannelId",
                    isGroup: true,
                  ),
                ),
              ],
            ),
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
          MaterialPageRoute(builder: (context) => AudioStageScreen(stageName: "${community.name} Global Summit")),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6200EE), Color(0xFFBB86FC)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const Icon(Icons.waves, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Live Strategy Stage Active 🎙️", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text("Join the Titan elite voice discussion", style: TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const Text("JOIN", style: TextStyle(color: Color(0xFF6200EE), fontWeight: FontWeight.w900, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityDrawer(Community community, ScreenThemeProvider themeProvider) {
    final textColor = themeProvider.getColor('text');
    final secondaryColor = themeProvider.getColor('textSecondary');

    return Drawer(
      backgroundColor: themeProvider.getColor('scaffold'),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: BoxDecoration(
              color: themeProvider.getColor('primary'),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Row(
              children: [
                Avatar(name: community.name, size: 60, isTitanElite: true),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(community.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      const Text("Titan Elite Verified Community", style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _drawerHeader("COMMUNITY CHANNELS"),
                ...community.channels.map((channel) => _buildChannelTile(channel, themeProvider)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider()),
                _drawerHeader("LINKED GROUPS"),
                ...community.groupIds.map((groupId) => ListTile(
                  leading: CircleAvatar(backgroundColor: secondaryColor.withOpacity(0.1), radius: 15, child: const Icon(Icons.groups, size: 16, color: Colors.grey)),
                  title: Text("Group #$groupId", style: TextStyle(color: textColor, fontSize: 14)),
                  onTap: () {},
                )),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.logout, color: Colors.red, size: 18),
              label: const Text("Leave Community", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTile(CommunityChannel channel, ScreenThemeProvider themeProvider) {
    final isSelected = _selectedChannelId == channel.id;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(_getChannelIcon(channel.type), color: isSelected ? themeProvider.getColor('primary') : Colors.grey, size: 20),
      title: Text(
        channel.name, 
        style: TextStyle(
          color: isSelected ? themeProvider.getColor('primary') : themeProvider.getColor('text'),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() {
          _selectedChannelId = channel.id;
          _selectedChannelName = channel.name;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _drawerHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5)),
    );
  }

  IconData _getChannelIcon(String type) {
    switch (type) {
      case 'announcement': return Icons.campaign_outlined;
      case 'voice': return Icons.record_voice_over_outlined;
      default: return Icons.tag;
    }
  }
}
