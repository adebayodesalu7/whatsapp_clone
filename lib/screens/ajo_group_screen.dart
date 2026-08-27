import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/screen_theme_provider.dart';
import '../services/payment_service.dart';
import '../services/paystack_service.dart';
import 'ajo_dashboard_screen.dart';

class AjoGroupScreen extends StatefulWidget {
  const AjoGroupScreen({super.key});

  @override
  State<AjoGroupScreen> createState() => _AjoGroupScreenState();
}

class _AjoGroupScreenState extends State<AjoGroupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _showStartAjoDialog(ScreenThemeProvider themeProvider, {AjoGroup? editGroup}) {
    final nameController = TextEditingController(text: editGroup?.name);
    final amountController = TextEditingController(text: editGroup?.contributionAmount.toString());
    final cyclesController = TextEditingController(text: editGroup?.totalCycles.toString() ?? '12');
    String frequency = editGroup?.frequencyType ?? 'Monthly';

    final rulesController = TextEditingController(text: editGroup?.rules);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: themeProvider.getColor('card'),
          title: Text(editGroup == null ? 'Start New Ajo' : 'Edit Ajo Settings', 
              style: TextStyle(color: themeProvider.getColor('text'), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController, 
                  style: TextStyle(color: themeProvider.getColor('text')),
                  decoration: const InputDecoration(labelText: 'Group Name'),
                ),
                TextField(
                  controller: amountController, 
                  style: TextStyle(color: themeProvider.getColor('text')),
                  decoration: const InputDecoration(labelText: 'Contribution Amount (₦)'), 
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: frequency,
                  dropdownColor: themeProvider.getColor('card'),
                  decoration: const InputDecoration(labelText: 'Contribution Frequency'),
                  style: TextStyle(color: themeProvider.getColor('text')),
                  items: ['Daily', 'Weekly', 'Monthly'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (v) => setDialogState(() => frequency = v!),
                ),
                TextField(
                  controller: cyclesController, 
                  style: TextStyle(color: themeProvider.getColor('text')),
                  decoration: const InputDecoration(labelText: 'Duration (Number of Payments)'), 
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: rulesController, 
                  style: TextStyle(color: themeProvider.getColor('text')),
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Group Rules / Targets', hintText: 'e.g. Must pay before 5th of every month'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: themeProvider.getColor('primary')),
              onPressed: () async {
                if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                  final amount = double.tryParse(amountController.text) ?? 0.0;
                  final cycles = int.tryParse(cyclesController.text) ?? 12;
                  
                  int freqDays = 30;
                  if (frequency == 'Daily') freqDays = 1;
                  else if (frequency == 'Weekly') freqDays = 7;

                  final ajoData = {
                    'name': nameController.text,
                    'contributionAmount': amount,
                    'frequencyType': frequency,
                    'frequencyDays': freqDays,
                    'totalCycles': cycles,
                    'totalTargetAmount': amount * cycles,
                    'rules': rulesController.text,
                  };

                  if (editGroup == null) {
                    final user = FirebaseAuth.instance.currentUser;
                    String email = user?.email ?? '${user?.phoneNumber?.replaceAll('+', '') ?? 'user'}@titan-ajo.com';

                    final paystackService = PaystackService();
                    
                    // Show a sub-loading for account generation
                    showDialog(
                      context: context, 
                      barrierDismissible: false, 
                      builder: (c) => const Center(child: CircularProgressIndicator())
                    );

                    final accountDetails = await paystackService.createDedicatedAccount(nameController.text, email);
                    
                    if (mounted) Navigator.pop(context); // Close sub-loading

                    await _firestore.collection('ajo_groups').add({
                      ...ajoData,
                      'creatorId': _currentUserId,
                      'members': [_currentUserId],
                      'payoutStatus': {_currentUserId: false},
                      'createdAt': FieldValue.serverTimestamp(),
                      'bankName': accountDetails['bankName'],
                      'accountNumber': accountDetails['accountNumber'],
                      'accountName': accountDetails['accountName'],
                      'currentTurnIndex': 0,
                    });
                  } else {
                    await _firestore.collection('ajo_groups').doc(editGroup.id).update(ajoData);
                  }
                  
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Text(editGroup == null ? 'Start' : 'Update', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
    final isAdmin = group.creatorId == _currentUserId;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AjoDashboardScreen(groupId: group.id),
          ),
        );
      },
      child: Card(
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
                  Expanded(child: Text(group.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor), overflow: TextOverflow.ellipsis)),
                  if (isAdmin) 
                    IconButton(
                      icon: Icon(Icons.edit_note, color: themeProvider.getColor('primary')), 
                      onPressed: () => _showStartAjoDialog(themeProvider, editGroup: group),
                    ),
                  Icon(Icons.savings, color: themeProvider.getColor('primary')),
                ],
              ),
              const SizedBox(height: 8),
              Text('Contribution: ₦${group.contributionAmount} (${group.frequencyType})', style: TextStyle(color: secondaryTextColor)),
              Text('Target: ₦${group.totalTargetAmount?.toStringAsFixed(0)} / ${group.totalCycles} Cycles', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
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
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;

                      String? email = user.email;
                      if (email == null || email.isEmpty) {
                        final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
                        final phoneNumber = userDoc.data()?['phoneNumber'] as String? ?? '';
                        if (phoneNumber.isNotEmpty) {
                          email = '${phoneNumber.replaceAll('+', '')}@titan-ajo.com';
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number not found.')));
                          return;
                        }
                      }

                      final paystackService = PaystackService();
                      final reference = paystackService.generateReference();

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );

                      final response = await paystackService.checkout(
                        context: context,
                        email: email,
                        amount: group.contributionAmount,
                        reference: reference,
                      );

                      if (mounted) Navigator.pop(context); // Close loading

                      if (response != null && response['status'] == true) {
                        await _firestore.collection('ajo_groups').doc(group.id).update({
                          'payoutStatus.$_currentUserId': true,
                        });

                        // Record contribution
                        await _firestore.collection('ajo_groups').doc(group.id).collection('contributions').add({
                          'userId': _currentUserId,
                          'userName': user.displayName ?? 'Member',
                          'amount': group.contributionAmount,
                          'reference': reference,
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Contribution of ₦${group.contributionAmount} successful!')),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(response?['message'] ?? 'Payment failed or cancelled'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: const Text('Contribute', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
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
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(member).get(),
                  builder: (context, userSnap) {
                    String name = "Loading...";
                    if (userSnap.hasData && userSnap.data!.exists) {
                       name = (userSnap.data!.data() as Map<String, dynamic>)['name'] ?? member;
                    }
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: themeProvider.getColor('primary').withOpacity(0.1),
                        child: Icon(Icons.person, color: themeProvider.getColor('primary')),
                      ),
                      title: Text(name, style: TextStyle(fontWeight: FontWeight.w500, color: themeProvider.getColor('text'))),
                      trailing: isPaid
                          ? Chip(label: const Text('Paid'), backgroundColor: Colors.green.withOpacity(0.1), labelStyle: const TextStyle(color: Colors.green, fontSize: 12))
                          : Chip(label: const Text('Pending'), backgroundColor: Colors.orange.withOpacity(0.1), labelStyle: const TextStyle(color: Colors.orange, fontSize: 12)),
                    );
                  }
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}
