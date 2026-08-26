import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_clone/models/models.dart';
import 'package:whatsapp_clone/providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/screens/add_item_screen.dart';
import 'package:whatsapp_clone/screens/item_detail_screen.dart';
import 'package:whatsapp_clone/screens/business_tools_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    try {
      double value = double.parse(newValue.text.replaceAll(RegExp(r'[^0-9]'), ''));
      final formatter = NumberFormat.currency(symbol: 'N', decimalDigits: 0);
      String newText = formatter.format(value);
      return newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    } catch (e) {
      return newValue;
    }
  }
}

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String _selectedCategory = 'All';
  String _selectedState = 'All';
  String _searchQuery = '';
  double? _minPrice;
  double? _maxPrice;
  bool _showNearbyOnly = false;
  Position? _currentPosition;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['All', 'Vehicle Sales', 'Vehicle Rentals', 'Property Lease', 'Electronics', 'Home & Office'];
  final List<String> _nigerianStates = [
    'All', 'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue', 'Borno', 
    'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'Gombe', 'Imo', 
    'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi', 'Kwara', 'Lagos', 
    'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo', 'Plateau', 'Rivers', 
    'Sokoto', 'Taraba', 'Yobe', 'Zamfara', 'FCT'
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final scaffoldColor = themeProvider.getColor('scaffold');
    final textColor = themeProvider.getColor('text');
    final secondaryTextColor = themeProvider.getColor('textSecondary');
    final appBarColor = themeProvider.getColor('appBar');

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text('Marketplace', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: themeProvider.getColor('appBarText'))),
        backgroundColor: appBarColor,
        toolbarHeight: 40,
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText'), size: 16),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.business_center_outlined, size: 18), 
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const BusinessToolsScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            color: appBarColor,
            child: Column(
              children: [
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: themeProvider.getColor('card').withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      icon: const Icon(Icons.search, color: Colors.white70, size: 16),
                      hintText: 'Search products...',
                      hintStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterBadge('Location', Icons.location_on_outlined, _selectedState != 'All', () => _showLocationFilter()),
                      const SizedBox(width: 4),
                      _buildFilterBadge('Price', Icons.payments_outlined, _minPrice != null || _maxPrice != null, () => _showPriceFilter()),
                      const SizedBox(width: 4),
                      _buildFilterBadge('Category', Icons.category_outlined, _selectedCategory != 'All', () => _showCategoryFilter()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildFeaturedCarousel(themeProvider),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('marketplace_items')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: textColor)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off_outlined, size: 80, color: secondaryTextColor.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('No items found.', style: TextStyle(color: secondaryTextColor)),
                      ],
                    ),
                  );
                }

                final items = snapshot.data!.docs
                    .map((doc) => MarketplaceItem.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                    .where((item) {
                      bool catMatch = _selectedCategory == 'All' || item.category == _selectedCategory;
                      bool stateMatch = _selectedState == 'All' || item.location == _selectedState;
                      bool priceMatch = true;
                      if (_minPrice != null && item.price < _minPrice!) priceMatch = false;
                      if (_maxPrice != null && item.price > _maxPrice!) priceMatch = false;
                      bool searchMatch = _searchQuery.isEmpty || item.title.toLowerCase().contains(_searchQuery);
                      return catMatch && stateMatch && priceMatch && searchMatch;
                    })
                    .toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildMarketplaceCard(context, item, themeProvider);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddItemScreen()));
        },
        backgroundColor: themeProvider.getColor('primary'),
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white, size: 20),
        label: const Text('Sell', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildFeaturedCarousel(ScreenThemeProvider themeProvider) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('marketplace_items').where('isPromoted', isEqualTo: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        final promoted = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text('Featured ✨', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: promoted.length,
                itemBuilder: (context, index) {
                  final item = MarketplaceItem.fromMap(promoted[index].id, promoted[index].data() as Map<String, dynamic>);
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item))),
                    child: Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(image: NetworkImage(item.imageUrl), fit: BoxFit.cover),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(NumberFormat.currency(symbol: 'N', decimalDigits: 0).format(item.price), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBadge(String label, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isActive ? Colors.blue : Colors.white70),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isActive ? Colors.blue : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            Icon(Icons.arrow_drop_down, size: 12, color: isActive ? Colors.blue : Colors.white70),
          ],
        ),
      ),
    );
  }

  void _showLocationFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        children: _nigerianStates.map((s) => ListTile(
          title: Text(s, style: const TextStyle(fontSize: 14)),
          selected: _selectedState == s,
          onTap: () {
            setState(() => _selectedState = s);
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        children: _categories.map((c) => ListTile(
          title: Text(c, style: const TextStyle(fontSize: 14)),
          selected: _selectedCategory == c,
          onTap: () {
            setState(() => _selectedCategory = c);
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }

  void _showPriceFilter() {
    final currencyFormat = NumberFormat.currency(symbol: 'N', decimalDigits: 0);
    final minController = TextEditingController(text: _minPrice != null ? currencyFormat.format(_minPrice) : '');
    final maxController = TextEditingController(text: _maxPrice != null ? currencyFormat.format(_maxPrice) : '');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Price Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minController, 
                    decoration: const InputDecoration(labelText: 'Min Price', hintText: 'N0'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TextField(
                    controller: maxController, 
                    decoration: const InputDecoration(labelText: 'Max Price', hintText: 'N10M'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _minPrice = double.tryParse(minController.text.replaceAll(RegExp(r'[^0-9]'), ''));
                  _maxPrice = double.tryParse(maxController.text.replaceAll(RegExp(r'[^0-9]'), ''));
                });
                Navigator.pop(context);
              },
              child: const Text('Apply Filter'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketplaceCard(BuildContext context, MarketplaceItem item, ScreenThemeProvider themeProvider) {
    final currencyFormat = NumberFormat.currency(symbol: 'N', decimalDigits: 0);
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)));
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: themeProvider.getColor('card'),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: themeProvider.getColor('textSecondary').withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Hero(
                      tag: 'item-image-${item.id}',
                      child: item.imageUrl.isNotEmpty
                          ? (item.imageUrl.startsWith('http') 
                              ? Image.network(
                                  item.imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 30),
                                  ),
                                )
                              : Image.file(
                                  io.File(item.imageUrl.startsWith('file://') ? item.imageUrl.replaceFirst('file://', '') : item.imageUrl),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 30),
                                  ),
                                ))
                          : Container(
                              color: Colors.grey.shade100,
                              child: const Icon(Icons.image_outlined, color: Colors.grey, size: 30),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: themeProvider.getColor('text')),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormat.format(item.price),
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: themeProvider.getColor('primary')),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 10, color: themeProvider.getColor('textSecondary')),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            item.location,
                            style: TextStyle(color: themeProvider.getColor('textSecondary'), fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
