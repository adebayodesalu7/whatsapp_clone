import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/widgets/theme_selector.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/screens/public_profile_screen.dart';

class ContactsScreen extends StatefulWidget {
  final bool isPicker;
  const ContactsScreen({super.key, this.isPicker = false});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Contact> _deviceContacts = [];
  List<String> _registeredNumbers = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatPhoneNumber(String number) {
    number = number.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (number.startsWith('0')) {
      if (number.length == 10) {
        return '+234$number';
      } else if (number.length == 11) {
        return '+234${number.substring(1)}';
      }
    }
    if (number.startsWith('+234')) {
      return number;
    }
    if (number.startsWith('234')) {
      return '+$number';
    }
    if (number.length >= 10) {
      return '+234$number';
    }
    return number;
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await Permission.contacts.request();

      if (status.isGranted) {
        setState(() {
          _hasPermission = true;
        });

        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );

        setState(() {
          _deviceContacts = contacts;
        });

        final phoneNumbers = <String>[];
        for (var contact in contacts) {
          for (var phone in contact.phones) {
            String number = _formatPhoneNumber(phone.number);
            if (number.isNotEmpty && number.length >= 10) {
              phoneNumbers.add(number);
            }
          }
        }

        if (phoneNumbers.isNotEmpty) {
          final batches = <List<String>>[];
          for (var i = 0; i < phoneNumbers.length; i += 30) {
            batches.add(phoneNumbers.sublist(
              i,
              i + 30 > phoneNumbers.length ? phoneNumbers.length : i + 30,
            ));
          }

          List<String> allRegistered = [];
          for (var batch in batches) {
            try {
              final usersSnapshot = await FirebaseFirestore.instance
                  .collection('users')
                  .where('phoneNumber', whereIn: batch)
                  .get();

              final registered = usersSnapshot.docs
                  .map((doc) => (doc.data() as Map<String, dynamic>)['phoneNumber'] as String)
                  .toList();

              allRegistered.addAll(registered);
            } catch (e) {
              print('❌ Firestore query error: $e');
            }
          }

          setState(() {
            _registeredNumbers = allRegistered;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else if (status.isPermanentlyDenied) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
        _showMessage('Contacts permission is permanently denied. Please enable it in settings.', isError: true);
        openAppSettings();
      } else {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showMessage('❌ Error: $e', isError: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final screenColor = themeProvider.getColor('contacts');
    final primaryLight = screenColor.withOpacity(0.2);

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: screenColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PublicProfileScreen(
                    userId: currentUser.uid,
                  ),
                ),
              );
            },
          ),
          ThemeSelector(screenName: 'contacts'),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text('Loading contacts...'),
          ],
        ),
      )
          : !_hasPermission
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.contacts, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Permission Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Allow ChatApp to access your contacts',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadContacts,
              style: ElevatedButton.styleFrom(
                backgroundColor: screenColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      )
          : _deviceContacts.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No contacts found',
              style: TextStyle(color: Colors.grey),
            ),
            Text(
              'Add contacts to your phone',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final allUsers = snapshot.data!.docs;
          final registeredUsers = allUsers
              .where((doc) => doc.id != currentUser.uid)
              .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final phone = data['phoneNumber'] ?? '';
            return _registeredNumbers.contains(phone);
          })
              .toList();

          List<Map<String, dynamic>> contactList = [];
          for (var contact in _deviceContacts) {
            if (contact.displayName == null || contact.displayName!.isEmpty) continue;

            bool isRegistered = false;
            String userId = '';
            String phoneNumber = '';

            for (var phone in contact.phones) {
              String formattedNumber = _formatPhoneNumber(phone.number);

              if (_registeredNumbers.contains(formattedNumber)) {
                isRegistered = true;
                phoneNumber = formattedNumber;
                for (var user in registeredUsers) {
                  final userData = user.data() as Map<String, dynamic>;
                  if (userData['phoneNumber'] == formattedNumber) {
                    userId = user.id;
                    break;
                  }
                }
                break;
              }
            }

            contactList.add({
              'name': contact.displayName ?? 'Unknown',
              'isRegistered': isRegistered,
              'userId': userId,
              'phoneNumber': phoneNumber,
              'photoUrl': '',
            });
          }

          contactList.sort((a, b) => a['name'].compareTo(b['name']));

          final registeredOnApp = contactList.where((c) => c['isRegistered']).toList();
          final others = contactList.where((c) => !c['isRegistered']).toList();

          if (_searchQuery.isNotEmpty) {
            contactList = contactList.where((contact) {
              return contact['name']
                  .toLowerCase()
                  .contains(_searchQuery);
            }).toList();
          }

          if (contactList.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.contacts, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No contacts found',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView(
            children: [
              if (registeredOnApp.isNotEmpty && _searchQuery.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('CONTACTS ON CHATAPP', style: TextStyle(color: screenColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                ...registeredOnApp.map((c) => _buildContactTile(c, screenColor, primaryLight)).toList(),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('INVITE TO CHATAPP', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                ...others.map((c) => _buildContactTile(c, screenColor, primaryLight)).toList(),
              ] else 
                ...contactList.map((c) => _buildContactTile(c, screenColor, primaryLight)).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContactTile(Map<String, dynamic> contact, Color screenColor, Color primaryLight) {
    final isRegistered = contact['isRegistered'];
    final userId = contact['userId'];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isRegistered ? primaryLight : Colors.grey.shade300,
        child: Text(
          contact['name'].isNotEmpty ? contact['name'][0].toUpperCase() : '?',
          style: TextStyle(
            color: isRegistered ? screenColor : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              contact['name'],
              style: TextStyle(fontWeight: isRegistered ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          if (isRegistered)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: primaryLight, borderRadius: BorderRadius.circular(10)),
              child: Text('ChatApp', style: TextStyle(color: screenColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      subtitle: Text(contact['phoneNumber'] ?? 'No phone number', style: TextStyle(color: isRegistered ? Colors.grey : Colors.grey.shade400)),
      trailing: isRegistered 
        ? Icon(Icons.chat_bubble_outline, color: screenColor)
        : Text('INVITE', style: TextStyle(color: screenColor, fontWeight: FontWeight.bold, fontSize: 12)),
      onTap: () {
        if (widget.isPicker) {
          Navigator.pop(context, contact);
        } else if (isRegistered) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(contactName: contact['name'], receiverId: contact['userId'])));
        }
      },
    );
  }
}