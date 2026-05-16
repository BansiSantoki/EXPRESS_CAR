// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:express_car/services/car_image_widget.dart';
import 'package:express_car/HomeDetails/Booking/live_booking_tracking_page.dart';
import 'package:express_car/theme/app_theme.dart';
import 'HandleBussiness.dart';

class ManageBookingsPage extends StatefulWidget {
  const ManageBookingsPage({super.key});

  @override
  State<ManageBookingsPage> createState() => _ManageBookingsPageState();
}

class _ManageBookingsPageState extends State<ManageBookingsPage> {
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> _availableDrivers = [];
  bool _isLoading = true;
  int _totalBooked = 0;
  double _filteredRevenue = 0.0;
  DateTimeRange? _dateRange;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _fetchAvailableDrivers();
    _loadOwnerBookings();
  }

  Future<void> _fetchAvailableDrivers() async {
    try {
      final snap = await _firestore
          .collection('driver_documents')
          .where('approvalStatus', isEqualTo: 'approved')
          .get();

      if (mounted) {
        setState(() {
          _availableDrivers = snap.docs.map((doc) {
            return {'doc_id': doc.id, ...doc.data()};
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching drivers: $e");
    }
  }

  Future<void> _loadOwnerBookings() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      final QuerySnapshot bookingsSnap;
      final Map<int, Map<String, dynamic>> carDataById = {};

      if (user == null) {
        final allCarsSnap = await _firestore.collection('cars').get();
        for (final doc in allCarsSnap.docs) {
          final data = doc.data();
          final carIdValue = data['car_id'];
          final carId = carIdValue is int
              ? carIdValue
              : int.tryParse(carIdValue?.toString() ?? '') ?? 0;
          if (carId != 0) {
            carDataById[carId] = data;
          }
        }
        bookingsSnap = await _firestore.collection('bookings').get();
      } else {
        // Get all cars owned by this user
        final carsSnap = await _firestore
            .collection('cars')
            .where('owner_email', isEqualTo: user.email)
            .get();

        final carIds = carsSnap.docs
            .map((doc) {
              final carIdValue = doc['car_id'];
              return carIdValue is int
                  ? carIdValue
                  : int.tryParse(carIdValue?.toString() ?? '') ?? 0;
            })
            .where((value) => value != 0)
            .toList();

        if (carIds.isEmpty) {
          setState(() {
            bookings = [];
            _totalBooked = 0;
            _filteredRevenue = 0.0;
            _isLoading = false;
          });
          return;
        }

        for (var doc in carsSnap.docs) {
          final carIdValue = doc['car_id'];
          final carId = carIdValue is int
              ? carIdValue
              : int.tryParse(carIdValue?.toString() ?? '') ?? 0;
          if (carId != 0) {
            carDataById[carId] = doc.data();
          }
        }

        bookingsSnap = await _firestore
            .collection('bookings')
            .where('car_id', whereIn: carIds)
            .get();
      }

      List<Map<String, dynamic>> loaded = [];
      double calculatedRevenue = 0.0;

      for (final doc in bookingsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};

        // Date Filtering Logic
        DateTime? createdAt;
        if (data['created_at'] is Timestamp) {
          createdAt = (data['created_at'] as Timestamp).toDate();
        } else if (data['createdAt'] is Timestamp) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        }

        if (_dateRange != null && createdAt != null) {
          // If outside the selected date range, skip this booking
          if (createdAt.isBefore(_dateRange!.start) ||
              createdAt.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
            continue;
          }
        }

        final carIdValue = data['car_id'];
        final carId = carIdValue is int
            ? carIdValue
            : int.tryParse(carIdValue?.toString() ?? '') ?? 0;
        final carData = carDataById[carId] ?? <String, dynamic>{};
        final imageUrl =
            data['image_url']?.toString() ??
            carData['image_url']?.toString() ??
            '';

        final driverDocs = data['driver_documents'];
        final driverDocsMap = driverDocs is Map
            ? driverDocs.map((key, value) => MapEntry(key.toString(), value))
            : <String, dynamic>{};

        final driverName =
            data['driver_name']?.toString() ??
            (driverDocsMap['driver_name']?.toString() ?? '');
        final driverDetails =
            data['driver_details']?.toString() ??
            (driverDocsMap['driver_details']?.toString() ?? '');
        final driverAadhar =
            data['aadhar_card']?.toString() ??
            (driverDocsMap['aadhar_card']?.toString() ?? '');
        final driverLicense =
            data['license_number']?.toString() ??
            (driverDocsMap['license_number']?.toString() ?? '');
        final driverPan =
            data['pan_card']?.toString() ??
            (driverDocsMap['pan_card']?.toString() ?? '');

        final paymentStatus = data['payment_status']?.toString() ?? 'pending';
        final paymentAmount =
            (data['payment_amount'] as num?)?.toDouble() ??
            (data['total_amount'] as num?)?.toDouble() ??
            0.0;

        if (paymentStatus.toLowerCase() == 'paid') {
          calculatedRevenue += paymentAmount;
        }

        loaded.add({
          'booking_id': data['booking_id']?.toString() ?? doc.id,
          'booking_doc_id': doc.id,
          'car_id': carId,
          'car_name': data['car_name']?.toString() ?? 'Car $carId',
          'user_email': data['user_mail']?.toString() ?? 'unknown',
          'user_id': data['userId']?.toString() ?? '',
          'fleet_type':
              (data['fleet_type'] ?? data['fleetType'] ?? 'driverless')
                  .toString(),
          'booking_status':
              data['booking_status']?.toString() ??
              data['status']?.toString() ??
              'pending',
          'rental_unit': data['rental_unit']?.toString() ?? 'day',
          'rental_quantity': data['rental_quantity'] ?? 0,
          'unit_price': data['unit_price'] ?? 0,
          'start_date': data['start_date']?.toString() ?? '',
          'end_date': data['end_date']?.toString() ?? '',
          'pickup_location': data['pickup_location']?.toString() ?? '',
          'pickup_lat': data['pickup_lat'],
          'pickup_lng': data['pickup_lng'],
          'driver_name': driverName,
          'driver_details': driverDetails,
          'aadhar_card': driverAadhar,
          'license_number': driverLicense,
          'pan_card': driverPan,
          'user_rating': data['user_rating'],
          'user_review': data['user_review']?.toString() ?? '',
          'total_amount': data['total_amount'] ?? 0,
          'payment_status': paymentStatus,
          'payment_method': data['payment_method']?.toString() ?? 'online',
          'payment_amount': paymentAmount,
          'payment_id': data['payment_id']?.toString() ?? '',
          'payment_order_id': data['payment_order_id']?.toString() ?? '',
          'transaction_ref': data['transaction_ref']?.toString() ?? '',
          'paid_at': data['paid_at'],
          'created_at': createdAt,
          'image_url': imageUrl,
        });
      }

      // Sort by newest first
      loaded.sort((a, b) {
        final aDate =
            a['created_at'] as DateTime? ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            b['created_at'] as DateTime? ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      setState(() {
        bookings = loaded;
        _totalBooked = loaded.length;
        _filteredRevenue = calculatedRevenue;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load bookings: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markBookingPaid(Map<String, dynamic> booking) async {
    final bookingDocId = booking['booking_doc_id']?.toString() ?? '';
    if (bookingDocId.isEmpty) return;

    try {
      await _firestore.collection('bookings').doc(bookingDocId).set({
        'payment_status': 'paid',
        'payment_method': 'cash_on_pickup',
        'payment_time': FieldValue.serverTimestamp(),
        'paid_at': FieldValue.serverTimestamp(),
        'payment_id': 'CASH_PICKUP',
        'payment_order_id': '',
        'transaction_ref': 'CASH-${DateTime.now().millisecondsSinceEpoch}',
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Booking marked as paid.')));
      await _loadOwnerBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to mark paid: $e')));
    }
  }

  Future<void> _updateBookingStatus(String docId, String newStatus) async {
    try {
      await _firestore.collection('bookings').doc(docId).set({
        'booking_status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
      await _loadOwnerBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  Future<void> _assignDriver(
    String docId,
    Map<String, dynamic> driverData,
  ) async {
    try {
      await _firestore.collection('bookings').doc(docId).set({
        'driver_name': driverData['driverName'] ?? '',
        'driver_details': driverData['phone'] ?? '',
        'aadhar_card': driverData['aadhaarNumber'] ?? '',
        'license_number': driverData['licenseNumber'] ?? '',
        'pan_card':
            driverData['permitNumber'] ??
            '', // Using permit as PAN fallback if needed
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver assigned successfully')),
      );
      await _loadOwnerBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to assign driver: $e')));
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
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
      setState(() => _dateRange = picked);
      _loadOwnerBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + Title + Menu
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Manage Bookings",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
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

              const SizedBox(height: 16),

              // Filter & Stats Row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Filter by Date",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                        if (_dateRange != null)
                          InkWell(
                            onTap: () {
                              setState(() => _dateRange = null);
                              _loadOwnerBookings();
                            },
                            child: const Text(
                              "Clear Filter",
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _dateRange == null
                              ? "All Time"
                              : "${_dateRange!.start.toString().substring(0, 10)} to ${_dateRange!.end.toString().substring(0, 10)}",
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryDark,
                          side: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Total Bookings",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              "$_totalBooked",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ink,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              "Revenue (Paid)",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              "₹${_filteredRevenue.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (bookings.isEmpty
                          ? const Center(
                              child: Text(
                                "No bookings found for this period.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: bookings.length,
                              itemBuilder: (context, index) {
                                final booking = bookings[index];
                                final docId = booking['booking_doc_id'];
                                final carName =
                                    booking['car_name'] ?? 'Unknown Car';
                                final carId = booking['car_id'] as int;
                                final startDate =
                                    booking['start_date']?.toString().substring(
                                      0,
                                      10,
                                    ) ??
                                    'N/A';
                                final endDate =
                                    booking['end_date']?.toString().substring(
                                      0,
                                      10,
                                    ) ??
                                    'N/A';
                                final totalAmount =
                                    booking['total_amount'] ?? 0;
                                final userEmail =
                                    booking['user_email'] ?? 'unknown';
                                final fleetType =
                                    booking['fleet_type']?.toString() ??
                                    'driverless';
                                final bookingStatus =
                                    booking['booking_status']
                                        ?.toString()
                                        .toLowerCase() ??
                                    'pending';
                                final paymentStatus =
                                    booking['payment_status']?.toString() ??
                                    'pending';
                                final driverName =
                                    booking['driver_name']?.toString() ?? '';
                                final imageUrl =
                                    booking['image_url'] as String? ?? '';
                                final pickupLat = _toDouble(
                                  booking['pickup_lat'],
                                );
                                final pickupLng = _toDouble(
                                  booking['pickup_lng'],
                                );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: AppTheme.border),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.03,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header: Image & Basic Info
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: SizedBox(
                                                height: 60,
                                                width: 80,
                                                child: CarApiImage(
                                                  imageUrl: imageUrl,
                                                  fallbackAssetPath:
                                                      'assets/images/Honda City.jpg',
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    carName,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppTheme.ink,
                                                    ),
                                                  ),
                                                  Text(
                                                    "$startDate → $endDate",
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "User: $userEmail",
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppTheme.primaryDark,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  "₹$totalAmount",
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppTheme.ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        paymentStatus
                                                                .toLowerCase() ==
                                                            'paid'
                                                        ? const Color(
                                                            0xFFDCFCE7,
                                                          )
                                                        : const Color(
                                                            0xFFFEF3C7,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    paymentStatus.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color:
                                                          paymentStatus
                                                                  .toLowerCase() ==
                                                              'paid'
                                                          ? const Color(
                                                              0xFF166534,
                                                            )
                                                          : const Color(
                                                              0xFF92400E,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      const Divider(height: 1),

                                      // Interactive Controls
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          children: [
                                            // Booking Status Dropdown
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.info_outline,
                                                  size: 18,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  "Status:",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.ink,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Container(
                                                    height: 36,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFF8F9FA,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: AppTheme.border,
                                                      ),
                                                    ),
                                                    child: DropdownButtonHideUnderline(
                                                      child: DropdownButton<String>(
                                                        value:
                                                            [
                                                              'pending',
                                                              'active',
                                                              'completed',
                                                              'cancelled',
                                                            ].contains(
                                                              bookingStatus,
                                                            )
                                                            ? bookingStatus
                                                            : 'pending',
                                                        isExpanded: true,
                                                        icon: const Icon(
                                                          Icons.arrow_drop_down,
                                                          size: 20,
                                                        ),
                                                        items: const [
                                                          DropdownMenuItem(
                                                            value: 'pending',
                                                            child: Text(
                                                              'Pending',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ),
                                                          DropdownMenuItem(
                                                            value: 'active',
                                                            child: Text(
                                                              'Active',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ),
                                                          DropdownMenuItem(
                                                            value: 'completed',
                                                            child: Text(
                                                              'Completed',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ),
                                                          DropdownMenuItem(
                                                            value: 'cancelled',
                                                            child: Text(
                                                              'Cancelled',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                        onChanged: (val) {
                                                          if (val != null &&
                                                              val !=
                                                                  bookingStatus) {
                                                            _updateBookingStatus(
                                                              docId,
                                                              val,
                                                            );
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 10),

                                            // Driver Assignment (Only for 'with_driver')
                                            if (fleetType == 'with_driver')
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .person_pin_circle_outlined,
                                                    size: 18,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    "Driver:",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppTheme.ink,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Container(
                                                      height: 36,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFF8F9FA,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              AppTheme.border,
                                                        ),
                                                      ),
                                                      child: DropdownButtonHideUnderline(
                                                        child: DropdownButton<String>(
                                                          value:
                                                              driverName.isEmpty
                                                              ? null
                                                              : driverName,
                                                          hint: const Text(
                                                            "Assign Driver",
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          isExpanded: true,
                                                          icon: const Icon(
                                                            Icons
                                                                .arrow_drop_down,
                                                            size: 20,
                                                          ),
                                                          items: _availableDrivers.map((
                                                            driver,
                                                          ) {
                                                            return DropdownMenuItem<
                                                              String
                                                            >(
                                                              value:
                                                                  driver['driverName'],
                                                              child: Text(
                                                                driver['driverName'],
                                                                style:
                                                                    const TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                          onChanged: (val) {
                                                            if (val != null &&
                                                                val !=
                                                                    driverName) {
                                                              final selectedDriver =
                                                                  _availableDrivers
                                                                      .firstWhere(
                                                                        (d) =>
                                                                            d['driverName'] ==
                                                                            val,
                                                                      );
                                                              _assignDriver(
                                                                docId,
                                                                selectedDriver,
                                                              );
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),

                                            if (fleetType == 'driverless')
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.person_off_outlined,
                                                    size: 18,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    "Driver:",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppTheme.ink,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      driverName.isNotEmpty
                                                          ? "Self-Drive ($driverName)"
                                                          : "Self-Drive (Pending Docs)",
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: AppTheme
                                                            .primaryDark,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Action Buttons
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF8F9FA),
                                          borderRadius: BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (paymentStatus.toLowerCase() !=
                                                'paid')
                                              TextButton.icon(
                                                onPressed: () =>
                                                    _markBookingPaid(booking),
                                                icon: const Icon(
                                                  Icons.verified,
                                                  size: 16,
                                                  color: Color(0xFF166534),
                                                ),
                                                label: const Text(
                                                  'Mark Paid',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF166534),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: carId == 0
                                                  ? null
                                                  : () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              LiveBookingTrackingPage(
                                                                carId: carId,
                                                                carName:
                                                                    carName,
                                                                fallbackLat:
                                                                    pickupLat,
                                                                fallbackLng:
                                                                    pickupLng,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppTheme.primary,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 0,
                                                    ),
                                                minimumSize: const Size(0, 32),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.location_on,
                                                size: 14,
                                              ),
                                              label: const Text(
                                                'Track',
                                                style: TextStyle(
                                                  fontSize: 12,
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
                            )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
