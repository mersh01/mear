import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dw_app/constants/api_constants.dart';  // Import the constants file

class ChangeDwInfo extends StatefulWidget {
  final String username;

  ChangeDwInfo({required this.username});

  @override
  _ChangeDwInfoState createState() => _ChangeDwInfoState();
}

class _ChangeDwInfoState extends State<ChangeDwInfo> {
  final _formKey = GlobalKey<FormState>();
  late String _newUsername;
  late String _newPassword;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _newUsername = widget.username; // Initialize with the current username
    _newPassword = ''; // Initialize with an empty password
  }

  Future<void> _updateUserInfo() async {
    if (!_formKey.currentState!.validate()) {
      return; // If form is not valid, do nothing
    }
    _formKey.currentState!.save(); // Save form state

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}update_DW.php'),
        headers: {"Accept": "application/json"},
        body: {
          'new_username': _newUsername,
          'new_password': _newPassword,
          'current_username': widget.username,
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User info updated successfully!')),
          );
          Navigator.pop(context, _newUsername); // Return the updated username
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update info: ${result['message']}')),
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

    setState(() {
      _isLoading = false; // Hide loading indicator
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Change Info'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: _newUsername,
                decoration: InputDecoration(labelText: 'New Username'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new username';
                  }
                  return null;
                },
                onSaved: (value) {
                  _newUsername = value!;
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(labelText: 'New Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  return null;
                },
                onSaved: (value) {
                  _newPassword = value!;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateUserInfo,
                child: Text('Update'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange, // Background color
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
