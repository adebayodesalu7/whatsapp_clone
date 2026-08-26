import 'package:flutter/material.dart';
import '../services/payment_service.dart';

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

  void _purchaseAirtime() async {
    if (_phoneController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);
    final success = await PaymentService().purchaseAirtime(
      _selectedProvider,
      _phoneController.text,
      double.tryParse(_amountController.text) ?? 0.0,
    );
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Airtime purchase successful!')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient balance')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Buy Airtime', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Provider', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _providers.map((p) => _buildProviderLogo(p)).toList(),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. 08030000000',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₦ ',
                prefixIcon: const Icon(Icons.account_balance_wallet),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _purchaseAirtime,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('PROCEED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderLogo(Map<String, String> provider) {
    bool isSelected = _selectedProvider == provider['name'];
    return GestureDetector(
      onTap: () => setState(() => _selectedProvider = provider['name']!),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? const Color(0xFF25D366) : Colors.grey.shade200, width: 2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Image.network(provider['logo']!, height: 40, width: 40, fit: BoxFit.contain, 
                errorBuilder: (_, __, ___) => const Icon(Icons.cell_tower, size: 40)),
            const SizedBox(height: 4),
            Text(provider['name']!, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
