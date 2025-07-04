import 'dart:math';
import 'package:dw_app/screens2/payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'order_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // For LatLng
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file
import 'package:geocoding/geocoding.dart';
import 'dart:async';

class CheckoutScreen extends StatefulWidget {
  final double totalPrice;
  final int userId;

  CheckoutScreen({
    required this.totalPrice,
    required this.userId,
  });

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _searchController = TextEditingController();

  TextEditingController addressController = TextEditingController();
  double deliveryFee = 0.0; // Ensure it starts with a default value
  bool isMapSelection = false; // Toggle between share location and map selection
  LatLng? selectedLocation; // Store the selected location from the map
  final MapController mapController = MapController(); // Controller for flutter_map
  String selectedAddress = '';
  Timer? _debounce;
  bool isDeliveryFeeUpdated = false;

  String _generateRandomCode() {
    final random = Random();
    const characters = '0123456789';
    return String.fromCharCodes(Iterable.generate(
        6, (_) => characters.codeUnitAt(random.nextInt(characters.length))));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching address. Please try again.')),
      );
    }
    return "Address not found"; // Fallback message
  }

  Future<LatLng?> _searchPlace(String query) async {
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        LatLng newLocation = LatLng(locations.first.latitude, locations.first.longitude);
        String address = await _getAddressFromCoordinates(newLocation.latitude, newLocation.longitude);

        setState(() {
          selectedLocation = newLocation;
          selectedAddress = address;
          addressController.text = address;
        });

        return newLocation;
      }
    } catch (e) {
      print("Search error: $e");
    }
    return null;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isNotEmpty) {
        LatLng? location = await _searchPlace(query);
        if (location != null) {
          mapController.move(location, 15);
          _updateDeliveryFee(location.latitude, location.longitude);
        }
      }
    });
  }
  Future<void> _shareLocation() async {
    setState(() {
      isLoading = true;
      isDeliveryFeeUpdated = false;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Fluttertoast.showToast(
          msg: "Location services are disabled. Please enable them.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Fluttertoast.showToast(
            msg: "Location permissions are denied.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Fluttertoast.showToast(
          msg: "Location permissions are permanently denied.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      String address = await _getAddressFromCoordinates(position.latitude, position.longitude);

      setState(() {
        selectedLocation = LatLng(position.latitude, position.longitude);
        selectedAddress = address;
        addressController.text = address; // Update text field
      });

      // Move map to selected location (if applicable)
      if (isMapSelection) {
        mapController.move(selectedLocation!, 15);
      }

      // Simulate delivery fee API call
      _updateDeliveryFee(position.latitude, position.longitude);
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } finally {
      setState(() {
        isLoading = false; // Stop loading indicator
      });
    }
  }

  bool isPlacingOrder = false; // Flag to track if order is being placed

  _placeOrder() async {
    if (addressController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please share your location or select a location on the map first.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    // Prevent multiple submissions if an order is being placed
    if (isPlacingOrder) {
      return; // If the order is already being placed, do nothing
    }

    setState(() {
      isPlacingOrder = true; // Set the flag to true when starting the order
    });

    String confirmationCode = _generateRandomCode();
    print("Placing order with confirmation code: $confirmationCode");

    try {
      final cartResponse = await http.get(
        Uri.parse('${ApiConstants.baseUrl}get_cartss.php?user_id=${widget.userId}'),
      );

      print("Cart response status: ${cartResponse.statusCode}");
      print("Cart response body: ${cartResponse.body}");

      if (cartResponse.statusCode != 200) {
        Fluttertoast.showToast(
          msg: "Failed to retrieve cart. Please try again.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        setState(() {
          isPlacingOrder = false; // Re-enable the button when the request fails
        });
        return;
      }

      final Map<String, dynamic> decodedResponse = jsonDecode(cartResponse.body);
      if (decodedResponse['success'] != true || !decodedResponse.containsKey('items')) {
        Fluttertoast.showToast(
          msg: "Failed to retrieve valid cart items.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        print("Invalid response structure: $decodedResponse");
        setState(() {
          isPlacingOrder = false; // Re-enable the button when the request fails
        });
        return;
      }

      List<dynamic> cartItems = decodedResponse['items'];
      print("Cart items retrieved: $cartItems");

      if (cartItems.isEmpty) {
        Fluttertoast.showToast(
          msg: "Your cart is empty.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        setState(() {
          isPlacingOrder = false; // Re-enable the button when the cart is empty
        });
        return;
      }

      // Prepare the request payload with the correct format
      List<Map<String, dynamic>> formattedCartItems = [];

      for (var item in cartItems) {
        if (item['type'] == 'restaurant') {
          formattedCartItems.add({
            'type': 'restaurant',
            'menu_item_id': item['item_id'],
            'quantity': item['quantity'],
            'price': double.tryParse(item['price'].toString()) ?? 0.0,
            'restaurant_id': item['restaurant_id'],
            'restaurant_name': item['restaurant_name'],
          });
        } else if (item['type'] == 'shop') {
          formattedCartItems.add({
            'type': 'shop',
            'item_id': item['item_id'],
            'quantity': item['quantity'],
            'price': double.tryParse(item['price'].toString()) ?? 0.0,
            'shop_id': item['shop_id'],
            'shop_name': item['shop_name'],
          });
        }
      }

      print("Formatted cart items: $formattedCartItems");
      String formattedLocation = selectedLocation != null
          ? "${selectedLocation!.latitude},${selectedLocation!.longitude}"
          : "0.0,0.0"; // Default fallback value

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}place_order.php'),
        body: jsonEncode({
          'user_id': widget.userId,
          'location': formattedLocation,
          'confirmation_code': confirmationCode,
          'cart_items': formattedCartItems,
          'payment_method': 'COD',
          'payment_status': 'not paid',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      print("Place order response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final clearCartResponse = await http.post(
          Uri.parse('${ApiConstants.baseUrl}clear_cart.php'),
          body: jsonEncode({'user_id': widget.userId.toString()}),
          headers: {'Content-Type': 'application/json'},
        );

        if (clearCartResponse.statusCode == 200) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderScreen(
                userId: widget.userId,
              ),
            ),
          );
          Fluttertoast.showToast(
            msg: "All orders placed successfully!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        } else {
          Fluttertoast.showToast(
            msg: "Failed to clear cart. Please try again.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: "Failed to place order. Please try again.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }

      setState(() {
        isPlacingOrder = false; // Re-enable the button when the order process finishes
      });
    } catch (e) {
      print("Error while placing order: $e");
      Fluttertoast.showToast(
        msg: "Error: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      setState(() {
        isPlacingOrder = false; // Re-enable the button if there's an error
      });
    }
  }

  Future<void> _getUserCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Fluttertoast.showToast(
          msg: "Location services are disabled. Please enable them.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Fluttertoast.showToast(
            msg: "Location permissions are denied.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Fluttertoast.showToast(
          msg: "Location permissions are permanently denied.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        selectedLocation = LatLng(position.latitude, position.longitude);
        addressController.text =
        '${position.latitude}, ${position.longitude}';
      });

      // Move the camera to the user's current location with a reasonable zoom level
      mapController.move(selectedLocation!, 13); // Zoom level 13

      // Calculate the delivery fee for the initial location
      _updateDeliveryFee(position.latitude, position.longitude);
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

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Select Payment Method"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.money, color: Colors.green),
                title: const Text("Pay with Cash"),
                onTap: () {
                  Navigator.pop(context); // Close dialog
                  _placeOrder(); // Process order with cash
                },
              ),
              ListTile(
                leading: const Icon(Icons.credit_card, color: Colors.blue),
                title: const Text("Pay with Transfer"),
                onTap: () {
                  Navigator.pop(context); // Close dialog
                  _goToPaymentScreen(); // Navigate to payment screen
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _goToPaymentScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          totalAmount: widget.totalPrice + deliveryFee, // Ensure this is correct
          userId: widget.userId, // Ensure this is correct
          selectedLocation: selectedLocation,  // Pass location here

        ),
      ),
    );
  }


  // Update the delivery fee based on the selected location
  bool isLoading = false; // Add this to track the loading state

  Future<void> _updateDeliveryFee(double latitude, double longitude) async {
    setState(() {
      isLoading = true;
      isDeliveryFeeUpdated = false;

    });
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}update_locations.php'),
        body: jsonEncode({
          'user_id': widget.userId.toString(),
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'total_price': widget.totalPrice.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['status'] == 'success') {
          setState(() {
            deliveryFee = double.parse(responseBody['total_delivery_fee'].toString());
            isDeliveryFeeUpdated = true; // Mark delivery fee as updated
          });
        } else {
          Fluttertoast.showToast(msg: responseBody['message']);
        }
      } else {
        Fluttertoast.showToast(msg: "Failed to update delivery fee. Please try again.");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }



  @override
  void initState() {
    super.initState();
    if (isMapSelection) {
      _getUserCurrentLocation();
      _shareLocation(); // Get the user's location initially

    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            SwitchListTile(
              title: const Text('Select Location on Map'),
              value: isMapSelection,
              onChanged: (bool value) {
                setState(() {
                  isMapSelection = value;
                  _shareLocation();
                  if (!isMapSelection) {
                    addressController.clear();
                    selectedLocation = null;
                    selectedAddress = "";

                  }
                });
              },
            ),
            const SizedBox(height: 10),

            if (isMapSelection)
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Search for a place...',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () async {
                              final query = _searchController.text;
                              if (query.isNotEmpty) {
                                final location = await _searchPlace(query);
                                if (location != null) {
                                  setState(() {
                                    selectedLocation = location;
                                  });
                                  mapController.move(location, 15);

                                  String address = await _getAddressFromCoordinates(location.latitude, location.longitude);
                                  setState(() {
                                    selectedAddress = address;
                                  });

                                  _updateDeliveryFee(location.latitude, location.longitude);
                                }
                              }
                            },
                          ),
                        ),
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                      ),
                      const SizedBox(height: 10),

                      // Map widget
                      SizedBox(
                        height: 200,
                        child: FlutterMap(
                          mapController: mapController,
                          options: MapOptions(
                            // Set the map center to the selected location or default (e.g., user's current location)
                            center: selectedLocation ?? LatLng(8.9, 38.014194), // Default to San Francisco
                            zoom: 13,
                            onTap: (tapPosition, latLng) async {
                              setState(() {
                                isLoading = true; // Immediately show loading
                                selectedLocation = latLng;
                              });

                              String address = await _getAddressFromCoordinates(latLng.latitude, latLng.longitude);
                              setState(() {
                                selectedAddress = address;
                              });

                              _updateDeliveryFee(latLng.latitude, latLng.longitude); // API call
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: ['a', 'b', 'c'],
                            ),
                            MarkerLayer(
                              markers: selectedLocation != null
                                  ? [
                                Marker(
                                  point: selectedLocation!,
                                  builder: (ctx) => const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ]
                                  : [],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Show the selected address and other details
                      if (selectedAddress.isNotEmpty)
                        Text(
                          "Address: $selectedAddress",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        "Selected Location: ${selectedLocation != null ? '${selectedLocation!.latitude}, ${selectedLocation!.longitude}' : 'Not selected'}",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Text(
                        "Delivery Fee: ETB ${deliveryFee.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Total Price: ETB ${(widget.totalPrice + deliveryFee).toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            if (!isMapSelection)
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: <Widget>[
                      TextField(
                        controller: addressController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Delivery Address',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Text("Delivery Fee: ETB ${deliveryFee.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("Total Price: ETB ${(widget.totalPrice + deliveryFee).toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: isMapSelection ? null : _shareLocation,
              child: const Text('Share Location'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isDeliveryFeeUpdated
                  ? _showPaymentDialog // Open payment method dialog first
                  : null, // Disable button if delivery fee isn't updated
              child: const Text('Place Order'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

}