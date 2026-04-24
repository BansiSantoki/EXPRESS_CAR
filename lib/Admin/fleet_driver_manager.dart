import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:express_car/Handle_Car/Add_Car.dart';
import 'package:express_car/theme/app_theme.dart';

class FleetDriverManagerPage extends StatefulWidget {
  const FleetDriverManagerPage({super.key});

  @override
  State<FleetDriverManagerPage> createState() => _FleetDriverManagerPageState();
}

class _FleetDriverManagerPageState extends State<FleetDriverManagerPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _fleetFormKey = GlobalKey<FormState>();
  final _driverFormKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final cloudinary = CloudinaryPublic('dstlqyncg', 'carimages18', cache: false);

  final _fleetNameController = TextEditingController();
  final _fleetModelController = TextEditingController();
  final _fleetLocationController = TextEditingController();
  final _fleetNotesController = TextEditingController();

  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _licenseController = TextEditingController();
  final _rcController = TextEditingController();
  final _insuranceController = TextEditingController();
  final _permitController = TextEditingController();

  bool _savingFleet = false;
  bool _savingDriver = false;
  String _selectedFleetType = 'driverless';
  String _selectedApprovalStatus = 'pending';
  String _selectedDriverAvailability = 'available';
  String _selectedDriverApprovalStatus = 'pending';

  File? _aadhaarFrontFile;
  File? _aadhaarBackFile;
  File? _licenseFile;
  File? _rcFile;
  File? _insuranceFile;
  File? _permitFile;

  final List<Map<String, String>> _docRequirements = const [
    {
      'title': 'Aadhaar Card',
      'subtitle': 'Driver identity verification',
      'icon': 'badge',
    },
    {
      'title': 'Driving License',
      'subtitle': 'Valid LMV/Transport license',
      'icon': 'car_rental',
    },
    {
      'title': 'RC Book',
      'subtitle': 'Vehicle registration proof',
      'icon': 'description',
    },
    {
      'title': 'Insurance',
      'subtitle': 'Active policy document',
      'icon': 'verified',
    },
    {
      'title': 'Permit',
      'subtitle': 'Commercial / local permit',
      'icon': 'policy',
    },
    {
      'title': 'PUC / Fitness',
      'subtitle': 'Pollution & fitness record',
      'icon': 'health_and_safety',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fleetNameController.dispose();
    _fleetModelController.dispose();
    _fleetLocationController.dispose();
    _fleetNotesController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _aadhaarController.dispose();
    _licenseController.dispose();
    _rcController.dispose();
    _insuranceController.dispose();
    _permitController.dispose();
    super.dispose();
  }

  Future<File?> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
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

  Future<void> _saveFleetItem() async {
    if (!_fleetFormKey.currentState!.validate()) return;
    setState(() => _savingFleet = true);

    try {
      await FirebaseFirestore.instance.collection('fleet_items').add({
        'name': _fleetNameController.text.trim(),
        'model': _fleetModelController.text.trim(),
        'location': _fleetLocationController.text.trim(),
        'notes': _fleetNotesController.text.trim(),
        'fleetType': _selectedFleetType,
        'approvalStatus': _selectedApprovalStatus,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _fleetNameController.clear();
      _fleetModelController.clear();
      _fleetLocationController.clear();
      _fleetNotesController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fleet item added successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save fleet item: $e')));
    } finally {
      if (mounted) setState(() => _savingFleet = false);
    }
  }

  Future<void> _saveDriverProfile() async {
    if (!_driverFormKey.currentState!.validate()) return;
    setState(() => _savingDriver = true);

    try {
      await FirebaseFirestore.instance.collection('driver_documents').add({
        'driverName': _driverNameController.text.trim(),
        'phone': _driverPhoneController.text.trim(),
        'aadhaarNumber': _aadhaarController.text.trim(),
        'licenseNumber': _licenseController.text.trim(),
        'rcNumber': _rcController.text.trim(),
        'insuranceNumber': _insuranceController.text.trim(),
        'permitNumber': _permitController.text.trim(),
        'availability': _selectedDriverAvailability,
        'approvalStatus': _selectedDriverApprovalStatus,
        'aadhaarFrontUrl': await _uploadImage(
          _aadhaarFrontFile,
          'driver_docs/aadhaar_front',
        ),
        'aadhaarBackUrl': await _uploadImage(
          _aadhaarBackFile,
          'driver_docs/aadhaar_back',
        ),
        'licenseUrl': await _uploadImage(_licenseFile, 'driver_docs/license'),
        'rcUrl': await _uploadImage(_rcFile, 'driver_docs/rc'),
        'insuranceUrl': await _uploadImage(
          _insuranceFile,
          'driver_docs/insurance',
        ),
        'permitUrl': await _uploadImage(_permitFile, 'driver_docs/permit'),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _driverNameController.clear();
      _driverPhoneController.clear();
      _aadhaarController.clear();
      _licenseController.clear();
      _rcController.clear();
      _insuranceController.clear();
      _permitController.clear();
      _aadhaarFrontFile = null;
      _aadhaarBackFile = null;
      _licenseFile = null;
      _rcFile = null;
      _insuranceFile = null;
      _permitFile = null;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver documents saved successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save driver docs: $e')));
    } finally {
      if (mounted) setState(() => _savingDriver = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Fleet & Driver Management'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.primaryDark,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Fleet'),
            Tab(text: 'Drivers'),
            Tab(text: 'Docs'),
            Tab(text: 'Vehicle Add'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFleetTab(),
          _buildDriverTab(),
          _buildDocsTab(),
          _buildVehicleTab(),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            'Driverless or With Driver',
            'Create car categories and keep fleet notes clean.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _blueChoiceCard(
                  title: 'Driverless',
                  subtitle: 'Self-drive fleet',
                  icon: Icons.directions_car,
                  selected: _selectedFleetType == 'driverless',
                  onTap: () =>
                      setState(() => _selectedFleetType = 'driverless'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _blueChoiceCard(
                  title: 'With Driver',
                  subtitle: 'Driver included',
                  icon: Icons.person_pin,
                  selected: _selectedFleetType == 'with_driver',
                  onTap: () =>
                      setState(() => _selectedFleetType = 'with_driver'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildFormCard(
            child: Form(
              key: _fleetFormKey,
              child: Column(
                children: [
                  _field(
                    _fleetNameController,
                    'Car Name',
                    Icons.directions_car,
                  ),
                  _field(
                    _fleetModelController,
                    'Model / Variant',
                    Icons.confirmation_number,
                  ),
                  _field(
                    _fleetLocationController,
                    'Location',
                    Icons.location_on_outlined,
                  ),
                  _field(
                    _fleetNotesController,
                    'Notes',
                    Icons.notes,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 4),
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
                      if (value != null) {
                        setState(() => _selectedApprovalStatus = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _savingFleet ? null : _saveFleetItem,
                      icon: _savingFleet
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _savingFleet ? 'Saving...' : 'Save Fleet Item',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _liveList('fleet_items', 'No fleet items yet.'),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () => _tabController.animateTo(3),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Open Vehicle Add Form'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            'Driver Documents',
            'Store Aadhaar, license, RC, insurance, and permit details.',
          ),
          const SizedBox(height: 16),
          _buildFormCard(
            child: Form(
              key: _driverFormKey,
              child: Column(
                children: [
                  _field(_driverNameController, 'Driver Name', Icons.person),
                  _field(_driverPhoneController, 'Phone Number', Icons.phone),
                  _field(
                    _aadhaarController,
                    'Aadhaar Number',
                    Icons.badge_outlined,
                  ),
                  _field(
                    _licenseController,
                    'Driving License Number',
                    Icons.credit_card,
                  ),
                  _field(
                    _rcController,
                    'RC Number',
                    Icons.description_outlined,
                  ),
                  _field(
                    _insuranceController,
                    'Insurance Number',
                    Icons.verified_outlined,
                  ),
                  _field(
                    _permitController,
                    'Permit Number',
                    Icons.policy_outlined,
                  ),
                  const SizedBox(height: 8),
                  _uploadRow(label: 'Aadhaar Front', file: _aadhaarFrontFile),
                  _uploadRow(label: 'Aadhaar Back', file: _aadhaarBackFile),
                  _uploadRow(label: 'License Image', file: _licenseFile),
                  _uploadRow(label: 'RC Image', file: _rcFile),
                  _uploadRow(label: 'Insurance Image', file: _insuranceFile),
                  _uploadRow(label: 'Permit Image', file: _permitFile),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedDriverAvailability,
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
                      if (value != null) {
                        setState(() => _selectedDriverAvailability = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedDriverApprovalStatus,
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
                      if (value != null) {
                        setState(() => _selectedDriverApprovalStatus = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _savingDriver ? null : _saveDriverProfile,
                      icon: _savingDriver
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.badge_outlined),
                      label: Text(
                        _savingDriver ? 'Saving...' : 'Save Driver Documents',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _liveList('driver_documents', 'No driver documents saved yet.'),
        ],
      ),
    );
  }

  Widget _buildVehicleTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            'Vehicle Add Form',
            'Use the existing car add form from the admin page.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a new vehicle to Firestore using the existing car form.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This keeps one add-flow for vehicles while the admin page remains the control center.',
                  style: TextStyle(color: AppTheme.primaryDark),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddCarPage()),
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Open Add Vehicle Form'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            'Required Documents',
            'A clean checklist for driver verification and fleet compliance.',
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _docRequirements.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              final doc = _docRequirements[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primarySoft,
                      child: Icon(
                        _iconForName(doc['icon']!),
                        color: AppTheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      doc['title']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doc['subtitle']!,
                      style: const TextStyle(
                        color: AppTheme.primaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          const Text(
            'Tip: Add a driver profile only after Aadhaar, license, RC, insurance, and permit are verified.',
            style: TextStyle(color: AppTheme.primaryDark, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _uploadRow({required String label, required File? file}) {
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
          const Icon(Icons.upload_file, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file == null ? label : '$label selected',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await _pickImage();
              setState(() {
                switch (label) {
                  case 'Aadhaar Front':
                    _aadhaarFrontFile = picked;
                    break;
                  case 'Aadhaar Back':
                    _aadhaarBackFile = picked;
                    break;
                  case 'License Image':
                    _licenseFile = picked;
                    break;
                  case 'RC Image':
                    _rcFile = picked;
                    break;
                  case 'Insurance Image':
                    _insuranceFile = picked;
                    break;
                  case 'Permit Image':
                    _permitFile = picked;
                    break;
                }
              });
            },
            child: const Text('Choose'),
          ),
        ],
      ),
    );
  }

  Widget _liveList(String collection, String emptyText) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                emptyText,
                style: const TextStyle(color: AppTheme.primaryDark),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final title = data['name'] ?? data['driverName'] ?? 'Untitled';
            final subtitle = data['fleetType'] ?? data['availability'] ?? '';
            final approvalStatus =
                data['approvalStatus']?.toString() ?? 'pending';
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primarySoft,
                    child: Icon(
                      collection == 'fleet_items'
                          ? Icons.directions_car
                          : Icons.badge,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle.toString(),
                          style: const TextStyle(color: AppTheme.primaryDark),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: approvalStatus == 'approved'
                                ? const Color(0xFFE6F2FF)
                                : approvalStatus == 'rejected'
                                ? const Color(0xFFDCEBFF)
                                : const Color(0xFFF8FBFF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            'Approval: ${approvalStatus.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }

  Widget _blueChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(icon, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.primaryDark, fontSize: 12),
            ),
          ],
        ),
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
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
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

  IconData _iconForName(String name) {
    switch (name) {
      case 'badge':
        return Icons.badge_outlined;
      case 'car_rental':
        return Icons.car_rental;
      case 'description':
        return Icons.description_outlined;
      case 'verified':
        return Icons.verified_outlined;
      case 'policy':
        return Icons.policy_outlined;
      default:
        return Icons.health_and_safety;
    }
  }
}
