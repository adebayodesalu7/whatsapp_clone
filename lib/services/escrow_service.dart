import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/models.dart';

class EscrowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String paystackPublicKey = "pk_test_943913769cffce5c72ebbbbc703a825abe508c1d";
  static const String paystackSecretKey = "sk_test_dece568d838425c9ca1d3db8b18654fc9d1c2098";

  Future<bool> processPaystackPayment(BuildContext context, {
    required String email,
    required double amount,
    required String reference,
    required Function(String) onSuccess,
  }) async {
    try {
      print("💳 [Simulated] Processing Paystack payment of ₦$amount...");
      // For the demo build to work without package issues, we simulate success
      await Future.delayed(const Duration(seconds: 2));
      await onSuccess(reference);
      return true;
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
