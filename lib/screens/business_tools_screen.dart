import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/screen_theme_provider.dart';
import '../services/business_service.dart';
import '../models/models.dart';
import 'wallet_screen.dart';
import 'notes_to_self_screen.dart';
import 'catalog_screen.dart';
import 'market_orders_screen.dart';

class BusinessToolsScreen extends StatelessWidget {
  const BusinessToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: themeProvider.getColor('scaffold'),
        appBar: AppBar(
          title: Text('Business Tools', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
          backgroundColor: themeProvider.getColor('appBar'),
          iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
          elevation: 0,
        ),
        body: Column(
          children: [
            Container(
              color: themeProvider.getColor('appBar'),
              padding: const EdgeInsets.only(bottom: 12),
              child: TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                indicatorWeight: 4,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.6),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                tabs: const [
                  Tab(icon: Icon(Icons.receipt_long_outlined, size: 24), text: 'Escrow'),
                  Tab(icon: Icon(Icons.inventory_2_outlined, size: 24), text: 'Catalog'),
                  Tab(icon: Icon(Icons.calendar_month_outlined, size: 24), text: 'Orders'),
                  Tab(icon: Icon(Icons.analytics_outlined, size: 24), text: 'Analytics'),
                  Tab(icon: Icon(Icons.campaign_outlined, size: 24), text: 'Ads'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  EscrowTab(),
                  CatalogTab(),
                  OrdersTab(),
                  AnalyticsTab(),
                  AdsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EscrowTab extends StatelessWidget {
  const EscrowTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('escrow_transactions')
          .where('participants', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security_outlined, size: 80, color: themeProvider.getColor('textSecondary').withOpacity(0.3)),
                const SizedBox(height: 16),
                Text('No escrow transactions yet', style: TextStyle(color: themeProvider.getColor('textSecondary'))),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return BusinessToolCard(
              title: data['itemTitle'] ?? 'Escrow Payment',
              subtitle: '₦${data['amount']} • ${data['status'] ?? 'In Progress'}',
              icon: Icons.security,
              iconColor: Colors.blue,
              themeProvider: themeProvider,
            );
          },
        );
      },
    );
  }
}

class CatalogTab extends StatelessWidget {
  const CatalogTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CatalogScreen())),
            icon: const Icon(Icons.fullscreen),
            label: const Text('Open Full Catalog'),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.getColor('primary'),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('marketplace_items').where('sellerId', isEqualTo: userId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return Center(child: Text('Your catalog is empty', style: TextStyle(color: themeProvider.getColor('textSecondary'))));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return BusinessToolCard(
                    title: data['title'] ?? 'Item',
                    subtitle: '₦${data['price']} • ${data['category']}',
                    icon: Icons.inventory_2,
                    iconColor: Colors.purple,
                    themeProvider: themeProvider,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MarketOrdersScreen())),
            icon: const Icon(Icons.fullscreen),
            label: const Text('Manage All Orders'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('market_orders').where('sellerId', isEqualTo: userId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return Center(child: Text('No orders yet', style: TextStyle(color: themeProvider.getColor('textSecondary'))));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return BusinessToolCard(
                    title: data['itemTitle'] ?? 'Order',
                    subtitle: 'Status: ${data['status'] ?? 'Pending'} • ₦${data['amount']}',
                    icon: Icons.shopping_bag,
                    iconColor: Colors.orange,
                    themeProvider: themeProvider,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Performance Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        _buildStatCard('Total Sales', '₦1,250,000', Icons.trending_up, Colors.green, themeProvider),
        const SizedBox(height: 12),
        _buildStatCard('Item Views', '4,320', Icons.visibility, Colors.blue, themeProvider),
        const SizedBox(height: 12),
        _buildStatCard('Inquiries', '128', Icons.chat, Colors.orange, themeProvider),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, ScreenThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: themeProvider.getColor('card'), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: themeProvider.getColor('textSecondary'), fontSize: 12)),
              Text(value, style: TextStyle(color: themeProvider.getColor('text'), fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }
}

class AdsTab extends StatelessWidget {
  const AdsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(child: Text('Boost your items to the "Featured Deals" section for 2x more visibility.', style: TextStyle(fontSize: 12))),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 2,
            itemBuilder: (context, index) => BusinessToolCard(
              title: index == 0 ? 'Toyota Camry 2022' : 'Modern Sofa Set',
              subtitle: 'Boost Status: Inactive',
              icon: Icons.campaign,
              iconColor: Colors.blue,
              themeProvider: themeProvider,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚀 Ad boosting service pending payment...')));
              },
            ),
          ),
        ),
      ],
    );
  }
}

class BusinessToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final ScreenThemeProvider themeProvider;

  const BusinessToolCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.onTap,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: themeProvider.getColor('card'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: iconColor.withOpacity(0.1), child: Icon(icon, color: iconColor)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('text'))),
        subtitle: Text(subtitle, style: TextStyle(color: themeProvider.getColor('textSecondary'))),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: themeProvider.getColor('textSecondary')),
        onTap: onTap,
      ),
    );
  }
}
