import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:express_car/theme/app_theme.dart';

class DriverDetailsPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> driverData;

  const DriverDetailsPage({
    super.key,
    required this.docId,
    required this.driverData,
  });

  @override
  State<DriverDetailsPage> createState() => _DriverDetailsPageState();
}

class _DriverDetailsPageState extends State<DriverDetailsPage> {
  late String _approvalStatus;
  late String _availability;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _approvalStatus =
        widget.driverData['approvalStatus']?.toString() ?? 'pending';
    _availability =
        widget.driverData['availability']?.toString() ?? 'available';
  }

  Future<void> _updateField(String field, String value) async {
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('driver_documents')
          .doc(widget.docId)
          .update({field: value, 'updatedAt': FieldValue.serverTimestamp()});

      if (mounted) {
        setState(() {
          if (field == 'approvalStatus') _approvalStatus = value;
          if (field == 'availability') _availability = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${field == 'approvalStatus' ? 'Approval Status' : 'Availability'} updated to ${value.toUpperCase()}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverName =
        widget.driverData['driverName']?.toString() ?? 'Unknown Driver';
    final phone = widget.driverData['phone']?.toString() ?? 'N/A';
    final aadhaar = widget.driverData['aadhaarNumber']?.toString() ?? 'N/A';
    final license = widget.driverData['licenseNumber']?.toString() ?? 'N/A';
    final photoUrl = widget.driverData['photoUrl']
        ?.toString(); // 🚀 NEW: Fetch photo URL

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('Driver Details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 🚀 NEW: Display Driver Photo
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.primarySoft,
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? const Icon(
                              Icons.person,
                              size: 40,
                              color: AppTheme.primary,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      driverName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Status Controls
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Approval:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value:
                                    [
                                      'pending',
                                      'approved',
                                      'rejected',
                                    ].contains(_approvalStatus)
                                    ? _approvalStatus
                                    : 'pending',
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _approvalStatus == 'approved'
                                      ? const Color(0xFF166534)
                                      : (_approvalStatus == 'rejected'
                                            ? const Color(0xFF991B1B)
                                            : AppTheme.primaryDark),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'pending',
                                    child: Text('PENDING'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'approved',
                                    child: Text('APPROVED'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'rejected',
                                    child: Text('REJECTED'),
                                  ),
                                ],
                                onChanged: _isUpdating
                                    ? null
                                    : (val) {
                                        if (val != null &&
                                            val != _approvalStatus) {
                                          _updateField('approvalStatus', val);
                                        }
                                      },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Availability:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value:
                                    [
                                      'available',
                                      'busy',
                                      'inactive',
                                    ].contains(_availability)
                                    ? _availability
                                    : 'available',
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.ink,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'available',
                                    child: Text('AVAILABLE'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'busy',
                                    child: Text('BUSY'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'inactive',
                                    child: Text('INACTIVE'),
                                  ),
                                ],
                                onChanged: _isUpdating
                                    ? null
                                    : (val) {
                                        if (val != null &&
                                            val != _availability) {
                                          _updateField('availability', val);
                                        }
                                      },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Text Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Document Numbers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Aadhaar', aadhaar),
                    const Divider(),
                    _buildInfoRow('License', license),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Images
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Uploaded Images',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDocImage(
                      'Aadhaar Front',
                      widget.driverData['aadhaarFrontUrl'],
                    ),
                    _buildDocImage(
                      'Aadhaar Back',
                      widget.driverData['aadhaarBackUrl'],
                    ),
                    _buildDocImage(
                      'Driving License',
                      widget.driverData['licenseUrl'],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocImage(String label, String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.grey, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'Image failed to load',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
