import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/services/payment_service.dart';
import 'package:whatsapp_clone/services/escrow_service.dart';
import 'package:whatsapp_clone/services/crypto_service.dart';
import 'package:whatsapp_clone/screens/airtime_purchase_screen.dart';
import 'package:whatsapp_clone/screens/ajo_detail_screen.dart';
import 'package:whatsapp_clone/models/models.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _paymentService = PaymentService();
  final _escrowService = EscrowService();
  final _cryptoService = CryptoService();
  final _currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('My Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF128C7E),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF128C7E),
          tabs: const [
            Tab(text: 'Cash (Fiat)'),
            Tab(text: 'Web3 (Crypto)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCashView(themeProvider),
          _buildCryptoView(themeProvider),
        ],
      ),
    );
  }

  Widget _buildCashView(ScreenThemeProvider themeProvider) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Wallet Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF25D366).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    _currencyFormat.format(_paymentService.balance),
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Wallet ID: 234803...4290', style: TextStyle(color: Colors.white, fontSize: 14)),
                      const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAction(Icons.qr_code_scanner, 'Scan', _showScanner),
                _buildQuickAction(Icons.qr_code, 'Receive', _showReceiveQR),
                _buildQuickAction(Icons.phone_android, 'Airtime', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AirtimePurchaseScreen()));
                }),
                _buildQuickAction(Icons.savings_outlined, 'Ajo', () {}),
              ],
            ),
          ),

          _buildAjoDashboard(themeProvider),

          // Escrow Dashboard
          _buildEscrowDashboard(themeProvider),
          
          const SizedBox(height: 24),
          
          // Recent Transactions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _paymentService.transactions.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final tx = _paymentService.transactions[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _getTransactionColor(tx.type).withOpacity(0.1),
                        child: Icon(_getTransactionIcon(tx.type), color: _getTransactionColor(tx.type)),
                      ),
                      title: Text(tx.recipient, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(DateFormat('MMM dd, hh:mm a').format(tx.timestamp)),
                      trailing: Text(
                        '${tx.type == 'receive' ? '+' : '-'}${_currencyFormat.format(tx.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: tx.type == 'receive' ? Colors.green : Colors.red,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCryptoView(ScreenThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._cryptoService.assets.map((asset) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildAssetCard(asset.symbol, asset.name, asset.balance.toString(), asset.logoUrl),
          )),
          const SizedBox(height: 24),
          Text('Web3 Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeProvider.getColor('text'))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickAction(Icons.send_rounded, 'Send', _showSendCryptoDialog),
              _buildQuickAction(Icons.call_received_rounded, 'Receive', _showReceiveCryptoQR),
              _buildQuickAction(Icons.swap_horiz_rounded, 'Swap', () {}),
              _buildQuickAction(Icons.account_balance_rounded, 'Vault', () {}),
            ],
          ),
          const SizedBox(height: 30),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(child: Text('Your assets are secured by your on-device Biometric key.', style: TextStyle(fontSize: 12))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSendCryptoDialog() {
    final addressController = TextEditingController();
    final amountController = TextEditingController();
    String selectedAsset = _cryptoService.assets.first.symbol;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Crypto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedAsset,
                isExpanded: true,
                items: _cryptoService.assets.map((asset) => DropdownMenuItem(
                  value: asset.symbol,
                  child: Text('${asset.name} (${asset.symbol})'),
                )).toList(),
                onChanged: (val) => setDialogState(() => selectedAsset = val!),
              ),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Recipient Address')),
              TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _cryptoService.sendCrypto(selectedAsset, addressController.text, double.parse(amountController.text));
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction Successful!')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiveCryptoQR() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your Wallet Address', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            QrImageView(
              data: _cryptoService.walletAddress,
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 20),
            Text(_cryptoService.walletAddress, style: const TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
            TextButton(
              onPressed: () {
                _cryptoService.generateNewAddress();
                Navigator.pop(context);
                _showReceiveCryptoQR();
              },
              child: const Text('Generate New Address'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetCard(String symbol, String name, String balance, String logoUrl) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade100, backgroundImage: NetworkImage(logoUrl)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(name, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
          Text(balance, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
        ],
      ),
    );
  }

  void _showReceiveQR() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Receive Money', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            QrImageView(
              data: 'pay_to:${user.uid}',
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 20),
            Text('Wallet ID: ${user.uid.substring(0, 8)}...', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Scan QR Code')),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  Navigator.pop(context);
                  _handleScannedData(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _handleScannedData(String data) {
    if (data.startsWith('pay_to:')) {
      final userId = data.split(':')[1];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Processing payment to user: $userId')),
      );
    }
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(icon, size: 28, color: const Color(0xFF128C7E)),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEscrowDashboard(ScreenThemeProvider themeProvider) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('escrow_transactions')
          .where('buyerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'held')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        final escrows = snapshot.data!.docs;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text('Funds in Escrow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: escrows.length,
                itemBuilder: (context, index) {
                  final data = escrows[index].data() as Map<String, dynamic>;
                  final orderId = escrows[index].id;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(data['itemTitle'] ?? 'Item'),
                    subtitle: Text('Held: ${_currencyFormat.format(data['amount'])}'),
                    trailing: ElevatedButton(
                      onPressed: () => _confirmDelivery(orderId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text('Release Funds'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAjoDashboard(ScreenThemeProvider themeProvider) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ajo_groups')
          .where('members', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        final ajoGroups = snapshot.data!.docs;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.savings, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Titan Ajo Savings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ajoGroups.length,
                itemBuilder: (context, index) {
                  final data = ajoGroups[index].data() as Map<String, dynamic>;
                  final ajoId = ajoGroups[index].id;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(data['name'] ?? 'Savings Circle'),
                    subtitle: Text('Monthly: ${NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(data['contributionAmount'])}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => AjoDetailScreen(ajoId: ajoId)));
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelivery(String orderId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: const Text('By confirming, you authorize the release of funds to the seller. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _escrowService.confirmDelivery(orderId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Funds released to seller.')),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'receive': return Colors.green;
      case 'send': return Colors.red;
      case 'airtime': return Colors.blue;
      case 'ajo': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'receive': return Icons.arrow_downward;
      case 'send': return Icons.arrow_upward;
      case 'airtime': return Icons.phone_android;
      case 'ajo': return Icons.savings;
      default: return Icons.payment;
    }
  }
}
