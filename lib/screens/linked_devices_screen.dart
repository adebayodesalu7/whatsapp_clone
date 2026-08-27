import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/screen_theme_provider.dart';

class LinkedDevicesScreen extends StatelessWidget {
  const LinkedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ScreenThemeProvider>(context);
    final textColor = theme.getColor('text');
    final secondaryTextColor = theme.getColor('textSecondary');

    return Scaffold(
      backgroundColor: theme.getColor('scaffold'),
      appBar: AppBar(
        title: Text('Linked Devices', style: TextStyle(fontWeight: FontWeight.bold, color: theme.getColor('appBarText'))),
        backgroundColor: theme.getColor('appBar'),
        iconTheme: IconThemeData(color: theme.getColor('appBarText')),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.devices, size: 100, color: theme.getColor('primary').withOpacity(0.5)),
                const SizedBox(height: 20),
                Text(
                  'Use your account on other devices simultaneously.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your messages are end-to-end encrypted across all devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanning for QR Code...')));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.getColor('primary'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('LINK A DEVICE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('DEVICE STATUS', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 10),
          _deviceTile('Windows (Chrome)', 'Last active today at 02:30 AM', Icons.laptop, theme),
          _deviceTile('iPad Pro', 'Last active yesterday', Icons.tablet_android, theme),
        ],
      ),
    );
  }

  Widget _deviceTile(String name, String status, IconData icon, ScreenThemeProvider theme) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.getColor('primary').withOpacity(0.1),
        child: Icon(icon, color: theme.getColor('primary')),
      ),
      title: Text(name, style: TextStyle(color: theme.getColor('text'), fontWeight: FontWeight.bold)),
      subtitle: Text(status, style: TextStyle(color: theme.getColor('textSecondary'), fontSize: 12)),
    );
  }
}
