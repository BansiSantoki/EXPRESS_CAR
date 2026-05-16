import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:express_car/theme/app_theme.dart';

class UserVerificationDetailsPage extends StatefulWidget {
  final String bookingDocId;
  final Map<String, dynamic> bookingData;

  const UserVerificationDetailsPage({
    super.key,
    required this.bookingDocId,
    required this.bookingData,
  });

  @override
  State<UserVerificationDetailsPage> createState() =>
      _UserVerificationDetailsPageState();
}

class _UserVerificationDetailsPageState
    extends State<UserVerificationDetailsPage> {
  late String _verificationStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _verificationStatus =
        widget.bookingData['driver_verification_status']?.toString() ??
        'pending';
  }

  Future<void> _updateVerificationStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingDocId)
          .update({
            'driver_verification_status': newStatus,
            'updated_at': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        setState(() {
          _verificationStatus = newStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification status updated to ${newStatus.toUpperCase()}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        widget.bookingData['driver_name']?.toString() ?? 'Unknown User';
    final userDetails =
        widget.bookingData['driver_details']?.toString() ?? 'N/A';
    final aadhaar = widget.bookingData['aadhar_card']?.toString() ?? 'N/A';
    final license = widget.bookingData['license_number']?.toString() ?? 'N/A';
    final pan = widget.bookingData['pan_card']?.toString() ?? 'N/A';
    final bookingId =
        widget.bookingData['booking_id']?.toString() ?? widget.bookingDocId;
    final carName = widget.bookingData['car_name']?.toString() ?? 'Unknown Car';

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('User Verification')),
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
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFFFFF4D8),
                      child: Icon(
                        Icons.person_search,
                        size: 40,
                        color: Color(0xFFFFB000),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userDetails,
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

              // Booking Context
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
                      'Booking Context',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Booking ID', bookingId),
                    const Divider(),
                    _buildInfoRow('Car', carName),
                    const Divider(),
                    _buildInfoRow(
                      'Start Date',
                      widget.bookingData['start_date']?.toString().substring(
                            0,
                            10,
                          ) ??
                          'N/A',
                    ),
                    const Divider(),
                    _buildInfoRow(
                      'End Date',
                      widget.bookingData['end_date']?.toString().substring(
                            0,
                            10,
                          ) ??
                          'N/A',
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
                      'Verification Status',
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
                            'Status:',
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
                                    ].contains(_verificationStatus)
                                    ? _verificationStatus
                                    : 'pending',
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _verificationStatus == 'approved'
                                      ? const Color(0xFF166534)
                                      : (_verificationStatus == 'rejected'
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
                                            val != _verificationStatus) {
                                          _updateVerificationStatus(val);
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
                      'Submitted Documents',
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
                    const Divider(),
                    _buildInfoRow('PAN Card', pan),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFFD97706),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'User document images are not currently uploaded during checkout. Please verify these details manually against physical documents upon vehicle pickup.',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
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
}
