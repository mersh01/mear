import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file

class MenuEditingScreen extends StatefulWidget {
  final int restaurantId;
  final String type; // "shop" or "restaurant"

  final List<Map<String, dynamic>> categories = [
    {'id': 1, 'name': 'Clothes'},
    {'id': 2, 'name': 'Shoes'},
    {'id': 3, 'name': 'Electronics'},
    {'id': 4, 'name': 'Others'},
  ];

  MenuEditingScreen({
    required this.restaurantId,
    required this.type,
  });

  @override
  _MenuEditingScreenState createState() => _MenuEditingScreenState();
}

class _MenuEditingScreenState extends State<MenuEditingScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _menuItems = [];
  final ImagePicker _picker = ImagePicker();
  List<dynamic> _selectedImages = []; // List to hold selected images (File or String)
  List<String> _removedImages = []; // List to track removed image paths
  @override
  void initState() {
    super.initState();
    _fetchMenuItems();
  }

  Future<void> _toggleAvailability(int id, int currentAvailability) async {
    try {
      final String endpoint = widget.type == 'shop'
          ? 'toggle_shop_item_availability.php' // Toggle in 'items' table
          : 'toggle_menu_item_availability.php'; // Toggle in 'menu_items' table

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        body: {
          'id': id.toString(),
          'availability': currentAvailability == 1 ? '0' : '1',
        },
      );

      if (response.statusCode == 200) {
        _fetchMenuItems(); // Refresh the list of menu items
      } else {
        throw Exception('Failed to toggle availability');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling availability: $e')),
      );
    }
  }

  Future<void> _fetchMenuItems() async {
    if (!mounted) return; // Prevent execution if widget is already disposed

    try {
      final String endpoint = widget.type == 'shop'
          ? 'get_shop_item.php' // Fetch from 'items' table
          : 'get_menu_item.php'; // Fetch from 'menu_items' table

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}$endpoint?restaurant_id=${widget.restaurantId}'),
      );

      if (!mounted) return; // Check again after API response

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          _menuItems = data.map((item) {
            final Map<String, dynamic> menuItem = item as Map<String, dynamic>;

            // Ensure price is parsed correctly
            menuItem['price'] = double.tryParse(menuItem['price'].toString()) ?? 0.0;

            // 🔥 Handle image paths (Cloudinary & Local Server)
            if (menuItem['image_paths'] != null) {
              menuItem['image_paths'] = List<String>.from(menuItem['image_paths'].map((path) {
                if (path.startsWith('http')) {
                  return path; // Cloudinary URL (already complete)
                } else if (path.isNotEmpty) {
                  return '${ApiConstants.baseUrl}uploads/$path'; // Local server image
                } else {
                  return ''; // Handle empty case
                }
              }));
            } else {
              menuItem['image_paths'] = []; // Default to empty list if no images
            }

            // Ensure availability is parsed correctly
            menuItem['availability'] = int.tryParse(menuItem['availability'].toString()) ?? 1;

            return menuItem;
          }).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load menu items: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return; // Prevent setState() on disposed widget

      print('Error fetching menu items: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading menu items: $e')),
      );
    }
  }


  Future<void> _pickImages() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((file) => File(file.path)).toList());
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      const cloudName = "doqcck2lj"; // Replace with your Cloudinary Cloud Name
      const uploadPreset = "b5k12sct"; // Replace with your Upload Preset

      final url = "https://api.cloudinary.com/v1_1/$cloudName/image/upload";

      final request = http.MultipartRequest("POST", Uri.parse(url))
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await request.send();
      final responseString = await response.stream.bytesToString();

      print('Upload Response: $responseString'); // Debugging line

      final jsonResponse = jsonDecode(responseString);

      if (jsonResponse.containsKey('secure_url')) {
        print('Image Uploaded: ${jsonResponse['secure_url']}'); // Debugging line
        return jsonResponse['secure_url']; // Return the direct URL of the uploaded image
      } else {
        print('Upload Failed: ${jsonResponse['error']['message']}');
        return null;
      }
    } catch (e) {
      print('Image upload error: $e');
      return null;
    }
  }



  Future<void> _saveMenuItem(int id, String name, String description, double price, int? categoryId) async {
    try {
      List<String> imagePaths = [];

      // Upload all selected images
      for (var image in _selectedImages) {
        if (image is File) {
          // Upload new image and get the path
          final imagePath = await _uploadImage(image);
          if (imagePath != null) {
            imagePaths.add(imagePath); // Add the uploaded image path (String)
          }
        } else if (image is String) {
          // If the image is already a URL, keep it
          imagePaths.add(image); // Add the existing image path (String)
        }
      }

      // Log image paths for debugging
      print('Image paths to save: $imagePaths');
      print('Images to remove: $_removedImages');

      final String endpoint = id == 0
          ? (widget.type == 'shop' ? 'add_shop_item.php' : 'add_menu_item.php')
          : (widget.type == 'shop' ? 'update_shop_item.php' : 'update_menu_item.php');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      );

      request.fields['id'] = id.toString();
      request.fields['restaurant_id'] = widget.restaurantId.toString();
      request.fields['name'] = name;
      request.fields['description'] = description;
      request.fields['price'] = price.toString();
      if (widget.type == 'shop') {
        request.fields['category_id'] = categoryId.toString();
      }
      request.fields['image_paths'] = jsonEncode(imagePaths); // Send image paths as JSON
      request.fields['removed_images'] = jsonEncode(_removedImages); // Send removed image paths as JSON

      // Log the request payload
      print('Request payload: ${request.fields}');

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseString = await response.stream.bytesToString();
        print('Server response: $responseString');
        _fetchMenuItems(); // Refresh the list of menu items
        setState(() {
          _selectedImages.clear(); // Clear the selected images after saving
          _removedImages.clear(); // Clear the removed images after saving
        });
      } else {
        throw Exception('Failed to save menu item');
      }
    } catch (e) {
      print("Error saving menu item: $e");
    }
  }

  Future<void> _deleteMenuItem(int id) async {
    try {
      final String endpoint = widget.type == 'shop'
          ? 'delete_shop_item.php'
          : 'delete_menu_item.php';

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        body: {
          'id': id.toString(),
        },
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Menu item deleted successfully')),
        );
        _fetchMenuItems();
      } else {
        // Show error message from PHP
        String errorMessage = responseData['error'] ?? 'Failed to delete menu item';
        throw Exception(errorMessage);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('you cannot delete the item make it unavailable if you need by press the red x button')),
      );
    }
  }

  void _openMenuItemForm({
    int id = 0,
    String name = '',
    String description = '',
    double price = 0.0,
    int? categoryId,
    List<String>? existingImagePaths,
  }) {
    setState(() {
      _selectedImages = []; // Reset selected images
      _removedImages = []; // Reset removed images
    });

    showDialog(
      context: context,
      builder: (context) {
        final _formKey = GlobalKey<FormState>();
        String _name = name;
        String _description = description;
        double _price = price;
        int? _selectedCategoryId = categoryId;
        List<String> _currentImages = List.from(existingImagePaths ?? []);

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          initialValue: _name,
                          decoration: InputDecoration(labelText: 'Name'),
                          validator: (value) => value!.isEmpty ? 'Name is required' : null,
                          onSaved: (value) => _name = value!,
                        ),
                        TextFormField(
                          initialValue: _description,
                          decoration: InputDecoration(labelText: 'Description'),
                          onSaved: (value) => _description = value!,
                        ),
                        TextFormField(
                          initialValue: _price > 0 ? _price.toString() : '',
                          decoration: InputDecoration(labelText: 'Price'),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Price is required';
                            if (double.tryParse(value) == null) return 'Enter a valid price';
                            return null;
                          },
                          onSaved: (value) => _price = double.tryParse(value!) ?? 0.0,
                        ),
                        if (widget.type == 'shop')
                          DropdownButtonFormField<int>(
                            value: _selectedCategoryId,
                            decoration: InputDecoration(labelText: 'Category'),
                            items: widget.categories.map((category) {
                              return DropdownMenuItem<int>(
                                value: category['id'],
                                child: Text(category['name']),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() {
                              _selectedCategoryId = value;
                            }),
                          ),
                        TextButton(
                          onPressed: () async {
                            final List<XFile>? pickedFiles = await _picker.pickMultiImage();
                            if (pickedFiles != null) {
                              setState(() {
                                _selectedImages.addAll(pickedFiles.map((file) => File(file.path)).toList());
                              });
                            }
                          },
                          child: Text('Select Images'),
                        ),

                        // Existing Images Section
                        if (_currentImages.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Existing Images',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 4.0,
                                  mainAxisSpacing: 4.0,
                                ),
                                itemCount: _currentImages.length,
                                itemBuilder: (context, index) {
                                  final image = _currentImages[index];
                                  return Stack(
                                    children: [
                                      Image.network(
                                        image,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey,
                                            child: Center(
                                              child: Icon(Icons.error, color: Colors.red),
                                            ),
                                          );
                                        },
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: IconButton(
                                          icon: Icon(Icons.close, color: Colors.red),
                                          onPressed: () {
                                            setState(() {
                                              _removedImages.add(image); // Mark for deletion
                                              _currentImages.removeAt(index); // Remove from UI
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              Divider(),
                            ],
                          ),

                        // Newly Selected Images Section
                        if (_selectedImages.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Images',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 4.0,
                                  mainAxisSpacing: 4.0,
                                ),
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, index) {
                                  final image = _selectedImages[index];
                                  return Stack(
                                    children: [
                                      Image.file(image, fit: BoxFit.cover),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: IconButton(
                                          icon: Icon(Icons.close, color: Colors.red),
                                          onPressed: () {
                                            setState(() {
                                              _selectedImages.removeAt(index);
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedImages.clear();
                                });
                                Navigator.pop(context);
                              },
                              child: Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _formKey.currentState!.save();
                                  Navigator.pop(context);
                                  _saveMenuItem(id, _name, _description, _price, _selectedCategoryId);
                                  _fetchMenuItems();
                                }
                              },
                              child: Text(id == 0 ? 'Add Item' : 'Save Changes'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Menu for ${widget.type == 'shop' ? 'Shop' : 'Restaurant'}'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _openMenuItemForm(
              categoryId: widget.type == 'shop' ? widget.categories.first['id'] : null,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
               return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: item['availability'] == 1 ? Colors.red[100] : null, // Change color if item is not available
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display images in a PageView
                        if (item['image_paths'] != null && item['image_paths'].isNotEmpty)
                          SizedBox(
                            height: 150, // Increased image size
                            child: PageView.builder(
                              itemCount: item['image_paths'].length,
                              itemBuilder: (context, imgIndex) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    item['image_paths'][imgIndex],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: Icon(Icons.error, color: Colors.red),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(Icons.image, color: Colors.white),
                            ),
                          ),
                        SizedBox(height: 12), // Space between image and text
                        // Display name, description, and price
                        Text(
                          item['name'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          item['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ETB ${(item['price'] as double).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _openMenuItemForm(
                            id: item['id'],
                            name: item['name'],
                            description: item['description'],
                            price: item['price'],
                            categoryId: item['category_id'],
                            existingImagePaths: item['image_paths'] != null
                                ? List<String>.from(item['image_paths'])
                                : null,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deleteMenuItem(item['id']);
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            item['availability'] == 1 ? Icons.check_circle : Icons.cancel,
                            color: item['availability'] == 1 ? Colors.green : Colors.red,
                          ),
                          onPressed: () {
                            _toggleAvailability(item['id'], item['availability']);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}