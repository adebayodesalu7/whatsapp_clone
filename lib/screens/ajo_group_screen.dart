import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/screen_theme_provider.dart';

class AjoGroupScreen extends StatefulWidget {
  const AjoGroupScreen({super.key});

  @override
  State<AjoGroupScreen> createState() => _AjoGroupScreenState();
}

class _AjoGroupScreenState extends State<AjoGroupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _showStartAjoDialog(ScreenThemeProvider themeProvider) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final frequencyController = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.getColor('card'),
        title: Text('Start New Ajo', style: TextStyle(color: themeProvider.getColor('text'), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Group Name')),
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Monthly Contribution (₦)'), keyboardType: TextInputType.number),
            TextField(controller: frequencyController, decoration: const InputDecoration(labelText: 'Frequency (Days)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeProvider.getColor('primary')),
            onPressed: () async {
              if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                await _firestore.collection('ajo_groups').add({
                  'name': nameController.text,
                  'contributionAmount': double.tryParse(amountController.text) ?? 0.0,
                  'frequencyDays': int.tryParse(frequencyController.text) ?? 30,
                  'members': [_currentUserId],
                  'payoutStatus': {_currentUserId: false},
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Start', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: Text('Community Savings (Ajo)', style: TextStyle(color: themeProvider.getColor('appBarText'), fontWeight: FontWeight.bold)),
        backgroundColor: themeProvider.getColor('appBar'),
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('ajo_groups').where('members', arrayContains: _currentUserId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: themeProvider.getColor('primary')));
          
          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined, size: 80, color: secondaryTextColor.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No Ajo groups yet', style: TextStyle(color: secondaryTextColor, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final group = AjoGroup.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
              return _buildAjoGroupCard(group, themeProvider);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStartAjoDialog(themeProvider),
        backgroundColor: themeProvider.getColor('primary'),
        foregroundColor: Colors.white,
        label: const Text('Start New Ajo', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAjoGroupCard(AjoGroup group, ScreenThemeProvider themeProvider) {
    int paidCount = group.payoutStatus.values.where((v) => v).length;
    double progress = group.members.isEmpty ? 0 : paidCount / group.members.length;
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Card(
      color: themeProvider.getColor('card'),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(group.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                Icon(Icons.savings, color: themeProvider.getColor('primary')),
              ],
            ),
            const SizedBox(height: 8),
            Text('Contribution: ₦${group.contributionAmount} / ${group.frequencyDays} days', style: TextStyle(color: secondaryTextColor)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payout Progress', style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                Text('$paidCount / ${group.members.length} paid', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: secondaryTextColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(themeProvider.getColor('primary')),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showMembers(group, themeProvider), 
                  child: Text('View Members', style: TextStyle(color: themeProvider.getColor('primary'))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.getColor('primary'), 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {},
                  child: const Text('Contribute', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMembers(AjoGroup group, ScreenThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${group.name} Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: themeProvider.getColor('text'))),
              const SizedBox(height: 20),
              ...group.members.map((member) {
                bool isPaid = group.payoutStatus[member] ?? false;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: themeProvider.getColor('primary').withOpacity(0.1),
                    child: Icon(Icons.person, color: themeProvider.getColor('primary')),
                  ),
                  title: Text(member, style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.getColor('text'))),
                  trailing: isPaid
                      ? Chip(label: const Text('Paid'), backgroundColor: Colors.green.withOpacity(0.1), labelStyle: const TextStyle(color: Colors.green, fontSize: 12))
                      : Chip(label: const Text('Pending'), backgroundColor: Colors.orange.withOpacity(0.1), labelStyle: const TextStyle(color: Colors.orange, fontSize: 12)),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}
