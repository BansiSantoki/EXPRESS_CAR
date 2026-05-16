// ignore_for_file: file_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'HandleBussiness.dart';
import 'manage_booking.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoadingStats = true;
  int _totalCars = 0;
  int _activeBookings = 0;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    try {
      // 1. Fetch Total Cars
      final carsSnap = await FirebaseFirestore.instance
          .collection('cars')
          .count()
          .get();
      final carsCount = carsSnap.count ?? 0;

      // 2. Fetch Active Bookings
      final bookingsSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .count()
          .get();
      final bookingsCount = bookingsSnap.count ?? 0;

      // 3. Fetch Total Revenue (Manual sum to avoid AggregateQuerySnapshot versioning issues)
      final revenueSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('payment_status', isEqualTo: 'paid')
          .get();

      double revenue = 0.0;
      for (var doc in revenueSnap.docs) {
        final data = doc.data();
        revenue += (data['payment_amount'] as num?)?.toDouble() ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _totalCars = carsCount;
          _activeBookings = bookingsCount;
          _totalRevenue = revenue;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching dashboard stats: $e");
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Text(
                    "Dashboard",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HandleBusinessPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Total Revenue Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total Revenue",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFE6F4EA,
                        ), // Light green background
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: _isLoadingStats
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              "₹ ${_totalRevenue.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534), // Dark green text
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Info cards (Total Cars & Active Bookings)
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      "Total Cars",
                      _isLoadingStats ? "..." : _totalCars.toString(),
                      Icons.directions_car_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      "Total Bookings",
                      _isLoadingStats ? "..." : _activeBookings.toString(),
                      Icons.assignment_turned_in_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                "Recent Bookings",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Live Recent Bookings Stream
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .orderBy('created_at', descending: true)
                      .limit(5) // Only show the 5 most recent
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          "Unable to load recent bookings.",
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No bookings found.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;

                        final carName =
                            data['car_name']?.toString() ?? 'Unknown Car';
                        final rentalQty =
                            data['rental_quantity']?.toString() ?? '0';
                        final rentalUnit =
                            data['rental_unit']?.toString() ?? 'day';
                        final startDate =
                            data['start_date']?.toString().substring(0, 10) ??
                            'N/A';
                        final endDate =
                            data['end_date']?.toString().substring(0, 10) ??
                            'N/A';
                        final status =
                            data['payment_status']?.toString().toLowerCase() ??
                            'pending';

                        Color statusBgColor;
                        Color statusTextColor;

                        if (status == 'paid') {
                          statusBgColor = const Color(0xFFDCFCE7);
                          statusTextColor = const Color(0xFF166534);
                        } else if (status == 'failed') {
                          statusBgColor = const Color(0xFFFEE2E2);
                          statusTextColor = const Color(0xFF991B1B);
                        } else {
                          statusBgColor = const Color(0xFFFEF3C7);
                          statusTextColor = const Color(0xFF92400E);
                        }

                        return _buildBookingItem(
                          car: carName,
                          duration: "$rentalQty $rentalUnit(s)",
                          date: "$startDate → $endDate",
                          status: status.toUpperCase(),
                          statusColor: statusBgColor,
                          textColor: statusTextColor,
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // View All Bookings Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F221A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageBookingsPage(),
                      ),
                    );
                  },
                  child: const Text(
                    "View All Bookings",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable info card
  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.black54),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Reusable booking item
  Widget _buildBookingItem({
    required String car,
    required String duration,
    required String date,
    required String status,
    required Color statusColor,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Car info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  car,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "$duration • $date",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
