import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/services/status_service.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/widgets/theme_selector.dart';
import 'package:whatsapp_clone/screens/add_status_screen.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final StatusService _statusService = StatusService();
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserPhoto;
  bool _isLoading = true;

  final Map<String, Map<String, String>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _currentUserId = _statusService.getCurrentUserId();
    if (_currentUserId != null) {
      await _loadCurrentUser();
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserName = data['name'] ?? 'User';
            _currentUserPhoto = data['photoUrl'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading user: $e');
    }
  }

  Future<Map<String, String>> _getUserDetails(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final result = <String, String>{
          'name': data['name']?.toString() ?? userId,
          'photoUrl': data['photoUrl']?.toString() ?? '',
        };
        _userCache[userId] = result;
        return result;
      }
    } catch (e) {
      print('Error loading user: $e');
    }
    return {'name': userId, 'photoUrl': ''};
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final appBarColor = themeProvider.getColor('appBar');
    final scaffoldColor = themeProvider.getColor('scaffold');
    final cardColor = themeProvider.getColor('card');
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');
    final primaryColor = themeProvider.getColor('primary');

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        elevation: 0,
        actions: [
          ThemeSelector(screenName: 'status'),
        ],
      ),
      body: Column(
        children: [
          // My Status Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(
                bottom: BorderSide(color: themeProvider.getColor('divider')),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddStatusScreen(),
                      ),
                    );
                  },
                  child: Stack(
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: _statusService.getMyStatuses(),
                        builder: (context, mySnap) {
                          String? latestStatusUrl;
                          if (mySnap.hasData && mySnap.data!.docs.isNotEmpty) {
                            final lastDoc = mySnap.data!.docs.first.data() as Map<String, dynamic>;
                            latestStatusUrl = lastDoc['imageUrl'];
                          }

                          return CircleAvatar(
                            radius: 30,
                            backgroundImage: latestStatusUrl != null && latestStatusUrl.isNotEmpty
                                ? (latestStatusUrl.startsWith('http') ? NetworkImage(latestStatusUrl) : FileImage(File(latestStatusUrl)) as ImageProvider)
                                : (_currentUserPhoto != null && _currentUserPhoto!.isNotEmpty 
                                    ? NetworkImage(_currentUserPhoto!) 
                                    : null),
                            backgroundColor: primaryColor.withOpacity(0.1),
                            child: (latestStatusUrl == null || latestStatusUrl.isEmpty) && (_currentUserPhoto == null || _currentUserPhoto!.isEmpty)
                                ? Text(
                                    _currentUserName?.isNotEmpty == true ? _currentUserName![0].toUpperCase() : '?',
                                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                                  )
                                : null,
                          );
                        }
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Tap to add status update',
                        style: TextStyle(color: secondaryTextColor, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Status "Road"
          _buildRoadStatus(themeProvider),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent updates',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _statusService.getStatuses(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: textColor)));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final now = DateTime.now();
                final validStatuses = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final expiresAt = data['expiresAt'] as Timestamp?;
                  return expiresAt != null && expiresAt.toDate().isAfter(now);
                }).toList();

                if (validStatuses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.circle, size: 40, color: secondaryTextColor.withOpacity(0.3)),
                        const SizedBox(height: 8),
                        Text(
                          'No recent updates',
                          style: TextStyle(color: secondaryTextColor),
                        ),
                      ],
                    ),
                  );
                }

                final Map<String, List<QueryDocumentSnapshot>> groupedStatuses = {};
                for (var doc in validStatuses) {
                  final userId = (doc.data() as Map<String, dynamic>)['userId'] ?? 'unknown';
                  groupedStatuses.putIfAbsent(userId, () => []).add(doc);
                }

                return ListView.builder(
                  itemCount: groupedStatuses.length,
                  itemBuilder: (context, index) {
                    final userId = groupedStatuses.keys.toList()[index];
                    final userStatuses = groupedStatuses[userId]!;
                    final unviewedCount = userStatuses.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final viewedBy = data['viewedBy'] as List? ?? [];
                      return !viewedBy.contains(_currentUserId);
                    }).length;

                    return FutureBuilder<Map<String, String>>(
                      future: _getUserDetails(userId),
                      builder: (context, userSnapshot) {
                        final name = userSnapshot.data?['name'] ?? userId;
                        final photoUrl = userSnapshot.data?['photoUrl'] ?? '';
                        
                        // Get the latest status image for this user
                        final lastStatusData = userStatuses.first.data() as Map<String, dynamic>;
                        final statusImageUrl = lastStatusData['imageUrl'];

                        return ListTile(
                          onTap: () {
                             _showStatusViewer(userStatuses);
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: unviewedCount > 0 ? primaryColor : Colors.grey,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundImage: (statusImageUrl != null && statusImageUrl.isNotEmpty)
                                ? (statusImageUrl.startsWith('http') ? NetworkImage(statusImageUrl) : FileImage(File(statusImageUrl)) as ImageProvider)
                                : (photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null),
                              backgroundColor: primaryColor.withOpacity(0.1),
                              child: (statusImageUrl == null || statusImageUrl.isEmpty) && photoUrl.isEmpty 
                                ? Text(name[0], style: TextStyle(color: primaryColor)) 
                                : null,
                            ),
                          ),
                          title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                          subtitle: Text('Recently updated', style: TextStyle(color: secondaryTextColor)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddStatusScreen(),
            ),
          );
        },
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }

  void _showStatusViewer(List<QueryDocumentSnapshot> statuses) {
    int currentIndex = 0;
    
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                PageView.builder(
                  itemCount: statuses.length,
                  onPageChanged: (index) {
                    setStateDialog(() => currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final data = statuses[index].data() as Map<String, dynamic>;
                    final imageUrl = data['imageUrl'];
                    final text = data['text'] ?? '';
                    
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          imageUrl.startsWith('http') 
                            ? Image.network(imageUrl, fit: BoxFit.contain, width: double.infinity, height: double.infinity)
                            : Image.file(File(imageUrl), fit: BoxFit.contain, width: double.infinity, height: double.infinity),
                        if (text.isNotEmpty)
                          Positioned(
                            bottom: 100,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 18)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                
                // Progress Bars
                Positioned(
                  top: 50,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: List.generate(statuses.length, (index) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: index <= currentIndex ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                Positioned(
                  top: 65,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildRoadStatus(ScreenThemeProvider theme) {
    return Container(
      height: 125,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: StreamBuilder<QuerySnapshot>(
        stream: _statusService.getStatuses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          
          final now = DateTime.now();
          final validStatuses = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final expiresAt = data['expiresAt'] as Timestamp?;
            return expiresAt != null && expiresAt.toDate().isAfter(now);
          }).toList();

          if (validStatuses.isEmpty) return const SizedBox.shrink();

          // Group by userId for horizontal bar
          final Map<String, List<QueryDocumentSnapshot>> grouped = {};
          for (var doc in validStatuses) {
            final uid = (doc.data() as Map<String, dynamic>)['userId'] ?? 'unknown';
            grouped.putIfAbsent(uid, () => []).add(doc);
          }

          final users = grouped.keys.toList();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userId = users[index];
              final userStatuses = grouped[userId]!;
              final latestStatus = userStatuses.first.data() as Map<String, dynamic>;
              final imageUrl = latestStatus['imageUrl'];

              return FutureBuilder<Map<String, String>>(
                future: _getUserDetails(userId),
                builder: (context, userSnap) {
                  final name = userSnap.data?['name'] ?? 'User';
                  
                  return GestureDetector(
                    onTap: () => _showStatusViewer(userStatuses),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.getColor('primary'), 
                                width: 2
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                                ? (imageUrl.startsWith('http') ? NetworkImage(imageUrl) : FileImage(File(imageUrl)) as ImageProvider)
                                : null,
                              backgroundColor: theme.getColor('primary').withOpacity(0.1),
                              child: imageUrl == null || imageUrl.isEmpty ? Text(name[0], style: TextStyle(color: theme.getColor('primary'))) : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            userId == _currentUserId ? 'You' : name, 
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: theme.getColor('text')),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
              );
            },
          );
        },
      ),
    );
  }
}
