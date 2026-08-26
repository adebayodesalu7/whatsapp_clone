import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class BusinessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser?.uid ?? '';

  // Catalog Management
  Future<void> addCatalogItem(CatalogItem item) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('catalog')
        .add(item.toMap());
  }

  Stream<List<CatalogItem>> getCatalogItems(String vendorId) {
    return _firestore
        .collection('users')
        .doc(vendorId)
        .collection('catalog')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CatalogItem.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> deleteCatalogItem(String itemId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('catalog')
        .doc(itemId)
        .delete();
  }

  // Invoice Management
  Future<void> updateInvoiceStatus(String chatId, String messageId, String status) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'metadata.status': status,
    });
  }

  Stream<List<Invoice>> getInvoices(String userId) {
    return _firestore
        .collectionGroup('messages')
        .where('type', isEqualTo: 'invoice')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Invoice.fromMap({...doc.data()['metadata'] ?? {}, 'id': doc.id}))
            .toList());
  }

  Stream<List<Map<String, dynamic>>> getOrders(String vendorId) {
    return _firestore
        .collection('users')
        .doc(vendorId)
        .collection('orders')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }
}
