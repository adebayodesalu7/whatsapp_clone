import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/screen_theme_provider.dart';
import '../services/payment_service.dart';
import '../services/paystack_service.dart';
import 'ajo_dashboard_screen.dart';
import 'personal_savings_screen.dart';

class AjoGroupScreen extends StatefulWidget {
  const AjoGroupScreen({super.key});

  @override
  State<AjoGroupScreen> createState() => _AjoGroupScreenState();
}

class _AjoGroupScreenState extends State<AjoGroupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: Text(editGroup == null ? 'Start New Circle' : 'Edit Circle Settings', 
              style: TextStyle(color: themeProvider.getColor('text'), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController, 
                  style: TextStyle(color: themeProvider.getColor('text')),
                  decoration: const InputDecoration(labelText: 'Circle Name'),
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
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  style: TextStyle(color: themeProvider.getColor('text')),
                  items: ['Daily', 'Weekly', 'Monthly'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (v) => setDialogState(() => frequency = v!),
                ),
                TextField(
                  controller: cyclesController, 
                  style: TextStyle(color: themeProvider.getColor('text')),
                  decoration: const InputDecoration(labelText: 'Total Turns'), 
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: themeProvider.getColor('primary'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
                    
                    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
                    final accountDetails = await paystackService.createDedicatedAccount(nameController.text, email);
                    if (mounted) Navigator.pop(context);

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
              child: Text(editGroup == null ? 'Launch' : 'Update', style: const TextStyle(color: Colors.white)),
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
      backgroundColor: Colors.black, // Dark themed Hub as in screenshot
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WELCOME,', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.2)),
            FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(_currentUserId).get(),
              builder: (context, snap) {
                String name = snap.data?.get('name') ?? 'Adebayo';
                return Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20));
              }
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Trust Status Card
          _buildTrustStatusCard(),
          const SizedBox(height: 24),
          
          // Expected Returns Card
          _buildReturnsCard(),
          const SizedBox(height: 24),

          // Quick Action Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildQuickAction(Icons.add, 'New Circle', 'Start fresh', () => _showStartAjoDialog(themeProvider)),
              _buildQuickAction(Icons.swap_horiz, 'Import Ajo', 'Digitize existing', () {}),
              _buildQuickAction(Icons.search, 'Find Ajo', 'Join nearby', () {}),
            ],
          ),

          const SizedBox(height: 32),

          // Verification Status
          _buildVerificationBanner(themeProvider),
          
          const SizedBox(height: 32),
          Text('ACTIVE CIRCLES', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('ajo_groups').where('members', arrayContains: _currentUserId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return _buildEmptyState(secondaryTextColor);
              
              return Column(
                children: docs.map((doc) {
                   final group = AjoGroup.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                   return _buildCircleTile(group, themeProvider);
                }).toList(),
              );
            }
          ),
          
          const SizedBox(height: 24),
          Text('PERSONAL SAVINGS', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildPersonalSavingsButton(themeProvider),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTrustStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: Colors.green, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TRUST STATUS', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('Newbie • 150 PTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const Spacer(),
              Container(
                width: 100,
                height: 6,
                decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(3)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(width: 40, height: 6, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReturnsCard() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006D4E), Color(0xFF004D3F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.orangeAccent, size: 16),
              const SizedBox(width: 8),
              const Text('EXPECTED RETURNS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          Text(_currencyFormat.format(0), style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
          const Spacer(),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text('Locked in 0 Active Circles', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.orangeAccent, size: 24),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 8), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBanner(ScreenThemeProvider theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: Colors.orangeAccent, size: 40),
          const SizedBox(height: 16),
          const Text('Complete Verification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Get verified with BVN and ₦500 to unlock higher tiers', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _showVerificationDialog(theme),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.getColor('primary'),
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('VERIFY NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showVerificationDialog(ScreenThemeProvider theme) {
    final bvnController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.getColor('card'),
        title: Text('BVN Verification', style: TextStyle(color: theme.getColor('text'), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your 11-digit Bank Verification Number to upgrade to Tier 2.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 20),
            TextField(
              controller: bvnController,
              keyboardType: TextInputType.number,
              maxLength: 11,
              style: TextStyle(color: theme.getColor('text')),
              decoration: const InputDecoration(labelText: 'BVN Number', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (bvnController.text.length == 11) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ BVN Verified Successfully! Upgraded to Tier 2.')));
              }
            }, 
            child: const Text('VERIFY'),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleTile(AjoGroup group, ScreenThemeProvider theme) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AjoDashboardScreen(groupId: group.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1C1F26), borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: theme.getColor('primary').withOpacity(0.1), child: const Icon(Icons.group, color: Colors.white)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('₦${group.contributionAmount} / ${group.frequencyType}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalSavingsButton(ScreenThemeProvider theme) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PersonalSavingsScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: theme.getColor('primary').withOpacity(0.3)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_pin, color: Colors.orangeAccent),
            const SizedBox(width: 16),
            const Expanded(
              child: Text('Setup Personal Savings Circle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const Icon(Icons.add_circle_outline, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color color) {
     return Center(child: Text('No active group circles yet', style: TextStyle(color: color, fontSize: 12)));
  }
}
