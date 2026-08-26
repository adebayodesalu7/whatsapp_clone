import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/services/security_service.dart';

class PrivacySettings extends StatefulWidget {
  const PrivacySettings({super.key});

  @override
  State<PrivacySettings> createState() => _PrivacySettingsState();
}

class _PrivacySettingsState extends State<PrivacySettings> {
  bool _screenshotPrevention = true;
  bool _readReceipts = true;
  bool _typingIndicators = true;
  
  final Map<String, String> _visibility = {
    'Last Seen': 'Everyone',
    'Profile Photo': 'Everyone',
    'Status': 'Everyone',
    'Online Visibility': 'Everyone',
  };

  void _showVisibilityDialog(String title, ScreenThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: themeProvider.getColor('card'),
          title: Text('Who can see my $title', style: TextStyle(color: themeProvider.getColor('text'))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRadioTile('Everyone', title, themeProvider),
              _buildRadioTile('My Contacts', title, themeProvider),
              _buildRadioTile('My Contacts Except...', title, themeProvider, hasPicker: true),
              _buildRadioTile('Nobody', title, themeProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadioTile(String value, String title, ScreenThemeProvider themeProvider, {bool hasPicker = false}) {
    return RadioListTile<String>(
      title: Text(value, style: TextStyle(color: themeProvider.getColor('text'))),
      value: value,
      groupValue: _visibility[title],
      onChanged: (v) {
        setState(() => _visibility[title] = v!);
        Navigator.pop(context);
        if (hasPicker) _showContactPicker(title, themeProvider);
      },
      activeColor: themeProvider.getColor('primary'),
    );
  }

  void _showContactPicker(String title, ScreenThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.getColor('card'),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select contacts to hide $title from', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeProvider.getColor('text'))),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    final contacts = ['Alice', 'Bob', 'Charlie', 'David', 'Eve'];
                    return CheckboxListTile(
                      title: Text(contacts[index], style: TextStyle(color: themeProvider.getColor('text'))),
                      value: index % 2 == 0,
                      onChanged: (v) {},
                      activeColor: themeProvider.getColor('primary'),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.getColor('primary'),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: Text('Privacy', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
        backgroundColor: themeProvider.getColor('appBar'),
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader('Visibility Settings', textColor),
          _buildVisibilityTile('Last Seen', _visibility['Last Seen']!, themeProvider),
          _buildVisibilityTile('Profile Photo', _visibility['Profile Photo']!, themeProvider),
          _buildVisibilityTile('Status', _visibility['Status']!, themeProvider),
          _buildVisibilityTile('Online Visibility', _visibility['Online Visibility']!, themeProvider),
          const SizedBox(height: 12),
          Divider(color: themeProvider.getColor('divider')),
          const SizedBox(height: 12),
          
          _buildHeader('Security Features', textColor),
          _buildSwitchTile(
            themeProvider, 
            Icons.fingerprint, 
            'App Lock', 
            'Use Biometrics to unlock the app', 
            themeProvider.isAppLockEnabled, 
            (v) async {
              if (v) {
                final auth = SecurityService();
                final success = await auth.authenticate();
                if (success) {
                  themeProvider.toggleAppLock(true);
                }
              } else {
                themeProvider.toggleAppLock(false);
              }
            }
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            themeProvider, 
            Icons.visibility_off_outlined, 
            'Stealth Mode', 
            'Hide read receipts and online status', 
            themeProvider.isStealthMode, 
            (v) => themeProvider.toggleStealthMode(v)
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            themeProvider, 
            Icons.phonelink_lock, 
            'Screenshot Prevention', 
            'Prevent screenshots in private chats', 
            themeProvider.isScreenshotPreventionEnabled, 
            (v) async {
              themeProvider.toggleScreenshotPrevention(v);
              if (v) {
                await ScreenProtector.preventScreenshotOn();
              } else {
                await ScreenProtector.preventScreenshotOff();
              }
            }
          ),
          const SizedBox(height: 12),
          Divider(color: themeProvider.getColor('divider')),
          const SizedBox(height: 12),
          
          _buildHeader('Read & Typing', textColor),
          _buildSwitchTile(
            themeProvider, 
            Icons.done_all, 
            'Read Receipts', 
            'Show blue ticks when you read messages', 
            themeProvider.isReadReceiptsEnabled, 
            (v) => themeProvider.toggleReadReceipts(v)
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            themeProvider, 
            Icons.keyboard_outlined, 
            'Typing Indicators', 
            'Show when you\'re typing', 
            themeProvider.isTypingIndicatorEnabled, 
            (v) => themeProvider.toggleTypingIndicator(v)
          ),
          const SizedBox(height: 12),
          Divider(color: themeProvider.getColor('divider')),
          const SizedBox(height: 12),
          
          _buildHeader('Security', textColor),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: themeProvider.getColor('primary').withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.shield, color: themeProvider.getColor('primary')),
            ),
            title: Text('Blocked Contacts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
            subtitle: Text('0 contacts blocked', style: TextStyle(fontSize: 12, color: secondaryTextColor)),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: secondaryTextColor),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
    );
  }

  Widget _buildVisibilityTile(String title, String value, ScreenThemeProvider themeProvider) {
    return ListTile(
      onTap: () => _showVisibilityDialog(title, themeProvider),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeProvider.getColor('text'))),
      subtitle: Text('Who can see your ${title.toLowerCase()}', style: TextStyle(fontSize: 12, color: themeProvider.getColor('textSecondary'))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: themeProvider.getColor('primary'))),
          Icon(Icons.arrow_drop_down, color: themeProvider.getColor('textSecondary')),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(ScreenThemeProvider themeProvider, IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Icon(icon, color: themeProvider.getColor('primary'), size: 28),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeProvider.getColor('text'))),
              Text(subtitle, style: TextStyle(fontSize: 12, color: themeProvider.getColor('textSecondary'))),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: themeProvider.getColor('primary'),
        ),
      ],
    );
  }
}
