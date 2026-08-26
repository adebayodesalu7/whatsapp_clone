import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? getCurrentUserId() => _auth.currentUser?.uid;

  Stream<QuerySnapshot> getMyStatuses() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('statuses')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot> getStatuses() {
    return _firestore
        .collection('statuses')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> markStatusAsViewed(String statusId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('statuses').doc(statusId).update({
      'viewedBy': FieldValue.arrayUnion([uid])
    });
  }
}
