import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/models.dart';
import '../providers/screen_theme_provider.dart';
import '../services/payment_service.dart';
import '../services/paystack_service.dart';
import '../services/chat_service.dart';

class AjoDashboardScreen extends StatefulWidget {
  final String groupId;

  const AjoDashboardScreen({super.key, required this.groupId});

  @override
  State<AjoDashboardScreen> createState() => _AjoDashboardScreenState();
}

class _AjoDashboardScreenState extends State<AjoDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
  final PaystackService _paystackService = PaystackService();
  
  String _timeFilter = 'This Month'; 
  int _weeklyCount = 0;
  int _monthlyCount = 0;
  double _amountCollected = 0.0;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');
    final primaryColor = themeProvider.getColor('primary');
    final cardColor = themeProvider.getColor('card');

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('ajo_groups').doc(widget.groupId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text('Group not found')));
        
        final group = AjoGroup.fromMap(snapshot.data!.data() as Map<String, dynamic>, snapshot.data!.id);
        final isAdmin = group.creatorId == _currentUserId;
        final isMember = group.members.contains(_currentUserId);

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('ajo_groups').doc(widget.groupId).collection('contributions').snapshots(),
          builder: (context, contribSnapshot) {
            if (contribSnapshot.hasData) {
              final now = DateTime.now();
              final weekAgo = now.subtract(const Duration(days: 7));
              final monthAgo = now.subtract(const Duration(days: 30));

              _weeklyCount = 0;
              _monthlyCount = 0;
              _amountCollected = 0.0;

              for (var doc in contribSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                final amount = double.tryParse(data['amount'].toString()) ?? 0.0;

                _amountCollected += amount;
                if (timestamp.isAfter(weekAgo)) _weeklyCount++;
                if (timestamp.isAfter(monthAgo)) _monthlyCount++;
              }
            }

            int membersCount = group.members.length;
            int currentPaid = group.payoutStatus.values.where((v) => v).length;
            int owingCount = membersCount - currentPaid;
            double amountOwed = owingCount * group.contributionAmount;

            bool hasContributed = group.payoutStatus[_currentUserId] ?? false;

            return Scaffold(
              backgroundColor: themeProvider.getColor('scaffold'),
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeProvider.getColor('appBarText'))),
                    Text('Active Dashboard', style: TextStyle(fontSize: 11, color: themeProvider.getColor('appBarText').withOpacity(0.7))),
                  ],
                ),
                backgroundColor: themeProvider.getColor('appBar'),
                iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
                elevation: 0,
                actions: [
                  if (isAdmin) ...[
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1),
                      onPressed: () => _pickAndAddMember(group),
                      tooltip: 'Add Member from Contacts',
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') _confirmDeleteGroup(group);
                        else if (value == 'edit') _editRules(group, themeProvider);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit Rules & Targets')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete Ajo Group', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.analytics),
                    onPressed: () => _showDetailedAnalysis(context, group, themeProvider),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Member Stats
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        _buildStatCard('Total Members', membersCount.toString(), Icons.group, Colors.blue, themeProvider),
                        _buildStatCard('Members Owing', owingCount.toString(), Icons.warning_amber, Colors.red, themeProvider),
                        _buildStatCard('Cycle Duration', '${group.totalCycles} ${group.frequencyType}s', Icons.timer_outlined, Colors.green, themeProvider),
                        _buildStatCard('Group Target', _currencyFormat.format(group.totalTargetAmount ?? 0), Icons.track_changes, Colors.purple, themeProvider),
                      ],
                    ),
                    
                    const SizedBox(height: 20),

                    // Group-Specific Receiving Account
                    if (group.accountNumber != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance, color: Colors.blue, size: 18),
                                const SizedBox(width: 8),
                                Text('Group Receiving Account', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(group.accountNumber!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 1.5)),
                                    Text(group.bankName ?? 'Titan Bank', style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: Colors.blue, size: 20),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: group.accountNumber!));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account number copied!')));
                                  },
                                ),
                              ],
                            ),
                            const Divider(),
                            Text('Account Name: ${group.accountName ?? group.name}', style: TextStyle(fontSize: 11, color: secondaryTextColor, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),

                    // Financial Dashboard
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Financial Health', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                          const SizedBox(height: 20),
                          _buildFinanceRow('Generally Contributed', _amountCollected, Colors.green, themeProvider),
                          const SizedBox(height: 12),
                          _buildFinanceRow('Total Amount Owed', amountOwed, Colors.red, themeProvider),
                          const Divider(height: 32),
                          _buildFinanceRow('Projected Pool', membersCount * group.contributionAmount, primaryColor, themeProvider, isBold: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Group Rules Section
                    if (group.rules != null && group.rules!.isNotEmpty)
                      ExpansionTile(
                        initiallyExpanded: true,
                        title: Text('Group Rules & Targets', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
                        leading: const Icon(Icons.rule, color: Colors.orange),
                        childrenPadding: const EdgeInsets.all(16),
                        backgroundColor: cardColor,
                        collapsedBackgroundColor: cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        children: [
                          Text(group.rules!, style: TextStyle(color: textColor, height: 1.5, fontSize: 13)),
                        ],
                      ),

                    const SizedBox(height: 24),
                    Text('Contribution Roster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                    const SizedBox(height: 12),
                    
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: group.members.length,
                      itemBuilder: (context, index) {
                        final memberId = group.members[index];
                        final isPaid = group.payoutStatus[memberId] ?? false;
                        final isMe = memberId == _currentUserId;

                        return FutureBuilder<DocumentSnapshot>(
                          future: _firestore.collection('users').doc(memberId).get(),
                          builder: (context, userSnap) {
                            final data = userSnap.data?.data() as Map<String, dynamic>?;
                            final name = data?['name'] ?? 'Member ${index + 1}';
                            final photoUrl = data?['photoUrl'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: isMe ? Border.all(color: primaryColor.withOpacity(0.3)) : null,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                  backgroundColor: primaryColor.withOpacity(0.1),
                                  child: photoUrl == null ? Text(name[0].toUpperCase(), style: TextStyle(color: primaryColor)) : null,
                                ),
                                title: Text(isMe ? '$name (You)' : name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
                                subtitle: Text(isPaid ? 'Payment Confirmed' : 'Payment Pending', style: TextStyle(fontSize: 11, color: isPaid ? Colors.green : Colors.orange)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPaid) 
                                      const Icon(Icons.check_circle, color: Colors.green, size: 22)
                                    else 
                                      Text('₦${group.contributionAmount}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                    if (isAdmin && !isMe) 
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                        onPressed: () => _confirmRemoveMember(group, memberId, name),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              bottomNavigationBar: isMember ? Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Requirement', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                          Text(hasContributed ? 'SETTLED' : 'OWING ₦${group.contributionAmount}', 
                              style: TextStyle(color: hasContributed ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                    if (group.members.isNotEmpty && group.members[group.currentTurnIndex] == _currentUserId && currentPaid == membersCount)
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _handleWithdrawal(group, themeProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('WITHDRAW POOL'),
                        ),
                      )
                    else
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (hasContributed || !isMember) ? null : () => _handlePaystackPayment(group, themeProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C3F7), 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            disabledBackgroundColor: Colors.grey.shade300,
                            elevation: 0,
                          ),
                          child: Text(!isMember ? 'Limited Access' : (hasContributed ? 'Payment Verified' : 'Pay via Paystack')),
                        ),
                      ),
                  ],
                ),
              ) : null,
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, ScreenThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.getColor('card'),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.getColor('divider').withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(color: theme.getColor('textSecondary'), fontSize: 9, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: theme.getColor('text'), fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFinanceRow(String label, double amount, Color color, ScreenThemeProvider theme, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: theme.getColor('textSecondary'), fontSize: 13)),
        Text(_currencyFormat.format(amount), 
          style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: isBold ? 17 : 14)),
      ],
    );
  }

  Future<void> _handleWithdrawal(AjoGroup group, ScreenThemeProvider theme) async {
    final double totalPool = group.members.length * group.contributionAmount;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Ajo Pool'),
        content: Text('It is your turn! You are about to withdraw the total contribution of ${_currencyFormat.format(totalPool)} to your wallet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final paymentService = PaymentService();
              await paymentService.topUp(totalPool);

              int nextTurn = (group.currentTurnIndex + 1) % group.members.length;
              
              Map<String, bool> newStatus = {};
              for (var member in group.members) {
                newStatus[member] = false;
              }

              await _firestore.collection('ajo_groups').doc(group.id).update({
                'currentTurnIndex': nextTurn,
                'payoutStatus': newStatus,
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payout of ${_currencyFormat.format(totalPool)} successful! It is now Member ${nextTurn + 1}\'s turn.')),
                );
              }
            },
            child: const Text('WITHDRAW'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePaystackPayment(AjoGroup group, ScreenThemeProvider theme) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User email not found. Please update profile.')));
      return;
    }

    final reference = _paystackService.generateReference();

    final response = await _paystackService.checkout(
      context: context,
      email: user.email!,
      amount: group.contributionAmount,
      reference: reference,
    );

    if (response != null && response['status'] == true) {
      await _firestore.collection('ajo_groups').doc(group.id).update({
        'payoutStatus.$_currentUserId': true,
      });

      await _firestore.collection('ajo_groups').doc(group.id).collection('contributions').add({
        'userId': _currentUserId,
        'userName': user.displayName ?? 'Member',
        'amount': group.contributionAmount,
        'reference': reference,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showReceipt(context, group, reference, theme);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment failed or cancelled'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showReceipt(BuildContext context, AjoGroup group, String ref, ScreenThemeProvider theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.getColor('card'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 70),
            const SizedBox(height: 16),
            Text('Receipt Generated', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.getColor('text'))),
            const SizedBox(height: 8),
            Text('Contribution for ${group.name} is successful.', textAlign: TextAlign.center, style: TextStyle(color: theme.getColor('textSecondary'), fontSize: 13)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.getColor('scaffold'), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _receiptRow('Amount Paid', _currencyFormat.format(group.contributionAmount), theme),
                  const Divider(),
                  _receiptRow('Ref ID', ref.substring(0, 12) + '...', theme),
                  const Divider(),
                  _receiptRow('Date', DateFormat('MMM dd, yyyy').format(DateTime.now()), theme),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: theme.getColor('primary'), foregroundColor: Colors.white),
                child: const Text('BACK TO DASHBOARD'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, ScreenThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: theme.getColor('textSecondary'))),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.getColor('text'))),
        ],
      ),
    );
  }

  void _showDetailedAnalysis(BuildContext context, AjoGroup group, ScreenThemeProvider theme) {
     showModalBottomSheet(
      context: context,
      backgroundColor: theme.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajo Group Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.getColor('text'))),
            const SizedBox(height: 20),
            _analysisTile(Icons.trending_up, 'Weekly Growth', '+${(_weeklyCount / (group.members.isEmpty ? 1 : group.members.length) * 100).toInt()}%', theme),
            _analysisTile(Icons.people_outline, 'Active Turn', 'Member ${group.currentTurnIndex + 1}', theme),
            _analysisTile(Icons.account_balance, 'Pool Stability', 'Stable', theme),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: theme.getColor('primary'), minimumSize: const Size(double.infinity, 45)),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analysisTile(IconData icon, String label, String value, ScreenThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: theme.getColor('primary'), size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: theme.getColor('textSecondary'))),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: theme.getColor('text'))),
        ],
      ),
    );
  }

  Future<void> _pickAndAddMember(AjoGroup group) async {
    final TextEditingController manualPhoneController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Provider.of<ScreenThemeProvider>(context, listen: false).getColor('card'),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        final theme = Provider.of<ScreenThemeProvider>(context);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.getColor('text'))),
              const SizedBox(height: 20),
              TextField(
                controller: manualPhoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: theme.getColor('text')),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone),
                  filled: true,
                  fillColor: theme.getColor('inputFill'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (manualPhoneController.text.isNotEmpty) {
                    Navigator.pop(context);
                    _addMemberToFirestore(group, 'Invited Member', manualPhoneController.text);
                  }
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('SEND INVITATION'),
              ),
              const Divider(height: 40),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  _pickFromContacts(group);
                },
                icon: const Icon(Icons.contacts),
                label: const Text('PICK FROM CONTACTS'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromContacts(AjoGroup group) async {
    try {
      if (await FlutterContacts.requestPermission()) {
        final contacts = await FlutterContacts.getContacts(withProperties: true);
        if (mounted) {
          if (contacts.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No contacts found on device.')));
            return;
          }
          showModalBottomSheet(
            context: context,
            backgroundColor: Provider.of<ScreenThemeProvider>(context, listen: false).getColor('card'),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Pick from Contacts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Provider.of<ScreenThemeProvider>(context).getColor('text'))),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : 'No Number';
                        return ListTile(
                          leading: CircleAvatar(child: Text(contact.displayName.isNotEmpty ? contact.displayName[0] : '?')),
                          title: Text(contact.displayName),
                          subtitle: Text(phone),
                          onTap: () async {
                            Navigator.pop(context);
                            _addMemberToFirestore(group, contact.displayName, phone);
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contacts permission denied.')));
        }
      }
    } catch (e) {
      print('Error picking contact: $e');
    }
  }

  Future<void> _addMemberToFirestore(AjoGroup group, String name, String phone) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    
    try {
      final userSnap = await _firestore.collection('users').where('phoneNumber', isEqualTo: phone).limit(1).get();
      String targetId = userSnap.docs.isNotEmpty ? userSnap.docs.first.id : phone.replaceAll(RegExp(r'[^0-9]'), '');

      if (targetId.isEmpty) {
        Navigator.pop(context);
        return;
      }

      final chatService = ChatService();
      await chatService.sendAjoInvitation(targetId, {
        'id': group.id,
        'name': group.name,
        'contributionAmount': group.contributionAmount,
        'frequencyType': group.frequencyType,
        'totalCycles': group.totalCycles,
        'rules': group.rules ?? '',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation sent to $name.')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _confirmDeleteGroup(AjoGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ajo Group?'),
        content: const Text('This will permanently delete the group and all its records. Funds already contributed will need manual settlement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await _firestore.collection('ajo_groups').doc(group.id).delete();
              if (mounted) {
                Navigator.pop(context); 
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajo Group deleted.')));
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editRules(AjoGroup group, ScreenThemeProvider theme) {
    final rulesController = TextEditingController(text: group.rules);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.getColor('card'),
        title: Text('Edit Group Rules', style: TextStyle(color: theme.getColor('text'))),
        content: TextField(
          controller: rulesController,
          maxLines: 5,
          style: TextStyle(color: theme.getColor('text')),
          decoration: const InputDecoration(hintText: 'Enter new rules...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await _firestore.collection('ajo_groups').doc(group.id).update({'rules': rulesController.text});
              if (mounted) Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMember(AjoGroup group, String memberId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $name?'),
        content: const Text('Are you sure you want to remove this member from the Ajo group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await _firestore.collection('ajo_groups').doc(group.id).update({
                'members': FieldValue.arrayRemove([memberId]),
                'payoutStatus.$memberId': FieldValue.delete(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('REMOVE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
