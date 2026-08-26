import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/screen_theme_provider.dart';
import 'package:whatsapp_clone/services/cloudinary_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:whatsapp_clone/models/models.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;
    double value = double.parse(newValue.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final formatter = NumberFormat.currency(symbol: 'N', decimalDigits: 0);
    String newText = formatter.format(value);
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class AddItemScreen extends StatefulWidget {
  final MarketplaceItem? editItem;
  const AddItemScreen({super.key, this.editItem});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _videoUrlController;
  
  // Car specific
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _fuelController;
  late TextEditingController _transController;

  String _selectedCategory = 'Cars';
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  List<XFile> _selectedImages = [];
  bool _isLoading = false;
  Position? _currentPosition;
  List<String> _detectedTags = [];
  bool _isModerated = false;

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

  @override
  void initState() {
    super.initState();
    final item = widget.editItem;
    _titleController = TextEditingController(text: item?.title);
    _priceController = TextEditingController(text: item?.price.toStringAsFixed(0));
    _descriptionController = TextEditingController(text: item?.description);
    _locationController = TextEditingController();
    _videoUrlController = TextEditingController(text: item?.videoUrl);
    _brandController = TextEditingController(text: item?.brand);
    _modelController = TextEditingController(text: item?.model);
    _yearController = TextEditingController(text: item?.year);
    _fuelController = TextEditingController(text: item?.specs?['fuel']);
    _transController = TextEditingController(text: item?.specs?['transmission']);
    
    if (item != null) {
      _selectedCategory = item.category;
      _selectedState = item.location;
    }
  }

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
    
    bool isEditing = widget.editItem != null;

    if (!isEditing && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one photo is required')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to post items.')));
        return;
      }

      String? mainImageUrl = widget.editItem?.imageUrl;
      String? mainImagePublicId = widget.editItem?.imagePublicId;
      List<String> moreImageUrls = widget.editItem?.moreImages ?? [];
      List<String> aiTags = [];

      if (_selectedImages.isNotEmpty) {
        // Upload main image with AI Features
        print('📸 Uploading main image with AI Analysis: ${_selectedImages[0].path}');
        final uploadResult = await _cloudinaryService.uploadMarketplaceImage(_selectedImages[0]);
        
        if (uploadResult == null || uploadResult['url'] == null) {
          print('❌ Main image upload failed');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Upload failed. Please check your Cloudinary settings.'),
            ));
          }
          return;
        }
        mainImageUrl = uploadResult['url'];
        mainImagePublicId = uploadResult['publicId'];
        if (uploadResult['tags'] != null) {
          aiTags = List<String>.from(uploadResult['tags']);
          setState(() {
            _detectedTags = aiTags;
            _isModerated = true; // Simulating success moderation from Cloudinary
          });
        }

        // Upload other images
        for (int i = 1; i < _selectedImages.length; i++) {
          print('📸 Uploading extra image $i...');
          final result = await _cloudinaryService.uploadMarketplaceImage(_selectedImages[i]);
          if (result != null && result['url'] != null) {
            moreImageUrls.add(result['url']);
          }
        }
      }

      Map<String, String> specs = {};
      if (_selectedCategory == 'Cars') {
        specs = {
          'fuel': _fuelController.text,
          'transmission': _transController.text,
        };
      }

      // Convert formatted price back to double (remove 'N' and ',')
      final cleanPrice = double.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

      final itemData = {
        'sellerId': user.uid,
        'title': _titleController.text,
        'price': cleanPrice,
        'description': _descriptionController.text,
        'category': _selectedCategory,
        'location': _selectedState,
        'lat': _currentPosition?.latitude ?? widget.editItem?.lat,
        'lng': _currentPosition?.longitude ?? widget.editItem?.lng,
        'imageUrl': mainImageUrl, 
        'imagePublicId': mainImagePublicId,
        'moreImages': moreImageUrls,
        'aiTags': aiTags, 
        'videoUrl': _videoUrlController.text,
        'brand': _brandController.text,
        'model': _modelController.text,
        'year': _yearController.text,
        'specs': specs,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isEditing) {
        await FirebaseFirestore.instance.collection('marketplace_items').doc(widget.editItem!.id).update(itemData);
      } else {
        itemData['createdAt'] = FieldValue.serverTimestamp();
        itemData['isPromoted'] = false;
        itemData['isVerifiedSeller'] = false;
        await FirebaseFirestore.instance.collection('marketplace_items').add(itemData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? 'Item updated successfully!' : 'Item listed successfully!')));
      }
    } catch (e) {
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
    bool isEditing = widget.editItem != null;

    return Scaffold(
      backgroundColor: themeProvider.getColor('scaffold'),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Item' : 'List New Item', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.getColor('appBarText'))),
        backgroundColor: themeProvider.getColor('appBar'),
        iconTheme: IconThemeData(color: themeProvider.getColor('appBarText')),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _postItem,
            child: Text(isEditing ? 'UPDATE' : 'POST', style: TextStyle(color: themeProvider.getColor('appBarText'), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeProvider.getColor('primary')))
          : Container(
              color: themeProvider.getColor('scaffold'),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
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
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        dropdownColor: themeProvider.getColor('card'),
                        style: TextStyle(color: textColor, fontSize: 13),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val!),
                        decoration: _inputDecoration('Category*', themeProvider),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedState,
                        dropdownColor: themeProvider.getColor('card'),
                        style: TextStyle(color: textColor, fontSize: 13),
                        items: _nigerianStates.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setState(() => _selectedState = val!),
                        decoration: _inputDecoration('State*', themeProvider),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: Icon(Icons.my_location, size: 16, color: _currentPosition != null ? Colors.green : Colors.white70),
                        label: Text(_currentPosition != null ? 'Captured' : 'Tag GPS', style: const TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                      const SizedBox(height: 4),
                      Text(isEditing ? 'Add more photos or leave empty to keep existing.' : 'First picture is the title.', 
                        style: TextStyle(color: themeProvider.getColor('primary'), fontSize: 11)),
                      const SizedBox(height: 10),
                      _buildImagePicker(themeProvider.getColor('card'), secondaryColor, themeProvider),
                      
                      if (_detectedTags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.withOpacity(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.psychology, size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text('Titan AI Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade800)),
                                  const Spacer(),
                                  if (_isModerated)
                                    Row(
                                      children: [
                                        Icon(Icons.verified_user, size: 14, color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text('Safe Content', style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _detectedTags.map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                  ),
                                  child: Text('#$tag', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                                )).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (isEditing && widget.editItem!.imageUrl.isNotEmpty) ...[
                         const SizedBox(height: 8),
                         Text('Current Title Photo:', style: TextStyle(color: secondaryColor, fontSize: 12)),
                         const SizedBox(height: 4),
                         ClipRRect(
                           borderRadius: BorderRadius.circular(8),
                           child: Image.network(widget.editItem!.imageUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.image)),
                         ),
                      ],
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _videoUrlController,
                        label: 'Video Link',
                        themeProvider: themeProvider,
                      ),
                      if (_selectedCategory == 'Cars') ...[
                        const SizedBox(height: 16),
                        Text('Vehicle Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                        const SizedBox(height: 10),
                        _buildTextField(controller: _brandController, label: 'Brand', themeProvider: themeProvider),
                        const SizedBox(height: 8),
                        _buildTextField(controller: _modelController, label: 'Model', themeProvider: themeProvider),
                        const SizedBox(height: 8),
                        _buildTextField(controller: _yearController, label: 'Year', themeProvider: themeProvider, keyboardType: TextInputType.number),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(controller: _fuelController, label: 'Fuel', themeProvider: themeProvider)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildTextField(controller: _transController, label: 'Transmission', themeProvider: themeProvider)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _priceController,
                        label: 'Price (₦)*',
                        keyboardType: TextInputType.number,
                        themeProvider: themeProvider,
                        inputFormatters: [CurrencyInputFormatter()],
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        maxLines: 3,
                        themeProvider: themeProvider,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _postItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.getColor('primary'),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 1,
                        ),
                        child: Text(isEditing ? 'Update Item' : 'Post Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildImagePicker(Color cardColor, Color secondaryColor, ScreenThemeProvider themeProvider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._selectedImages.asMap().entries.map((entry) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: io.File(entry.value.path).existsSync()
                  ? Image.file(io.File(entry.value.path), width: 80, height: 80, fit: BoxFit.cover)
                  : Container(width: 80, height: 80, color: secondaryColor.withOpacity(0.1), child: Icon(Icons.image, color: secondaryColor)),
              ),
              Positioned(
                right: 0,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedImages.removeAt(entry.key)),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          );
        }),
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: themeProvider.getColor('primary').withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: themeProvider.getColor('primary').withOpacity(0.3)),
            ),
            child: Icon(Icons.add_a_photo_outlined, color: themeProvider.getColor('primary'), size: 24),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, ScreenThemeProvider themeProvider) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: themeProvider.getColor('textSecondary'), fontSize: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: themeProvider.getColor('textSecondary').withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: themeProvider.getColor('primary')),
      ),
      filled: true,
      fillColor: themeProvider.getColor('card'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefixText,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    required ScreenThemeProvider themeProvider,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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
