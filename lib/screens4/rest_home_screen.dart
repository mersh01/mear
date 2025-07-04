import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'menu_editing_screen.dart';
import 'restaurant_info_change_screen.dart';
import 'dart:async'; // Import for Timer
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file

class RestHomeScreen extends StatefulWidget {
  final String username;
  final String restaurantName;
  final String restaurantDescription;
  final int restaurantId;
  final String type;
  RestHomeScreen({
    required this.username,
    required this.restaurantName,
    required this.restaurantDescription,
    required this.restaurantId,
    required this.type,
  });

  @override
  _RestHomeScreenState createState() => _RestHomeScreenState();
}

class _RestHomeScreenState extends State<RestHomeScreen> {
  List<dynamic> _orders = [];
  String _restaurantStatus = 'unknown'; // Default status
  Timer? _timer; // Timer to update elapsed time
  double _restaurantRating = 0.0; // Default rating
  int _reviewCount = 0; // Default review count

  @override
  void initState() {
    super.initState();
    _fetchOrders();

    // Start the timer to update the elapsed time every second
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        // Triggering setState every second to update the elapsed time
      });
    });
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed to avoid memory leaks
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}get_order.php?type=${widget.type}&id=${widget.restaurantId}',
        ),
      );
      print("API Response: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print("Parsed JSON: $jsonData"); // Debugging

        setState(() {
          _orders = jsonData['orders'] ?? [];
          _restaurantStatus = jsonData['status'] ?? 'unknown';
          _restaurantRating = double.tryParse(jsonData['rating'].toString()) ?? 0.0;
          _reviewCount = jsonData['review_count'] ?? 0; // Store number of reviews
        });
      } else {
        print('Failed to load orders. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  String _formatElapsedTime(String createdAt) {
    final createdTime = DateTime.parse(createdAt);
    final now = DateTime.now();
    final difference = now.difference(createdTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  void _onMenuItemSelected(String value) async {
    if (value == 'change_info') {
      // Navigate to RestaurantInfoChangeScreen and wait for a result (true or false)
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RestaurantInfoChangeScreen(
            restaurantId: widget.restaurantId, // Use actual restaurant ID
            type: widget.type,
          ),
        ),
      );

      // If result is true, refresh the screen
      if (result == true) {
        _fetchOrders(); // Reload the updated restaurant data
      }
    } else if (value == 'edit_menu') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MenuEditingScreen(
              restaurantId: widget.restaurantId,
              type: widget.type,
          ),

        ),
      );
    }
  }

  Color _getStatusColor() {
    if (_restaurantStatus == 'open') {
      return Colors.green;
    } else if (_restaurantStatus == 'closed') {
      return Colors.red;
    }
    return Colors.grey; // Default color for unknown status
  }
  void _showEnterCodeDialog(int orderId) {
    TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Enter Delivery Code"),
          content: TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: "Enter 6-digit code"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                String enteredCode = codeController.text.trim();
                if (enteredCode.isNotEmpty) {
                  _verifyAndUpdateOrder(orderId, enteredCode);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please enter a valid code")),
                  );
                }
              },
              child: Text("Confirm"),
            ),
          ],
        );
      },
    );
  }
  Future<void> _verifyAndUpdateOrder(int orderId, String dwCode) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}verify_order_code.php'),
        headers: {"Accept": "application/json"},
        body: {
          'order_id': orderId.toString(),
          'dw_code': dwCode,
        },
      );

      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order is now on the way!')),
          );
          _fetchOrders(); // Refresh orders list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${result['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error in _verifyAndUpdateOrder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  Widget _buildAppBarTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Text
        AnimatedOpacity(
          opacity: 1.0,
          duration: Duration(milliseconds: 500),
          child: Text(
            'Welcome, ${widget.username}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(height: 4), // Add spacing

        // Status, Rating, and Review Count
        AnimatedContainer(
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          child: Row(
            children: [
              // Status Badge
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _restaurantStatus.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              SizedBox(width: 10), // Spacing
              IconButton(
                icon: Icon(Icons.refresh), // Add refresh icon
                onPressed: () {
                  _fetchOrders(); // Call fetch orders on refresh button press
                },
              ),
              // Rating and Review Count
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 20),
                  SizedBox(width: 4),
                  Text(
                    _restaurantRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '($_reviewCount Reviews)', // Show number of reviews
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuItemSelected,
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'change_info',
                  child: Text('Change Info'),
                ),
                PopupMenuItem<String>(
                  value: 'edit_menu',
                  child: Text('Edit Menu'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              color: Colors.blueAccent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.type}  Name: ${widget.restaurantName}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '${widget.restaurantDescription}',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Orders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final order = _orders[index];

                  int orderId = int.parse(order['order_id'].toString());
                  String userName = order['user_name'] ?? 'Unknown'; // Handle null case
                  String phone = order['phone'] ?? 'Unknown';
                  String status = order['order_status'] ?? 'Unknown';
                  double itemTotalPrice = double.parse(order['item_total_price'].toString());
                  double totalPrice = double.parse(order['total_price'].toString());
                  double deliveryFee = double.parse(order['delivery_fee'].toString());
                  String deliveryWorker = order['delivery_worker'] ?? "Not Assigned";
                  String payment = order['payment_status'] ?? "Unknown";
                  String dw_phone = order['dw_phone']?? "Unknown";
                  List items = order['items'] ?? []; // Ensure items is a list, default to empty

                  return GestureDetector(
                      onTap: () {
                          _showEnterCodeDialog(orderId); // Ask for dw_code if status is "taken"
                      },
                  child: Card(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order #$orderId', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Customer: $userName', style: TextStyle(fontSize: 16)),
                          Text('phone: $phone', style: TextStyle(fontSize: 16)),
                          Text('Ordered: ${_formatElapsedTime(order['created_at'])}', style: TextStyle(fontSize: 16)),
                          Text('status: $status', style: TextStyle(fontSize: 16)),
                          Text('payment: $payment', style: TextStyle(fontSize: 16)),
                          Text('Delivery Worker: $deliveryWorker($dw_phone)', style: TextStyle(fontSize: 16)),
                          Text('Item Total Price: ETB ${itemTotalPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 16)),
                          Text('Delivery Fee: ETB ${deliveryFee.toStringAsFixed(2)}', style: TextStyle(fontSize: 16)),
                          Text('Total Price: ETB ${totalPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 16)),
                          SizedBox(height: 10),
                          Text('Items:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          if (items.isEmpty)
                            Text('No items ordered', style: TextStyle(fontSize: 16))
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: items.map<Widget>((item) {
                                String foodItem='null';
                                if (widget.type == 'restaurant') {
                                  foodItem = item['food_item'] ?? 'Unknown Item';

                                } else if (widget.type == 'shop') {
                                  foodItem = item['shop_item'] ?? 'Unknown Item';
                                }
                                // Handle null case
                                String quantityString = item['quantity'].toString() ?? '0'; // Handle null case
                                int quantity = int.tryParse(quantityString) ?? 0;
                                return Text('- $foodItem x $quantity', style: TextStyle(fontSize: 16));
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  );
                },
              ),
            ),

          ],
        ),
      ),
    );
  }
}
