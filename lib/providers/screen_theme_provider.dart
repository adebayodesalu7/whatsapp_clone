import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_clone/models/enums.dart';

class ChatBackground {
  final String name;
  final LinearGradient? gradient;
  final BackgroundPatternType patternType;
  final Color patternColor;

  ChatBackground({
    required this.name,
    this.gradient,
    this.patternType = BackgroundPatternType.none,
    this.patternColor = Colors.black,
  });
}

final List<ChatBackground> chatBackgrounds = [
  ChatBackground(name: 'Default', patternType: BackgroundPatternType.dots, patternColor: Colors.black12),
  ChatBackground(name: 'Ocean', gradient: const LinearGradient(colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)]), patternType: BackgroundPatternType.lines, patternColor: Colors.white10),
  ChatBackground(name: 'Midnight', gradient: const LinearGradient(colors: [Color(0xFF232526), Color(0xFF414345)]), patternType: BackgroundPatternType.grid, patternColor: Colors.white10),
  ChatBackground(name: 'Sunset', gradient: const LinearGradient(colors: [Color(0xFFee9ca7), Color(0xFFffdde1)]), patternType: BackgroundPatternType.dots, patternColor: Colors.black12),
];

class ScreenThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isOLEDMode = false;
  double _fontSize = 14.0;
  int _wallpaperIndex = 0;
  double _bubbleRadius = 10.0;
  int _chatBackgroundIndex = 0;
  bool _isAppLockEnabled = false;
  bool _isBusinessBotEnabled = false;
  bool _isStealthMode = false;
  bool _isGlassMode = false;
  bool _isLoaded = false;

  ScreenThemeProvider() {
    _loadFromPrefs();
  }

  bool get isDarkMode => _isDarkMode;
  bool get isOLEDMode => _isOLEDMode;
  double get fontSize => _fontSize;
  int get wallpaperIndex => _wallpaperIndex;
  double get bubbleRadius => _bubbleRadius;
  int get chatBackgroundIndex => _chatBackgroundIndex;
  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get isBusinessBotEnabled => _isBusinessBotEnabled;
  bool get isStealthMode => _isStealthMode;
  bool get isGlassMode => _isGlassMode;
  bool get isLoaded => _isLoaded;

  void _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _isOLEDMode = prefs.getBool('isOLEDMode') ?? false;
    _fontSize = prefs.getDouble('fontSize') ?? 14.0;
    _wallpaperIndex = prefs.getInt('wallpaperIndex') ?? 0;
    _bubbleRadius = prefs.getDouble('bubbleRadius') ?? 10.0;
    _chatBackgroundIndex = prefs.getInt('chatBackgroundIndex') ?? 0;
    _isAppLockEnabled = prefs.getBool('isAppLockEnabled') ?? false;
    _isBusinessBotEnabled = prefs.getBool('isBusinessBotEnabled') ?? false;
    _isStealthMode = prefs.getBool('isStealthMode') ?? false;
    _isGlassMode = prefs.getBool('isGlassMode') ?? false;
    _isLoaded = true;
    notifyListeners();
  }

  void _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _isDarkMode);
    prefs.setBool('isOLEDMode', _isOLEDMode);
    prefs.setDouble('fontSize', _fontSize);
    prefs.setInt('wallpaperIndex', _wallpaperIndex);
    prefs.setDouble('bubbleRadius', _bubbleRadius);
    prefs.setInt('chatBackgroundIndex', _chatBackgroundIndex);
    prefs.setBool('isAppLockEnabled', _isAppLockEnabled);
    prefs.setBool('isBusinessBotEnabled', _isBusinessBotEnabled);
    prefs.setBool('isStealthMode', _isStealthMode);
    prefs.setBool('isGlassMode', _isGlassMode);
  }

  void toggleDarkMode(bool value) {
    _isDarkMode = value;
    _saveToPrefs();
    notifyListeners();
  }

  void toggleOLEDMode(bool value) {
    _isOLEDMode = value;
    if (_isOLEDMode) _isDarkMode = true;
    _saveToPrefs();
    notifyListeners();
  }

  void toggleAppLock(bool value) {
    _isAppLockEnabled = value;
    _saveToPrefs();
    notifyListeners();
  }

  void toggleBusinessBot(bool value) {
    _isBusinessBotEnabled = value;
    _saveToPrefs();
    notifyListeners();
  }

  void toggleStealthMode(bool value) {
    _isStealthMode = value;
    _saveToPrefs();
    notifyListeners();
  }

  void toggleGlassMode(bool value) {
    _isGlassMode = value;
    _saveToPrefs();
    notifyListeners();
  }

  void setFontSize(double size) {
    _fontSize = size;
    _saveToPrefs();
    notifyListeners();
  }

  void setWallpaperIndex(int index) {
    _wallpaperIndex = index;
    _saveToPrefs();
    notifyListeners();
  }

  void setBubbleRadius(double radius) {
    _bubbleRadius = radius;
    _saveToPrefs();
    notifyListeners();
  }

  void setChatBackground(int index) {
    _chatBackgroundIndex = index;
    _saveToPrefs();
    notifyListeners();
  }

  ChatBackground getChatBackground() {
    return chatBackgrounds[_chatBackgroundIndex];
  }

  Color getColor(String type) {
    if (_isDarkMode) {
      switch (type) {
        case 'appBar':
          return _isOLEDMode ? Colors.black : const Color(0xFF1F2C33);
        case 'appBarText':
          return Colors.white;
        case 'scaffold':
          return _isOLEDMode ? Colors.black : const Color(0xFF0B141A);
        case 'card':
          return _isOLEDMode ? Colors.black : const Color(0xFF111B21);
        case 'text':
          return Colors.white;
        case 'textSecondary':
          return const Color(0xFF8696A0);
        case 'primary':
          return const Color(0xFF00A884);
        case 'chatBubbleMe':
          return const Color(0xFF005C4B);
        case 'chatBubbleOther':
          return _isOLEDMode ? const Color(0xFF1F2C33) : const Color(0xFF202C33);
        case 'divider':
          return const Color(0xFF233138);
        case 'background':
          return _isOLEDMode ? Colors.black : const Color(0xFF0B141A);
        case 'inputFill':
          return _isOLEDMode ? Colors.black : const Color(0xFF1F2C33);
        default:
          return const Color(0xFF00A884);
      }
    } else {
      switch (type) {
        case 'appBar':
          return const Color(0xFF008069);
        case 'appBarText':
          return Colors.white;
        case 'scaffold':
          return const Color(0xFFF0F2F3);
        case 'card':
          return Colors.white;
        case 'text':
          return Colors.black;
        case 'textSecondary':
          return Colors.grey.shade600;
        case 'primary':
          return const Color(0xFF008069);
        case 'chatBubbleMe':
          return const Color(0xFFE7FFDB);
        case 'chatBubbleOther':
          return Colors.white;
        case 'divider':
          return Colors.grey.shade300;
        case 'background':
          return const Color(0xFFF0F2F3);
        case 'inputFill':
          return Colors.white;
        default:
          return const Color(0xFF008069);
      }
    }
  }

  ThemeData get currentTheme {
    return _isDarkMode ? _darkTheme : _lightTheme;
  }

  ThemeData get _lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF008069),
    scaffoldBackgroundColor: const Color(0xFFF0F2F3),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF008069),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF008069),
      primary: const Color(0xFF008069),
      secondary: const Color(0xFF25D366),
      brightness: Brightness.light,
      surface: Colors.white,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(fontSize: _fontSize),
      bodyMedium: TextStyle(fontSize: _fontSize - 2),
      titleMedium: TextStyle(fontSize: _fontSize),
    ),
    useMaterial3: true,
  );

  ThemeData get _darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF00A884),
    scaffoldBackgroundColor: _isOLEDMode ? Colors.black : const Color(0xFF0B141A),
    appBarTheme: AppBarTheme(
      backgroundColor: _isOLEDMode ? Colors.black : const Color(0xFF1F2C33),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00A884),
      primary: const Color(0xFF00A884),
      secondary: const Color(0xFF25D366),
      brightness: Brightness.dark,
      surface: _isOLEDMode ? Colors.black : const Color(0xFF111B21),
    ),
    cardTheme: CardThemeData(
      color: _isOLEDMode ? Colors.black : const Color(0xFF111B21),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(fontSize: _fontSize, color: Colors.white),
      bodyMedium: TextStyle(fontSize: _fontSize - 2, color: Colors.white70),
      titleMedium: TextStyle(fontSize: _fontSize, color: Colors.white),
    ),
    useMaterial3: true,
  );
}
