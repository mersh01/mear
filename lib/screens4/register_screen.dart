import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _confirmationCodeController = TextEditingController();

  String _confirmationCode = '';
  String _type = 'restaurant';
  String _name = '';
  String _description = '';
  String _username = '';
  String _password = '';
  String _phone = '';
  String _address = '';
  String _latitude = '';
  String _longitude = '';
  String? _categoryId;
  bool _isLoading = false;
  final List<Map<String, dynamic>> _categories = [
    {'id': 1, 'name': 'Clothes'},
    {'id': 2, 'name': 'Shoes'},
    {'id': 3, 'name': 'Electronics'},
    {'id': 4, 'name': 'Others'},
  ];

  @override
  void dispose() {
    _confirmationCodeController.dispose(); // Dispose of the controller
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Check if the user is registering as a shop and category is selected
      if (_type == 'shop' && _categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category for the shop.')),
        );
        return;
      }

      setState(() {
        _isLoading = true; // Start loading
      });
      try {
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}rest_register.php'),
          body: {

            'phone': _phone,
          // Will be null if not a shop
          },
        );

        final data = jsonDecode(response.body);
        setState(() {
          _isLoading = false; // Stop loading
        });

        if (data['success']) {
          _confirmationCode = data['confirmation_code'] ?? 'null'; // Store confirmation code
          _showConfirmationCodeDialog(); // Show confirmation dialog
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
        }
      } catch (error) {
        setState(() {
          _isLoading = false; // Stop loading
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  Future<void> _showConfirmationCodeDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Confirmation Code'),
          content: TextField(
            controller: _confirmationCodeController,
            decoration: const InputDecoration(
              labelText: 'Confirmation Code',
            ),
            keyboardType: TextInputType.number,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Confirm'),
              onPressed: _validateConfirmationCode,
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  Future<void> _validateConfirmationCode() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}validate_confirmation_code_rest.php'),
        body: {
          'type': _type,
          'name': _name,
          'description': _description,
          'username': _username,
          'password': _password,
          'phone': _phone,
          'address': _address,
          'latitude': _latitude,
          'longitude': _longitude,
          'category_id': _categoryId,
          'confirmation_code': _confirmationCodeController.text,
        },
      );

      final data = jsonDecode(response.body);
      if (data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration complete!')),
        );
        Navigator.pop(context); // Close the confirmation dialog
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Invalid confirmation code.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );

  }
  }


      Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude.toString();
        _longitude = position.longitude.toString();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create an Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _type,
                onChanged: (String? newValue) {
                  setState(() {
                    _type = newValue!;
                  });
                },
                items: <String>['restaurant', 'shop']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value.capitalizeFirstOfEach,
                      style: const TextStyle(color: Colors.teal),
                    ),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: 'Select Type',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              _buildTextField('Name', (value) => _name = value),
              const SizedBox(height: 10),
              _buildTextField('Description', (value) => _description = value),
              const SizedBox(height: 10),
              _buildTextField('Username', (value) => _username = value),
              const SizedBox(height: 10),
              _buildTextField('Password', (value) => _password = value, obscureText: true),
              const SizedBox(height: 10),
              _buildTextField('Phone', (value) => _phone = value),
              const SizedBox(height: 10),
              _buildTextField('Address', (value) => _address = value),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _getCurrentLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('Share Location', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 10),
              if (_type == 'shop') ...[
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Category',
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: const OutlineInputBorder(),
                  ),
                  value: _categoryId,
                  onChanged: (String? newValue) {
                    setState(() {
                      _categoryId = newValue!;
                    });
                  },
                  items: _categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category['id'].toString(),
                      child: Text(category['name']),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('Register', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _buildTextField(String label, Function(String) onSaved, {bool obscureText = false, bool isEnabled = true}) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[200],
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
      onSaved: (value) => onSaved(value!),
      obscureText: obscureText,
      enabled: isEnabled,
      initialValue: label == 'Latitude' ? _latitude : label == 'Longitude' ? _longitude : null,
    );
  }
}

extension StringExtension on String {
  String get capitalizeFirstOfEach => split(" ").map((str) => str.capitalize).join(" ");
  String get capitalize => length > 0 ? "${this[0].toUpperCase()}${substring(1)}" : "";
}
