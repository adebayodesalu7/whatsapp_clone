import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/services/backup_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

class StorageSettings extends StatefulWidget {
  const StorageSettings({super.key});

  @override
  State<StorageSettings> createState() => _StorageSettingsState();
}

class _StorageSettingsState extends State<StorageSettings> {
  bool _autoPlay = true;
  final String _wifiSetting = 'Images, Videos, Audio';
  final String _dataSetting = 'Images only';

  void _showMediaDownloadDialog(String title, bool isWifi, ScreenThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: themeProvider.getColor('card'),
          title: Text(title, style: TextStyle(color: themeProvider.getColor('text'))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(title: Text('Images', style: TextStyle(color: themeProvider.getColor('text'))), value: true, onChanged: (v) {}, activeColor: themeProvider.getColor('primary')),
              CheckboxListTile(title: Text('Videos', style: TextStyle(color: themeProvider.getColor('text'))), value: isWifi, onChanged: (v) {}, activeColor: themeProvider.getColor('primary')),
              CheckboxListTile(title: Text('Audio', style: TextStyle(color: themeProvider.getColor('text'))), value: isWifi, onChanged: (v) {}, activeColor: themeProvider.getColor('primary')),
              CheckboxListTile(title: Text('Documents', style: TextStyle(color: themeProvider.getColor('text'))), value: isWifi, onChanged: (v) {}, activeColor: themeProvider.getColor('primary')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: themeProvider.getColor('textSecondary')))),
            TextButton(onPressed: () => Navigator.pop(context), child: Text('OK', style: TextStyle(color: themeProvider.getColor('primary')))),
          ],
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
        title: Text('Storage & Data', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
        backgroundColor: themeProvider.getColor('appBar'),
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Media Auto-Download', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
          const SizedBox(height: 20),
          _buildItem(Icons.wifi, 'On Wi-Fi', _wifiSetting, () => _showMediaDownloadDialog('When using Wi-Fi', true, themeProvider), themeProvider),
          const SizedBox(height: 20),
          _buildItem(Icons.signal_cellular_alt, 'On Mobile Data', _dataSetting, () => _showMediaDownloadDialog('When using mobile data', false, themeProvider), themeProvider),
          const SizedBox(height: 12),
          Divider(color: themeProvider.getColor('divider')),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Icon(Icons.play_arrow, color: themeProvider.getColor('primary'), size: 28),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-Play Videos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    Text('Auto-play videos when scrolling', style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                  ],
                ),
              ),
              Switch(
                value: _autoPlay,
                onChanged: (v) => setState(() => _autoPlay = v),
                activeColor: themeProvider.getColor('primary'),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          Divider(color: themeProvider.getColor('divider')),
          const SizedBox(height: 12),
          
          Text('Storage Usage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
          const SizedBox(height: 20),
          _buildItem(Icons.format_list_bulleted, 'Manage Storage', 'Clear cache, manage media', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageStorageScreen()));
          }, themeProvider),
          const SizedBox(height: 20),
          _buildItem(Icons.donut_large, 'Data Usage', 'Network usage statistics', () {}, themeProvider),
          
          const SizedBox(height: 12),
          Divider(color: themeProvider.getColor('divider')),
          const SizedBox(height: 12),
          
          Text('Backup & Restore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
          const SizedBox(height: 20),
          _buildItem(Icons.cloud_upload, 'Create Backup', 'Save chat history locally', () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final path = await BackupService().createBackup(user.uid);
              if (path != null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved: $path')));
                }
              }
            }
          }, themeProvider),
          const SizedBox(height: 20),
          _buildItem(Icons.cloud_download, 'Restore Chats', 'Import history from file', () async {
             try {
               FilePickerResult? result = await FilePicker.platform.pickFiles(
                 type: FileType.custom,
                 allowedExtensions: ['json'],
               );

               if (result != null) {
                 final path = result.files.single.path!;
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⏳ Restoring chats...')));
                 
                 final success = await BackupService().restoreBackup(path);
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text(success ? '✅ Restore successful' : '❌ Restore failed')),
                   );
                 }
               }
             } catch (e) {
               print('Restore Picker Error: $e');
             }
          }, themeProvider),
        ],
      ),
    );
  }

  Widget _buildItem(IconData icon, String title, String subtitle, VoidCallback onTap, ScreenThemeProvider themeProvider) {
    return InkWell(
      onTap: onTap,
      child: Row(
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
          Icon(Icons.arrow_forward_ios, size: 16, color: themeProvider.getColor('textSecondary')),
        ],
      ),
    );
  }
}

class ManageStorageScreen extends StatelessWidget {
  const ManageStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: Text('Manage Storage', style: TextStyle(color: themeProvider.getColor('appBarText'))),
        backgroundColor: themeProvider.getColor('appBar'),
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storage, size: 80, color: themeProvider.getColor('textSecondary').withOpacity(0.3)),
            const SizedBox(height: 20),
            Text('No large files found to clear.', style: TextStyle(color: themeProvider.getColor('textSecondary'))),
          ],
        ),
      ),
    );
  }
}
