import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer'; // For debugging
import 'package:provider/provider.dart'; // Add this import

import 'package:dw_app/screens2/restaurant_list_screen.dart';
import 'package:dw_app/screens3/dw_home_screen.dart';
import 'package:dw_app/screens4/rest_home_screen.dart';
import 'package:dw_app/constants/api_constants.dart';
import 'screens2/theme_provider.dart'; // Import your theme provider

// Import the Register Screens
import 'package:dw_app/screens2/register_screen.dart' as customer_register;
import 'package:dw_app/screens3/register_screen.dart' as dw_register;
import 'package:dw_app/screens4/register_screen.dart' as rest_register;

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedType = 'customer'; // Default to customer

  Future<void> _login() async {
    try {
      final String loginUrl;

      // Determine the appropriate API endpoint based on user type
      if (_selectedType == 'customer') {
        loginUrl = '${ApiConstants.baseUrl}login.php';
      } else if (_selectedType == 'delivery_worker') {
        loginUrl = '${ApiConstants.baseUrl}dw_login.php';
      } else if (_selectedType == 'restaurant' || _selectedType == 'shop') {
        loginUrl = '${ApiConstants.baseUrl}restaurant_login.php';
      } else {
        throw Exception('Invalid user type selected');
      }

      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json", // Send request as JSON
        },
        body: json.encode({
          'username': _usernameController.text,
          'password': _passwordController.text,
          if (_selectedType == 'restaurant' || _selectedType == 'shop') 'type': _selectedType, // Include type for restaurants and shops
        }),
      );

      // Log the raw response for debugging
      log('Raw Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data['success'] == true) {
          int userId = data['user_id'] ?? 0;
          String username = data['username'] ?? 'Unknown';

          // Navigate to the appropriate screen based on user type
          if (_selectedType == 'customer') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => RestaurantListScreen(
                  username: username,
                  userId: userId,
                ),
              ),
            );
          } else if (_selectedType == 'delivery_worker') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DwHomeScreen(
                  username: username,
                  userId: userId,
                ),
              ),
            );
          } else if (_selectedType == 'restaurant' || _selectedType == 'shop') {
            // Ensure the server response includes 'name' and 'description'
            String name = data['name'] ?? 'Restaurant/Shop Name';
            String description = data['description'] ?? 'Best service in town!';

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => RestHomeScreen(
                  username: username,
                  restaurantId: userId,
                  restaurantName: name,
                  type: _selectedType,
                  restaurantDescription: description,
                ),
              ),
            );
          }
        } else {
          String message = data['message'] ?? 'Login failed. Please try again.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
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

  // Show Register Dialog
  void _showRegisterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Register as'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.person, color: Colors.blue),
                title: Text('Customer'),
                onTap: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => customer_register.RegisterScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delivery_dining, color: Colors.green),
                title: Text('Delivery Worker'),
                onTap: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => dw_register.RegisterScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.store, color: Colors.orange),
                title: Text('Restaurant / Shop Owner'),
                onTap: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => rest_register.RegisterScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme(!isDarkMode);
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 100,
                color: Colors.deepOrange,
              ),
              SizedBox(height: 20),
              Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: const [
                  DropdownMenuItem(value: 'customer', child: Text('Customer')),
                  DropdownMenuItem(value: 'delivery_worker', child: Text('Delivery Worker')),
                  DropdownMenuItem(value: 'restaurant', child: Text('Restaurant')),
                  DropdownMenuItem(value: 'shop', child: Text('Shop')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Login as',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                ),
                child: const Text('Login'),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: _showRegisterDialog,
                child: Text(
                  'Don\'t have an account? Register here',
                  style: TextStyle(color: Colors.deepOrange, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
