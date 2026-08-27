import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/payment_service.dart';
import '../providers/screen_theme_provider.dart';

class AirtimePurchaseScreen extends StatefulWidget {
  const AirtimePurchaseScreen({super.key});

  @override
  State<AirtimePurchaseScreen> createState() => _AirtimePurchaseScreenState();
}

class _AirtimePurchaseScreenState extends State<AirtimePurchaseScreen> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedProvider = 'MTN';
  bool _isLoading = false;

  final List<Map<String, String>> _providers = [
    {'name': 'MTN', 'logo': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/MTN_Logo.svg/1024px-MTN_Logo.svg.png'},
    {'name': 'Glo', 'logo': 'https://upload.wikimedia.org/wikipedia/en/thumb/8/8e/Glo_logo.svg/1200px-Glo_logo.svg.png'},
    {'name': 'Airtel', 'logo': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Airtel_logo_new.svg/1280px-Airtel_logo_new.svg.png'},
    {'name': '9mobile', 'logo': 'https://upload.wikimedia.org/wikipedia/en/thumb/9/90/9mobile_logo.svg/1200px-9mobile_logo.svg.png'},
  ];

  void _purchaseAirtime(PaymentService paymentService) async {
    if (_phoneController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));
      return;
    }

    setState(() => _isLoading = true);
    final success = await paymentService.purchaseAirtime(
      _selectedProvider,
      _phoneController.text,
      amount,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Airtime purchase successful!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient wallet balance!'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ScreenThemeProvider>(context);
    final paymentService = PaymentService(); // Access instance

    return Scaffold(
      backgroundColor: theme.getColor('scaffold'),
      appBar: AppBar(
        title: Text('Buy Airtime', style: TextStyle(fontWeight: FontWeight.bold, color: theme.getColor('appBarText'))),
        backgroundColor: theme.getColor('appBar'),
        iconTheme: IconThemeData(color: theme.getColor('appBarText')),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Provider', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.getColor('text'))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _providers.map((p) => _buildProviderLogo(p, theme)).toList(),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: theme.getColor('text')),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(color: theme.getColor('textSecondary')),
                hintText: 'e.g. 08030000000',
                hintStyle: TextStyle(color: theme.getColor('textSecondary').withOpacity(0.5)),
                prefixIcon: Icon(Icons.phone, color: theme.getColor('primary')),
                filled: true,
                fillColor: theme.getColor('inputFill'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: theme.getColor('text')),
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: TextStyle(color: theme.getColor('textSecondary')),
                prefixText: '₦ ',
                prefixStyle: TextStyle(color: theme.getColor('primary'), fontWeight: FontWeight.bold),
                prefixIcon: Icon(Icons.account_balance_wallet, color: theme.getColor('primary')),
                filled: true,
                fillColor: theme.getColor('inputFill'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _purchaseAirtime(paymentService),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.getColor('primary'),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('PROCEED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderLogo(Map<String, String> provider, ScreenThemeProvider theme) {
    bool isSelected = _selectedProvider == provider['name'];
    return GestureDetector(
      onTap: () => setState(() => _selectedProvider = provider['name']!),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? theme.getColor('primary').withOpacity(0.1) : theme.getColor('card'),
          border: Border.all(color: isSelected ? theme.getColor('primary') : theme.getColor('divider'), width: 2),
          borderRadius: BorderRadius.circular(15),
          boxShadow: isSelected ? [BoxShadow(color: theme.getColor('primary').withOpacity(0.2), blurRadius: 8)] : null,
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(provider['logo']!, height: 40, width: 40, fit: BoxFit.contain, 
                  errorBuilder: (_, __, ___) => Icon(Icons.cell_tower, size: 40, color: theme.getColor('textSecondary'))),
            ),
            const SizedBox(height: 4),
            Text(provider['name']!, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: theme.getColor('text'))),
          ],
        ),
      ),
    );
  }
}
