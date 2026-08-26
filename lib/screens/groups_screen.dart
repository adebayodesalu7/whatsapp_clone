import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/widgets/avatar.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/screens/ajo_group_screen.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/screens/group_settings_screen.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final appBarColor = themeProvider.getColor('appBar');
    final scaffoldColor = themeProvider.getColor('scaffold');
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text('Groups', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        actions: [
          IconButton(
            icon: const Icon(Icons.savings_outlined),
            tooltip: 'Ajo Savings',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AjoGroupScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Discover Groups',
            onPressed: () {
               _showDiscoverGroups(context, themeProvider, currentUser!.uid);
            },
          ),
        ],
      ),
      body: currentUser == null
          ? Center(child: Text('Please login to view groups', style: TextStyle(color: textColor)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .where('members', arrayContains: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: textColor)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off_outlined, size: 80, color: secondaryTextColor.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('No groups joined yet', style: TextStyle(color: secondaryTextColor)),
                      ],
                    ),
                  );
                }

                final groups = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final data = groups[index].data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Group';
                    final photoUrl = data['photoUrl'];
                    final lastMessage = data['lastMessage'] ?? 'No messages yet';

                    return ListTile(
                      leading: Avatar(name: name, imageUrl: photoUrl, size: 50),
                      title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: secondaryTextColor)),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: secondaryTextColor),
                      onLongPress: () {
                         final isAdmin = data['createdBy'] == currentUser.uid;
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (context) => GroupSettingsScreen(
                               groupId: groups[index].id,
                               groupName: name,
                               isAdmin: isAdmin,
                             ),
                           ),
                         );
                      },
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
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Implement create group logic or navigate to create group screen
          showDialog(
            context: context,
            builder: (context) {
              final nameController = TextEditingController();
              return AlertDialog(
                backgroundColor: themeProvider.getColor('card'),
                title: Text('Create New Group', style: TextStyle(color: textColor)),
                content: TextField(
                  controller: nameController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Group Name',
                    hintStyle: TextStyle(color: secondaryTextColor),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: secondaryTextColor)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.getColor('primary'))),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: secondaryTextColor))),
                  TextButton(
                    onPressed: () async {
                      if (nameController.text.isNotEmpty && currentUser != null) {
                        await FirebaseFirestore.instance.collection('groups').add({
                          'name': nameController.text,
                          'members': [currentUser.uid],
                          'createdBy': currentUser.uid,
                          'createdAt': FieldValue.serverTimestamp(),
                          'lastMessage': 'Group created',
                          'slowModeSeconds': 0,
                          'approvalRequired': false,
                        });
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: Text('Create', style: TextStyle(color: themeProvider.getColor('primary'), fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            }
          );
        },
        backgroundColor: themeProvider.getColor('primary'),
        child: const Icon(Icons.group_add, color: Colors.white),
      ),
    );
  }

  void _showDiscoverGroups(BuildContext context, ScreenThemeProvider theme, String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Discover Communities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.getColor('text'))),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('groups').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final allGroups = snapshot.data!.docs.where((doc) {
                    final members = List<String>.from(doc['members'] ?? []);
                    return !members.contains(uid);
                  }).toList();

                  return ListView.builder(
                    controller: controller,
                    itemCount: allGroups.length,
                    itemBuilder: (context, index) {
                      final data = allGroups[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Group';
                      final approval = data['approvalRequired'] ?? false;

                      return ListTile(
                        leading: Avatar(name: name, size: 40),
                        title: Text(name, style: TextStyle(color: theme.getColor('text'))),
                        subtitle: Text(approval ? '🛡️ Admin Approval Required' : 'Public Group'),
                        trailing: ElevatedButton(
                          onPressed: () => _joinGroup(context, allGroups[index].id, name, approval, uid),
                          child: Text(approval ? 'Request' : 'Join'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _joinGroup(BuildContext context, String groupId, String groupName, bool approval, String uid) async {
    if (approval) {
       await FirebaseFirestore.instance
           .collection('groups')
           .doc(groupId)
           .collection('join_requests')
           .add({
             'userId': uid,
             'userName': FirebaseAuth.instance.currentUser?.displayName ?? 'New Member',
             'status': 'pending',
             'timestamp': FieldValue.serverTimestamp(),
           });
       if (context.mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🕒 Join request sent to admins.')));
       }
    } else {
      await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([uid]),
      });
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Joined group!')));
      }
    }
  }
}
