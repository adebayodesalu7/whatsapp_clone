import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/screen_theme_provider.dart';
import '../services/storage_service.dart';
import 'package:geolocator/geolocator.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  
  // Car specific
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _fuelController = TextEditingController();
  final TextEditingController _transController = TextEditingController();

  String _selectedCategory = 'Cars';
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  List<XFile> _selectedImages = [];
  bool _isLoading = false;
  Position? _currentPosition;

  String _selectedState = 'Lagos';
  final List<String> _nigerianStates = [
    'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue', 'Borno', 
    'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'Gombe', 'Imo', 
    'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi', 'Kwara', 'Lagos', 
    'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo', 'Plateau', 'Rivers', 
    'Sokoto', 'Taraba', 'Yobe', 'Zamfara', 'FCT'
  ];

  final List<String> _categories = [
    'Cars',
    'Vehicles',
    'Rentals',
    'Electronics',
    'Home & Office',
    'Services',
  ];

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 80);
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return; 

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
    });
  }

  void _postItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one photo is required')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      print('⏳ Starting item post process...');
      
      // Upload main image
      print('📸 Uploading main image: ${_selectedImages[0].path}');
      final String? mainImageUrl = await _storageService.uploadImage(_selectedImages[0].path, 'marketplace');
      
      if (mainImageUrl == null || mainImageUrl.isEmpty) {
        print('❌ Main image upload failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload image. Please check your connection.')));
        }
        return;
      }

      // Upload other images
      List<String> moreImageUrls = [];
      for (int i = 1; i < _selectedImages.length; i++) {
        print('📸 Uploading extra image $i: ${_selectedImages[i].path}');
        final url = await _storageService.uploadImage(_selectedImages[i].path, 'marketplace');
        if (url != null && url.isNotEmpty) {
          moreImageUrls.add(url);
        }
      }

      print('📝 Saving document to Firestore...');
      
      Map<String, String> specs = {};
      if (_selectedCategory == 'Cars') {
        specs = {
          'fuel': _fuelController.text,
          'transmission': _transController.text,
        };
      }

      final itemData = {
        'sellerId': user.uid,
        'title': _titleController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'description': _descriptionController.text,
        'category': _selectedCategory,
        'location': _selectedState,
        'lat': _currentPosition?.latitude,
        'lng': _currentPosition?.longitude,
        'imageUrl': mainImageUrl, 
        'moreImages': moreImageUrls,
        'videoUrl': _videoUrlController.text,
        'brand': _brandController.text,
        'model': _modelController.text,
        'year': _yearController.text,
        'specs': specs,
        'createdAt': FieldValue.serverTimestamp(),
        'isPromoted': false,
        'isVerifiedSeller': false,
      };

      print('DEBUG: Item Data to save: $itemData');

      await FirebaseFirestore.instance.collection('marketplace_items').add(itemData);

      print('✅ Item listed successfully!');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item listed successfully!')));
      }
    } catch (e) {
      print('❌ ERROR POSTING ITEM: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ScreenThemeProvider>(context);
    final textColor = themeProvider.getColor('text');
    final secondaryColor = themeProvider.getColor('textSecondary');
    final cardColor = themeProvider.getColor('card');

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: Text('List New Item', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
        backgroundColor: themeProvider.getColor('appBar'),
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _postItem,
            child: Text('POST', style: TextStyle(color: themeProvider.getColor('appBarText'), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeProvider.getColor('primary')))
          : Container(
              color: themeProvider.getColor('scaffold'),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _titleController,
                        label: 'Title*',
                        hint: '0 / 70',
                        themeProvider: themeProvider,
                        validator: (v) => v!.isEmpty ? 'This field is required.' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        dropdownColor: themeProvider.getColor('card'),
                        style: TextStyle(color: textColor),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val!),
                        decoration: _inputDecoration('Category*', themeProvider),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedState,
                        dropdownColor: themeProvider.getColor('card'),
                        style: TextStyle(color: textColor),
                        items: _nigerianStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) => setState(() => _selectedState = val!),
                        decoration: _inputDecoration('State of Sale*', themeProvider),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: Icon(Icons.my_location, color: _currentPosition != null ? Colors.green : Colors.white70),
                        label: Text(_currentPosition != null ? 'Location Captured' : 'Tag GPS Location (Optional)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Add Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                      const SizedBox(height: 8),
                      Text('First picture is the title picture.', 
                        style: TextStyle(color: themeProvider.getColor('primary'), fontSize: 13)),
                      const SizedBox(height: 16),
                      _buildImagePicker(themeProvider.getColor('card'), secondaryColor, themeProvider),
                      const SizedBox(height: 8),
                      Text('Supported formats are *.jpg and *.png', style: TextStyle(color: secondaryColor, fontSize: 12)),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _videoUrlController,
                        label: 'Video Link (Optional)',
                        themeProvider: themeProvider,
                      ),
                      if (_selectedCategory == 'Cars') ...[
                        const SizedBox(height: 24),
                        Text('Vehicle Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        const SizedBox(height: 16),
                        _buildTextField(controller: _brandController, label: 'Brand', themeProvider: themeProvider),
                        const SizedBox(height: 12),
                        _buildTextField(controller: _modelController, label: 'Model', themeProvider: themeProvider),
                        const SizedBox(height: 12),
                        _buildTextField(controller: _yearController, label: 'Year', themeProvider: themeProvider, keyboardType: TextInputType.number),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(controller: _fuelController, label: 'Fuel', hint: 'Petrol/Diesel', themeProvider: themeProvider)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField(controller: _transController, label: 'Transmission', hint: 'Auto/Manual', themeProvider: themeProvider)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _priceController,
                        label: 'Price (₦)*',
                        keyboardType: TextInputType.number,
                        themeProvider: themeProvider,
                        validator: (v) => v!.isEmpty ? 'Price is required.' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        maxLines: 4,
                        themeProvider: themeProvider,
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _postItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.getColor('primary'),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: const Text('Post Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildImagePicker(Color cardColor, Color secondaryColor, ScreenThemeProvider themeProvider) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ..._selectedImages.asMap().entries.map((entry) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: io.File(entry.value.path).existsSync()
                  ? Image.file(io.File(entry.value.path), width: 100, height: 100, fit: BoxFit.cover)
                  : Container(width: 100, height: 100, color: secondaryColor.withOpacity(0.1), child: Icon(Icons.image, color: secondaryColor)),
              ),
              Positioned(
                right: 0,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedImages.removeAt(entry.key)),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          );
        }),
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: themeProvider.getColor('primary').withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: themeProvider.getColor('primary').withOpacity(0.3)),
            ),
            child: Icon(Icons.add_a_photo_outlined, color: themeProvider.getColor('primary'), size: 32),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, ScreenThemeProvider themeProvider) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: themeProvider.getColor('textSecondary')),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: themeProvider.getColor('textSecondary').withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: themeProvider.getColor('primary')),
      ),
      filled: true,
      fillColor: themeProvider.getColor('card'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefixText,
    int maxLines = 1,
    TextInputType? keyboardType,
    required ScreenThemeProvider themeProvider,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: themeProvider.getColor('text')),
      decoration: _inputDecoration(label, themeProvider).copyWith(
        hintText: hint,
        hintStyle: TextStyle(color: themeProvider.getColor('textSecondary').withOpacity(0.5)),
        prefixText: prefixText,
      ),
    );
  }
}
