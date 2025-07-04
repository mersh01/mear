import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // For Timer
import 'map_screen.dart'; // Import the MapScreen
import 'delivered_list_screen.dart';
import 'taken_order.dart';
import 'change_dw_info.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';  // Import Geolocator package
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file

class DwHomeScreen extends StatefulWidget {
  final String username;
  final int userId;

  DwHomeScreen({required this.username, required this.userId});

  @override
  _DwHomeScreenState createState() => _DwHomeScreenState();
}

class _DwHomeScreenState extends State<DwHomeScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  late String _updatedUsername;
  Timer? _timer; // Timer to update elapsed time
  Position? _currentPosition; // To store the detected location
  Map<int, String> _orderAddresses = {};

  @override
  void initState() {
    super.initState();
    _updatedUsername = widget.username;
    _fetchOrders();
    _getCurrentLocation();
    // Start the timer to update elapsed time every second
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

  Future<void> _openMap(String location) async {
    final Uri mapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$location');
    print('Attempting to open map: $mapUri');
    if (await canLaunch(mapUri.toString())) {
      await launch(mapUri.toString());
    } else {
      throw 'Could not launch $mapUri';
    }
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the map')),
      );
    }
  }
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    // Check for location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permissions are permanently denied')),
      );
      return;
    }

    // Get the current position
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentPosition = position;
    });

    // Once location is detected, send it to the backend
    _sendLocationToDatabase(position.latitude, position.longitude);
  }

  // Send the detected location to the database
  Future<void> _sendLocationToDatabase(double latitude, double longitude) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}update_dw_location.php'),
        headers: {"Accept": "application/json"},
        body: {
          'user_id': widget.userId.toString(),
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
        },
      );

      if (response.statusCode == 200) {
        print('Location updated successfully');
      } else {
        print('Failed to update location. Status code: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update location')),
        );
      }
    } catch (e) {
      print('Error in _sendLocationToDatabase: $e');
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

  Future<void> _fetchOrders() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}get_orders.php'),
        headers: {"Accept": "application/json"},
        body: {
          'user_id': widget.userId.toString(),
        },
      );

      print('Response body: ${response.body}');

      if (response.statusCode == 200) {

        try {
          final data = json.decode(utf8.decode(response.bodyBytes));
          setState(() {
            _orders = data['orders'];
            _isLoading = false;

          });
        } catch (e) {
          print('Error parsing JSON: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid response format: $e')),
          );
          setState(() {
            _isLoading = false;
          });
        }
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

  Future<void> _takeOrder(int orderId) async {
    try {
      print('Taking order with ID: $orderId');
      print('Delivery Worker ID: ${widget.userId}');
      print('Order Status: taken');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}update_order_status.php'),
        headers: {"Accept": "application/json"},
        body: {
          'order_id': orderId.toString(),
          'status': 'taken',
          'delivery_worker_id': widget.userId.toString(),
        },
      );

      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(utf8.decode(response.bodyBytes));
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order taken successfully!')),
          );
          _fetchOrders(); // Refresh the order list
        } else {
          // Show error message returned from the backend
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to take order: ${result['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error in _takeOrder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }



  String _formatElapsedTime(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s) ago';
    } else if (difference.inSeconds > 0) {
      return '${difference.inSeconds} second(s) ago';
    } else {
      return 'Just now';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      case 'Taken':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Orders for $_updatedUsername'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh), // Add refresh icon
            onPressed: () {
              _fetchOrders(); // Call fetch orders on refresh button press
            },
          ),
          IconButton(
            icon: Icon(Icons.assignment_turned_in),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TakenOrder(
                        username: _updatedUsername,
                        userId: widget.userId,
                      ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.archive),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DeliveredListScreen(
                        username: _updatedUsername,
                        userId: widget.userId,
                      ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ChangeDwInfo(username: _updatedUsername),
                ),
              ).then((updatedUsername) {
                if (updatedUsername != null) {
                  setState(() {
                    _updatedUsername = updatedUsername;
                  });
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? Center(child: Text('No pending orders found'))
          : ListView.builder(
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            final order = _orders[index];
            final createdAt = DateTime.parse(order['created_at']);
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
                leading: Icon(Icons.shopping_cart, color: Colors.deepOrange),
                title: Text('Order #${order['order_id']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order for ${order['user_name']}'),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Ordered: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: _formatElapsedTime(createdAt)),
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
                  icon: Icon(Icons.location_on),
                  onPressed: () {
                    if (lat != null && lng != null) {
                      _openMap('$lat,$lng'); // Open Google Maps for the order's delivery location
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invalid location data')),
                      );
                    }
                  },
                ),
                onTap: () {
                  if (orderId > 0) {
                    _takeOrder(orderId);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invalid order ID')),
                    );
                  }
                },
              ),
            );

          }


      ),
    );
  }
}