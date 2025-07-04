import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file

class RestaurantInfoChangeScreen extends StatefulWidget {
  final int restaurantId;
  final String type; // 'restaurant' or 'shop'

  RestaurantInfoChangeScreen({
    required this.restaurantId,
    required this.type,
  });

  @override
  _RestaurantInfoChangeScreenState createState() =>
      _RestaurantInfoChangeScreenState();
}

class _RestaurantInfoChangeScreenState
    extends State<RestaurantInfoChangeScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _packagingController; // New controller for packaging

  bool _isOpen = true; // Default status

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _packagingController = TextEditingController(); // Initialize the packaging field

    _fetchInfoFromDatabase();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _packagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchInfoFromDatabase() async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConstants.baseUrl}get_info.php?id=${widget.restaurantId}&type=${widget.type}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          setState(() {
            _nameController.text = data['name'];
            _descriptionController.text = data['description'];
            _usernameController.text = data['username'];
            _isOpen = data['statuss'] == 'open';

            // Fetch packaging if the type is restaurant
            if (widget.type == 'restaurant' && data.containsKey('packaging')) {
              _packagingController.text = data['packaging'];
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch data: ${data['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error. Please try again later.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All fields are required!')),
      );
      return;
    }

    final url = '${ApiConstants.baseUrl}update_restaurant_info.php';

    final Map<String, String> body = {
      'id': widget.restaurantId.toString(),
      'name': _nameController.text,
      'description': _descriptionController.text,
      'username': _usernameController.text,
      'type': widget.type,
      'password': _passwordController.text,
      if (widget.type == 'restaurant') 'packaging': _packagingController.text, // Ensure this field is sent
    };

    final response = await http.post(
      Uri.parse(url),
      body: body,
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Information updated successfully!')),
        );
        Navigator.pop(context, true); // Indicate success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${responseData['message']}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error. Please try again later.')),
      );
    }
  }

  Future<void> _updateStatus(bool isOpen) async {
    final newStatus = isOpen ? 'open' : 'closed';
    final url = '${ApiConstants.baseUrl}update_restaurant_status.php';

    final response = await http.post(
      Uri.parse(url),
      body: {
        'id': widget.restaurantId.toString(),
        'status': newStatus,
        'type': widget.type,
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus!')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${responseData['error']}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error. Please try again later.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Change Settings'),
        backgroundColor: Colors.brown,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.brown.shade100, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(
                            _isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              color: _isOpen ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          value: _isOpen,
                          onChanged: (bool newValue) {
                            setState(() {
                              _isOpen = newValue;
                            });
                            _updateStatus(newValue);
                          },
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.red,
                        ),
                        SizedBox(height: 16),
                        _buildTextField(_nameController, "Name", Icons.restaurant),
                        SizedBox(height: 16),
                        _buildTextField(_descriptionController, "Description", Icons.description),
                        SizedBox(height: 16),
                        _buildTextField(_usernameController, "Username", Icons.person),
                        SizedBox(height: 16),
                        _buildTextField(_passwordController, "Password", Icons.lock, obscureText: true),
                        SizedBox(height: 16),

                        // Show packaging field only if type is restaurant
                        if (widget.type == 'restaurant') ...[
                          _buildTextField(_packagingController, "Packaging Type", Icons.local_dining),
                          SizedBox(height: 16),
                        ],

                        ElevatedButton(
                          onPressed: _saveChanges,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                          child: Text('Save Changes'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
