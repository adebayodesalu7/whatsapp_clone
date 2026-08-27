import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/screen_theme_provider.dart';
import 'contacts_screen.dart';

class ContactInfoScreen extends StatefulWidget {
  final String contactId;
  final String contactName;
  final bool isGroup;

  const ContactInfoScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    this.isGroup = false,
  });

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  Future<void> _pickImage(bool isAdmin) async {
    if (!isAdmin && widget.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admins can change group photo.')));
      return;
    }
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      String collection = widget.isGroup ? 'groups' : 'users';
      await FirebaseFirestore.instance.collection(collection).doc(widget.contactId).set({
        'photoUrl': pickedFile.path, 
      }, SetOptions(merge: true));
    }
  }

  Future<void> _editField(String title, String field, String currentValue, ScreenThemeProvider themeProvider, bool isAdmin) async {
    if (!isAdmin && widget.isGroup) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admins can edit group details.')));
      return;
    }
    final controller = TextEditingController(text: currentValue);
    String collection = widget.isGroup ? 'groups' : 'users';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.getColor('card'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit $title', style: TextStyle(color: themeProvider.getColor('text'), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: themeProvider.getColor('text')),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.getColor('textSecondary').withOpacity(0.5))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: themeProvider.getColor('primary'))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: themeProvider.getColor('textSecondary'))),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection(collection).doc(widget.contactId).set({
                field: controller.text,
              }, SetOptions(merge: true));
              if (mounted) Navigator.pop(context);
              setState(() {});
            },
            child: Text('Save', style: TextStyle(color: themeProvider.getColor('primary'), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRolePicker(String memberId, String name, ScreenThemeProvider themeProvider, bool currentUserIsAdmin) {
    if (!currentUserIsAdmin) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Manage $name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeProvider.getColor('text'))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.blue),
              title: const Text('Promote to Admin'),
              onTap: () async {
                await FirebaseFirestore.instance.collection('groups').doc(widget.contactId).update({
                  'admins': FieldValue.arrayUnion([memberId]),
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: const Text('Remove from Group'),
              onTap: () async {
                await FirebaseFirestore.instance.collection('groups').doc(widget.contactId).update({
                  'members': FieldValue.arrayRemove([memberId]),
                  'admins': FieldValue.arrayRemove([memberId]),
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addParticipant(bool isAdmin) async {
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admins can add members.')));
      return;
    }
    final contact = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ContactsScreen(isPicker: true)),
    );

    if (contact != null && contact['userId'] != null && contact['userId'].isNotEmpty) {
      await FirebaseFirestore.instance.collection('groups').doc(widget.contactId).update({
        'members': FieldValue.arrayUnion([contact['userId']]),
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${contact['name']} added.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');
    final scaffoldColor = themeProvider.getColor('scaffold');
    final appBarColor = themeProvider.getColor('appBar');
    final appBarTextColor = themeProvider.getColor('appBarText');
    
    String collection = widget.isGroup ? 'groups' : 'users';

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text(widget.isGroup ? 'Group Info' : 'Contact Info', style: TextStyle(fontWeight: FontWeight.bold, color: appBarTextColor)),
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: appBarTextColor),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection(collection).doc(widget.contactId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: themeProvider.getColor('primary')));
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final name = data['name'] ?? widget.contactName;
          final about = data['about'] ?? (widget.isGroup ? 'Group Description' : 'Hey there! I am using WhatsApp');
          final photoUrl = data['photoUrl'] ?? '';
          final members = widget.isGroup ? List<String>.from(data['members'] ?? []) : [];
          final admins = widget.isGroup ? List<String>.from(data['admins'] ?? []) : [];
          
          final currentUser = FirebaseAuth.instance.currentUser;
          final bool isAdmin = !widget.isGroup || (currentUser != null && admins.contains(currentUser.uid));

          ImageProvider? imageProvider;
          if (_imageFile != null) {
            imageProvider = FileImage(_imageFile!);
          } else if (photoUrl.isNotEmpty) {
            if (photoUrl.startsWith('http')) {
              imageProvider = NetworkImage(photoUrl);
            } else {
              final file = File(photoUrl);
              if (file.existsSync()) imageProvider = FileImage(file);
            }
          }

          return ListView(
            children: [
              Container(
                color: themeProvider.getColor('card'),
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _pickImage(isAdmin),
                        child: CircleAvatar(
                          radius: 80,
                          backgroundColor: themeProvider.getColor('scaffold'),
                          backgroundImage: imageProvider,
                          child: imageProvider == null 
                              ? Icon(Icons.person, size: 80, color: secondaryTextColor.withOpacity(0.5)) 
                              : null,
                        ),
                      ),
                      if (isAdmin)
                        Positioned(
                          bottom: 5,
                          right: 15,
                          child: CircleAvatar(
                            backgroundColor: themeProvider.getColor('primary'),
                            radius: 22,
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoSection(
                themeProvider,
                child: Column(
                  children: [
                    _buildInfoTile(
                      icon: Icons.info_outline,
                      title: widget.isGroup ? 'Group Name' : 'Name',
                      subtitle: name,
                      onTap: isAdmin ? () => _editField(widget.isGroup ? 'Group Name' : 'Name', 'name', name, themeProvider, isAdmin) : null,
                      themeProvider: themeProvider,
                    ),
                    Divider(indent: 70, color: themeProvider.getColor('divider')),
                    _buildInfoTile(
                      icon: Icons.description_outlined,
                      title: widget.isGroup ? 'Group Description' : 'About',
                      subtitle: about,
                      onTap: isAdmin ? () => _editField(widget.isGroup ? 'Description' : 'About', 'about', about, themeProvider, isAdmin) : null,
                      themeProvider: themeProvider,
                    ),
                    if (widget.isGroup) ...[
                      Divider(indent: 70, color: themeProvider.getColor('divider')),
                      _buildInfoTile(
                        icon: Icons.task_alt,
                        title: 'Shared Task List',
                        subtitle: 'Manage group goals and tasks',
                        onTap: () => _showTaskList(context, themeProvider),
                        themeProvider: themeProvider,
                      ),
                      Divider(indent: 70, color: themeProvider.getColor('divider')),
                      _buildInfoTile(
                        icon: Icons.photo_library_outlined,
                        title: 'Collaborative Album',
                        subtitle: 'A shared gallery for group members',
                        onTap: () => _showCollaborativeAlbum(context, themeProvider),
                        themeProvider: themeProvider,
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.isGroup) ...[
                const SizedBox(height: 12),
                _buildInfoSection(
                  themeProvider,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 70, top: 16, bottom: 8),
                        child: Text('Participants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: themeProvider.getColor('primary'))),
                      ),
                      ...members.map((memberId) => FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
                        builder: (context, userSnap) {
                          final userData = userSnap.data?.data() as Map<String, dynamic>?;
                          final memberName = userData?['name'] ?? memberId;
                          final isMemberAdmin = admins.contains(memberId);
                          return ListTile(
                            onTap: isAdmin ? () => _showRolePicker(memberId, memberName, themeProvider, isAdmin) : null,
                            leading: CircleAvatar(
                              backgroundColor: themeProvider.getColor('primary').withOpacity(0.1),
                              child: Text(memberName[0].toUpperCase(), style: TextStyle(color: themeProvider.getColor('primary'))),
                            ),
                            title: Text(memberName, style: TextStyle(color: textColor)),
                            trailing: isMemberAdmin ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(border: Border.all(color: themeProvider.getColor('primary')), borderRadius: BorderRadius.circular(4)),
                              child: Text('Admin', style: TextStyle(color: themeProvider.getColor('primary'), fontSize: 10)),
                            ) : null,
                          );
                        }
                      )).toList(),
                      if (isAdmin)
                        ListTile(
                          leading: Icon(Icons.person_add, color: themeProvider.getColor('primary')),
                          title: Text('Add Participant', style: TextStyle(color: themeProvider.getColor('primary'), fontWeight: FontWeight.bold)),
                          onTap: () => _addParticipant(isAdmin),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _buildInfoSection(
                themeProvider,
                child: Column(
                  children: [
                    ListTile(leading: const Icon(Icons.block, color: Colors.red), title: const Text('Block', style: TextStyle(color: Colors.red))),
                    Divider(indent: 70, color: themeProvider.getColor('divider')),
                    ListTile(leading: const Icon(Icons.thumb_down, color: Colors.red), title: const Text('Report', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
              const SizedBox(height: 50),
            ],
          );
        },
      ),
    );
  }

  void _showCollaborativeAlbum(BuildContext context, ScreenThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.getColor('card'),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Collaborative Album', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeProvider.getColor('text'))),
                      IconButton(
                        icon: Icon(Icons.add_a_photo, color: themeProvider.getColor('primary')),
                        onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload to Album feature coming soon!')));
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('groups').doc(widget.contactId).collection('album').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final images = snapshot.data!.docs;
                      if (images.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_album_outlined, size: 60, color: themeProvider.getColor('textSecondary').withOpacity(0.3)),
                              const SizedBox(height: 10),
                              Text('No photos yet', style: TextStyle(color: themeProvider.getColor('textSecondary'))),
                            ],
                          ),
                        );
                      }
                      
                      return GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 5, mainAxisSpacing: 5),
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final data = images[index].data() as Map<String, dynamic>;
                          return Image.network(data['url'], fit: BoxFit.cover);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTaskList(BuildContext context, ScreenThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.getColor('card'),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Shared Task List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeProvider.getColor('text'))),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: themeProvider.getColor('primary')),
                        onPressed: () => _showAddTaskDialog(context, themeProvider),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('groups').doc(widget.contactId).collection('tasks').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final tasks = snapshot.data!.docs;
                      if (tasks.isEmpty) return Center(child: Text('No tasks yet', style: TextStyle(color: themeProvider.getColor('textSecondary'))));
                      
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index].data() as Map<String, dynamic>;
                          final isDone = task['isDone'] ?? false;
                          return CheckboxListTile(
                            title: Text(task['title'] ?? '', style: TextStyle(color: themeProvider.getColor('text'), decoration: isDone ? TextDecoration.lineThrough : null)),
                            value: isDone,
                            onChanged: (v) {
                              tasks[index].reference.update({'isDone': v});
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddTaskDialog(BuildContext context, ScreenThemeProvider themeProvider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.getColor('card'),
        title: Text('New Task', style: TextStyle(color: themeProvider.getColor('text'))),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: themeProvider.getColor('text')),
          decoration: const InputDecoration(hintText: 'What needs to be done?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('groups').doc(widget.contactId).collection('tasks').add({
                  'title': controller.text,
                  'isDone': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(ScreenThemeProvider themeProvider, {required Widget child}) {
    return Container(color: themeProvider.getColor('card'), child: child);
  }

  Widget _buildInfoTile({required IconData icon, required String title, required String subtitle, VoidCallback? onTap, required ScreenThemeProvider themeProvider}) {
    return ListTile(
      leading: Icon(icon, color: themeProvider.getColor('textSecondary')),
      title: Text(title, style: TextStyle(color: themeProvider.getColor('textSecondary'), fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: themeProvider.getColor('text'), fontSize: 16)),
      trailing: onTap != null ? const Icon(Icons.edit, size: 20) : null,
      onTap: onTap,
    );
  }
}
