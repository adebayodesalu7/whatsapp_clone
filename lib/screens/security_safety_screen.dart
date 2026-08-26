import 'package:flutter/material.dart';

class SecuritySafetyScreen extends StatefulWidget {
  const SecuritySafetyScreen({super.key});

  @override
  State<SecuritySafetyScreen> createState() => _SecuritySafetyScreenState();
}

class _SecuritySafetyScreenState extends State<SecuritySafetyScreen> {
  bool _aiScamDetection = true;
  bool _childSafeMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Security & Safety', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent.shade200,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader('AI Protection'),
          _buildSwitchTile('AI Scam Detection', 'Automatically flag suspicious links and fraudulent behavior.', _aiScamDetection, (v) => setState(() => _aiScamDetection = v)),
          const Divider(height: 1),
          ListTile(
            title: const Text('Fake Account Shield', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: const Text('Warns you when chatting with accounts that show bot-like behavior.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
          
          const SizedBox(height: 24),
          _buildHeader('Personal Safety'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm SOS'),
                    content: const Text('This will send your location to your trusted contacts. Continue?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('SOS Alert Triggered! Signals sent to trusted contacts.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                        child: const Text('SEND', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
              label: const Text('TRIGGER EMERGENCY SOS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.shade200,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Trusted Contacts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: const Text('Manage who receives your SOS alerts.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {},
          ),
          
          const SizedBox(height: 24),
          _buildHeader('Parental Controls'),
          _buildSwitchTile('Child-Safe Mode', 'Blocks adult content, restricts unknown contacts, and limits usage time.', _childSafeMode, (v) => setState(() => _childSafeMode = v)),
        ],
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(text, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.redAccent.shade200,
    );
  }
}
