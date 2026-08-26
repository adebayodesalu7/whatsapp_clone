import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String getChatId(String user1Id, String user2Id) {
    List<String> ids = [user1Id, user2Id];
    ids.sort();
    return ids.join('_');
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  Future<void> sendMessage(String receiverId, String message, {bool isGroup = false, String? replyTo, int? disappearingTimer}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);

    final messageData = {
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'message': message,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'replyTo': replyTo,
      'isDisappearing': (disappearingTimer ?? 0) > 0,
      'expiresAt': (disappearingTimer ?? 0) > 0 
          ? Timestamp.fromDate(DateTime.now().add(Duration(seconds: disappearingTimer!)))
          : null,
    };

    await _firestore.collection('chats').doc(chatId).collection('messages').add(messageData);

    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUser.uid,
      'participants': isGroup ? null : [currentUser.uid, receiverId],
      'isGroup': isGroup,
    }, SetOptions(merge: true));
  }

  Future<void> sendImageMessage(String receiverId, String imageUrl, bool isGroup, {bool isViewOnce = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'imageUrl': imageUrl,
      'type': 'image',
      'isViewOnce': isViewOnce,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> sendVoiceMessage(String receiverId, String audioUrl, bool isGroup) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'audioUrl': audioUrl,
      'type': 'voice',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> sendVideoMessage(String receiverId, String videoUrl, bool isGroup) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'videoUrl': videoUrl,
      'type': 'video',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> sendLocationMessage(String receiverId, double lat, double lng, bool isGroup) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'message': '📍 Location',
      'type': 'location',
      'metadata': {'lat': lat, 'lng': lng},
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> sendContactMessage(String receiverId, Map<String, dynamic> contact, bool isGroup) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'message': '👤 Contact',
      'type': 'contact',
      'metadata': contact,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> sendInvoiceMessage(String receiverId, Map<String, dynamic> invoice) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = getChatId(currentUser.uid, receiverId);

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'message': '🧾 Invoice',
      'type': 'invoice',
      'metadata': invoice,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> sendCryptoPayment(String receiverId, double amount, String currency, String txHash) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = getChatId(currentUser.uid, receiverId);

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'message': '💸 Paid $amount $currency',
      'type': 'crypto_payment',
      'metadata': {'amount': amount, 'currency': currency, 'txHash': txHash},
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> sendCallLogMessage({
    required String receiverId,
    required String callType,
    required bool isMissed,
    required int duration,
    bool isGroup = false,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'type': 'call_log',
      'callType': callType,
      'isMissed': isMissed,
      'duration': duration,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> sendGameChallenge(String receiverId, String game, {bool isGroup = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'type': 'game_challenge',
      'game': game,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> sendChannelMessage(String channelId, String message) async {
    await _firestore.collection('channels').doc(channelId).collection('messages').add({
      'senderId': _auth.currentUser?.uid,
      'message': message,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteChannelMessage(String channelId, String messageId) async {
    await _firestore.collection('channels').doc(channelId).collection('messages').doc(messageId).delete();
  }

  Future<void> updateChannel(String channelId, Map<String, dynamic> data) async {
    await _firestore.collection('channels').doc(channelId).update(data);
  }

  Stream<QuerySnapshot> getMessages(String receiverId, {bool isGroup = false}) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> markMessagesAsRead(String receiverId, {bool isGroup = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);

    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('read', isEqualTo: false)
        .get();

    for (var doc in messages.docs) {
      await doc.reference.update({'read': true});
    }
  }

  Future<void> clearChat(String receiverId, {bool isGroup = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);

    final messages = await _firestore.collection('chats').doc(chatId).collection('messages').get();
    for (var doc in messages.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> pinMessage(String receiverId, String messageId, bool pin, bool isGroup) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).update({'isPinned': pin});
  }

  Stream<QuerySnapshot> getPinnedMessages(String receiverId, bool isGroup) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isPinned', isEqualTo: true)
        .snapshots();
  }

  Future<void> setDisappearingTimer(String chatId, int seconds) async {
    await _firestore.collection('chats').doc(chatId).update({
      'disappearingTimer': seconds,
    });
  }

  Future<void> toggleChatLock(String chatId, bool lock) async {
    await _firestore.collection('chats').doc(chatId).update({'isLocked': lock});
  }

  Future<void> pinChat(String chatId, bool pin) async {
    await _firestore.collection('chats').doc(chatId).update({'isPinned': pin});
  }

  Future<void> toggleFollowChannel(String channelId, bool follow) async {
     final currentUser = _auth.currentUser;
     if (currentUser == null) return;
     if (follow) {
       await _firestore.collection('channels').doc(channelId).update({
         'followers': FieldValue.arrayUnion([currentUser.uid])
       });
     } else {
       await _firestore.collection('channels').doc(channelId).update({
         'followers': FieldValue.arrayRemove([currentUser.uid])
       });
     }
  }

  Future<void> promoteToAdmin(String channelId, String userId) async {
    await _firestore.collection('channels').doc(channelId).update({
      'admins': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> deleteChannel(String channelId) async {
    await _firestore.collection('channels').doc(channelId).delete();
  }

  Future<void> processAjoContribution(String ajoId, String userId, double amount) async {
    print("Processed Ajo contribution: $amount for $userId in $ajoId");
  }
}
