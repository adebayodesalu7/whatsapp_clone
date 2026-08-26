import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/widgets/theme_selector.dart';
import 'package:whatsapp_clone/widgets/avatar.dart';
import 'package:whatsapp_clone/screens/profile_settings.dart';
import 'package:whatsapp_clone/screens/chat_settings.dart';
import 'package:whatsapp_clone/screens/notification_settings.dart';
import 'package:whatsapp_clone/screens/privacy_settings.dart';
import 'package:whatsapp_clone/screens/storage_settings.dart';
import 'package:whatsapp_clone/screens/security_safety_screen.dart';
import 'package:whatsapp_clone/screens/notes_to_self_screen.dart';
import 'package:whatsapp_clone/screens/appearance_screen.dart';
import 'wallet_screen.dart';
import 'marketplace_screen.dart';
import 'discussion_rooms_screen.dart';
import 'catalog_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = 'joy';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _userName = data['name'] ?? 'User';
            _profileImageUrl = data['photoUrl'];
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeProvider.getColor('appBar'),
        foregroundColor: themeProvider.getColor('appBarText'),
        elevation: 0,
        actions: [
          ThemeSelector(screenName: 'settings'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Card
          _buildCard(
            themeProvider,
            child: ListTile(
              leading: Avatar(name: _userName, imageUrl: _profileImageUrl, size: 60),
              title: Text(_userName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeProvider.getColor('text'))),
              subtitle: Text('Tap to change profile', style: TextStyle(color: themeProvider.getColor('textSecondary'), fontSize: 14)),
              trailing: Icon(Icons.keyboard_arrow_right, color: themeProvider.getColor('textSecondary')),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileSettings()));
                _loadUserData(); // Refresh data when coming back
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // AI Business Bot Toggle Card
          _buildCard(
            themeProvider,
            child: SwitchListTile(
              secondary: Icon(Icons.smart_toy_outlined, color: themeProvider.getColor('primary')),
              title: Text('AI Business Bot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeProvider.getColor('text'))),
              subtitle: Text('Auto-reply to customers when away', style: TextStyle(color: themeProvider.getColor('textSecondary'), fontSize: 13)),
              value: themeProvider.isBusinessBotEnabled,
              activeColor: themeProvider.getColor('primary'),
              onChanged: (value) {
                themeProvider.toggleBusinessBot(value);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Dark Mode Toggle Card
          _buildCard(
            themeProvider,
            child: SwitchListTile(
              secondary: Icon(Icons.dark_mode_outlined, color: themeProvider.getColor('primary')),
              title: Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeProvider.getColor('text'))),
              subtitle: Text('Toggle 3D depth mode', style: TextStyle(color: themeProvider.getColor('textSecondary'), fontSize: 13)),
              value: isDarkMode,
              activeColor: themeProvider.getColor('primary'),
              onChanged: (value) {
                themeProvider.toggleDarkMode(value);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Main Settings Group
          _buildCard(
            themeProvider,
            child: Column(
              children: [
                _buildSettingsItem(themeProvider, Icons.chat_outlined, Colors.green, 'Chat Settings', 'Wallpaper, backup, media', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatSettings()));
                }),
                Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
                _buildSettingsItem(themeProvider, Icons.notifications_outlined, Colors.blue, 'Notifications', 'Message, group, call tones', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationSettings()));
                }),
                Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
                _buildSettingsItem(themeProvider, Icons.lock_outline, Colors.grey, 'Privacy', 'Last seen, profile, status', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PrivacySettings()));
                }),
                Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
                _buildSettingsItem(themeProvider, Icons.storage_outlined, Colors.orange, 'Storage & Data', 'Network usage, auto-download', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => StorageSettings()));
                }),
                Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
                _buildSettingsItem(themeProvider, Icons.payments_outlined, Colors.blueAccent, 'Payments', 'Wallet, airtime, history', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => WalletScreen()));
                }),
                Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
                _buildSettingsItem(themeProvider, Icons.storefront_outlined, Colors.deepOrange, 'Marketplace', 'Buy and sell items', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MarketplaceScreen()));
                }),
                Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
                _buildSettingsItem(themeProvider, Icons.business_center_outlined, Colors.brown, 'Business Tools', 'Catalog, invoices, profiling', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CatalogScreen()));
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Settings Group
          _buildCard(
            themeProvider,
            child: Column(
              children: [
                _buildSettingsItem(themeProvider, Icons.edit_note, Colors.blue, 'Notes & Productivity', 'Notes to self, reminders', () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => NotesToSelfScreen()));
                }),
                Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
                _buildSettingsItem(themeProvider, Icons.security_outlined, Colors.red, 'Security & Safety', 'AI scam detection, SOS', () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => SecuritySafetyScreen()));
                }),
                Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
                _buildSettingsItem(themeProvider, Icons.palette_outlined, Colors.purple, 'Appearance', 'Themes, fonts, backgrounds', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AppearanceScreen()));
                }),
                Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
                _buildSettingsItem(themeProvider, Icons.forum_outlined, Colors.teal, 'Discussion Rooms', 'Temporary chat rooms (24h)', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => DiscussionRoomsScreen()));
                }),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCard(ScreenThemeProvider themeProvider, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.getColor('card'),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSettingsItem(ScreenThemeProvider themeProvider, IconData icon, Color iconColor, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: themeProvider.getColor('text'))),
      subtitle: Text(subtitle, style: TextStyle(color: themeProvider.getColor('textSecondary'), fontSize: 12)),
      trailing: Icon(Icons.keyboard_arrow_right, color: themeProvider.getColor('textSecondary'), size: 20),
      onTap: onTap,
    );
  }
}
