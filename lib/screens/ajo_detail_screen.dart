import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_clone/models/models.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/services/chat_service.dart';

class AjoDetailScreen extends StatefulWidget {
  final String ajoId;
  const AjoDetailScreen({super.key, required this.ajoId});

  @override
  State<AjoDetailScreen> createState() => _AjoDetailScreenState();
}

class _AjoDetailScreenState extends State<AjoDetailScreen> {
  final _chatService = ChatService();
  final _currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('ajo_groups').doc(widget.ajoId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final ajo = AjoGroup.fromMap(data, widget.ajoId);
        final currentUser = _chatService.getCurrentUserId();

        return Scaffold(
          backgroundColor: themeProvider.getColor('scaffold'),
          appBar: AppBar(
            title: Text(ajo.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: themeProvider.getColor('appBar'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(ajo, themeProvider),
                const SizedBox(height: 24),
                _buildSectionTitle("ROTATION LIST", themeProvider),
                const SizedBox(height: 12),
                _buildRotationList(ajo, themeProvider),
                const SizedBox(height: 30),
                if (currentUser != null && ajo.members.contains(currentUser))
                  _buildContributionSection(ajo, currentUser, themeProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(AjoGroup ajo, ScreenThemeProvider themeProvider) {
    final nextPayout = ajo.nextPayoutDate ?? DateTime.now().add(const Duration(days: 7));
    final daysRemaining = nextPayout.difference(DateTime.now()).inDays;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF128C7E), Color(0xFF075E54)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(
            _currencyFormat.format(ajo.contributionAmount * ajo.members.length),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const Text("Total Payout Pool", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoTile("Next Payout", DateFormat('MMM dd').format(nextPayout)),
              _infoTile("Countdown", "$daysRemaining Days"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ScreenThemeProvider themeProvider) {
    return Text(title, style: TextStyle(color: themeProvider.getColor('textSecondary'), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1));
  }

  Widget _buildRotationList(AjoGroup ajo, ScreenThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.getColor('card'),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ajo.members.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final memberId = ajo.members[index];
          final isCurrentTurn = index == ajo.currentTurnIndex;
          
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
            builder: (context, userSnap) {
              final name = userSnap.hasData ? (userSnap.data!.data() as Map)['name'] : "Loading...";
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCurrentTurn ? Colors.green : Colors.grey.shade200,
                  child: Text("${index + 1}", style: TextStyle(color: isCurrentTurn ? Colors.white : Colors.black)),
                ),
                title: Text(name, style: TextStyle(color: themeProvider.getColor('text'), fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.normal)),
                trailing: isCurrentTurn 
                  ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Text("CURRENT", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)))
                  : null,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContributionSection(AjoGroup ajo, String userId, ScreenThemeProvider themeProvider) {
    final hasContributed = ajo.payoutStatus[userId] ?? false;

    return Center(
      child: ElevatedButton(
        onPressed: hasContributed ? null : () => _chatService.processAjoContribution(ajo.id, userId, ajo.contributionAmount),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text(hasContributed ? "CONTRIBUTION PAID ✅" : "PAY CONTRIBUTION (${_currencyFormat.format(ajo.contributionAmount)})"),
      ),
    );
  }
}
