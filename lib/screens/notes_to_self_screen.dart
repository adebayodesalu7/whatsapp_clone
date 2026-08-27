import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/screen_theme_provider.dart';

class NotesToSelfScreen extends StatefulWidget {
  const NotesToSelfScreen({super.key});

  @override
  State<NotesToSelfScreen> createState() => _NotesToSelfScreenState();
}

class _NotesToSelfScreenState extends State<NotesToSelfScreen> {
  String _selectedFilter = 'General';
  final List<String> _filters = ['General', 'Work', 'Personal', 'Ideas'];

  @override
  void initState() {
    super.initState();
  }

  void _addNote(ScreenThemeProvider themeProvider) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.getColor('card'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('New Note in $_selectedFilter', style: TextStyle(color: themeProvider.getColor('text'), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: noteController,
          autofocus: true,
          style: TextStyle(color: themeProvider.getColor('text')),
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Type something...',
            hintStyle: TextStyle(color: themeProvider.getColor('textSecondary').withOpacity(0.5)),
            filled: true,
            fillColor: themeProvider.getColor('inputFill'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: themeProvider.getColor('textSecondary')))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.getColor('primary'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (noteController.text.isNotEmpty) {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('notes').add({
                    'text': noteController.text,
                    'folder': _selectedFilter,
                    'time': DateTime.now().toIso8601String(),
                  });
                }
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add Note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');
    final primaryColor = themeProvider.getColor('primary');
    final cardColor = themeProvider.getColor('card');
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: Text('Notes to Self', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
        backgroundColor: themeProvider.getColor('appBar'),
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.create_new_folder_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Folders Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                TextButton(
                  onPressed: () {}, 
                  child: Text('View All', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Folder Grid
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final folder = _filters[index];
                final isSelected = _selectedFilter == folder;
                IconData folderIcon;
                switch (folder) {
                  case 'Work': folderIcon = Icons.work; break;
                  case 'Personal': folderIcon = Icons.person; break;
                  case 'Ideas': folderIcon = Icons.lightbulb; break;
                  default: folderIcon = Icons.folder;
                }

                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = folder),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isSelected ? 0.1 : 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(folderIcon, color: isSelected ? Colors.white : primaryColor, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          folder,
                          style: TextStyle(
                            color: isSelected ? Colors.white : textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
            ),
          ),

          Expanded(
            child: user == null 
              ? const Center(child: Text('Login to see notes'))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('notes').where('folder', isEqualTo: _selectedFilter).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final currentNotes = snapshot.data!.docs;

                    if (currentNotes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.note_alt_outlined, size: 80, color: secondaryTextColor.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            Text('No notes in $_selectedFilter.', style: TextStyle(color: secondaryTextColor, fontSize: 16)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: currentNotes.length,
                      itemBuilder: (context, index) {
                        final noteDoc = currentNotes[index];
                        final note = noteDoc.data() as Map<String, dynamic>;
                        return Card(
                          color: cardColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: themeProvider.getColor('divider').withOpacity(0.5)),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            title: Text(note['text']!, style: TextStyle(color: textColor, fontSize: 15)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(note['time'] != null ? note['time'].toString().substring(11, 16) : '', style: TextStyle(color: secondaryTextColor, fontSize: 11)),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.withOpacity(0.6)),
                              onPressed: () => noteDoc.reference.delete(),
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNote(themeProvider),
        backgroundColor: primaryColor,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
