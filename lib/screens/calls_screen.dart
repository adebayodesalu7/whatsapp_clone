import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/screens/contacts_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/avatar.dart';
import '../providers/screen_theme_provider.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _pickCameraImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo captured for status/chat.')));
    }
  }

  void _showCallSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Provider.of<ScreenThemeProvider>(context, listen: false).getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('Clear Call Log'),
              onTap: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final logs = await FirebaseFirestore.instance
                      .collection('call_logs')
                      .where('participants', arrayContains: user.uid)
                      .get();
                  for (var doc in logs.docs) {
                    await doc.reference.delete();
                  }
                }
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Call Settings'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final appBarColor = themeProvider.getColor('appBar');
    final scaffoldColor = themeProvider.getColor('scaffold');
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: _searchQuery.isEmpty 
          ? Text('Calls', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText')))
          : TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Search calls...', border: InputBorder.none, hintStyle: TextStyle(color: Colors.white70)),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined), 
            onPressed: _pickCameraImage,
          ),
          IconButton(
            icon: Icon(_searchQuery.isEmpty ? Icons.search : Icons.close), 
            onPressed: () {
              setState(() {
                if (_searchQuery.isNotEmpty) {
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _searchQuery = ' '; // trigger rebuild for search field
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert), 
            onPressed: _showCallSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuickCallActions(themeProvider),
          const Divider(height: 1),
          Expanded(
            child: currentUser == null
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

                    final allCalls = snapshot.data?.docs ?? [];
                    
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _processCalls(allCalls, currentUser.uid, _searchQuery),
                      builder: (context, processedSnap) {
                        final calls = processedSnap.data ?? [];
                        
                        if (calls.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.call_end_outlined, size: 80, color: secondaryTextColor.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text('No recent calls', style: TextStyle(color: secondaryTextColor, fontSize: 16)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: calls.length,
                          itemBuilder: (context, index) {
                            final call = calls[index];
                            return ListTile(
                              leading: Avatar(name: call['name'], imageUrl: call['photoUrl'], size: 45),
                              title: Text(call['name'], style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                              subtitle: Row(
                                children: [
                                  Icon(
                                    call['isIncoming'] ? Icons.call_received : Icons.call_made,
                                    size: 14,
                                    color: call['isMissed'] ? Colors.red : Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    call['isMissed'] ? 'Missed' : (call['isIncoming'] ? 'Incoming' : 'Outgoing'),
                                    style: TextStyle(color: call['isMissed'] ? Colors.red : secondaryTextColor, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(call['timeStr'], style: TextStyle(color: secondaryTextColor, fontSize: 13)),
                                ],
                              ),
                              trailing: Icon(
                                call['isVideo'] ? Icons.videocam : Icons.call,
                                color: themeProvider.getColor('primary'),
                              ),
                              onTap: () {
                                // Redial logic
                              },
                            );
                          },
                        );
                      }
                    );
                  },
                ),
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
        child: const Icon(Icons.add_call, color: Colors.white),
      ),
    );
  }

  Widget _buildQuickCallActions(ScreenThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _quickActionItem(Icons.star_outline, 'Favorite', theme),
          _quickActionItem(Icons.phone_outlined, 'Voice Call', theme),
          _quickActionItem(Icons.videocam_outlined, 'Video Call', theme),
          _quickActionItem(Icons.dialpad, 'Dial Pad', theme),
        ],
      ),
    );
  }

  Widget _quickActionItem(IconData icon, String label, ScreenThemeProvider theme) {
    return InkWell(
      onTap: () {
        if (label == 'Dial Pad') {
          _showDialPad();
        } else if (label == 'Favorite') {
           _showFavorites();
        } else {
           Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactsScreen()));
        }
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: theme.getColor('primary').withOpacity(0.1),
            child: Icon(icon, color: theme.getColor('primary')),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: theme.getColor('text'), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showDialPad() {
    final TextEditingController _dialController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _dialController,
              readOnly: true,
              showCursor: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'].map((digit) {
                  return InkWell(
                    onTap: () => setState(() => _dialController.text += digit),
                    borderRadius: BorderRadius.circular(50),
                    child: Center(child: Text(digit, style: const TextStyle(fontSize: 24))),
                  );
                }).toList(),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.backspace_outlined),
                  onPressed: () {
                    if (_dialController.text.isNotEmpty) {
                      setState(() => _dialController.text = _dialController.text.substring(0, _dialController.text.length - 1));
                    }
                  },
                ),
                FloatingActionButton(
                  onPressed: () {
                     // Start call
                     Navigator.pop(context);
                  },
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.call, color: Colors.white),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFavorites() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Favorite Contacts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            const Text('No favorites yet. Long press a contact to add.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _processCalls(List<QueryDocumentSnapshot> docs, String currentUid, String query) async {
    List<Map<String, dynamic>> results = [];
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);
      final otherUserId = participants.firstWhere((id) => id != currentUid, orElse: () => '');
      
      final userSnap = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
      final userData = userSnap.data() as Map<String, dynamic>?;
      final name = userData?['name'] ?? 'Contact';
      
      if (query.isNotEmpty && !name.toLowerCase().contains(query)) continue;

      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      results.add({
        'name': name,
        'photoUrl': userData?['photoUrl'],
        'isIncoming': data['isIncoming'] ?? (data['callerId'] != currentUid),
        'isMissed': data['isMissed'] ?? false,
        'isVideo': data['isVideo'] ?? (data['callType'] == 'video'),
        'timeStr': timestamp != null ? "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}" : '',
      });
    }
    return results;
  }
}
