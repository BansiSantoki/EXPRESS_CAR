import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:express_car/theme/app_theme.dart';

import 'add_driver_page.dart';
import 'driver_details_page.dart';
import 'user_verification_details_page.dart';

class DriverManagementPage extends StatefulWidget {
  const DriverManagementPage({super.key});

  @override
  State<DriverManagementPage> createState() => _DriverManagementPageState();
}

class _DriverManagementPageState extends State<DriverManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Driver Management'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.primaryDark,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Company Drivers'),
            Tab(text: 'User Verifications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCompanyDriversTab(), _buildUserVerificationsTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddDriverPage()),
          );
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(
          'Add Driver',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildCompanyDriversTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('driver_documents')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No company drivers added yet.',
              style: TextStyle(color: AppTheme.primaryDark),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Padding for FAB
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final docId = snapshot.data!.docs[index].id;
            final data =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final title = data['driverName'] ?? 'Untitled';
            final subtitle = data['availability'] ?? 'Unknown';
            final approvalStatus =
                data['approvalStatus']?.toString() ?? 'pending';
            final photoUrl = data['photoUrl']
                ?.toString(); // 🚀 NEW: Fetch photo URL

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DriverDetailsPage(docId: docId, driverData: data),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 🚀 NEW: Display Driver Photo in the list
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.primarySoft,
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? const Icon(Icons.person, color: AppTheme.primary)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Availability: ${subtitle.toString().toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(approvalStatus),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserVerificationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('driver_documents_required', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No user verifications pending.',
              style: TextStyle(color: AppTheme.primaryDark),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final docId = snapshot.data!.docs[index].id;
            final data =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;

            final userName = data['driver_name']?.toString() ?? 'Unknown User';
            final bookingId = data['booking_id']?.toString() ?? docId;
            final verificationStatus =
                data['driver_verification_status']?.toString() ?? 'pending';

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserVerificationDetailsPage(
                      bookingDocId: docId,
                      bookingData: data,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFFFFF4D8),
                      child: Icon(
                        Icons.person_search,
                        color: Color(0xFFFFB000),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Booking: $bookingId',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(verificationStatus),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'approved':
        bgColor = const Color(0xFFE6F2FF);
        textColor = const Color(0xFF0066CC);
        break;
      case 'rejected':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        break;
      default:
        bgColor = const Color(0xFFF8FBFF);
        textColor = AppTheme.primaryDark;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}
