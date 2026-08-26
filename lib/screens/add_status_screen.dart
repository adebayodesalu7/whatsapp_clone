import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';

class AddStatusScreen extends StatefulWidget {
  const AddStatusScreen({super.key});

  @override
  State<AddStatusScreen> createState() => _AddStatusScreenState();
}

class _AddStatusScreenState extends State<AddStatusScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  File? _image;
  String? _selectedMusic;
  Map<String, dynamic>? _momentWidget;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _showMomentWidgetPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          const ListTile(title: Text('Add Interactive Widget', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.poll),
            title: const Text('Poll'),
            onTap: () {
              Navigator.pop(context);
              _showPollCreator();
            },
          ),
          ListTile(
            leading: const Icon(Icons.question_answer),
            title: const Text('AMA (Ask Me Anything)'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _momentWidget = {'type': 'ama', 'question': 'Ask me anything!'});
            },
          ),
        ],
      ),
    );
  }

  void _showPollCreator() {
    final qController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Poll'),
        content: TextField(controller: qController, decoration: const InputDecoration(hintText: 'Ask a question...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (qController.text.isNotEmpty) {
                setState(() => _momentWidget = {
                  'type': 'poll',
                  'question': qController.text,
                  'options': ['Yes', 'No'],
                  'votes': [0, 0],
                });
                Navigator.pop(context);
              }
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  void _postStatus() async {
    if (_controller.text.isEmpty && _image == null && _momentWidget == null) return;

    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        String? imageUrl;
        if (_image != null) {
          imageUrl = await _storageService.uploadImage(_image!.path, 'status_images');
        }

        await FirebaseFirestore.instance.collection('statuses').add({
          'userId': uid,
          'text': _controller.text,
          'imageUrl': imageUrl,
          'musicUrl': _selectedMusic,
          'momentWidget': _momentWidget,
          'type': imageUrl != null ? 'image' : 'text',
          'timestamp': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
          'viewedBy': [],
        });
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting status: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Status', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_image != null)
                Stack(
                  children: [
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        image: DecorationImage(
                          image: FileImage(_image!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => _image = null),
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'What\'s on your mind?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Pick Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showMusicPicker,
                    icon: Icon(Icons.music_note, color: _selectedMusic != null ? Colors.pink : Colors.purple.shade700),
                    label: Text(_selectedMusic != null ? 'Music Added' : 'Add Music'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade100,
                      foregroundColor: Colors.purple.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showMomentWidgetPicker,
                    icon: Icon(Icons.auto_awesome, color: _momentWidget != null ? Colors.amber : Colors.orange.shade700),
                    label: Text(_momentWidget != null ? 'Widget Added' : 'Titan Widget'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade100,
                      foregroundColor: Colors.orange.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _postStatus,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Post Status'),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMusicPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Select Background Music', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          _musicOption('Upbeat Afrobeat', 'https://example.com/song1.mp3'),
          _musicOption('Chill Lo-Fi', 'https://example.com/song2.mp3'),
          _musicOption('Lagos Vibes', 'https://example.com/song3.mp3'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _musicOption(String title, String url) {
    return ListTile(
      leading: const Icon(Icons.music_note),
      title: Text(title),
      onTap: () {
        setState(() => _selectedMusic = title);
        Navigator.pop(context);
      },
    );
  }
}

