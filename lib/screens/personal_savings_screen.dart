import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/screen_theme_provider.dart';
import '../services/paystack_service.dart';
import '../services/security_service.dart';

class PersonalSavingsScreen extends StatefulWidget {
  const PersonalSavingsScreen({super.key});

  @override
  State<PersonalSavingsScreen> createState() => _PersonalSavingsScreenState();
}

class _PersonalSavingsScreenState extends State<PersonalSavingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Personal Savings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('personal_savings').where('userId', isEqualTo: _currentUserId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.savings_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No personal savings circles yet', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _showCreateSavingsDialog(themeProvider),
                    child: const Text('START SAVING'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final savings = PersonalSavings.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
              return _buildSavingsCard(savings, themeProvider);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSavingsDialog(themeProvider),
        backgroundColor: themeProvider.getColor('primary'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showCreateSavingsDialog(ScreenThemeProvider themeProvider) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final durationController = TextEditingController(text: '6');
    final nextOfKinController = TextEditingController();
    String frequency = 'Monthly';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: themeProvider.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Savings Circle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 20),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Savings Goal Name', hintText: 'e.g. Dream House, New Car')),
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target Amount (₦)')),
            TextField(controller: durationController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (Months)')),
            DropdownButtonFormField<String>(
              value: frequency,
              items: ['Daily', 'Weekly', 'Monthly'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) => frequency = v!,
              decoration: const InputDecoration(labelText: 'Savings Frequency'),
            ),
            TextField(controller: nextOfKinController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Next of Kin Phone Number')),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text('Verification fee of ₦500 applies to activate withdrawal.', style: TextStyle(color: themeProvider.getColor('textSecondary'), fontSize: 10))),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                 if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                    _createSavings(
                      nameController.text,
                      double.parse(amountController.text),
                      int.parse(durationController.text),
                      frequency,
                      nextOfKinController.text,
                    );
                    Navigator.pop(context);
                 }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('CREATE CIRCLE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSavings(String name, double target, int months, String freq, String nok) async {
    final user = FirebaseAuth.instance.currentUser;
    String email = user?.email ?? '${user?.phoneNumber?.replaceAll('+', '') ?? 'user'}@titan-ajo.com';
    
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    final paystackService = PaystackService();
    final accountDetails = await paystackService.createDedicatedAccount(name, email);
    
    if (mounted) Navigator.pop(context);

    final now = DateTime.now();
    final targetDate = now.add(Duration(days: months * 30));

    await _firestore.collection('personal_savings').add({
      'userId': _currentUserId,
      'name': name,
      'targetAmount': target,
      'currentBalance': 0.0,
      'durationMonths': months,
      'frequency': freq,
      'startDate': now,
      'targetDate': targetDate,
      'bankName': accountDetails['bankName'],
      'accountNumber': accountDetails['accountNumber'],
      'nextOfKinPhone': nok,
      'isVerified': false,
      'isBvnVerified': false,
      'tier': 1,
      'points': 150,
      'isLocked': true,
    });
  }

  Widget _buildSavingsCard(PersonalSavings savings, ScreenThemeProvider theme) {
    double progress = savings.currentBalance / (savings.targetAmount > 0 ? savings.targetAmount : 1);
    bool isTargetMet = savings.currentBalance >= savings.targetAmount;
    bool isDurationMet = DateTime.now().isAfter(savings.targetDate);

    return GestureDetector(
      onTap: () => _openSavingsDashboard(savings),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: savings.isVerified ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(savings.name.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                if (savings.isLocked) const Icon(Icons.lock, color: Colors.green, size: 14),
              ],
            ),
            const SizedBox(height: 12),
            Text(_currencyFormat.format(savings.currentBalance), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Target: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(_currencyFormat.format(savings.targetAmount), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade800,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniInfo(Icons.calendar_today, DateFormat('MMM dd, yyyy').format(savings.targetDate)),
                _miniInfo(Icons.shield_outlined, 'Tier ${savings.tier}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 12),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  void _openSavingsDashboard(PersonalSavings savings) async {
    final security = SecurityService();
    final authenticated = await security.authenticate();
    if (authenticated) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (c) => PersonalSavingsDashboard(savingsId: savings.id)));
      }
    }
  }
}

