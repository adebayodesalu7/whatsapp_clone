import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/screen_theme_provider.dart';

class FindAjoScreen extends StatefulWidget {
  const FindAjoScreen({super.key});

  @override
  State<FindAjoScreen> createState() => _FindAjoScreenState();
}

class _FindAjoScreenState extends State<FindAjoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search groups by name or interest...',
            hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
            border: InputBorder.none,
          ),
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('ajo_groups').where('isPublic', isEqualTo: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final rules = (data['rules'] ?? '').toString().toLowerCase();
            final interests = List<String>.from(data['interests'] ?? []).map((e) => e.toLowerCase()).toList();
            
            final isMatch = name.contains(_searchQuery) || 
                          rules.contains(_searchQuery) || 
                          interests.any((i) => i.contains(_searchQuery));
            
            final members = List<String>.from(data['members'] ?? []);
            return isMatch && !members.contains(_currentUserId);
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(_searchQuery.isEmpty 
                    ? 'No public Ajo circles available right now.' 
                    : 'No circles found matching "$_searchQuery"', 
                    style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final group = AjoGroup.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
              return _buildPublicGroupCard(group, themeProvider);
            },
          );
        },
      ),
    );
  }

  Widget _buildPublicGroupCard(AjoGroup group, ScreenThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.getColor('primary').withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(group.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const Icon(Icons.public, color: Colors.blue, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text('Contribution: ₦${group.contributionAmount} (${group.frequencyType})', style: const TextStyle(color: Colors.grey)),
          Text('Total Members: ${group.members.length}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _requestToJoin(group),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.getColor('primary'),
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('REQUEST TO JOIN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _requestToJoin(AjoGroup group) async {
    final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
    final name = userDoc.data()?['name'] ?? 'User';
    final points = userDoc.data()?['trustPoints'] ?? 150;

    await _firestore.collection('ajo_groups').doc(group.id).collection('join_requests').doc(_currentUserId).set({
      'userId': _currentUserId,
      'userName': name,
      'trustPoints': points,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join request sent! Admin will review your trust score.')),
      );
    }
  }
}
