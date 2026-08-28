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
import 'find_ajo_screen.dart';

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
    final interestsController = TextEditingController(text: editGroup?.interests.join(', '));
    bool isPublic = editGroup?.isPublic ?? false;

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
                TextField(
                  controller: interestsController, 
                  style: TextStyle(color: themeProvider.getColor('text')),
                  decoration: const InputDecoration(labelText: 'Interests (comma separated)', hintText: 'Business, Tech, Savings'),
                ),
                SwitchListTile(
                  title: const Text('Public (Discoverable)', style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: isPublic,
                  onChanged: (v) => setDialogState(() => isPublic = v),
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
                    'isPublic': isPublic,
                    'interests': interestsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(_currentUserId).snapshots(),
        builder: (context, userSnap) {
          final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
          final int userPoints = userData['trustPoints'] ?? 150;
          final int userTier = userData['tier'] ?? 1;
          final bool isVerified = userData['isVerified'] ?? false;
          final String tierName = userTier == 1 ? 'Newbie' : (userTier == 2 ? 'Bronze' : 'Silver');

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('personal_savings').where('userId', isEqualTo: _currentUserId).snapshots(),
            builder: (context, personalSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('ajo_groups').where('members', arrayContains: _currentUserId).snapshots(),
                builder: (context, groupsSnap) {
                  double totalExpected = 0;
                  int activeCircles = 0;
                  List<Map<String, dynamic>> breakdown = [];

                  if (personalSnap.hasData) {
                    for (var doc in personalSnap.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final current = (data['currentBalance'] ?? 0.0).toDouble();
                      final target = (data['targetAmount'] ?? 0.0).toDouble();
                      
                      if (current < target) {
                        totalExpected += target;
                        activeCircles++;
                        breakdown.add({'name': data['name'] ?? 'Saving', 'amount': target, 'type': 'Personal'});
                      }
                    }
                  }

                  if (groupsSnap.hasData) {
                    for (var doc in groupsSnap.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final contribution = (data['contributionAmount'] ?? 0.0).toDouble();
                      final members = List<String>.from(data['members'] ?? []);
                      final int userIndex = members.indexOf(_currentUserId);
                      final int currentTurn = data['currentTurnIndex'] ?? 0;

                      // Only count as "Expected" if the user hasn't received the payout in this cycle
                      if (userIndex >= currentTurn) {
                        double payout = (contribution * members.length);
                        totalExpected += payout;
                        activeCircles++;
                        breakdown.add({'name': data['name'] ?? 'Group', 'amount': payout, 'type': 'Ajo'});
                      }
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Trust Status Card
                      _buildTrustStatusCard(tierName, userPoints),
                      const SizedBox(height: 24),
                      
                      // Expected Returns Card
                      _buildReturnsCard(totalExpected, activeCircles, breakdown, themeProvider),
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
                          _buildQuickAction(Icons.search, 'Find Ajo', 'Join nearby', () {
                            Navigator.push(context, MaterialPageRoute(builder: (c) => const FindAjoScreen()));
                          }),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Verification Status - Hide if already verified
                      if (!isVerified) ...[
                        _buildVerificationBanner(themeProvider),
                        const SizedBox(height: 32),
                      ],
                      
                      Text('ACTIVE CIRCLES', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                      const SizedBox(height: 16),
                      
                      if (groupsSnap.hasData && groupsSnap.data!.docs.isNotEmpty)
                        Column(
                          children: groupsSnap.data!.docs.map((doc) {
                             final group = AjoGroup.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                             return _buildCircleTile(group, themeProvider);
                          }).toList(),
                        )
                      else 
                        _buildEmptyState(secondaryTextColor),
                      
                      const SizedBox(height: 24),
                      Text('PERSONAL SAVINGS', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                      const SizedBox(height: 16),
                      _buildPersonalSavingsButton(themeProvider),
                      
                      const SizedBox(height: 100),
                    ],
                  );
                }
              );
            }
          );
        }
      ),
    );
  }

  Widget _buildTrustStatusCard(String tier, int points) {
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
                  Text('$tier • $points PTS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const Spacer(),
              Container(
                width: 100,
                height: 6,
                decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(3)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: (points % 500) / 5, // Simple progress representation
                    height: 6, 
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3))
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReturnsCard(double total, int count, List<Map<String, dynamic>> breakdown, ScreenThemeProvider theme) {
    return GestureDetector(
      onTap: () => _showReturnsBreakdown(theme, breakdown),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF006D4E), Color(0xFF004D3F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
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
                const Spacer(),
                const Icon(Icons.info_outline, color: Colors.white38, size: 14),
              ],
            ),
            const SizedBox(height: 20),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(_currencyFormat.format(total), style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
            ),
            const Spacer(),
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('Locked in $count Active Circles', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReturnsBreakdown(ScreenThemeProvider theme, List<Map<String, dynamic>> breakdown) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RETURNS SCORE SHEET', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            const Text('Future Payouts', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            if (breakdown.isEmpty)
              const Center(child: Text('No active expectations', style: TextStyle(color: Colors.grey)))
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: breakdown.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: item['type'] == 'Ajo' ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(item['type'] == 'Ajo' ? Icons.group : Icons.person, color: item['type'] == 'Ajo' ? Colors.blue : Colors.green, size: 16),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text(item['type'], style: const TextStyle(color: Colors.grey, fontSize: 10)),
                              ],
                            ),
                          ),
                          Text(_currencyFormat.format(item['amount']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL EXPECTED', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                Text(_currencyFormat.format(breakdown.fold(0.0, (sum, item) => sum + item['amount'])), 
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
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
                await _firestore.collection('users').doc(_currentUserId).update({
                  'isBvnVerified': true,
                  'tier': FieldValue.increment(0), // Placeholder to ensure logic exists
                  'trustPoints': FieldValue.increment(25),
                });
                
                // Logic: Move to Tier 2 if both BVN and N500 are done
                final doc = await _firestore.collection('users').doc(_currentUserId).get();
                if ((doc.data()?['isVerified'] ?? false) == true) {
                  await _firestore.collection('users').doc(_currentUserId).update({'tier': 2});
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ BVN Verified Successfully!')));
                }
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
