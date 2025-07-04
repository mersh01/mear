import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:photo_view/photo_view.dart';
import 'cart_screen.dart';
import 'package:carousel_slider/carousel_slider.dart'; // Add this package for carousel
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file

class ShopItemsScreen extends StatelessWidget {
  final int shopId;
  final int userId;

  ShopItemsScreen({
    required this.shopId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shop Items'),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CartScreen(
                    userId: userId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.lightBlueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<List<dynamic>>(
          future: fetchItems(shopId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error fetching items'));
            }

            final items = snapshot.data;

            if (items == null || items.isEmpty) {
              return Center(child: Text('No items available in this shop.'));
            }

            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, // Ensure full width

                    children: [
                      // Image Carousel
                      if (item['images'] != null && item['images'].isNotEmpty)
                        CarouselSlider(
                          options: CarouselOptions(
                            height: 200.0,
                            autoPlay: true,
                            enlargeCenterPage: true,
                            aspectRatio: 16 / 9,
                            viewportFraction: 0.8,
                          ),
                          items: item['images'].map<Widget>((imageUrl) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ImageViewerScreen(
                                      imageUrls: List<String>.from(item['images']),
                                    ),
                                  ),
                                );
                              },
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey,
                                    child: Icon(Icons.broken_image, color: Colors.white),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      // Item Details
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              item['description'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Price: ETB ${item['price']}',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),

                            ),

                          ],
                        ),
                      ),
                      // Add to Cart Button
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: ElevatedButton(
                          onPressed: () {
                            _showQuantityDialog(context, userId, item['id']);
                          },
                          child: Text('Add to Cart'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Show the dialog to input the quantity
  void _showQuantityDialog(BuildContext context, int userId, int itemId) {
    TextEditingController quantityController = TextEditingController(text: "1");
    bool isAddingToCart = false; // Track loading state

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Enter Quantity'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: "Enter quantity"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isAddingToCart ? null : () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isAddingToCart
                      ? null
                      : () async {
                    if (quantityController.text.isNotEmpty &&
                        int.tryParse(quantityController.text) != null) {
                      int quantity = int.parse(quantityController.text);
                      if (quantity > 0) {
                        setState(() => isAddingToCart = true); // Start loading

                        await addToCart(userId, itemId, quantity); // Wait for the cart update

                        setState(() => isAddingToCart = false); // Stop loading

                        Navigator.of(context).pop(); // Close the dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added to Cart')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Quantity must be greater than zero')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter a valid quantity')),
                      );
                    }
                  },
                  child: isAddingToCart
                      ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Text('Add to Cart'),
                ),

              ],
            );
          },
        );
      },
    );
  }


  Future<void> addToCart(int userId, int itemId, int quantity) async {
    try {
      print('UserId: $userId, ItemId: $itemId, Quantity: $quantity');

      // Prepare the data to be sent as JSON
      final Map<String, dynamic> requestBody = {
        'user_id': userId,
        'item_id': itemId,
        'quantity': quantity,
      };

      // Send the request with the proper headers and body
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}shop_add_to_cart.php'),
        headers: {
          'Content-Type': 'application/json', // Specify that it's JSON
        },
        body: json.encode(requestBody), // Encode the request body as JSON
      );

      print('Response: ${response.body}'); // Print the response for debugging

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['status'] == 'success') {
          print('Item added to cart successfully');
        } else {
          print('Failed to add item to cart: ${responseBody['message']}');
        }
      } else {
        print('Failed to connect to the server');
      }
    } catch (e) {
      print('Error adding item to cart: $e');
    }
  }

  Future<List<dynamic>> fetchItems(int shopId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}get_items_by_shop.php'),
        headers: {'Content-Type': 'application/json'},  // Set the Content-Type to application/json
        body: json.encode({'shopId': shopId}),  // Send data as JSON
      );

      if (response.statusCode == 200) {
        print(response.body);

        // Parse the response body into a map
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Check if 'success' is true and the 'items' field exists
        if (responseData['success'] == true) {
          // If no items found, return an empty list
          if (responseData['items'] == null || responseData['items'].isEmpty) {
            return []; // No items available for this shop
          }

          List<dynamic> items = responseData['items'];

          return items;
        } else {
          // Handle when success is false or message is available
          print(responseData['message']);
          return []; // Return an empty list or you can handle it further
        }
      } else {
        print('Failed to fetch items');
        return [];
      }
    } catch (e) {
      print('Error: $e');
      return [];
    }
  }
}

// Define ImageViewerScreen at the top level
class ImageViewerScreen extends StatelessWidget {
  final List<String> imageUrls;

  ImageViewerScreen({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image View'),
      ),
      body: PageView.builder(
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return PhotoView(
            imageProvider: NetworkImage(imageUrls[index]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          );
        },
      ),
    );
  }
}