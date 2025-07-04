import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme_provider.dart'; // Import ThemeProvider
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:typed_data';
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file

class ChangeUserInfoScreen extends StatefulWidget {
  final String username;
  final int userId;

  ChangeUserInfoScreen({required this.username, required this.userId});

  @override
  _ChangeUserInfoScreenState createState() => _ChangeUserInfoScreenState();
}

class _ChangeUserInfoScreenState extends State<ChangeUserInfoScreen> {
  bool _isLoading = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _profileImagePath; // Holds the image path

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}get_user_profile.php'),
        headers: {"Accept": "application/json"},
        body: {'user_id': widget.userId.toString()},
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            _usernameController.text = jsonResponse['username'];
            _profileImagePath = jsonResponse['profile_image']; // Store the image path
          });
        } else {
          Fluttertoast.showToast(msg: jsonResponse['message']);
        }
      } else {
        Fluttertoast.showToast(msg: "Server error. Please try again later.");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Network error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showDeleteConfirmation() async {
    String? deletionReason;

    List<String> reasons = [
      "I no longer need this account",
      "I am experiencing issues",
      "Privacy concerns",
      "Other",
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please select a reason for deleting your account:'),
              DropdownButton<String>(
                hint: Text('Select a reason'),
                value: deletionReason,
                items: reasons.map((String reason) {
                  return DropdownMenuItem<String>(
                    value: reason,
                    child: Text(reason),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    deletionReason = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (deletionReason != null) {
                  var response = await http.post(
                    Uri.parse('${ApiConstants.baseUrl}delete_user.php'),
                    body: {
                      'id': widget.userId.toString(),
                      'reason': deletionReason,
                      'category': 'customer',
                    },
                  );

                  if (response.statusCode == 200) {
                    var jsonResponse = json.decode(response.body);
                    Fluttertoast.showToast(
                      msg: jsonResponse['success'] ?? jsonResponse['error'],
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: jsonResponse['success'] != null ? Colors.green : Colors.red,
                      textColor: Colors.white,
                    );

                    Navigator.of(context).pop(); // Close the dialog
                    Navigator.of(context).pop(); // Navigate back to previous screen
                  } else {
                    Fluttertoast.showToast(
                      msg: "Server error. Please try again later.",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                    );
                  }
                } else {
                  Fluttertoast.showToast(
                    msg: "Please select a reason.",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                  );
                }
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.deepOrange,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator()) // Show loading indicator
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [Colors.black, Colors.grey[850]!]
                : [Colors.orange.shade100, Colors.deepOrange.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildProfileSection(context), // Display user profile
            SizedBox(height: 20),
            _buildTextField(
              controller: _usernameController,
              labelText: 'Username',
              prefixIcon: Icons.person,
              context: context,
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: _passwordController,
              labelText: 'Password',
              prefixIcon: Icons.lock,
              obscureText: true,
              context: context,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                String newUsername = _usernameController.text;
                String newPassword = _passwordController.text;

                var response = await http.post(
                  Uri.parse('${ApiConstants.baseUrl}update_user.php'),
                  body: {
                    'old_username': widget.username,
                    'new_username': newUsername,
                    'new_password': newPassword,
                  },
                );

                if (response.statusCode == 200) {
                  var jsonResponse = json.decode(response.body);
                  if (jsonResponse['status'] == 'success') {
                    Fluttertoast.showToast(
                      msg: jsonResponse['message'],
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: Colors.green,
                      textColor: Colors.white,
                    );
                    Navigator.pop(context);
                  } else {
                    Fluttertoast.showToast(
                      msg: jsonResponse['message'],
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                    );
                  }
                } else {
                  Fluttertoast.showToast(
                    msg: "Server error. Please try again later.",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              ),
              child: Text(
                'Update',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showDeleteConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              ),
              child: Text(
                'Delete Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildProfileSection(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: _profileImagePath != null && _profileImagePath!.isNotEmpty
              ? NetworkImage(_profileImagePath!) // Load image from path
              : AssetImage('assets/profile_placeholder.png') as ImageProvider,
        ),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.username,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Edit your details below',
              style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
            ),
          ],
        ),
      ],
    );



  }


  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool obscureText = false,
    required BuildContext context,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey),
        ),
      ),
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
    );
  }
}
