import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'encryption_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _encryptionKey = 'ChatAppSecretKey2024!@#';

  bool _isOnline = true; 

  void setOnlineStatus(bool online) {
    _isOnline = online;
    if (_isOnline) {
      _syncPendingMessages();
    }
  }

  bool get isOnline => _isOnline;

  Future<void> _syncPendingMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingJson = prefs.getStringList('pending_messages') ?? [];
    if (pendingJson.isEmpty) return;

    print('🔄 Syncing ${pendingJson.length} pending messages from storage...');
    
    List<String> remaining = [];
    for (var jsonStr in pendingJson) {
      final msg = json.decode(jsonStr);
      try {
        await sendMessage(
          msg['receiverId'], 
          msg['message'], 
          isGroup: msg['isGroup'] ?? false,
          isEncrypted: msg['isEncrypted'] ?? false,
        );
      } catch (e) {
        remaining.add(jsonStr);
      }
    }
    await prefs.setStringList('pending_messages', remaining);
  }

  String getChatId(String user1Id, String user2Id) {
    List<String> ids = [user1Id, user2Id];
    ids.sort();
    return ids.join('_');
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  Future<void> sendMessage(String receiverId, String message, {bool isGroup = false, String? replyTo, int? disappearingTimer, bool isEncrypted = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (!_isOnline) {
      print('📴 Offline: Saving message to persistent queue...');
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_messages') ?? [];
      pending.add(json.encode({
        'receiverId': receiverId,
        'message': message,
        'isGroup': isGroup,
        'isEncrypted': isEncrypted,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      await prefs.setStringList('pending_messages', pending);
      return;
    }

    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);
    final encryptedMessage = isEncrypted ? message : EncryptionService.encrypt(message, _encryptionKey);

    final messageData = {
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'message': encryptedMessage,
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
      'lastMessage': encryptedMessage,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUser.uid,
      'participants': isGroup ? null : [currentUser.uid, receiverId],
      'isGroup': isGroup,
    }, SetOptions(merge: true));
  }

  Future<void> sendImageMessage(String receiverId, String imageUrl, {bool isGroup = false, bool isViewOnce = false}) async {
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

  Future<void> sendInvoiceMessage(String receiverId, Map<String, dynamic> invoice, {bool isGroup = false}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);
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

  Future<void> sendSplitBillMessage(String receiverId, Map<String, dynamic> splitData, bool isGroup) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final chatId = isGroup ? receiverId : getChatId(currentUser.uid, receiverId);
    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'message': '💸 Split Bill',
      'type': 'split_bill',
      'metadata': splitData,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> sendAjoInvitation(String receiverId, Map<String, dynamic> ajoData) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    final chatId = getChatId(currentUser.uid, receiverId);
    
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [currentUser.uid, receiverId],
      'lastMessage': '📩 Ajo Group Invitation',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'isGroup': false,
    }, SetOptions(merge: true));

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'message': 'Invitation to join Ajo: ${ajoData['name']}',
      'type': 'ajo_invitation',
      'metadata': ajoData,
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

  Future<void> promoteToAdmin(String channelId, String userId) async {
    await _firestore.collection('channels').doc(channelId).update({
      'admins': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> deleteChannel(String channelId) async {
    await _firestore.collection('channels').doc(channelId).delete();
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

  Future<void> setDisappearingTimer(String chatId, int seconds) async {
    await _firestore.collection('chats').doc(chatId).update({
      'disappearingTimer': seconds,
    });
  }

  Future<void> toggleChatLock(String chatId, bool lock) async {
    await _firestore.collection('chats').doc(chatId).update({'isLocked': lock});
  }

  Future<void> muteChat(String chatId, int hours) async {
    final DateTime until = DateTime.now().add(Duration(hours: hours));
    await _firestore.collection('chats').doc(chatId).update({
      'mutedUntil': Timestamp.fromDate(until),
    });
  }

  Future<void> unmuteChat(String chatId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'mutedUntil': null,
    });
  }

  Future<void> pinChat(String chatId, bool pin) async {
    await _firestore.collection('chats').doc(chatId).update({'isPinned': pin});
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

  Future<void> deleteChat(String chatId) async {
    // Delete all messages in the sub-collection
    final messages = await _firestore.collection('chats').doc(chatId).collection('messages').get();
    for (var doc in messages.docs) {
      await doc.reference.delete();
    }
    // Delete the chat metadata document
    await _firestore.collection('chats').doc(chatId).delete();
  }
}
