import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/services/security_service.dart';
import 'package:whatsapp_clone/screens/chat_list_screen.dart';
import 'package:whatsapp_clone/screens/settings_screen.dart';
import 'package:whatsapp_clone/screens/login_screen.dart';
import 'package:whatsapp_clone/screens/groups_screen.dart';
import 'package:whatsapp_clone/screens/status_screen.dart';
import 'package:whatsapp_clone/screens/channels_screen.dart';
import 'package:whatsapp_clone/screens/calls_screen.dart';
import 'package:whatsapp_clone/screens/marketplace_screen.dart';
import 'package:whatsapp_clone/screens/wallet_screen.dart';
import 'package:whatsapp_clone/screens/ajo_group_screen.dart';
import 'package:whatsapp_clone/screens/airtime_purchase_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('⚠️ Firebase not initialized: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScreenThemeProvider()),
      ],
      child: const WhatsappCloneApp(),
    ),
  );
}

class WhatsappCloneApp extends StatelessWidget {
  const WhatsappCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);

    return MaterialApp(
      title: 'ChatApp',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainNavigation(),
        '/settings': (context) => const SettingsScreen(),
        '/marketplace': (context) => const MarketplaceScreen(),
        '/wallet': (context) => const WalletScreen(),
        '/ajo': (context) => const AjoGroupScreen(),
        '/airtime': (context) => const AirtimePurchaseScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const AppLockWrapper(child: MainNavigation());
        }
        return const LoginScreen();
      },
    );
  }
}

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> {
  bool _isUnlocked = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  void _checkLock() async {
    final themeProvider = Provider.of<ScreenThemeProvider>(context, listen: false);
    if (themeProvider.isAppLockEnabled) {
      _authenticate();
    } else {
      setState(() => _isUnlocked = true);
    }
  }

  Future<void> _authenticate() async {
    setState(() => _isAuthenticating = true);
    final security = SecurityService();
    final success = await security.authenticate();
    if (mounted) {
      setState(() {
        _isUnlocked = success;
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    
    if (!themeProvider.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isUnlocked || !themeProvider.isAppLockEnabled) return widget.child;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Color(0xFF25D366)),
            const SizedBox(height: 20),
            const Text('WhatsApp is Locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (!_isAuthenticating)
              ElevatedButton(
                onPressed: _authenticate,
                child: const Text('Unlock with Biometrics'),
              )
            else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ChatListScreen(),
    const GroupsScreen(),
    const StatusScreen(),
    const ChannelsScreen(),
    const MarketplaceScreen(),
    const CallsScreen(),
  ];

  void _showSOSDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Emergency SOS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('This will share your live location with your trusted emergency contacts and record 30 seconds of audio. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 SOS Alert Sent! Your location is being shared.'),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 5),
                ),
              );
            },
            child: const Text('SEND ALERT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: _screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 2 
        ? FloatingActionButton(
            onPressed: _showSOSDialog,
            backgroundColor: Colors.red,
            child: const Icon(Icons.sos, color: Colors.white, size: 32),
          )
        : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: isDark ? Colors.black : Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat, color: Color(0xFF25D366)),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups, color: Color(0xFF25D366)),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.update_outlined),
            selectedIcon: Icon(Icons.update, color: Color(0xFF25D366)),
            label: 'Updates',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub, color: Color(0xFF25D366)),
            label: 'Channels',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: Color(0xFF25D366)),
            label: 'Marketplace',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call, color: Color(0xFF25D366)),
            label: 'Calls',
          ),
        ],
      ),
    );
  }
}
