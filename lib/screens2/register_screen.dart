import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dw_app/constants/api_constants.dart'; // Import API constants file

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _fullname, _username, _address, _phone, _password;
  File? _idPicture;
  final picker = ImagePicker();

  // ✅ Upload image to Cloudinary
  Future<String?> _uploadImage(File image) async {
    try {
      const cloudName = "doqcck2lj";
      const uploadPreset = "b5k12sct";
      final url = "https://api.cloudinary.com/v1_1/$cloudName/image/upload";

      final request = http.MultipartRequest("POST", Uri.parse(url))
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await request.send();
      final jsonResponse = jsonDecode(await response.stream.bytesToString());

      return jsonResponse['secure_url'] ?? null;
    } catch (e) {
      return null;
    }
  }

  // ✅ Register user
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      String? imageUrl = _idPicture != null ? await _uploadImage(_idPicture!) : null;
      final response = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/register.php"),
        body: {
          'fullname': _fullname,
          'username': _username,
          'address': _address,
          'phone': _phone,
          'password': _password,
          'id_picture': imageUrl ?? "",
        },
      );

      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration Successful')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(jsonResponse['message'] ?? 'Registration failed')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ✅ Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      setState(() => _idPicture = pickedFile != null ? File(pickedFile.path) : null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register'), backgroundColor: Colors.deepOrange),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
              children: [
              _buildTextField(label: 'Full Name', onSaved: (val) => _fullname = val, validator: (val) => val!.isEmpty ? 'Enter full name' : null),
          _buildTextField(label: 'Username', onSaved: (val) => _username = val, validator: (val) => val!.isEmpty ? 'Enter username' : null),
          _buildTextField(label: 'Address', onSaved: (val) => _address = val, validator: (val) => val!.isEmpty ? 'Enter address' : null),
          _buildTextField(label: 'Phone', onSaved: (val) => _phone = val, validator: (val) => val!.isEmpty ? 'Enter phone number' : null),
          _buildTextField(label: 'Password', obscureText: true, onSaved: (val) => _password = val, validator: (val) => val!.isEmpty ? 'Enter password' : null),
          SizedBox(height: 15.0),
          GestureDetector(
              onTap: _pickImage,
              child: _idPicture == null
                  ? Container(height: 150, color: Colors.grey[200], child: Center(child: Text('No ID picture selected', style: TextStyle(color: Colors.grey))))
                  : Image.file(_idPicture!, height: 150, fit: BoxFit.cover),
        ),
        SizedBox(height: 15.0),
        ElevatedButton(
          onPressed: _register,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text('Register', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildTextField({required String label, required FormFieldSetter<String> onSaved, required FormFieldValidator<String> validator, bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        obscureText: obscureText,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        onSaved: onSaved,
        validator: validator,
      ),
    );
  }
}
