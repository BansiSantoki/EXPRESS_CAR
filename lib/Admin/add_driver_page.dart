import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:express_car/theme/app_theme.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  // Initialize Cloudinary
  final cloudinary = CloudinaryPublic('dstlqyncg', 'carimages18', cache: false);

  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _licenseController = TextEditingController();

  bool _isSaving = false;
  String _selectedAvailability = 'available';
  String _selectedApprovalStatus = 'pending';

  File? _driverPhotoFile; // 🚀 NEW: Driver Profile Photo
  File? _aadhaarFrontFile;
  File? _aadhaarBackFile;
  File? _licenseFile;

  @override
  void dispose() {
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _aadhaarController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<File?> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  Future<String?> _uploadImage(File? file, String folderName) async {
    if (file == null) return null;
    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Image,
        folder: folderName,
      ),
    );
    return response.secureUrl;
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('driver_documents').add({
        'driverName': _driverNameController.text.trim(),
        'phone': _driverPhoneController.text.trim(),
        'aadhaarNumber': _aadhaarController.text.trim(),
        'licenseNumber': _licenseController.text.trim(),
        'availability': _selectedAvailability,
        'approvalStatus': _selectedApprovalStatus,
        'photoUrl': await _uploadImage(
          _driverPhotoFile,
          'driver_docs/photos',
        ), // 🚀 NEW: Upload Photo
        'aadhaarFrontUrl': await _uploadImage(
          _aadhaarFrontFile,
          'driver_docs/aadhaar_front',
        ),
        'aadhaarBackUrl': await _uploadImage(
          _aadhaarBackFile,
          'driver_docs/aadhaar_back',
        ),
        'licenseUrl': await _uploadImage(_licenseFile, 'driver_docs/license'),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company Driver added successfully.')),
      );
      Navigator.pop(context); // Go back to the list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save driver: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('Add Company Driver')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driver Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🚀 NEW: Driver Photo Picker UI
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await _pickImage();
                        if (picked != null) {
                          setState(() => _driverPhotoFile = picked);
                        }
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppTheme.primarySoft,
                            backgroundImage: _driverPhotoFile != null
                                ? FileImage(_driverPhotoFile!)
                                : null,
                            child: _driverPhotoFile == null
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: AppTheme.primary,
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _field(_driverNameController, 'Driver Name', Icons.person),
                  _field(
                    _driverPhoneController,
                    'Phone Number',
                    Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  _field(
                    _aadhaarController,
                    'Aadhaar Number',
                    Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  _field(
                    _licenseController,
                    'Driving License Number',
                    Icons.credit_card,
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Document Images',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _uploadRow(
                    label: 'Aadhaar Front',
                    file: _aadhaarFrontFile,
                    onFileSelected: (f) =>
                        setState(() => _aadhaarFrontFile = f),
                  ),
                  _uploadRow(
                    label: 'Aadhaar Back',
                    file: _aadhaarBackFile,
                    onFileSelected: (f) => setState(() => _aadhaarBackFile = f),
                  ),
                  _uploadRow(
                    label: 'License Image',
                    file: _licenseFile,
                    onFileSelected: (f) => setState(() => _licenseFile = f),
                  ),

                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedAvailability,
                    decoration: _inputDecoration(
                      'Availability',
                      Icons.toggle_on,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'available',
                        child: Text('Available'),
                      ),
                      DropdownMenuItem(value: 'busy', child: Text('Busy')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null)
                        setState(() => _selectedAvailability = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedApprovalStatus,
                    decoration: _inputDecoration(
                      'Approval Status',
                      Icons.verified_user_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'approved',
                        child: Text('Approved'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Rejected'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null)
                        setState(() => _selectedApprovalStatus = value);
                    },
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveDriver,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving
                            ? 'Uploading & Saving...'
                            : 'Save Company Driver',
                        style: const TextStyle(
                          fontSize: 16,
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
      ),
    );
  }

  Widget _uploadRow({
    required String label,
    required File? file,
    required Function(File?) onFileSelected,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(
            file == null ? Icons.upload_file : Icons.check_circle,
            color: file == null ? AppTheme.primary : Colors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file == null ? label : '$label Selected',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await _pickImage();
              if (picked != null) onFileSelected(picked);
            },
            child: Text(file == null ? 'Choose' : 'Change'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.primary),
      filled: true,
      fillColor: const Color(0xFFF8FBFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
        decoration: _inputDecoration(label, icon),
      ),
    );
  }
}
