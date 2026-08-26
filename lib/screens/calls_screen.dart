import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/screens/contacts_screen.dart';
import '../widgets/avatar.dart';
import '../providers/screen_theme_provider.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final appBarColor = themeProvider.getColor('appBar');
    final scaffoldColor = themeProvider.getColor('scaffold');
    final cardColor = themeProvider.getColor('card');
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text('Calls', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined), 
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera feature coming soon')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.search), 
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search calls coming soon')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert), 
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
            },
          ),
        ],
      ),
      body: currentUser == null
          ? Center(child: Text('Please login to view calls', style: TextStyle(color: textColor)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('call_logs')
                  .where('participants', arrayContains: currentUser.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: textColor)));
                }

                final calls = snapshot.data?.docs ?? [];
                
                if (calls.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.call_end_outlined, size: 80, color: secondaryTextColor.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('No recent calls', style: TextStyle(color: secondaryTextColor, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Recent calls will appear here', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: calls.length,
                  itemBuilder: (context, index) {
                    final data = calls[index].data() as Map<String, dynamic>;
                    final participants = List<String>.from(data['participants'] ?? []);
                    final otherUserId = participants.firstWhere((id) => id != currentUser.uid, orElse: () => '');
                    
                    final isVideo = data['isVideo'] ?? (data['callType'] == 'video');
                    final isIncoming = data['isIncoming'] ?? (data['callerId'] != currentUser.uid);
                    final isMissed = data['isMissed'] ?? false;
                    
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                    final timeStr = timestamp != null ? "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}" : '';

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                      builder: (context, userSnap) {
                        String name = 'Contact';
                        String? photoUrl;
                        
                        if (userSnap.hasData && userSnap.data!.exists) {
                          final userData = userSnap.data!.data() as Map<String, dynamic>;
                          name = userData['name'] ?? 'Contact';
                          photoUrl = userData['photoUrl'];
                        }

                        return ListTile(
                          leading: Avatar(name: name, imageUrl: photoUrl, size: 55),
                          title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                          subtitle: Row(
                            children: [
                              Icon(
                                isIncoming ? Icons.call_received : Icons.call_made,
                                size: 14,
                                color: isMissed ? Colors.red : (isIncoming ? Colors.green : Colors.green),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isMissed ? 'Missed' : (isIncoming ? 'Incoming' : 'Outgoing'),
                                style: TextStyle(color: isMissed ? Colors.red : secondaryTextColor, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              Text(timeStr, style: TextStyle(color: secondaryTextColor, fontSize: 13)),
                            ],
                          ),
                          trailing: Icon(
                            isVideo ? Icons.videocam : Icons.call,
                            color: themeProvider.getColor('primary'),
                          ),
                          onTap: () {
                            // Redial
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ContactsScreen()),
          );
        },
        backgroundColor: themeProvider.getColor('primary'),
        child: const Icon(Icons.add_call, color: Colors.white),
      ),
    );
  }
}
