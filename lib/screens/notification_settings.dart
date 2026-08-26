import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';

class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key});

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  bool _messageNotifications = true;
  bool _groupNotifications = true;
  bool _callNotifications = true;
  bool _vibrate = true;
  bool _showPreview = true;
  String _selectedTone = 'Default';
  String _selectedRingtone = 'Aurora';

  void _playSound(String name) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Previewing sound: $name...'),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showTonePicker(String title, bool isRingtone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Provider.of<ScreenThemeProvider>(context, listen: false).getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        final theme = Provider.of<ScreenThemeProvider>(context);
        final tones = isRingtone 
            ? ['Aurora', 'Celestial', 'Galaxy', 'Digital', 'Note']
            : ['Default', 'Bamboo', 'Glass', 'Pop', 'Pulse'];
            
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select $title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.getColor('text'))),
              const SizedBox(height: 16),
              ...tones.map((tone) => ListTile(
                title: Text(tone, style: TextStyle(color: theme.getColor('text'))),
                trailing: (isRingtone ? _selectedRingtone : _selectedTone) == tone 
                    ? Icon(Icons.check, color: theme.getColor('primary')) 
                    : null,
                onTap: () {
                  setState(() {
                    if (isRingtone) _selectedRingtone = tone;
                    else _selectedTone = tone;
                  });
                  _playSound(tone);
                  Navigator.pop(context);
                },
              )).toList(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
        backgroundColor: themeProvider.getColor('appBar'),
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader('ALERTS', secondaryTextColor),
          _buildSettingsGroup(themeProvider, [
            _buildSwitchTile(themeProvider, Icons.chat_outlined, 'Message Notifications', 'Show notifications for new messages', _messageNotifications, (v) => setState(() => _messageNotifications = v)),
            Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
            _buildSwitchTile(themeProvider, Icons.groups_outlined, 'Group Notifications', 'Show notifications for group messages', _groupNotifications, (v) => setState(() => _groupNotifications = v)),
            Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
            _buildSwitchTile(themeProvider, Icons.call_outlined, 'Call Notifications', 'Show notifications for incoming calls', _callNotifications, (v) => setState(() => _callNotifications = v)),
          ]),
          const SizedBox(height: 24),
          _buildHeader('SOUND & HAPTICS', secondaryTextColor),
          _buildSettingsGroup(themeProvider, [
            _buildActionTile(themeProvider, Icons.notifications_outlined, Colors.blue, 'Notification Tone', _selectedTone, () => _showTonePicker('Notification Tone', false)),
            Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
            _buildActionTile(themeProvider, Icons.music_note_outlined, Colors.purple, 'Ringtone', _selectedRingtone, () => _showTonePicker('Ringtone', true)),
            Divider(indent: 56, height: 1, color: themeProvider.getColor('divider')),
            _buildSwitchTile(themeProvider, Icons.vibration_outlined, 'Vibrate', 'Vibration for incoming alerts', _vibrate, (v) => setState(() => _vibrate = v)),
          ]),
          const SizedBox(height: 24),
          _buildHeader('PRIVACY', secondaryTextColor),
          _buildSettingsGroup(themeProvider, [
            _buildSwitchTile(themeProvider, Icons.visibility_outlined, 'Show Preview', 'Show message text in notifications', _showPreview, (v) => setState(() => _showPreview = v)),
          ]),
        ],
      ),
    );
  }

  Widget _buildHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0)),
    );
  }

  Widget _buildSettingsGroup(ScreenThemeProvider themeProvider, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.getColor('card'),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeProvider.getColor('divider').withOpacity(0.1)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(ScreenThemeProvider themeProvider, IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: themeProvider.getColor('primary').withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: themeProvider.getColor('primary'), size: 22),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: themeProvider.getColor('text'))),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: themeProvider.getColor('textSecondary'))),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: themeProvider.getColor('primary'),
      ),
    );
  }

  Widget _buildActionTile(ScreenThemeProvider themeProvider, IconData icon, Color iconColor, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: themeProvider.getColor('text'))),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: themeProvider.getColor('textSecondary'))),
      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: themeProvider.getColor('textSecondary')),
      onTap: onTap,
    );
  }
}
