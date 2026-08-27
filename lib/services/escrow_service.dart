import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/models.dart';
import 'paystack_service.dart';

class EscrowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PaystackService _paystackService = PaystackService();

  Future<bool> processPaystackPayment(BuildContext context, {
    required String email,
    required double amount,
    required String reference,
    required Function(String) onSuccess,
  }) async {
    try {
      final response = await _paystackService.checkout(
        context: context,
        email: email,
        amount: amount,
        reference: reference,
      );

      if (response != null && response['status'] == true) {
        await onSuccess(reference);
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response?['message'] ?? 'Payment failed'), backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      print("❌ Paystack Error: $e");
      return false;
    }
  }

  Future<String> createEscrowInvoice({
    required MarketplaceItem item,
    required String buyerId,
  }) async {
    final orderRef = _firestore.collection('market_orders').doc();
    
    final orderData = {
      'buyerId': buyerId,
      'sellerId': item.sellerId,
      'itemId': item.id,
      'itemTitle': item.title,
      'amount': item.price,
      'status': 'Pending',
      'escrowStatus': 'awaiting_payment',
      'timestamp': FieldValue.serverTimestamp(),
    };

    await orderRef.set(orderData);
    
    await _firestore.collection('escrow_transactions').doc(orderRef.id).set({
      ...orderData,
      'paymentMethod': 'Paystack',
      'participants': [buyerId, item.sellerId],
    });

    return orderRef.id;
  }

  Future<void> updateOrderToPaid(String orderId, String reference) async {
    await _firestore.collection('market_orders').doc(orderId).update({
      'status': 'Paid',
      'escrowStatus': 'funds_held',
      'paystackReference': reference,
      'paidAt': FieldValue.serverTimestamp(),
    });
    
    await _firestore.collection('escrow_transactions').doc(orderId).update({
      'status': 'funds_held',
      'reference': reference,
    });
  }

  Future<void> confirmDelivery(String orderId) async {
    await _firestore.collection('escrow_transactions').doc(orderId).update({
      'status': 'released',
      'confirmedAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('market_orders').doc(orderId).update({
      'escrowStatus': 'released',
    });
  }

  Stream<DocumentSnapshot> getEscrowStatus(String orderId) {
    return _firestore.collection('escrow_transactions').doc(orderId).snapshots();
  }
}
