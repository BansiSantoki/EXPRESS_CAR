// ignore_for_file: file_names

import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:express_car/theme/app_theme.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize Cloudinary (Using the same credentials from your Admin panel)
  final cloudinary = CloudinaryPublic('dstlqyncg', 'carimages18', cache: false);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  String? _selectedGender;
  String? _profileImage; // URL from Firestore
  Uint8List? _profileImageBytes; // For UI Preview
  File? _selectedImageFile; // For Cloudinary Upload

  bool _isSubmitting = false;
  final Color _primaryColor = AppTheme.primary;
  static const List<String> _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      if (!mounted) return;
      setState(() {
        _nameController.text = data['displayName']?.toString() ?? '';
        _emailController.text = data['email']?.toString() ?? '';
        _phoneController.text = data['phone']?.toString() ?? '';
        _addressController.text = data['address']?.toString() ?? '';
        _dobController.text = data['dob']?.toString() ?? '';
        _selectedGender = _normalizeGender(data['gender']?.toString());
        _profileImage = data['photoURL']?.toString();
      });
    }
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    if (!mounted) return;
    setState(() {
      _selectedImageFile = File(picked.path);
      _profileImageBytes = bytes;
    });
  }

  String? _normalizeGender(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    for (final option in _genderOptions) {
      if (option.toLowerCase() == text.toLowerCase()) {
        return option;
      }
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String? photoUrl = _profileImage;
      String? uploadError;

      // 🚀 OPTIMIZATION: Upload to Cloudinary instead of Firebase Storage
      if (_selectedImageFile != null) {
        try {
          final response = await cloudinary.uploadFile(
            CloudinaryFile.fromFile(
              _selectedImageFile!.path,
              resourceType: CloudinaryResourceType.Image,
              folder: 'profile_images',
            ),
          );
          photoUrl = response.secureUrl;
        } catch (e) {
          uploadError = e.toString();
        }
      }

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await docRef.set({
        'displayName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'dob': _dobController.text.trim(),
        'gender': _selectedGender,
        'photoURL': photoUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(_nameController.text.trim());
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await user.updatePhotoURL(photoUrl);
      }

      if (!mounted) return;
      final message = uploadError == null
          ? 'Profile updated successfully!'
          : 'Profile updated, but photo upload failed: $uploadError';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _fieldDecoration(
    String label,
    String hint, {
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          "Edit Profile",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: _profileImageBytes != null
                            ? MemoryImage(_profileImageBytes!)
                            : (_profileImage != null &&
                                      _profileImage!.isNotEmpty
                                  ? NetworkImage(_profileImage!)
                                  : const AssetImage(
                                          "assets/images/profile.jpg",
                                        )
                                        as ImageProvider),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _pickProfileImage,
                          borderRadius: BorderRadius.circular(20),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: _primaryColor,
                            child: const Icon(
                              Icons.cloud_upload,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _pickProfileImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Change Photo'),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: _fieldDecoration("Full Name", "Ethan John"),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return "Please enter your name";
                    final text = value.trim();
                    if (!RegExp(r"^[a-zA-Z0-9 .'-]{2,}$").hasMatch(text)) {
                      return "Enter a valid name";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  enabled: false,
                  decoration: _fieldDecoration("Email", "ethan@example.com"),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDecoration(
                    "Phone Number",
                    "+91 98765 43210",
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return "Please enter phone number";
                    if (!RegExp(r'^[0-9+ ]{10,15}$').hasMatch(value))
                      return "Enter valid number";
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  decoration: _fieldDecoration("Address", "Surat, Gujarat"),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return "Please enter address";
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  decoration: _fieldDecoration(
                    "Date of Birth",
                    "Select your DOB",
                    suffix: const Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.tryParse(
                            _dobController.text.split('/').reversed.join('-'),
                          ) ??
                          DateTime(2004),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (!mounted) return;
                    if (picked != null) {
                      _dobController.text =
                          "${picked.day}/${picked.month}/${picked.year}";
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please select DOB";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  decoration: _fieldDecoration("Gender", "Select gender"),
                  value: _selectedGender,
                  items: _genderOptions
                      .map(
                        (gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedGender = value),
                  validator: (value) =>
                      value == null ? "Please select gender" : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Save Changes",
                            style: TextStyle(fontSize: 16, color: Colors.white),
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
}
