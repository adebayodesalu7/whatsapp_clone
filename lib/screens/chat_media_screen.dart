import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';

class ChatMediaScreen extends StatelessWidget {
  final String chatId;
  const ChatMediaScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: themeProvider.getColor('scaffold'),
        appBar: AppBar(
          title: const Text('Media, links, and docs'),
          backgroundColor: themeProvider.getColor('appBar'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'MEDIA'),
              Tab(text: 'LINKS'),
              Tab(text: 'DOCS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MediaGrid(chatId: chatId, type: 'image'),
            _MediaList(chatId: chatId, type: 'link'),
            _MediaList(chatId: chatId, type: 'doc'),
          ],
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  final String chatId;
  final String type;
  const _MediaGrid({required this.chatId, required this.type});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('type', isEqualTo: type)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No media found'));

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final imageUrl = data['imageUrl'];
            return imageUrl != null
                ? Image.network(imageUrl, fit: BoxFit.cover)
                : Container(color: Colors.grey);
          },
        );
      },
    );
  }
}

class _MediaList extends StatelessWidget {
  final String chatId;
  final String type;
  const _MediaList({required this.chatId, required this.type});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('type', isEqualTo: type)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('Nothing here yet'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final dateStr = timestamp != null ? DateFormat('dd/MM/yyyy').format(timestamp.toDate()) : 'Unknown';
            return ListTile(
              leading: Icon(type == 'link' ? Icons.link : Icons.insert_drive_file),
              title: Text(data['message'] ?? 'Media Item'),
              subtitle: Text(dateStr),
            );
          },
        );
      },
    );
  }
}
