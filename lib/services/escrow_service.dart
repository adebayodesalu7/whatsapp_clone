import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whatsapp_clone/models/models.dart';

class EscrowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Paystack Configuration (Test Keys)
  static const String paystackPublicKey = "pk_test_943913769cffce5c72ebbbbc703a825abe508c1d";
  static const String paystackSecretKey = "sk_test_dece568d838425c9ca1d3db8b18654fc9d1c2098";

  Future<void> processPaystackPayment(String orderId, double amount) async {
    // This would normally call Paystack SDK
    print("💳 Processing Paystack payment of ₦$amount for Order $orderId");
    await Future.delayed(const Duration(seconds: 2));
    
    // Update statuses on success
    await _firestore.collection('market_orders').doc(orderId).update({
      'status': 'Paid',
      'escrowStatus': 'funds_held',
      'paidAt': FieldValue.serverTimestamp(),
    });
    
    await _firestore.collection('escrow_transactions').doc(orderId).update({
      'status': 'funds_held',
    });
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
    
    // Create dual record in escrow collection for tracking
    await _firestore.collection('escrow_transactions').doc(orderRef.id).set({
      ...orderData,
      'paymentMethod': 'Paystack',
      'participants': [buyerId, item.sellerId],
    });

    return orderRef.id;
  }

  Future<void> confirmDelivery(String orderId) async {
    await _firestore.collection('escrow_transactions').doc(orderId).update({
      'status': 'released',
      'confirmedAt': FieldValue.serverTimestamp(),
    });
    // In a real app, this would trigger a wallet transfer to the seller
  }

  Stream<DocumentSnapshot> getEscrowStatus(String orderId) {
    return _firestore.collection('escrow_transactions').doc(orderId).snapshots();
  }
}
