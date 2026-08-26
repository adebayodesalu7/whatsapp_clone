import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/screen_theme_provider.dart';

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

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      String collection = widget.isGroup ? 'groups' : 'users';
      // Saving local path to Firestore as a fallback for the emulator session
      await FirebaseFirestore.instance.collection(collection).doc(widget.contactId).set({
        'photoUrl': pickedFile.path, 
      }, SetOptions(merge: true));
    }
  }

  Future<void> _editField(String title, String field, String currentValue, ScreenThemeProvider themeProvider) async {
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
              if (field == 'members') {
                await FirebaseFirestore.instance.collection(collection).doc(widget.contactId).update({
                  'members': FieldValue.arrayUnion([controller.text]),
                });
              } else {
                await FirebaseFirestore.instance.collection(collection).doc(widget.contactId).set({
                  field: controller.text,
                }, SetOptions(merge: true));
              }
              if (mounted) Navigator.pop(context);
              setState(() {});
            },
            child: Text('Save', style: TextStyle(color: themeProvider.getColor('primary'), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRolePicker(String memberId, String name, ScreenThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Assign Role: $name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeProvider.getColor('text'))),
            const SizedBox(height: 20),
            _roleTile('Owner', Icons.star, Colors.orange, themeProvider),
            _roleTile('Admin', Icons.security, Colors.blue, themeProvider),
            _roleTile('Moderator', Icons.gavel, Colors.green, themeProvider),
            _roleTile('Event Manager', Icons.calendar_month, Colors.purple, themeProvider),
            _roleTile('Member', Icons.person, Colors.grey, themeProvider),
          ],
        ),
      ),
    );
  }

  Widget _roleTile(String label, IconData icon, Color color, ScreenThemeProvider themeProvider) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: themeProvider.getColor('text'))),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role "$label" assigned to member.')));
        Navigator.pop(context);
      },
    );
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
        actions: [
          if (!widget.isGroup) TextButton.icon(
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Now following ${widget.contactName}')));
            },
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 18),
            label: const Text('Follow', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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

          // Determine which image to show: local file if just picked, or Firestore path/URL
          ImageProvider? imageProvider;
          if (_imageFile != null) {
            imageProvider = FileImage(_imageFile!);
          } else if (photoUrl.isNotEmpty) {
            if (photoUrl.startsWith('http')) {
              imageProvider = NetworkImage(photoUrl);
            } else {
              final file = File(photoUrl);
              if (file.existsSync()) {
                imageProvider = FileImage(file);
              }
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
                        onTap: _pickImage,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: themeProvider.getColor('primary').withOpacity(0.5), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 80,
                            backgroundColor: themeProvider.getColor('scaffold'),
                            backgroundImage: imageProvider,
                            child: imageProvider == null 
                                ? Icon(Icons.person, size: 80, color: secondaryTextColor.withOpacity(0.5)) 
                                : null,
                          ),
                        ),
                      ),
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
                      icon: Icons.person,
                      title: widget.isGroup ? 'Group Name' : 'Name',
                      subtitle: name,
                      onTap: widget.isGroup ? () => _editField('Group Name', 'name', name, themeProvider) : null,
                      themeProvider: themeProvider,
                    ),
                    Divider(indent: 70, color: themeProvider.getColor('divider')),
                    _buildInfoTile(
                      icon: Icons.info_outline,
                      title: widget.isGroup ? 'Group Description' : 'About',
                      subtitle: about,
                      onTap: () => _editField(widget.isGroup ? 'Description' : 'About', 'about', about, themeProvider),
                      themeProvider: themeProvider,
                    ),
                    if (widget.isGroup) ...[
                      Divider(indent: 70, color: themeProvider.getColor('divider')),
                      _buildInfoTile(
                        icon: Icons.task_alt,
                        title: 'Shared Task List',
                        subtitle: 'Manage group goals and tasks',
                        onTap: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task List feature coming soon!')));
                        },
                        themeProvider: themeProvider,
                      ),
                      Divider(indent: 70, color: themeProvider.getColor('divider')),
                      _buildInfoTile(
                        icon: Icons.calendar_month,
                        title: 'Group Calendar',
                        subtitle: 'Plan group events and meetups',
                        onTap: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group Calendar coming soon!')));
                        },
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
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            leading: CircleAvatar(
                              backgroundColor: themeProvider.getColor('primary').withOpacity(0.1),
                              child: Text(memberName[0].toUpperCase(), style: TextStyle(color: themeProvider.getColor('primary'))),
                            ),
                            title: Text(memberName, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                            subtitle: Text(userData?['about'] ?? '', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                            trailing: widget.isGroup ? TextButton(
                              onPressed: () => _showRolePicker(memberId, memberName, themeProvider),
                              child: Text('Admin', style: TextStyle(color: themeProvider.getColor('primary'), fontSize: 12)),
                            ) : null,
                          );
                        }
                      )).toList(),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        leading: CircleAvatar(
                          backgroundColor: themeProvider.getColor('primary'),
                          child: const Icon(Icons.person_add, color: Colors.white, size: 20),
                        ),
                        title: Text('Add Participant', style: TextStyle(color: themeProvider.getColor('primary'), fontWeight: FontWeight.bold)),
                        onTap: () => _editField('Add Member (ID)', 'members', '', themeProvider),
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
                    ListTile(
                      leading: const Icon(Icons.block, color: Colors.red),
                      title: const Text('Block', style: TextStyle(color: Colors.red)),
                      onTap: () {},
                    ),
                    Divider(indent: 70, color: themeProvider.getColor('divider')),
                    ListTile(
                      leading: const Icon(Icons.thumb_down, color: Colors.red),
                      title: const Text('Report', style: TextStyle(color: Colors.red)),
                      onTap: () {},
                    ),
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

  Widget _buildInfoSection(ScreenThemeProvider themeProvider, {required Widget child}) {
    return Container(
      color: themeProvider.getColor('card'),
      child: child,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    required ScreenThemeProvider themeProvider,
  }) {
    return ListTile(
      leading: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Icon(icon, color: themeProvider.getColor('textSecondary')),
      ),
      title: Text(title, style: TextStyle(color: themeProvider.getColor('textSecondary'), fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: themeProvider.getColor('text'), fontSize: 17)),
      trailing: onTap != null ? Icon(Icons.edit, size: 20, color: themeProvider.getColor('primary')) : null,
      onTap: onTap,
    );
  }
}
