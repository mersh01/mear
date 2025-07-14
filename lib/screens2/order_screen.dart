import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:dw_app/constants/api_constants.dart';
import 'cart_screen.dart';

class OrderScreen extends StatefulWidget {
  final int userId;

  const OrderScreen({required this.userId, Key? key}) : super(key: key);

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
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}get_order_items.php?user_id=$userId&last_fetch=${_lastFetch.toIso8601String()}'),
      );

      if (response.statusCode == 200) {
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
    _timer = Timer.periodic(const Duration(seconds: 10), (Timer timer) {
      if (mounted) {
        setState(() {
          userOrders = fetchUserOrders(widget.userId);
        });
      }
    });
  }

  String calculateTimeGap(String createdAt) {
    DateTime orderTime = DateTime.parse(createdAt).toUtc();
    DateTime now = DateTime.now().toUtc();
    Duration difference = now.difference(orderTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Your Orders', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => CartScreen(userId: widget.userId),
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
            return _buildLoadingState();
          } else if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          } else {
            orders = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  userOrders = fetchUserOrders(widget.userId);
                });
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemCount: orders!.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(orders![index]);
                },
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final totalPrice = (order['total_price'] is String)
        ? double.tryParse(order['total_price']) ?? 0.0
        : order['total_price'].toDouble();

    final deliveryFee = (order['delivery_fee'] is String)
        ? double.tryParse(order['delivery_fee']) ?? 0.0
        : order['delivery_fee'].toDouble();

    final timeGap = calculateTimeGap(order['created_at']);
    final storeName = order['store_name'];
    final orderType = order['order_type'] == 'restaurant' ? 'Restaurant' : 'Shop';
    final status = order['status'] ?? 'Processing';
    final isCompleted = status.toLowerCase() == 'completed';
    final orderId = order['id'] ?? order['order_id'] ?? 'N/A';
    final confirmationCode = order['confirmation_code'] ?? 'N/A';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Order #$orderId',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isCompleted ? Colors.green[800] : Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            // Confirmation Code
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.confirmation_number,
                  color: Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Confirmation: $confirmationCode',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            // Store information and time
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  orderType == 'Restaurant' ? Icons.restaurant : Icons.shopping_bag,
                  color: Colors.deepOrange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  timeGap,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            // ... rest of your existing card content ...
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...order['items'].map<Widget>((item) {
              final itemPrice = (item['price'] is String)
                  ? double.tryParse(item['price']) ?? 0.0
                  : item['price'].toDouble();
              final quantity = item['quantity'] ?? 1;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['name'],
                        style: const TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$quantity x ETB ${itemPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Delivery Fee:',
                  style: TextStyle(fontSize: 15),
                ),
                Text(
                  'ETB ${deliveryFee.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ETB ${totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isCompleted)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // Add cancel order functionality
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Cancel Order'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          height: 180,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Failed to load orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                userOrders = fetchUserOrders(widget.userId);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'No Orders Yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "You haven't placed any orders yet. Start exploring our menu!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Explore Menu',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}