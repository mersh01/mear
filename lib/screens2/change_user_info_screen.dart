import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'theme_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dw_app/constants/api_constants.dart';

class ChangeUserInfoScreen extends StatefulWidget {
  final String username;
  final int userId;

  const ChangeUserInfoScreen({
    Key? key,
    required this.username,
    required this.userId,
  }) : super(key: key);

  @override
  _ChangeUserInfoScreenState createState() => _ChangeUserInfoScreenState();
}

class _ChangeUserInfoScreenState extends State<ChangeUserInfoScreen> {
  bool _isLoading = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _profileImagePath;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() => _isLoading = true);
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
            _profileImagePath = jsonResponse['profile_image'];
          });
        } else {
          _showToast(jsonResponse['message'], isError: true);
        }
      } else {
        _showToast("Server error. Please try again later.", isError: true);
      }
    } catch (e) {
      _showToast("Network error: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.red : Colors.green,
      textColor: Colors.white,
    );
  }

  Future<void> _showDeleteConfirmation() async {
    String? deletionReason;
    final reasons = [
      "I no longer need this account",
      "I am experiencing issues",
      "Privacy concerns",
      "Other",
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Account',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please select a reason for deleting your account:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                hint: const Text('Select a reason'),
                value: deletionReason,
                items: reasons.map((reason) {
                  return DropdownMenuItem<String>(
                    value: reason,
                    child: Text(reason),
                  );
                }).toList(),
                onChanged: (value) => setState(() => deletionReason = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (deletionReason == null) {
                  _showToast("Please select a reason", isError: true);
                  return;
                }

                final response = await http.post(
                  Uri.parse('${ApiConstants.baseUrl}delete_user.php'),
                  body: {
                    'id': widget.userId.toString(),
                    'reason': deletionReason,
                    'category': 'customer',
                  },
                );

                if (response.statusCode == 200) {
                  final jsonResponse = json.decode(response.body);
                  _showToast(
                    jsonResponse['success'] ?? jsonResponse['error'],
                    isError: jsonResponse['success'] == null,
                  );
                  if (jsonResponse['success'] != null) {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Navigate back
                  }
                } else {
                  _showToast(
                    "Server error. Please try again later.",
                    isError: true,
                  );
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
  Future<void> _updateUserInfo() async {
    final newUsername = _usernameController.text.trim();
    final newPassword = _passwordController.text.trim();

    if (newUsername.isEmpty) {
      _showToast("Username cannot be empty", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}update_user.php'),
        body: {
          'old_username': widget.username,
          'new_username': newUsername,
          'new_password': newPassword,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        _showToast(jsonResponse['message'], isError: jsonResponse['status'] != 'success');
        if (jsonResponse['status'] == 'success') {
          Navigator.pop(context);
        }
      } else {
        _showToast("Server error. Please try again later.", isError: true);
      }
    } catch (e) {
      _showToast("Network error: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.deepOrange,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [Colors.grey[850]!, Colors.grey[900]!]
                : [Colors.deepOrange.shade50, Colors.orange.shade100],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildProfileSection(context),
              const SizedBox(height: 32),
              _buildTextField(
                context: context,
                controller: _usernameController,
                label: 'Username',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _buildPasswordField(context),
              const SizedBox(height: 32),
              _buildActionButton(
                text: 'UPDATE PROFILE',
                icon: Icons.save,
                color: Colors.deepOrange,
                onPressed: _updateUserInfo,
              ),
              const SizedBox(height: 16),
              _buildActionButton(
                text: 'DELETE ACCOUNT',
                icon: Icons.delete_outline,
                color: Colors.red,
                onPressed: _showDeleteConfirmation,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _profileImagePath != null && _profileImagePath!.isNotEmpty
                  ? NetworkImage(_profileImagePath!)
                  : const AssetImage('assets/profile_placeholder.png') as ImageProvider,
              child: _profileImagePath == null || _profileImagePath!.isEmpty
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.deepOrange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                onPressed: () {
                  // Add image picker functionality
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          widget.username,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Edit your account details',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        prefixIcon: Icon(icon, color: Colors.deepOrange),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_showPassword,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.deepOrange),
        suffixIcon: IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(text, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}