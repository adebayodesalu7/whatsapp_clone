import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_clone/models/models.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/services/escrow_service.dart';
import 'package:uuid/uuid.dart';

class ItemDetailScreen extends StatelessWidget {
  final MarketplaceItem item;

  const ItemDetailScreen({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    const screenColor = Color(0xFF25D366);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Item Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 350,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
              ),
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, size: 60)),
                    )
                  : const Center(child: Icon(Icons.image, size: 80, color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Icon(Icons.share_outlined, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '₦${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 22, color: Color(0xFF25D366), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(item.location, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    item.description.isNotEmpty ? item.description : 'No description provided.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5),
                  ),
                  const SizedBox(height: 30),
                  if (currentUser != null && currentUser.uid != item.sellerId)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final escrow = EscrowService();
                          
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(child: CircularProgressIndicator()),
                          );

                          final orderId = await escrow.createEscrowInvoice(
                            item: item,
                            buyerId: currentUser.uid,
                          );

                          if (context.mounted) {
                            Navigator.pop(context); // Close loading
                            
                            // Send Invoice Message to Chat
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
                        },
                        icon: const Icon(Icons.shield_outlined),
                        label: const Text('Buy with Secure Escrow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (currentUser != null && currentUser.uid != item.sellerId)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
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
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (item.category == 'Electronics' || item.category == 'Home & Office' || item.category == 'Cars')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showARPreview(context),
                        icon: const Icon(Icons.view_in_ar),
                        label: const Text('View in your Room (AR)', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showARPreview(BuildContext context) {
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
                // Simulated Camera Feed
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
                        // Simulated 3D Model
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.network(item.imageUrl, height: 200, width: 200, fit: BoxFit.contain),
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
