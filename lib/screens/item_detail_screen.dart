import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_clone/models/models.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/services/escrow_service.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:share_plus/share_plus.dart';

class ItemDetailScreen extends StatelessWidget {
  final MarketplaceItem item;

  const ItemDetailScreen({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final scaffoldColor = themeProvider.getColor('scaffold');
    final cardColor = themeProvider.getColor('card');
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');
    final primaryColor = themeProvider.getColor('primary');

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: const Text('Item Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeProvider.getColor('appBar'),
        foregroundColor: themeProvider.getColor('appBarText'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              Share.share('Check out this ${item.title} on Titan Marketplace for ₦${item.price.toStringAsFixed(0)}!\n\n${item.description}');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Container(
              height: 350,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(bottom: BorderSide(color: secondaryTextColor.withOpacity(0.1))),
              ),
              child: Hero(
                tag: 'item-image-${item.id}',
                child: item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, size: 60)),
                      )
                    : const Center(child: Icon(Icons.image, size: 80, color: Colors.grey)),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Price Section
                  _buildSection(
                    cardColor: cardColor,
                    secondaryTextColor: secondaryTextColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                              ),
                            ),
                            if (item.isVerifiedSeller)
                              const Icon(Icons.verified, color: Colors.blue, size: 24),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '₦${item.price.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 26, color: primaryColor, fontWeight: FontWeight.w900),
                        ),
                        const Divider(height: 32),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 18, color: secondaryTextColor),
                            const SizedBox(width: 8),
                            Text(item.location, style: TextStyle(color: secondaryTextColor, fontSize: 14)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item.category,
                                style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description Section
                  _buildSection(
                    title: 'Description',
                    cardColor: cardColor,
                    secondaryTextColor: secondaryTextColor,
                    textColor: textColor,
                    child: Text(
                      item.description.isNotEmpty ? item.description : 'No description provided.',
                      style: TextStyle(fontSize: 15, color: textColor.withOpacity(0.8), height: 1.6),
                    ),
                  ),

                  if ((item.brand?.isNotEmpty ?? false) || (item.model?.isNotEmpty ?? false) || (item.specs != null && item.specs!.isNotEmpty)) ...[
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Specifications',
                      cardColor: cardColor,
                      secondaryTextColor: secondaryTextColor,
                      textColor: textColor,
                      child: Column(
                        children: [
                          if (item.brand?.isNotEmpty ?? false) _buildSpecRow('Brand', item.brand!, textColor, secondaryTextColor),
                          if (item.model?.isNotEmpty ?? false) _buildSpecRow('Model', item.model!, textColor, secondaryTextColor),
                          if (item.year?.isNotEmpty ?? false) _buildSpecRow('Year', item.year!, textColor, secondaryTextColor),
                          if (item.specs != null)
                            ...item.specs!.entries.map((e) => _buildSpecRow(e.key.toUpperCase(), e.value, textColor, secondaryTextColor)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Actions
                  if (currentUser != null && currentUser.uid != item.sellerId) ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        final escrow = EscrowService();
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );

                        try {
                          final orderId = await escrow.createEscrowInvoice(
                            item: item,
                            buyerId: currentUser.uid,
                          );

                          if (context.mounted) {
                            Navigator.pop(context); // Close loading
                            
                            final chatService = ChatService();
                            await chatService.sendInvoiceMessage(
                              item.sellerId, 
                              {
                                'itemName': item.title,
                                'amount': item.price,
                                'orderId': orderId,
                                'status': 'Pending',
                                'type': 'Escrow',
                              }
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('🛡️ Secure Titan Escrow Invoice generated.')),
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  contactName: 'Seller',
                                  receiverId: item.sellerId,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text('Buy with Secure Escrow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              contactName: 'Seller',
                              receiverId: item.sellerId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat with Seller', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  
                  if (item.category == 'Electronics' || item.category == 'Home & Office' || item.category == 'Cars')
                    ElevatedButton.icon(
                      onPressed: () => _showARPreview(context, themeProvider),
                      icon: const Icon(Icons.view_in_ar),
                      label: const Text('View in your Room (AR)', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({String? title, required Widget child, required Color cardColor, required Color secondaryTextColor, Color? textColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryTextColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, Color textColor, Color secondaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: secondaryColor, fontSize: 14)),
          Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  void _showARPreview(BuildContext context, ScreenThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isScanning = true;
          Future.delayed(const Duration(seconds: 3), () {
            if (context.mounted) setDialogState(() => isScanning = false);
          });

          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: const Text('Titan AR Lens'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            body: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.grey.shade900,
                  child: const Icon(Icons.camera, color: Colors.white10, size: 200),
                ),
                if (isScanning)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_scanner, color: Colors.blueAccent, size: 100),
                        const SizedBox(height: 20),
                        const Text('Scanning Room Surfaces...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SizedBox(width: 200, child: LinearProgressIndicator(backgroundColor: Colors.white24, color: Colors.blueAccent)),
                      ],
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.network(item.imageUrl, height: 200, width: 200, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.image, size: 100)),
                              const SizedBox(height: 10),
                              const Text("TITAN 3D RENDER", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text("Object Placed", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(30)),
                      child: Text(
                        isScanning ? 'Scan your floor or table' : 'Drag to move the ${item.title}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
