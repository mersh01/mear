import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../constants/api_constants.dart';
import 'payment_webview.dart'; // WebView to open Chapa's checkout

class PaymentScreen extends StatelessWidget {
  final double totalAmount;
  final int userId;
  LatLng? selectedLocation;

  PaymentScreen({required this.totalAmount, required this.userId, required this.selectedLocation});

  // Fetch user info from the backendr
  Future<Map<String, dynamic>> _fetchUserInfo() async {
    String apiUrl = "${ApiConstants.baseUrl}chapa_payment.php?user_id=$userId";

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data["status"] == "success") {
          return {
            "userName": data["user"]["fullname"],
            "userPhone": data["user"]["phone"],
          };
        } else {
          throw Exception("User not found");
        }
      } else {
        throw Exception("Failed to fetch user data");
      }
    } catch (e) {
      throw Exception("Error: $e");
    }
  }

  Future<void> _goToPaymentScreen(BuildContext context, String userName, String userPhone) async {
    String chapaApiUrl = "https://api.chapa.co/v1/transaction/initialize";
    String chapaSecretKey = "CHASECK_TEST-mzpcMD9zSfHfliZokORxMXGm3RD6PEDo";

    // Prepare the payment request data
    Map<String, dynamic> requestData = {
      "amount": totalAmount.toString(),
      "currency": "ETB",
      "email": "meraolfeye6@gmail.com",
      "first_name": userName.split(" ")[0], // Assuming first name is the first part of the full name
      "last_name": userName.split(" ").length > 1 ? userName.split(" ")[1] : "",
      "phone_number": userPhone,
      "tx_ref": "txn_${DateTime.now().millisecondsSinceEpoch}",
      "callback_url": "https://mersh011.atwebpages.com/payment_callback.php",
      "return_url": "https://mersh011.atwebpages.com/payment_success.php",
      "customization": {
        "title": "Mersh Payment", // Keep title <= 16 characters
        "description": "Online payment"
      }
    };

    try {
      final response = await http.post(
        Uri.parse(chapaApiUrl),
        headers: {
          "Authorization": "Bearer $chapaSecretKey",
          "Content-Type": "application/json"
        },
        body: jsonEncode(requestData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data["status"] == "success") {
          String paymentUrl = data["data"]["checkout_url"];
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PaymentWebView(paymentUrl: paymentUrl, userId: userId,  selectedLocation: selectedLocation,),
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to initialize payment: ${data['message']}")),
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error connecting to Chapa: ${response.statusCode}")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Payment", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade900, Colors.blue.shade500],
          ),
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _fetchUserInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: Colors.white));
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.white)));
            } else if (!snapshot.hasData || snapshot.data == null) {
              return Center(child: Text("User not found", style: TextStyle(color: Colors.white)));
            } else {
              // Extract user data from the snapshot
              String userName = snapshot.data!["userName"];
              String userPhone = snapshot.data!["userPhone"];

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Text(
                              "User Details",
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "User: $userName",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Phone: $userPhone",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.black87),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Total Amount: ETB ${totalAmount.toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                _goToPaymentScreen(context, userName, userPhone);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade900,
                                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                "Proceed to Payment",
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}