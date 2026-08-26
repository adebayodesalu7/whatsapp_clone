import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/services/cloudinary_service.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/widgets/avatar.dart';

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _interestsController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  
  bool _isPublic = true;
  bool _isTitanElite = false;
  String? _profileImageUrl;
  File? _newImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          if (data['name'] != null) _nameController.text = data['name'];
          if (data['about'] != null) _aboutController.text = data['about'];
          _profileImageUrl = data['photoUrl'];
          if (data['bio'] != null) _bioController.text = data['bio'];
          if (data['interests'] != null) _interestsController.text = data['interests'];
          _isPublic = data['isPublic'] ?? true;
          _isTitanElite = data['isTitanElite'] ?? false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      setState(() {
        _newImage = File(image.path);
        // Temporarily use local path for immediate UI update
        _profileImageUrl = image.path;
      });
    }
  }

  void _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? imageUrl = _profileImageUrl;
        if (_newImage != null) {
          imageUrl = await _cloudinaryService.uploadImage(XFile(_newImage!.path));
        }

        final profileData = {
          'name': _nameController.text,
          'about': _aboutController.text,
          'bio': _bioController.text,
          'interests': _interestsController.text,
          'isPublic': _isPublic,
          'isTitanElite': _isTitanElite,
          'photoUrl': imageUrl,
        };

        await FirebaseFirestore.instance.collection('users').doc(user.uid).update(profileData);

        if (mounted) {
          setState(() {
            _profileImageUrl = imageUrl;
            _newImage = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: Text('Profile Settings', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
        backgroundColor: themeProvider.getColor('appBar'),
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.palette_outlined), onPressed: () {}),
          _isSaving 
            ? Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: themeProvider.getColor('appBarText'), strokeWidth: 2))))
            : TextButton(
                onPressed: _saveProfile,
                child: Text('Save', style: TextStyle(color: themeProvider.getColor('appBarText'), fontWeight: FontWeight.bold, fontSize: 16)),
              ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Photo with Icons
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Avatar(
                      name: _nameController.text,
                      imageUrl: _newImage?.path ?? _profileImageUrl,
                      size: 140,
                      isTitanElite: _isTitanElite,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: themeProvider.getColor('primary'), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: themeProvider.getColor('card'), shape: BoxShape.circle),
                      child: const Text('🇳🇬', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // Name Input
            _buildCustomInput('Name', _nameController, themeProvider, emoji: true),
            const SizedBox(height: 16),
            // About Input
            _buildCustomInput('About', _aboutController, themeProvider, emoji: true, hint: 'About'),
            
            const SizedBox(height: 30),
            Divider(color: themeProvider.getColor('divider')),
            const SizedBox(height: 20),
            
            Text('Public Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
            const SizedBox(height: 8),
            Text('Make your profile visible to other users', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
            const SizedBox(height: 20),
            
            // Public Profile Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: themeProvider.getColor('card'),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: themeProvider.getColor('divider')),
                ),
                child: SwitchListTile(
                  secondary: Icon(Icons.public, color: themeProvider.getColor('primary')),
                  title: Text('Public Profile', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  subtitle: Text('Anyone can view your profile', style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                  activeColor: themeProvider.getColor('primary'),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            _buildCustomInput('Bio', _bioController, themeProvider, maxLines: 4),
            const SizedBox(height: 16),
            _buildCustomInput('Interests', _interestsController, themeProvider),
            
            const SizedBox(height: 30),
            if (!_isTitanElite)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.blue, Colors.purple]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.workspace_premium, color: Colors.white, size: 40),
                      const SizedBox(height: 10),
                      const Text(
                        'Unlock Titan Elite Status',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const Text(
                        'Get the exclusive animated verified badge and priority support.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _isTitanElite = true);
                          // Mock immediate upgrade for testing
                          _saveProfile();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.purple),
                        child: const Text('APPLY FOR ELITE'),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 30),
            Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeProvider.getColor('card'),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeProvider.getColor('divider')),
                ),
                child: Row(
                  children: [
                    const Text('🇳🇬', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text('+2348146294083', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomInput(String label, TextEditingController controller, ScreenThemeProvider themeProvider, {bool emoji = false, int maxLines = 1, String? hint}) {
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.5)),
              suffixIcon: emoji ? Icon(Icons.emoji_emotions_outlined, color: themeProvider.getColor('primary')) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: themeProvider.getColor('divider'))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: themeProvider.getColor('divider'))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: themeProvider.getColor('primary'), width: 2)),
              contentPadding: const EdgeInsets.all(16),
              filled: true,
              fillColor: themeProvider.getColor('inputFill'),
            ),
          ),
        ],
      ),
    );
  }
}