class PersonalSavingsDashboard extends StatelessWidget {
  final String savingsId;
  const PersonalSavingsDashboard({super.key, required this.savingsId});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final _firestore = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('personal_savings').doc(savingsId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final savings = PersonalSavings.fromMap(snapshot.data!.data() as Map<String, dynamic>, snapshot.data!.id);
        
        bool canWithdraw = savings.currentBalance >= savings.targetAmount || DateTime.now().isAfter(savings.targetDate);

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(savings.name),
            actions: [
              IconButton(icon: const Icon(Icons.history), onPressed: () {}),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
               _buildAccountDetails(savings),
               const SizedBox(height: 24),
               _buildStatsGrid(savings),
               const SizedBox(height: 24),
               _buildSavingsAction(context, savings),
               const SizedBox(height: 24),
               _buildActionCard(context, savings, canWithdraw),
               const SizedBox(height: 24),
               _buildNextOfKin(savings),
               const SizedBox(height: 40),
               if (canWithdraw)
                 ElevatedButton(
                   onPressed: () {}, 
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 55)),
                   child: const Text('WITHDRAW TO WALLET', style: TextStyle(fontWeight: FontWeight.bold)),
                 ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountDetails(PersonalSavings savings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1C1F26), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR SAVINGS ACCOUNT', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(savings.accountNumber, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  Text(savings.bankName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              IconButton(icon: const Icon(Icons.copy, color: Colors.blue), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(PersonalSavings savings) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _statBox('Points', '${savings.points}', Icons.star, Colors.orange),
        _statBox('Tier', 'Tier ${savings.tier}', Icons.military_tech, Colors.blue),
        _statBox('Status', savings.isVerified ? 'Verified' : 'Pending', Icons.verified_user, savings.isVerified ? Colors.green : Colors.orange),
        _statBox('Security', 'Biometric', Icons.fingerprint, Colors.purple),
      ],
    );
  }

  Widget _statBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1C1F26), borderRadius: BorderRadius.circular(15)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, PersonalSavings savings, bool canWithdraw) {
     return Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(color: const Color(0xFF1C1F26), borderRadius: BorderRadius.circular(20)),
       child: Column(
         children: [
           const Text('Verification Required', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
           const SizedBox(height: 8),
           const Text('Pay ₦500 signup fee to verify this account', style: TextStyle(color: Colors.grey, fontSize: 11)),
           const SizedBox(height: 16),
           ElevatedButton(
             onPressed: savings.isVerified ? null : () => _payVerificationFee(context, savings),
             child: Text(savings.isVerified ? 'VERIFIED' : 'PAY ₦500 NOW'),
           ),
         ],
       ),
     );
  }

  Widget _buildSavingsAction(BuildContext context, PersonalSavings savings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF00A884), Color(0xFF25D366)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('Top up your savings circle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAddSavingsDialog(context, savings),
            icon: const Icon(Icons.add_card, color: Color(0xFF00A884)),
            label: const Text('ADD SAVINGS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A884))),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSavingsDialog(BuildContext context, PersonalSavings savings) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111B21),
        title: const Text('Add Savings', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Amount (₦)',
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount > 0) {
                Navigator.pop(context);
                _processSavingsPayment(context, savings, amount);
              }
            },
            child: const Text('PAY VIA PAYSTACK'),
          ),
        ],
      ),
    );
  }

  Future<void> _processSavingsPayment(BuildContext context, PersonalSavings savings, double amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final paystackService = PaystackService();
    String? email = user.email;

    if (email == null || email.isEmpty || email.contains('titan-ajo.com')) {
      email = await paystackService.promptForEmail(context, email);
    }

    if (email == null || email.isEmpty) return;

    final reference = paystackService.generateReference();

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    final response = await paystackService.checkout(
      context: context,
      email: email,
      amount: amount,
      reference: reference,
    );

    if (context.mounted) Navigator.pop(context);

    if (response != null && response['status'] == true) {
      await FirebaseFirestore.instance.collection('personal_savings').doc(savings.id).update({
        'currentBalance': FieldValue.increment(amount),
        'points': FieldValue.increment(5), // Reward on-time payment
      });

      // Record transaction
      await FirebaseFirestore.instance.collection('personal_savings').doc(savings.id).collection('transactions').add({
        'type': 'deposit',
        'amount': amount,
        'reference': reference,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Successfully added ₦$amount to your savings!')));
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Payment failed: ${response?['message'] ?? 'Cancelled'}'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _payVerificationFee(BuildContext context, PersonalSavings savings) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final paystackService = PaystackService();
    String? email = user.email;

    if (email == null || email.isEmpty || email.contains('titan-ajo.com')) {
      email = await paystackService.promptForEmail(context, email);
    }

    if (email == null || email.isEmpty) return;

    final reference = 'ver_${const Uuid().v4()}';

    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    final response = await paystackService.checkout(
      context: context,
      email: email,
      amount: 500.0,
      reference: reference,
    );

    if (context.mounted) Navigator.pop(context);

    if (response != null && response['status'] == true) {
      await FirebaseFirestore.instance.collection('personal_savings').doc(savings.id).update({
        'isVerified': true,
        'tier': 2,
        'points': FieldValue.increment(50),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Account verified! You are now Tier 2.')));
      }
    }
  }

  Widget _buildNextOfKin(PersonalSavings savings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.2)), borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: const Icon(Icons.family_restroom, color: Colors.grey),
        title: const Text('Next of Kin', style: TextStyle(color: Colors.white70, fontSize: 12)),
        subtitle: Text(savings.nextOfKinPhone, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.edit, size: 16, color: Colors.grey),
      ),
    );
  }
}
