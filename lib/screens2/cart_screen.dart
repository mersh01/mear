import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'checkout_screen.dart';
import 'package:dw_app/constants/api_constants.dart'; // Import API constants

class CartScreen extends StatefulWidget {
  final int userId;

  CartScreen({required this.userId});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, List<Map<String, dynamic>>> restaurantItems = {};
  Map<String, List<Map<String, dynamic>>> shopItems = {};
  double totalPrice = 0.0;
  bool isLoading = true;
  bool hasUnavailableItems = false;

  @override
  void initState() {
    super.initState();
    fetchCartItems();
  }

  fetchCartItems() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}get_cart.php?user_id=${widget.userId}'),
      );

      print("API Response Status: ${response.statusCode}");
      print("Raw API Response: ${response.body}");

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);

        print("Parsed JSON Data: $jsonData");

        if (jsonData['success']) {
          setState(() {
            restaurantItems = {};
            shopItems = {};
            totalPrice = 0.0;
            hasUnavailableItems = false;

            List<dynamic> items = jsonData['items'];
            print("Cart Items: $items");

            for (var item in items) {
              print("Processing Item: $item");

              bool isRestaurant = item.containsKey('restaurant_name');
              String name = isRestaurant ? item['restaurant_name'] : item['shop_name'];
              bool isBlocked = item[isRestaurant ? 'restaurant_status' : 'shop_status'] == "Blocked";
              bool isClosed = item[isRestaurant ? 'restaurant_status' : 'shop_status'] == "Closed";
              bool isUnavailable = item['item_availability'] == "Unavailable";

              String statusText = "";
              if (isBlocked) statusText = " (Blocked)";
              if (isClosed) statusText = " (Closed)";

              String itemStatusText = isUnavailable ? " (Not Available)" : "";

              if (isRestaurant) {
                restaurantItems.putIfAbsent(name + statusText, () => []).add({
                  'menu_item_id': item['menu_item_id'],
                  'quantity': item['quantity'],
                  'price': double.tryParse(item['price'].toString()) ?? 0.0,
                  'name': item['name'] + itemStatusText,
                  'isBlockedOrClosed': isBlocked || isClosed,
                  'isUnavailable': isUnavailable,
                });
              } else {
                shopItems.putIfAbsent(name + statusText, () => []).add({
                  'item_id': item['item_id'],
                  'quantity': item['quantity'],
                  'price': double.tryParse(item['price'].toString()) ?? 0.0,
                  'name': item['name'] + itemStatusText,
                  'isBlockedOrClosed': isBlocked || isClosed,
                  'isUnavailable': isUnavailable,
                });
              }

              if (isUnavailable || isBlocked || isClosed) {
                hasUnavailableItems = true;
              }

              if (!isUnavailable && !isBlocked && !isClosed) {
                totalPrice += (double.tryParse(item['price'].toString()) ?? 0.0) * item['quantity'];
              }
            }

            print("Processed Restaurant Items: $restaurantItems");
            print("Processed Shop Items: $shopItems");
            print("Total Price: $totalPrice");
          });
        } else {
          Fluttertoast.showToast(msg: "No items found in cart.", backgroundColor: Colors.grey);
        }
      } else {
        Fluttertoast.showToast(msg: "Failed to load cart items.", backgroundColor: Colors.red);
      }
    } catch (e) {
      print("Error Fetching Cart: $e");
      Fluttertoast.showToast(msg: "Error: $e", backgroundColor: Colors.red);
    }

    setState(() {
      isLoading = false;
    });
  }


  void removeItem(String restaurantName, int menuItemId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}remove_item.php'),
        body: {
          'user_id': widget.userId.toString(),
          'menu_item_id': menuItemId.toString(),
        },
      );

      // Log the raw response body
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        if (jsonResponse['success']) {
          Fluttertoast.showToast(
            msg: "Item removed from cart and carts.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          fetchCartItems(); // Refresh the cart items
        } else {
          Fluttertoast.showToast(
            msg: jsonResponse['message'], // Show error message from server
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: "Failed to remove item.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }

    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Cart'),
        backgroundColor: Colors.deepOrange,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : restaurantItems.isEmpty && shopItems.isEmpty
          ? Center(child: Text('Your cart is empty', style: TextStyle(fontSize: 20, color: Colors.grey)))
          : ListView(
        children: [
          if (restaurantItems.isNotEmpty) ...[
            _buildSectionTitle('Restaurants'),
            ...restaurantItems.entries.map((entry) => _buildItemCard(entry.key, entry.value, true)),
          ],
          if (shopItems.isNotEmpty) ...[
            _buildSectionTitle('Shops'),
            ...shopItems.entries.map((entry) => _buildItemCard(entry.key, entry.value, false)),
          ],
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildItemCard(String name, List<Map<String, dynamic>> items, bool isRestaurant) {
    return Card(
      margin: EdgeInsets.all(16.0),
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
            ...items.map((item) => ListTile(
              title: Text(item['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Text('ETB ${item['price'].toStringAsFixed(2)}', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('x${item['quantity']}', style: TextStyle(fontSize: 16, color: Colors.black54)),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      removeItem(name, item[isRestaurant ? 'menu_item_id' : 'item_id']);                    },
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Price:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'ETB ${totalPrice.toStringAsFixed(2)}', // Formats price to 2 decimal places
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          SizedBox(height: 16.0),
          ElevatedButton(
            onPressed: hasUnavailableItems
                ? () {
              Fluttertoast.showToast(
                msg: "Remove unavailable items and closed/blocked restaurants or shops.",
                backgroundColor: Colors.red,
              );
            }
                : () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => CheckoutScreen(
                    totalPrice: totalPrice,
                    userId: widget.userId,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 14.0),
              backgroundColor: Colors.deepOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payment),
                SizedBox(width: 10),
                Text(
                  'Proceed to Checkout',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
