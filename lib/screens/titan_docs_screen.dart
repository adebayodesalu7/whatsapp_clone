import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';

class TitanDocsScreen extends StatefulWidget {
  final String? docId;
  final String? initialContent;
  final String? title;

  const TitanDocsScreen({super.key, this.docId, this.initialContent, this.title});

  @override
  State<TitanDocsScreen> createState() => _TitanDocsScreenState();
}

class _TitanDocsScreenState extends State<TitanDocsScreen> {
  late TextEditingController _contentController;
  late TextEditingController _titleController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent ?? "");
    _titleController = TextEditingController(text: widget.title ?? "Untitled Titan Doc");
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    final data = {
      'title': _titleController.text,
      'content': _contentController.text,
      'ownerId': user.uid,
      'lastModified': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.docId == null) {
        final docRef = await FirebaseFirestore.instance.collection('titan_docs').add(data);
        Navigator.pop(context, docRef.id);
      } else {
        await FirebaseFirestore.instance.collection('titan_docs').doc(widget.docId).update(data);
        Navigator.pop(context, widget.docId);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: TextField(
          controller: _titleController,
          style: TextStyle(color: themeProvider.getColor('appBarText'), fontWeight: FontWeight.bold),
          decoration: const InputDecoration(border: InputBorder.none),
        ),
        backgroundColor: themeProvider.getColor('appBar'),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _saveDoc),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _contentController,
          maxLines: null,
          expands: true,
          style: TextStyle(color: themeProvider.getColor('text'), fontSize: 16),
          decoration: const InputDecoration(
            hintText: "Start typing your Titan Doc...",
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
