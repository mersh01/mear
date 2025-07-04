import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async'; // Import for Timer
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file
import 'delivered_list_screen.dart';

class TakenOrder extends StatefulWidget {
  final String username;
  final int userId;

  TakenOrder({required this.username, required this.userId});

  @override
  _TakenOrderState createState() => _TakenOrderState();
}

class _TakenOrderState extends State<TakenOrder> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  Timer? _timer; // Timer for updating elapsed time
  Map<int, String> _orderAddresses = {};

  @override
  void initState() {
    super.initState();
    _fetchTakenOrders();

    // Start the timer to update the elapsed time every second
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        // Trigger a rebuild to update the elapsed time display
      });
    });
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed to avoid memory leaks
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTakenOrders() async {
    try {
      print('Fetching taken orders for user_id: ${widget.userId}'); // Log request

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}get_taken_order.php'),
        headers: {"Accept": "application/json"},
        body: {
          'user_id': widget.userId.toString(),
        },
      );

      print('Response Status Code: ${response.statusCode}'); // Log status code
      print('Response Body: ${response.body}'); // Log raw response

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data.containsKey('orders')) {
          setState(() {
            _orders = data['orders'];
            _isLoading = false;
          });
          print('Fetched orders: $_orders'); // Log successful orders list
        } else {
          print('Error: "orders" key not found in response');
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: "orders" key missing in response')),
          );
        }
      } else {
        print('Server Error: ${response.statusCode}'); // Log server error
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Exception: $e'); // Log caught exceptions
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }


  Future<void> _showConfirmationDialog(int orderId) async {
    String confirmationCode = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Delivery'),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'Enter confirmation code'),
            onChanged: (value) {
              confirmationCode = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _updateOrderStatus(orderId, 'Delivered', confirmationCode);
              },
              child: Text('Confirm'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }


  Future<void> _updateOrderStatus(int orderId, String status, String confirmationCode) async {
  try {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}update_order_to_delivered.php'),
      headers: {"Accept": "application/json"},
      body: {
        'order_id': orderId.toString(),
        'status': status,
        'confirmation_code': confirmationCode,
      },
    );

    if (response.statusCode == 200) {
      final result = json.decode(utf8.decode(response.bodyBytes));
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to $status')),
        );
        _fetchTakenOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order: ${result['message']}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server error: ${response.statusCode}')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred: $e')),
    );
  }
}
  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['display_name'] != null) {
          return data['display_name']; // Returns the full address
        }
      }
    } catch (e) {
      print("Error fetching address: $e");
    }
    return "Address not found"; // Fallback message
  }
  Future<void> _openMap(String location) async {
    final Uri mapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}');
    print('Attempting to open map: $mapUri');
    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open map')));
    }
  }


  String _formatElapsedTime(String createdAt) {
    final createdTime = DateTime.parse(createdAt);
    final now = DateTime.now();
    final difference = now.difference(createdTime);

    if (difference.inDays > 0) return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    if (difference.inHours > 0) return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes} min${difference.inMinutes == 1 ? '' : 's'} ago';
    return 'Just now';
  }


@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Taken Orders for ${widget.username}'),
      backgroundColor: Colors.deepOrange,
      actions: [
        IconButton(
          icon: Icon(Icons.archive),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeliveredListScreen(
                  username: widget.username,
                  userId: widget.userId,
                ),
              ),
            );
          },
        ),
      ],
    ),
    body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : _orders.isEmpty
        ? Center(child: Text('No taken orders found'))
        : ListView.builder(
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final orderId = int.tryParse(order['order_id']) ?? 0;

        // Extract latitude and longitude
        List<String> locationParts = order['location'].split(',');
        double? lat = locationParts.length == 2 ? double.tryParse(locationParts[0]) : null;
        double? lng = locationParts.length == 2 ? double.tryParse(locationParts[1]) : null;

        if (lat != null && lng != null && !_orderAddresses.containsKey(orderId)) {
          _getAddressFromCoordinates(lat, lng).then((address) {
            setState(() {
              _orderAddresses[orderId] = address;
            });
          });
        }
        // Use the order type from the response to determine which name to show
        String displayName;
        if (order['order_type'] == 'shop') {
          displayName = 'Shop: ${order['shop_name'] ?? 'N/A'}'; // Default to 'N/A' if shop_name is null
        } else if (order['order_type'] == 'restaurant') {
          displayName = 'Restaurant: ${order['restaurant_name'] ?? 'N/A'}'; // Default to 'N/A' if restaurant_name is null
        } else {
          displayName = 'Unknown order type';
        }

        return Card(
          margin: EdgeInsets.all(8.0),
          child: ListTile(
            contentPadding: EdgeInsets.all(16.0),
            leading: Icon(Icons.assignment_turned_in, color: Colors.blue),
            title: Text('Order #${order['order_id']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order for ${order['user_name']}'),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Ordered: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: _formatElapsedTime(order['created_at'])),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Phone: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: order['phone_number']),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Total Price: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: 'ETB ${order['total_amount']}'),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Delivery Fee: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: 'ETB ${order['delivery_fee']}'),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Payment method: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: '${order['payment_method']}'),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Location: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: _orderAddresses[orderId] ?? "Fetching address..."),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Order From: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: displayName),
                          ],
                        ),
                      ),
                    ),
                    if (order['order_type'] == 'restaurant' && order['restaurant_latitude'] != null && order['restaurant_longitude'] != null)
                      IconButton(
                        icon: Icon(Icons.map, color: Colors.blue),
                        onPressed: () {
                          _openMap('${order['restaurant_latitude']},${order['restaurant_longitude']}');
                        },
                      ),
                    if (order['order_type'] == 'shop' && order['shop_latitude'] != null && order['shop_longitude'] != null)
                      IconButton(
                        icon: Icon(Icons.map, color: Colors.green),
                        onPressed: () {
                          _openMap('${order['shop_latitude']},${order['shop_longitude']}');
                        },
                      ),
                  ],
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Items: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: order['order_type'] == 'shop'
                          ? (order['shop_items'] ?? 'No items available')
                          : (order['food_items'] ?? 'No items available')),
                    ],
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.location_on, color: Colors.red),
              onPressed: () {
                _openMap(order['location']);
              },
            ),
            onTap: () {
              if (orderId > 0) {
                _showConfirmationDialog(orderId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid order ID')),
                );
              }
            },
          ),
        );
      },
    ),
  );
}
}
