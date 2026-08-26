import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/screen_theme_provider.dart';
import '../models/enums.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');
    final primaryColor = themeProvider.getColor('primary');

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
        backgroundColor: themeProvider.getColor('appBar'),
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Theme', primaryColor),
          _buildCard(
            themeProvider,
            child: Column(
              children: [
                RadioListTile<bool>(
                  title: Text('Light', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                  value: false,
                  groupValue: isDark,
                  onChanged: (v) => themeProvider.toggleDarkMode(false),
                  activeColor: primaryColor,
                ),
                RadioListTile<bool>(
                  title: Text('Dark', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                  value: true,
                  groupValue: isDark,
                  onChanged: (v) => themeProvider.toggleDarkMode(true),
                  activeColor: primaryColor,
                ),
                if (isDark)
                  SwitchListTile(
                    title: Text('OLED Dark Mode', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                    subtitle: Text('Pure black for OLED screens', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                    value: themeProvider.isOLEDMode,
                    onChanged: (v) => themeProvider.toggleOLEDMode(v),
                    activeColor: primaryColor,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Display', primaryColor),
          _buildCard(
            themeProvider,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.format_size, color: primaryColor),
                  title: Text('Font Size', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                  subtitle: Text(themeProvider.fontSize == 14 ? 'Small' : themeProvider.fontSize == 16 ? 'Medium' : 'Large', style: TextStyle(color: secondaryTextColor)),
                  onTap: () => _showFontSizePicker(context, themeProvider),
                ),
                Divider(indent: 56, color: themeProvider.getColor('divider')),
                ListTile(
                  leading: Icon(Icons.rounded_corner, color: primaryColor),
                  title: Text('Bubble Roundness', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                  subtitle: Text('${themeProvider.bubbleRadius.toInt()} px', style: TextStyle(color: secondaryTextColor)),
                  onTap: () => _showBubbleRadiusPicker(context, themeProvider),
                ),
                Divider(indent: 56, color: themeProvider.getColor('divider')),
                ListTile(
                  leading: Icon(Icons.font_download, color: primaryColor),
                  title: Text('Custom Font', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                  subtitle: Text('Roboto (Default)', style: TextStyle(color: secondaryTextColor)),
                  onTap: () => _showFontPicker(context, themeProvider),
                ),
                Divider(indent: 56, color: themeProvider.getColor('divider')),
                ListTile(
                  leading: Icon(Icons.wallpaper, color: primaryColor),
                  title: Text('Chat Wallpaper', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                  subtitle: Text('Selected: ${chatBackgrounds[themeProvider.wallpaperIndex].name}', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                  onTap: () => _showWallpaperPicker(context, themeProvider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showWallpaperPicker(BuildContext context, ScreenThemeProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: provider.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose Chat Wallpaper', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: provider.getColor('text'))),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
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
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          gradient: bg.gradient,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: isSelected ? provider.getColor('primary') : Colors.transparent, width: 4),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Center(
                          child: Text(
                            bg.name, 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            textAlign: TextAlign.center,
                          )
                        ),
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

  void _showFontSizePicker(BuildContext context, ScreenThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        final textColor = themeProvider.getColor('text');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('Small', style: TextStyle(color: textColor)), onTap: () { themeProvider.setFontSize(14); Navigator.pop(context); }),
            ListTile(title: Text('Medium', style: TextStyle(color: textColor)), onTap: () { themeProvider.setFontSize(16); Navigator.pop(context); }),
            ListTile(title: Text('Large', style: TextStyle(color: textColor)), onTap: () { themeProvider.setFontSize(18); Navigator.pop(context); }),
          ],
        );
      },
    );
  }

  void _showBubbleRadiusPicker(BuildContext context, ScreenThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        final textColor = themeProvider.getColor('text');
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Bubble Roundness', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
              const SizedBox(height: 20),
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return Slider(
                    value: themeProvider.bubbleRadius,
                    min: 0,
                    max: 30,
                    divisions: 6,
                    label: '${themeProvider.bubbleRadius.toInt()}',
                    activeColor: themeProvider.getColor('primary'),
                    onChanged: (v) {
                      themeProvider.setBubbleRadius(v);
                      setDialogState(() {});
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFontPicker(BuildContext context, ScreenThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.getColor('card'),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        final textColor = themeProvider.getColor('text');
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Font', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: textColor)),
              const SizedBox(height: 20),
              _buildFontTile(context, 'Roboto', 'Roboto', textColor),
              _buildFontTile(context, 'Lato', 'Lato', textColor),
              _buildFontTile(context, 'Open Sans', 'OpenSans', textColor),
              _buildFontTile(context, 'Montserrat', 'Montserrat', textColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFontTile(BuildContext context, String label, String family, Color textColor) {
    return ListTile(
      title: Text(label, style: TextStyle(fontFamily: family, color: textColor, fontSize: 16)),
      onTap: () => Navigator.pop(context),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(ScreenThemeProvider themeProvider, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.getColor('card'),
        borderRadius: BorderRadius.circular(20),
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
}
