import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file
import 'cart_screen.dart';

class OrderScreen extends StatefulWidget {
  final int userId;

  OrderScreen({required this.userId});

  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  late Future<List<dynamic>> userOrders;
  Timer? _timer;
  DateTime _lastFetch = DateTime.now();
  List<dynamic>? orders;

  @override
  void initState() {
    super.initState();
    userOrders = fetchUserOrders(widget.userId);
    _startAutoRefresh();
  }
  Future<List<dynamic>> fetchUserOrders(int userId) async {
    try {
      // Change POST to GET, and send data in the URL query parameters
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}get_order_items.php?user_id=$userId&last_fetch=${_lastFetch.toIso8601String()}'),
      );

      if (response.statusCode == 200) {
        print('Response body: ${response.body}'); // Add this line for debugging
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success']) {
          _lastFetch = DateTime.now();
          return data['orders'];
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }




  void _startAutoRefresh() {
    _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  String calculateTimeGap(String createdAt) {
    DateTime orderTime = DateTime.parse(createdAt).toUtc();  // Ensure it's UTC
    DateTime now = DateTime.now().toUtc();  // Compare in UTC
    Duration difference = now.difference(orderTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s) ago';
    } else {
      return '${difference.inSeconds} second(s) ago';
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
        title: Text('Your Orders'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.pushReplacement(
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
      body: FutureBuilder<List<dynamic>>(
        future: userOrders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('You have not ordered yet.'));
          } else {
            orders = snapshot.data!;
            return ListView.builder(
              itemCount: orders!.length,
              itemBuilder: (context, index) {
                final order = orders![index];
                final totalPrice = (order['total_price'] is String)
                    ? double.tryParse(order['total_price']) ?? 0.0
                    : order['total_price'].toDouble();

                final deliveryFee = (order['delivery_fee'] is String)
                    ? double.tryParse(order['delivery_fee']) ?? 0.0
                    : order['delivery_fee'].toDouble();

                final timeGap = calculateTimeGap(order['created_at']);
                final storeName = order['store_name'];
                final orderType = order['order_type'] == 'restaurant'
                    ? 'Restaurant'
                    : 'Shop';

                return Card(
                  margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confirmation Code: ${order['confirmation_code'] ?? 'N/A'}',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '$orderType: $storeName',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Time Ago: $timeGap',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Total Price: ETB ${totalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Delivery Fee: ETB ${deliveryFee.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Order Items:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        ...order['items'].map<Widget>((item) {
                          final itemPrice = (item['price'] is String)
                              ? double.tryParse(item['price']) ?? 0.0
                              : item['price'].toDouble();

                          return ListTile(
                            title: Text(item['name']),
                            subtitle: Text('Quantity: ${item['quantity']}'),
                            trailing: Text('ETB ${itemPrice.toStringAsFixed(2)}'),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
