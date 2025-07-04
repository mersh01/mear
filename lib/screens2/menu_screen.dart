import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:dw_app/constants/api_constants.dart';
import 'cart_screen.dart';

class MenuScreen extends StatefulWidget {
  final int restaurantId;
  final int userId;

  MenuScreen({
    required this.restaurantId,
    required this.userId,
  });

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List menuItems = [];
  Timer? _timer;
  bool isAddingToCart = false; // State for loading

  @override
  void initState() {
    super.initState();
    fetchMenu();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(Duration(seconds: 30), (Timer timer) {
      fetchMenu();
    });
  }

  Future<void> fetchMenu() async {
    final response = await http.get(Uri.parse(
        '${ApiConstants.baseUrl}get_menu.php?restaurant_id=${widget.restaurantId}'));

    if (response.statusCode == 200) {
      setState(() {
        List<dynamic> jsonData = json.decode(response.body);

        // Log the response for debugging
        print('Fetched menu items: $jsonData');
        menuItems = jsonData.map((item) {
          print('Item: $item');
          print('Images: ${item['images']}');  // Log the images
          return {
            'id': int.tryParse(item['id'].toString()) ?? 0,
            'name': item['name'],
            'description': item['description'],
            'price': double.tryParse(item['price'].toString()) ?? 0.0,
            'images': (item['images'] as List<dynamic>?)?.cast<String>() ?? [],
          };
        }).toList();

      });
    } else {
      throw Exception('Failed to load menu');
    }
  }


  Future<void> addToCart(int menuItemId, int quantity) async {
    setState(() {
      isAddingToCart = true; // Show loading indicator
    });

    final cartItem = {
      'user_id': widget.userId,
      'menu_item_id': menuItemId,
      'quantity': quantity,
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}add_to_cart.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(cartItem),
      );

      final responseData = json.decode(response.body);
      if (responseData['status'] == 'success') {
        Fluttertoast.showToast(
          msg: responseData['message'] ?? "Item added to cart!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        Fluttertoast.showToast(
          msg: responseData['message'] ?? "Failed to add item to cart.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "An error occurred.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } finally {
      setState(() {
        isAddingToCart = false; // Hide loading indicator
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu'),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CartScreen(
                    userId: widget.userId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.lightBlueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  child: MenuItemWidget(
                    itemName: menuItems[index]['name'],
                    itemDescription: menuItems[index]['description'],
                    itemPrice: menuItems[index]['price'],
                    itemId: menuItems[index]['id'],
                    images: menuItems[index]['images'],
                    onAddToCart: (quantity) async {
                      await addToCart(menuItems[index]['id'], quantity);
                    },
                  ),
                );
              },
            ),
          ),
          if (isAddingToCart)
            Center(
              child: CircularProgressIndicator(), // Show loading indicator
            ),
        ],
      ),
    );
  }
}

class MenuItemWidget extends StatelessWidget {
  final String itemName;
  final String itemDescription;
  final double itemPrice;
  final int itemId;
  final List<String> images;
  final Future<void> Function(int quantity) onAddToCart;

  MenuItemWidget({
    required this.itemName,
    required this.itemDescription,
    required this.itemPrice,
    required this.itemId,
    required this.images,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      color: Colors.grey.shade300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // Ensure full width
        children: [
          if (images.isNotEmpty)
            CarouselSlider(
              options: CarouselOptions(
                height: 150,
                autoPlay: true,
                enlargeCenterPage: true,
                aspectRatio: 16 / 9,
                viewportFraction: 0.8,
              ),
              items: images.map((imageUrl) {
                final fixedImageUrl = imageUrl; // Keep the original Cloudinary URL


                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
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
            )
          else
            Container(
              color: Colors.grey,
              width: double.infinity,
              height: 150,
              child: Icon(Icons.image, color: Colors.white),
            ),
          SizedBox(height: 10),
          Text(
            itemName,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(itemDescription,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),),
          SizedBox(height: 5),
          Text(
            'price: ETB ${itemPrice.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              _showQuantityDialog(context);
            },
            child: Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(BuildContext context) {
    int tempQuantity = 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Select Quantity'),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              tempQuantity = int.tryParse(value) ?? 1;
            },
            controller: TextEditingController(text: '1'),
          ),
          actions: [

            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (tempQuantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select a valid quantity')),
                  );
                  return; // Stop execution if quantity is not valid
                }

                Navigator.of(context).pop();
                await onAddToCart(tempQuantity);
              },
              child: Text('Add to Cart'),
            )

          ],
        );
      },
    );
  }
}
