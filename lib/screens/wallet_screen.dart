import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/payment_service.dart';
import '../providers/screen_theme_provider.dart';
import 'airtime_purchase_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 2);

  void _showTopUpDialog(PaymentService paymentService, ScreenThemeProvider theme) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.getColor('card'),
        title: Text('Top Up Wallet', style: TextStyle(color: theme.getColor('text'))),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: theme.getColor('text')),
          decoration: InputDecoration(
            labelText: 'Enter Amount',
            prefixText: '₦',
            labelStyle: TextStyle(color: theme.getColor('textSecondary')),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                await paymentService.topUp(amount);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('₦$amount added to wallet!')));
                }
              }
            },
            child: const Text('Add Funds'),
          ),
        ],
      ),
    );
  }

  void _showSendMoneyDialog(PaymentService paymentService, ScreenThemeProvider theme) {
    final amountController = TextEditingController();
    final recipientController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.getColor('card'),
        title: Text('Send Money', style: TextStyle(color: theme.getColor('text'))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: recipientController,
              style: TextStyle(color: theme.getColor('text')),
              decoration: InputDecoration(labelText: 'Recipient Name', labelStyle: TextStyle(color: theme.getColor('textSecondary'))),
            ),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: theme.getColor('text')),
              decoration: InputDecoration(labelText: 'Amount', prefixText: '₦', labelStyle: TextStyle(color: theme.getColor('textSecondary'))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0 && recipientController.text.isNotEmpty) {
                final success = await paymentService.sendMoney(recipientController.text, amount);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Successfully sent ₦$amount' : 'Insufficient balance!')),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ScreenThemeProvider>(context);
    final isDark = theme.isDarkMode;
    
    // We use a ListenableProvider or just ChangeNotifierProvider at a higher level, 
    // but here we can just access it. Assuming it's already provided in main.dart
    return ChangeNotifierProvider.value(
      value: PaymentService(),
      child: Consumer<PaymentService>(
        builder: (context, paymentService, child) {
          return Scaffold(
            backgroundColor: theme.getColor('scaffold'),
            appBar: AppBar(
              title: Text('My Wallet', style: TextStyle(fontWeight: FontWeight.bold, color: theme.getColor('appBarText'))),
              backgroundColor: theme.getColor('appBar'),
              iconTheme: IconThemeData(color: theme.getColor('appBarText')),
              elevation: 0,
            ),
            body: SingleChildScrollView(
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
                            _currencyFormat.format(paymentService.balance),
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
                        _buildQuickAction(Icons.send, 'Send', () => _showSendMoneyDialog(paymentService, theme), theme),
                        _buildQuickAction(Icons.phone_android, 'Airtime', () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const AirtimePurchaseScreen()));
                        }, theme),
                        _buildQuickAction(Icons.add, 'Top Up', () => _showTopUpDialog(paymentService, theme), theme),
                        _buildQuickAction(Icons.history, 'History', () {}, theme),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Recent Transactions
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.getColor('card'),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.getColor('text'))),
                        const SizedBox(height: 16),
                        paymentService.transactions.isEmpty 
                          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('No transactions yet', style: TextStyle(color: theme.getColor('textSecondary')))))
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: paymentService.transactions.length,
                              separatorBuilder: (_, __) => Divider(color: theme.getColor('divider')),
                              itemBuilder: (context, index) {
                                final tx = paymentService.transactions[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: _getTransactionColor(tx.type).withOpacity(0.1),
                                    child: Icon(_getTransactionIcon(tx.type), color: _getTransactionColor(tx.type)),
                                  ),
                                  title: Text(tx.recipient, style: TextStyle(fontWeight: FontWeight.bold, color: theme.getColor('text'))),
                                  subtitle: Text(DateFormat('MMM dd, hh:mm a').format(tx.timestamp), style: TextStyle(color: theme.getColor('textSecondary'))),
                                  trailing: Text(
                                    '${(tx.type == 'receive') ? '+' : '-'}${_currencyFormat.format(tx.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: (tx.type == 'receive') ? Colors.green : Colors.red,
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
            ),
          );
        }
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap, ScreenThemeProvider theme) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.getColor('card'),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(icon, size: 28, color: theme.getColor('primary')),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.getColor('text'))),
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
