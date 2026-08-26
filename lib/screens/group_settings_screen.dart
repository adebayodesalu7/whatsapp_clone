import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final bool isAdmin;

  const GroupSettingsScreen({
    super.key, 
    required this.groupId, 
    required this.groupName,
    required this.isAdmin,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  int _slowModeSeconds = 0;
  bool _approvalRequired = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final textColor = themeProvider.getColor('text');

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: Text('Group Governance', style: TextStyle(color: themeProvider.getColor('appBarText'))),
        backgroundColor: themeProvider.getColor('appBar'),
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          _slowModeSeconds = data['slowModeSeconds'] ?? 0;
          _approvalRequired = data['approvalRequired'] ?? false;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Admin Tools', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('primary'))),
              const SizedBox(height: 20),
              
              // Slow Mode
              _buildSettingTile(
                icon: Icons.timer_outlined,
                title: 'Slow Mode',
                subtitle: _slowModeSeconds == 0 ? 'Off' : '$_slowModeSeconds seconds between messages',
                trailing: widget.isAdmin ? IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showSlowModePicker(context, themeProvider),
                ) : null,
                theme: themeProvider,
              ),
              
              const SizedBox(height: 16),
              
              // Member Approval
              SwitchListTile(
                secondary: Icon(Icons.verified_user_outlined, color: themeProvider.getColor('primary')),
                title: Text('Admin Approval', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: const Text('New members must be approved by an admin'),
                value: _approvalRequired,
                activeColor: themeProvider.getColor('primary'),
                onChanged: widget.isAdmin ? (val) {
                  FirebaseFirestore.instance.collection('groups').doc(widget.groupId).update({
                    'approvalRequired': val,
                  });
                } : null,
              ),

              const Divider(height: 40),
              
              if (widget.isAdmin) ...[
                Text('Pending Join Requests', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('primary'))),
                const SizedBox(height: 12),
                _buildJoinRequests(widget.groupId, themeProvider),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingTile({required IconData icon, required String title, required String subtitle, Widget? trailing, required ScreenThemeProvider theme}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.getColor('primary').withOpacity(0.1),
        child: Icon(icon, color: theme.getColor('primary')),
      ),
      title: Text(title, style: TextStyle(color: theme.getColor('text'), fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: theme.getColor('textSecondary'))),
      trailing: trailing,
    );
  }

  void _showSlowModePicker(BuildContext context, ScreenThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.getColor('card'),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Set Slow Mode Delay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          _slowModeOption(0, 'Off', theme),
          _slowModeOption(30, '30 Seconds', theme),
          _slowModeOption(60, '1 Minute', theme),
          _slowModeOption(300, '5 Minutes', theme),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _slowModeOption(int seconds, String label, ScreenThemeProvider theme) {
    return ListTile(
      title: Text(label, style: TextStyle(color: theme.getColor('text'))),
      onTap: () {
        FirebaseFirestore.instance.collection('groups').doc(widget.groupId).update({
          'slowModeSeconds': seconds,
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildJoinRequests(String groupId, ScreenThemeProvider theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('join_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No pending requests', style: TextStyle(color: Colors.grey)));
        }
        
        final requests = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final data = requests[index].data() as Map<String, dynamic>;
            final userId = data['userId'];
            final userName = data['userName'] ?? 'User';

            return ListTile(
              title: Text(userName, style: TextStyle(color: theme.getColor('text'))),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _handleRequest(groupId, requests[index].id, userId, true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _handleRequest(groupId, requests[index].id, userId, false),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleRequest(String groupId, String requestId, String userId, bool approved) async {
    if (approved) {
      await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([userId]),
      });
    }
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('join_requests')
        .doc(requestId)
        .update({'status': approved ? 'approved' : 'rejected'});
  }
}
