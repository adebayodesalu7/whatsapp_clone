import 'package:flutter/material.dart';
import 'package:flutter_paystack_max/flutter_paystack_max.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaystackService {
  static const String _secretKey = 'sk_test_dece568d838425c9ca1d3db8b18654fc9d1c2098';
  static const String _publicKey = 'pk_test_943913769cffce5c72ebbbbc703a825abe508c1d';

  PaystackService();

  Future<String?> promptForEmail(BuildContext context, String? currentEmail) async {
    // If we have a real email (not our virtual one), use it.
    if (currentEmail != null && currentEmail.isNotEmpty && !currentEmail.endsWith('@titan-ajo.com')) {
      return currentEmail;
    }

    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Email Address Required', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paystack requires a valid email to process payments and send receipts.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. adebayo@gmail.com',
                labelText: 'Email Address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final email = controller.text.trim();
              if (email.contains('@') && email.contains('.') && email.length > 5) {
                Navigator.pop(context, email);
              }
            },
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('PROCEED'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> checkout({
    required BuildContext context,
    required String email,
    required double amount,
    required String reference,
  }) async {
    // Paystack expects amount in Kobo (int)
    final double amountInKobo = amount * 100;

    final request = p.PaystackTransactionRequest(
      reference: reference,
      secretKey: _secretKey,
      email: email,
      amount: amountInKobo, 
      currency: p.PaystackCurrency.ngn,
      channel: [
        p.PaystackPaymentChannel.card,
        p.PaystackPaymentChannel.ussd,
        p.PaystackPaymentChannel.bankTransfer,
      ],
    );

    try {
      debugPrint('Paystack: Initializing transaction for $email (₦$amount)...');
      final initializedTransaction = await p.PaymentService.initializeTransaction(request);

      if (!initializedTransaction.status) {
        debugPrint('Paystack Init Failed: ${initializedTransaction.message}');
        return {'status': false, 'message': 'Init Error: ${initializedTransaction.message}'};
      }

      debugPrint('Paystack: Transaction initialized successfully. Access Code: ${initializedTransaction.data?.accessCode}');

      debugPrint('Paystack: Showing payment modal...');
      await p.PaymentService.showPaymentModal(
        context,
        transaction: initializedTransaction,
        callbackUrl: 'https://standard.paystack.co/close', 
      );

      debugPrint('Paystack: Verifying transaction $reference...');
      // Wait a bit for Paystack to process the webhook if any
      await Future.delayed(const Duration(seconds: 2));

      final verificationResponse = await p.PaymentService.verifyTransaction(
        paystackSecretKey: _secretKey,
        initializedTransaction.data?.reference ?? reference,
      );

      debugPrint('Paystack Verification Result: ${verificationResponse.status} - ${verificationResponse.message}');
      
      return {
        'status': verificationResponse.status,
        'message': verificationResponse.status ? 'Payment Successful' : 'Verification Failed: ${verificationResponse.message}',
        'reference': reference,
        'data': verificationResponse.data,
      };
    } catch (e) {
      debugPrint('Paystack Catch Error: $e');
      return {'status': false, 'message': 'Checkout exception: $e'};
    }
  }

  /// Generates a Dedicated Virtual Account for an Ajo Group
  /// In a production app, this SHOULD be done on a secure backend.
  Future<Map<String, String>> createDedicatedAccount(String groupName, String email) async {
    try {
      // 1. Create or Identify Customer on Paystack
      // 2. Request Dedicated Account
      
      // Since this is a test/demo environment, we simulate the API response
      // to avoid 'sk_key' exposure and account-specific API restrictions.
      
      await Future.delayed(const Duration(seconds: 2)); // Simulate network latency

      // Real API logic would look like this:
      /*
      final response = await http.post(
        Uri.parse('https://api.paystack.co/dedicated_account'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "customer": email, 
          "preferred_bank": "wema-bank"
        }),
      );
      */

      // Mocked NUBAN details based on Paystack's Test environment format
      final randomSuffix = (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
      
      return {
        'bankName': 'Wema Bank (Titan)',
        'accountNumber': '9920$randomSuffix',
        'accountName': 'Titan Ajo: $groupName',
      };
    } catch (e) {
      debugPrint('Paystack DVA Error: $e');
      return {
        'bankName': 'Titan Microfinance Bank',
        'accountNumber': '0000000000',
        'accountName': 'Generation Failed',
      };
    }
  }

  String generateReference() {
    return 'ajo_${const Uuid().v4()}';
  }
}
