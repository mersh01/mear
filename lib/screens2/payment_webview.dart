import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../constants/api_constants.dart';
import 'order_screen.dart';

class PaymentWebView extends StatefulWidget {
  final String paymentUrl;
  final int userId;
  LatLng? selectedLocation;

  PaymentWebView({required this.paymentUrl, required this.userId, required this.selectedLocation});

  @override
  _PaymentWebViewState createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool isPlacingOrder = false;
  String? selectedLocation;

  @override
  void initState() {
    super.initState();
    initializeWebView();
  }

  // Initialize the WebView
  void initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            print("Navigating to: ${request.url}");

            if (request.url.contains("success")) {
              _handlePaymentSuccess();
              return NavigationDecision.prevent;
            } else if (request.url.contains("failed")) {
              _handlePaymentFailure();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl)); // Load the payment URL
  }

  void _handlePaymentSuccess() async {
    Fluttertoast.showToast(
      msg: "Payment successful! Placing order...",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );

    // Call place order function
    await _placeOrder();
  }

  _placeOrder() async {
    if (widget.selectedLocation == null) {
      Fluttertoast.showToast(
        msg: "Please select a location on the map first.",
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
      String formattedLocation = widget.selectedLocation != null
          ? "${widget.selectedLocation!.latitude},${widget.selectedLocation!.longitude}"
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

  String _generateRandomCode() {
    final random = Random();
    const characters = '0123456789';
    return String.fromCharCodes(Iterable.generate(
        6, (_) => characters.codeUnitAt(random.nextInt(characters.length))));
  }

  void _handlePaymentFailure() {
    Navigator.pop(context, "failed");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed! Please try again.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Complete Your Payment"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WebViewWidget(controller: _controller), // Corrected usage of WebViewController
    );
  }
}
