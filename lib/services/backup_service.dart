import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

class BackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> createBackup(String userId) async {
    try {
      final chatsSnap = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      List<Map<String, dynamic>> backupData = [];

      for (var chatDoc in chatsSnap.docs) {
        final messagesSnap = await chatDoc.reference.collection('messages').get();
        final messages = messagesSnap.docs.map((d) => d.data()).toList();
        
        backupData.add({
          'chatId': chatDoc.id,
          'chatData': chatDoc.data(),
          'messages': messages,
        });
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/whatsapp_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonEncode(backupData));

      return file.path;
    } catch (e) {
      print('Backup Error: $e');
      return null;
    }
  }

  Future<bool> restoreBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final String content = await file.readAsString();
      final List<dynamic> backupData = jsonDecode(content);

      for (var chat in backupData) {
        final chatId = chat['chatId'];
        final chatData = chat['chatData'] as Map<String, dynamic>;
        final messages = chat['messages'] as List<dynamic>;

        await _firestore.collection('chats').doc(chatId).set(chatData);
        for (var msg in messages) {
          await _firestore.collection('chats').doc(chatId).collection('messages').add(Map<String, dynamic>.from(msg));
        }
      }
      return true;
    } catch (e) {
      print('Restore Error: $e');
      return false;
    }
  }
}
