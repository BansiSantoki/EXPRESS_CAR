// Path: lib/Authentication/CompleteProfile.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:express_car/Authentication/auth_wrapper.dart';
import 'package:express_car/theme/app_theme.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();

  String? _selectedGender;
  bool _isSubmitting = false;

  InputDecoration _fieldDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.primary),
      prefixIcon: Icon(icon, color: AppTheme.primary),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'displayName': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'dob': _dobController.text.trim(),
            'gender': _selectedGender,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  "Complete Your Profile",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Help us know you better",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.primaryDark, fontSize: 16),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AppTheme.primaryDark),
                  decoration: _fieldDecoration(
                    "Full Name",
                    Icons.person_outline,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Enter your full name";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppTheme.primaryDark),
                  decoration: _fieldDecoration("Phone", Icons.phone_outlined),
                  validator: (value) {
                    if (value == null ||
                        !RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                      return "Enter valid 10-digit number";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  style: const TextStyle(color: AppTheme.primaryDark),
                  decoration: _fieldDecoration("Address", Icons.home_outlined),
                  validator: (value) => value == null || value.isEmpty
                      ? "Enter your address"
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  style: const TextStyle(color: AppTheme.primaryDark),
                  decoration: _fieldDecoration(
                    "Date of Birth",
                    Icons.calendar_today_outlined,
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppTheme.primary,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: AppTheme.ink,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (picked != null) {
                      _dobController.text =
                          "${picked.day}/${picked.month}/${picked.year}";
                    }
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? "Select date of birth"
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  dropdownColor: Colors.white,
                  iconEnabledColor: AppTheme.primary,
                  decoration: _fieldDecoration("Gender", Icons.person),
                  value: _selectedGender,
                  style: const TextStyle(color: AppTheme.primaryDark),
                  items: ["Male", "Female", "Other"]
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text(
                            g,
                            style: const TextStyle(color: AppTheme.primaryDark),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedGender = value),
                  validator: (value) => value == null ? "Select gender" : null,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : const Text(
                            "Continue",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
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
