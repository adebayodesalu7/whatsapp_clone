import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/models/enums.dart';

class ChatSettings extends StatefulWidget {
  const ChatSettings({super.key});

  @override
  State<ChatSettings> createState() => _ChatSettingsState();
}

class _ChatSettingsState extends State<ChatSettings> {
  bool _autoDownload = true;
  bool _saveToGallery = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: Text('Chat Settings', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
        backgroundColor: themeProvider.getColor('appBar'),
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSwitchTile(themeProvider, Icons.file_download_outlined, 'Auto-download Media', 'Automatically download images and videos', _autoDownload, (v) => setState(() => _autoDownload = v)),
          const SizedBox(height: 16),
          _buildSwitchTile(themeProvider, Icons.file_download_done_outlined, 'Save to Gallery', 'Save received media to your gallery', _saveToGallery, (v) => setState(() => _saveToGallery = v)),
          const SizedBox(height: 12),
          Divider(color: themeProvider.getColor('divider')),
          const SizedBox(height: 12),
          
          _buildWallpaperTile(context, themeProvider),
          const SizedBox(height: 16),
          
          _buildFontSizeTile(context, themeProvider),
          const SizedBox(height: 12),
          Divider(color: themeProvider.getColor('divider')),
          const SizedBox(height: 12),
          
          _buildActionTile(themeProvider, Icons.history_outlined, 'Chat History', 'View your chat history', () {
            _showChatHistoryDialog(context, themeProvider);
          }),
        ],
      ),
    );
  }

  Widget _buildWallpaperTile(BuildContext context, ScreenThemeProvider provider) {
    final currentBg = chatBackgrounds[provider.wallpaperIndex];
    final textColor = provider.getColor('text');
    final secondaryTextColor = provider.getColor('textSecondary');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.wallpaper_outlined, color: provider.getColor('primary'), size: 28),
      title: Text('Chat Wallpaper', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
      subtitle: Text('Selected: ${currentBg.name}', style: TextStyle(color: secondaryTextColor)),
      trailing: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: currentBg.gradient,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: provider.getColor('divider')),
        ),
      ),
      onTap: () => _showWallpaperPicker(context, provider),
    );
  }

  void _showWallpaperPicker(BuildContext context, ScreenThemeProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: provider.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose Chat Wallpaper', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: provider.getColor('text'))),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: chatBackgrounds.length,
                  itemBuilder: (context, index) {
                    final bg = chatBackgrounds[index];
                    final isSelected = provider.wallpaperIndex == index;
                    return GestureDetector(
                      onTap: () {
                        provider.setWallpaperIndex(index);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          gradient: bg.gradient,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? provider.getColor('primary') : provider.getColor('divider'), width: 3),
                        ),
                        child: Center(child: Text(bg.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFontSizeTile(BuildContext context, ScreenThemeProvider provider) {
    String sizeLabel = 'Medium';
    if (provider.fontSize < 14) sizeLabel = 'Small';
    if (provider.fontSize > 18) sizeLabel = 'Large';
    final textColor = provider.getColor('text');
    final secondaryTextColor = provider.getColor('textSecondary');

    return Row(
      children: [
        Icon(Icons.text_fields_outlined, color: provider.getColor('primary'), size: 28),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Font Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
              Text('Selected: $sizeLabel', style: TextStyle(fontSize: 12, color: secondaryTextColor)),
            ],
          ),
        ),
        DropdownButton<double>(
          value: [12.0, 16.0, 20.0].contains(provider.fontSize) ? provider.fontSize : 16.0,
          dropdownColor: provider.getColor('card'),
          style: TextStyle(color: textColor),
          items: const [
            DropdownMenuItem(value: 12.0, child: Text('Small')),
            DropdownMenuItem(value: 16.0, child: Text('Medium')),
            DropdownMenuItem(value: 20.0, child: Text('Large')),
          ],
          onChanged: (v) {
            if (v != null) provider.setFontSize(v);
          },
          underline: const SizedBox(),
        ),
      ],
    );
  }

  void _showChatHistoryDialog(BuildContext context, ScreenThemeProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: provider.getColor('card'),
        title: Text('Chat History', style: TextStyle(color: provider.getColor('text'))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.upload_file, color: provider.getColor('primary')),
              title: Text('Export Chats', style: TextStyle(color: provider.getColor('text'))),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.clear_all, color: Colors.orange),
              title: Text('Clear All Chats', style: TextStyle(color: provider.getColor('text'))),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Delete All Chats', style: TextStyle(color: provider.getColor('text'))),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(ScreenThemeProvider provider, IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final textColor = provider.getColor('text');
    final secondaryTextColor = provider.getColor('textSecondary');

    return Row(
      children: [
        Icon(icon, color: provider.getColor('primary'), size: 28),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: secondaryTextColor)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: provider.getColor('primary'),
        ),
      ],
    );
  }

  Widget _buildActionTile(ScreenThemeProvider provider, IconData icon, String title, String subtitle, VoidCallback onTap) {
    final textColor = provider.getColor('text');
    final secondaryTextColor = provider.getColor('textSecondary');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: provider.getColor('primary'), size: 28),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: secondaryTextColor)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: secondaryTextColor),
      onTap: onTap,
    );
  }
}
