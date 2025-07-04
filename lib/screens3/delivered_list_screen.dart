import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file

class DeliveredListScreen extends StatefulWidget {
  final String username;
  final int userId;

  DeliveredListScreen({required this.username, required this.userId});

  @override
  _DeliveredListScreenState createState() => _DeliveredListScreenState();
}

class _DeliveredListScreenState extends State<DeliveredListScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDeliveredOrders();
  }

  Future<void> _fetchDeliveredOrders() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}get_delivered_order.php'),
        headers: {"Accept": "application/json"},
        body: {
          'user_id': widget.userId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        setState(() {
          _orders = data['orders'] ?? []; // Handle the case where 'orders' might be null
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delivered Orders for ${widget.username}'),
        backgroundColor: Colors.deepOrange,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? Center(child: Text('No delivered orders found'))
          : ListView.builder(
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];

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
              leading: Icon(Icons.assignment_turned_in, color: Colors.green),
              title: Text('Order #${order['order_id']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order for ${order['user_name']}'),
                  Text('Phone: ${order['phone_number']}'),
                  Text('Total Price: ETB ${order['total_amount']}'),
                  Text('Delivery Fee: ETB ${order['delivery_fee']}'),
                  Text('Location: ${order['location']}'),
                  Text(displayName), // Show either Shop or Restaurant with proper checks
                  Text('Items: ${order['order_type'] == 'shop' ? (order['shop_items'] ?? 'No items available') : (order['food_items'] ?? 'No items available')}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
