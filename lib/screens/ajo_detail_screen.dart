import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_clone/models/models.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AjoDetailScreen extends StatefulWidget {
  final String ajoId;
  const AjoDetailScreen({super.key, required this.ajoId});

  @override
  State<AjoDetailScreen> createState() => _AjoDetailScreenState();
}

class _AjoDetailScreenState extends State<AjoDetailScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final secondaryTextColor = themeProvider.getColor('textSecondary');
    final textColor = themeProvider.getColor('text');
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('ajo_groups').doc(widget.ajoId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text("Ajo group not found")));
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final ajo = AjoGroup.fromMap(data, widget.ajoId);
        
        final bool isAdmin = ajo.members.isNotEmpty && ajo.members.first == _currentUserId;
        
        // Calculate Dashboard Stats
        int paidCount = ajo.payoutStatus.values.where((v) => v).length;
        double totalSaved = ajo.contributionAmount * paidCount;
        double groupTarget = ajo.contributionAmount * ajo.members.length;
        // Mocking previous rotations for "All Time Saved"
        double allTimeSaved = totalSaved; 
        double myContribution = (ajo.payoutStatus[_currentUserId] ?? false) ? ajo.contributionAmount : 0;

        return Scaffold(
          backgroundColor: themeProvider.getColor('scaffold'),
          appBar: AppBar(
            title: const Text('Titan Ajo Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            backgroundColor: themeProvider.getColor('appBar'),
            foregroundColor: themeProvider.getColor('appBarText'),
            elevation: 0,
            actions: [
              if (isAdmin)
                IconButton(icon: const Icon(Icons.settings_outlined, size: 20), onPressed: () {}),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModernHeader(ajo, totalSaved, themeProvider),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("FINANCIAL OVERVIEW", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      _buildFinancialGrid(allTimeSaved, myContribution, paidCount, ajo.members.length, themeProvider),
                      const SizedBox(height: 24),
                      Text("ROTATION TIMELINE", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      _buildRotationTimeline(ajo, themeProvider),
                      const SizedBox(height: 32),
                      _buildContributionAction(ajo, _currentUserId, themeProvider),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernHeader(AjoGroup ajo, double totalSaved, ScreenThemeProvider themeProvider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: themeProvider.getColor('appBar'),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(ajo.name.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_currencyFormat.format(totalSaved), style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
          const Text("Total Current Rotation Pool", style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _headerStat("Payout", _currencyFormat.format(ajo.contributionAmount * ajo.members.length)),
              Container(width: 1, height: 30, color: Colors.white24),
              _headerStat("Next Date", DateFormat('dd MMM').format(ajo.nextPayoutDate ?? DateTime.now())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildFinancialGrid(double allTime, double mine, int paid, int total, ScreenThemeProvider themeProvider) {
    final cardColor = themeProvider.getColor('card');
    final textColor = themeProvider.getColor('text');
    final secondaryColor = themeProvider.getColor('textSecondary');

    return Row(
      children: [
        _finCard("All-Time Saved", _currencyFormat.format(allTime), Icons.auto_graph, Colors.blue, cardColor, textColor, secondaryColor),
        const SizedBox(width: 12),
        _finCard("My Stake", _currencyFormat.format(mine), Icons.person_outline, Colors.orange, cardColor, textColor, secondaryColor),
      ],
    );
  }

  Widget _finCard(String label, String value, IconData icon, Color color, Color cardBg, Color text, Color secondary) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: secondary.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: text)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: secondary, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildRotationTimeline(AjoGroup ajo, ScreenThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.getColor('card'),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeProvider.getColor('divider').withOpacity(0.05)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ajo.members.length,
        itemBuilder: (context, index) {
          final memberId = ajo.members[index];
          final isCurrent = index == ajo.currentTurnIndex;
          final isPast = index < ajo.currentTurnIndex;
          final hasContributed = ajo.payoutStatus[memberId] ?? false;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
            builder: (context, userSnap) {
              String name = 'User...';
              if (userSnap.hasData && userSnap.data!.exists) {
                name = (userSnap.data!.data() as Map<String, dynamic>)['name'] ?? 'User';
              }
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: isCurrent ? Colors.green : (isPast ? Colors.grey.shade400 : Colors.grey.shade100),
                          child: index < ajo.currentTurnIndex 
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : Text("${index + 1}", style: TextStyle(fontSize: 10, color: isCurrent ? Colors.white : Colors.black38)),
                        ),
                        if (index < ajo.members.length - 1)
                          Container(width: 1.5, height: 24, color: Colors.grey.shade100),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500, color: themeProvider.getColor('text'), fontSize: 14)),
                          if (isCurrent) const Text("Collecting Pool this period", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    if (hasContributed)
                      const Icon(Icons.verified, color: Colors.green, size: 18)
                    else if (isCurrent)
                       const Icon(Icons.pending_actions, color: Colors.orange, size: 18)
                    else 
                       Text("₦${_currencyFormat.format(ajo.contributionAmount).replaceAll('₦', '')}", style: TextStyle(color: themeProvider.getColor('textSecondary'), fontSize: 11)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContributionAction(AjoGroup ajo, String userId, ScreenThemeProvider themeProvider) {
    final bool hasPaid = ajo.payoutStatus[userId] ?? false;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: themeProvider.getColor('primary').withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeProvider.getColor('primary').withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, color: themeProvider.getColor('primary'), size: 18),
              const SizedBox(width: 10),
              Text("TITAN ESCROW PROTECTION ACTIVE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: themeProvider.getColor('primary'), letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: hasPaid ? null : () async {
               showDialog(context: context, builder: (c) => const Center(child: CircularProgressIndicator()));
               await FirebaseFirestore.instance.collection('ajo_groups').doc(ajo.id).update({
                 'payoutStatus.$userId': true,
               });
               if (mounted) {
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Payout contribution successful!')));
               }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.getColor('primary'),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(hasPaid ? "CONTRIBUTION SETTLED" : "PAY CONTRIBUTION", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
