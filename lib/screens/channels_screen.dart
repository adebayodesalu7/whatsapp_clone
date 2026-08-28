import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/widgets/avatar.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_clone/screens/channel_chat_screen.dart';
import 'package:whatsapp_clone/screens/community_detail_screen.dart';
import 'package:whatsapp_clone/services/paystack_service.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final textColor = themeProvider.getColor('text');
    final scaffoldColor = themeProvider.getColor('scaffold');

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: themeProvider.getColor('appBarText')),
              decoration: const InputDecoration(hintText: 'Search channels...', border: InputBorder.none, hintStyle: TextStyle(color: Colors.white60)),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            )
          : const Text('Updates', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeProvider.getColor('appBar'),
        foregroundColor: themeProvider.getColor('appBarText'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search), 
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
               if (val == 'elite') _showTitanEliteInfo(context, themeProvider);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'settings', child: Text('Channel Settings')),
              const PopupMenuItem(value: 'elite', child: Text('Titan Elite Status')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitanEliteSection(context, themeProvider),
            const Divider(height: 1),
            _buildEliteAccessCard(context, themeProvider),
            const Divider(height: 1),
            _buildChannelsSection(context, themeProvider),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'create-channel',
        onPressed: () => _showCreateChannelDialog(context, themeProvider),
        backgroundColor: themeProvider.getColor('primary'),
        child: const Icon(Icons.edit, color: Colors.white),
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
                if (_searchQuery.isNotEmpty && !name.toLowerCase().contains(_searchQuery)) return const SizedBox.shrink();
                
                final followersCount = data['followersCount'] ?? 0;
                final icon = data['iconUrl'];
                final channelId = channels[index].id;
                final currentUser = FirebaseAuth.instance.currentUser;
                final followers = List<String>.from(data['followers'] ?? []);
                final admins = List<String>.from(data['admins'] ?? []);
                final isFollowing = currentUser != null && followers.contains(currentUser.uid);
                final bool isAdmin = currentUser != null && (admins.contains(currentUser.uid) || data['createdBy'] == currentUser.uid);
                final bool isEliteChannel = data['isElite'] ?? false;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  leading: Avatar(name: name, imageUrl: icon, size: 45),
                  title: Row(
                    children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
                      if (isEliteChannel) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.stars, color: Colors.amber, size: 14),
                      ],
                      if (isAdmin) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, color: themeProvider.getColor('primary'), size: 14),
                      ],
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

  Widget _buildEliteAccessCard(BuildContext context, ScreenThemeProvider theme) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final bool isElite = data['isElite'] ?? false;

        if (isElite) {
          return ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.star, color: Colors.white)),
            title: const Text('Titan Elite Status Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: const Text('You have access to exclusive channels.', style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.verified, color: Colors.blue, size: 18),
            onTap: () => _showTitanEliteInfo(context, theme),
          );
        }

        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2E)]),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.amber, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Unlock Titan Elite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Join premium paid channels for business & networking.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _payForElite(context, theme),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text('JOIN ELITE - ₦1,000', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    );
  }

  void _showTitanEliteInfo(BuildContext context, ScreenThemeProvider theme) {
     showModalBottomSheet(
       context: context,
       backgroundColor: theme.getColor('card'),
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
       builder: (context) => Padding(
         padding: const EdgeInsets.all(24.0),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Icon(Icons.workspace_premium, color: Colors.amber, size: 60),
             const SizedBox(height: 16),
             Text('Titan Elite Community', style: TextStyle(color: theme.getColor('text'), fontSize: 20, fontWeight: FontWeight.bold)),
             const SizedBox(height: 8),
             const Text('Exclusive access to high-value networks and business insights.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
             const SizedBox(height: 24),
             const ListTile(leading: Icon(Icons.check, color: Colors.green), title: Text('Verified Badge')),
             const ListTile(leading: Icon(Icons.check, color: Colors.green), title: Text('Business Advisory')),
             const ListTile(leading: Icon(Icons.check, color: Colors.green), title: Text('Premium Marketplace Listing')),
           ],
         ),
       ),
     );
  }

  Future<void> _payForElite(BuildContext context, ScreenThemeProvider theme) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final paystack = PaystackService();
    String? email = user.email;

    if (email == null || email.isEmpty || email.contains('titan-ajo.com')) {
      email = await paystack.promptForEmail(context, email);
    }

    if (email == null || email.isEmpty) return;
    
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    final response = await paystack.checkout(
      context: context,
      email: email,
      amount: 1000.0,
      reference: 'elite_${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (context.mounted) Navigator.pop(context);

    if (response != null && response['status'] == true) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isElite': true});
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome to Titan Elite!')));
    }
  }

  void _showCreateChannelDialog(BuildContext context, ScreenThemeProvider themeProvider) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isEliteToggle = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: themeProvider.getColor('card'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Create New Channel', style: TextStyle(color: themeProvider.getColor('text'), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Elite Channel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber)),
                  subtitle: const Text('Premium channel for business. Fee: ₦10,000', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  value: isEliteToggle,
                  onChanged: (val) => setState(() => isEliteToggle = val),
                  secondary: const Icon(Icons.workspace_premium, color: Colors.amber),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  final user = FirebaseAuth.instance.currentUser!;

                  if (isEliteToggle) {
                    // Trigger Payment
                    final paystack = PaystackService();
                    String? email = user.email;
                    if (email == null || email.isEmpty || email.contains('titan-ajo.com')) {
                      email = await paystack.promptForEmail(context, email);
                    }
                    if (email == null || email.isEmpty) return;

                    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
                    final response = await paystack.checkout(
                      context: context,
                      email: email,
                      amount: 10000.0,
                      reference: 'create_elite_${uid}_${DateTime.now().millisecondsSinceEpoch}',
                    );
                    if (context.mounted) Navigator.pop(context); // Close loading

                    if (response == null || response['status'] != true) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment failed. Elite channel not created.')));
                      return;
                    }
                  }

                  await FirebaseFirestore.instance.collection('channels').add({
                    'name': nameController.text,
                    'description': descController.text,
                    'followersCount': 1,
                    'followers': [uid],
                    'admins': [uid],
                    'createdBy': uid,
                    'isElite': isEliteToggle,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isEliteToggle ? Colors.amber.shade800 : themeProvider.getColor('primary'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isEliteToggle ? 'Pay & Create' : 'Create Channel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
