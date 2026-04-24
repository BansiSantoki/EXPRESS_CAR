import 'HandleBussiness.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:express_car/services/car_image_widget.dart';
import 'package:express_car/HomeDetails/Booking/live_booking_tracking_page.dart';

class ManageBookingsPage extends StatefulWidget {
  const ManageBookingsPage({Key? key}) : super(key: key);

  @override
  _ManageBookingsPageState createState() => _ManageBookingsPageState();
}

class _ManageBookingsPageState extends State<ManageBookingsPage> {
  List<Map<String, dynamic>> bookings = [];
  bool _isLoading = true;
  int _totalBooked = 0;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> _markBookingPaid(Map<String, dynamic> booking) async {
    final bookingDocId = booking['booking_doc_id']?.toString() ?? '';
    if (bookingDocId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to mark paid: booking ID missing.'),
        ),
      );
      return;
    }

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

  @override
  void initState() {
    super.initState();
    _loadOwnerBookings();
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
            _isLoading = false;
          });
          return;
        }

        // Create a map of car data for easy lookup
        for (var doc in carsSnap.docs) {
          final carIdValue = doc['car_id'];
          final carId = carIdValue is int
              ? carIdValue
              : int.tryParse(carIdValue?.toString() ?? '') ?? 0;
          if (carId != 0) {
            carDataById[carId] = doc.data();
          }
        }

        // Get bookings for these cars
        bookingsSnap = await _firestore
            .collection('bookings')
            .where('car_id', whereIn: carIds)
            .get();
      }

      final List<Map<String, dynamic>> loaded = [];
      for (final doc in bookingsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
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
          'payment_status': data['payment_status']?.toString() ?? 'pending',
          'payment_method': data['payment_method']?.toString() ?? 'online',
          'payment_amount': data['payment_amount'] ?? data['total_amount'] ?? 0,
          'payment_id': data['payment_id']?.toString() ?? '',
          'payment_order_id': data['payment_order_id']?.toString() ?? '',
          'transaction_ref': data['transaction_ref']?.toString() ?? '',
          'paid_at': data['paid_at'],
          'image_url': imageUrl,
        });
      }

      setState(() {
        bookings = loaded;
        _totalBooked = loaded.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load bookings: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + Title + Menu
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Manage Bookings",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
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

              const SizedBox(height: 10),

              Text(
                "Total Booked Cars: $_totalBooked",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "Bookings for your cars",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (bookings.isEmpty
                          ? const Center(
                              child: Text(
                                "No bookings yet",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: bookings.length,
                              itemBuilder: (context, index) {
                                final booking = bookings[index];
                                final carName =
                                    booking['car_name'] ?? 'Unknown Car';
                                final carIdRaw = booking['car_id'];
                                final carId = carIdRaw is int
                                    ? carIdRaw
                                    : int.tryParse(
                                            carIdRaw?.toString() ?? '',
                                          ) ??
                                          0;
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
                                final userId = booking['user_id'] ?? '';
                                final fleetType =
                                    booking['fleet_type']?.toString() ??
                                    'driverless';
                                final rentalUnit =
                                    booking['rental_unit']?.toString() ?? 'day';
                                final rentalQty =
                                    booking['rental_quantity'] ?? 0;
                                final unitPrice = booking['unit_price'] ?? 0;
                                final pickupLocation =
                                    booking['pickup_location']?.toString() ??
                                    '';
                                final driverName =
                                    booking['driver_name']?.toString() ?? '';
                                final driverDetails =
                                    booking['driver_details']?.toString() ?? '';
                                final driverAadhar =
                                    booking['aadhar_card']?.toString() ?? '';
                                final driverLicense =
                                    booking['license_number']?.toString() ?? '';
                                final driverPan =
                                    booking['pan_card']?.toString() ?? '';
                                final userRating = booking['user_rating'];
                                final ratingValue = _toInt(userRating);
                                final userReview =
                                    booking['user_review']?.toString() ?? '';
                                final imageUrl =
                                    booking['image_url'] as String? ?? '';
                                final paymentStatus =
                                    booking['payment_status']?.toString() ??
                                    'pending';
                                final paymentMethod =
                                    booking['payment_method']?.toString() ??
                                    'online';
                                final paymentAmount =
                                    booking['payment_amount'] ?? 0;
                                final paymentId =
                                    booking['payment_id']?.toString() ?? '';
                                final paymentOrderId =
                                    booking['payment_order_id']?.toString() ??
                                    '';
                                final transactionRef =
                                    booking['transaction_ref']?.toString() ??
                                    '';
                                final paidAt = _formatTimestamp(
                                  booking['paid_at'],
                                );
                                final pickupLat = _toDouble(
                                  booking['pickup_lat'],
                                );
                                final pickupLng = _toDouble(
                                  booking['pickup_lng'],
                                );
                                final driverStatus = driverName.isNotEmpty
                                    ? '$driverName is taking this car'
                                    : (fleetType == 'with_driver'
                                          ? 'Driver will be assigned by admin/company'
                                          : 'Self-drive booking by user');

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      // Car Image
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          height: 50,
                                          width: 70,
                                          child: CarApiImage(
                                            imageUrl: imageUrl,
                                            fallbackAssetPath:
                                                'assets/images/Honda City.jpg',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Car details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              carName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              "$startDate → $endDate",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              "Unit: $rentalQty $rentalUnit @ ₹$unitPrice/$rentalUnit",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              "User: $userEmail",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            if (userId.toString().isNotEmpty)
                                              Text(
                                                "User ID: $userId",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            Text(
                                              "Type: ${fleetType == 'with_driver' ? 'With Driver' : 'Driverless'}",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            if (pickupLocation.isNotEmpty)
                                              Text(
                                                "Pickup: $pickupLocation",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            if (driverName.isNotEmpty)
                                              Text(
                                                "Driver: $driverName",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            if (driverDetails.isNotEmpty)
                                              Text(
                                                "Driver Details: $driverDetails",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            if (driverAadhar.isNotEmpty)
                                              Text(
                                                "Aadhar: $driverAadhar",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            if (driverLicense.isNotEmpty)
                                              Text(
                                                "License: $driverLicense",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            if (driverPan.isNotEmpty)
                                              Text(
                                                "PAN: $driverPan",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            Text(
                                              "Driver Status: $driverStatus",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF1E40AF),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (ratingValue != null &&
                                                ratingValue > 0)
                                              Row(
                                                children: [
                                                  const Text(
                                                    "Rating: ",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  ...List.generate(5, (i) {
                                                    return Icon(
                                                      i < ratingValue
                                                          ? Icons.star
                                                          : Icons.star_border,
                                                      size: 12,
                                                      color: const Color(
                                                        0xFFFFB000,
                                                      ),
                                                    );
                                                  }),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "$ratingValue/5",
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            if (userReview.isNotEmpty)
                                              Text(
                                                "Review: $userReview",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            Text(
                                              "Total: ₹$totalAmount",
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Payment: ${paymentStatus.toUpperCase()} ($paymentMethod)",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    paymentStatus
                                                            .toLowerCase() ==
                                                        'paid'
                                                    ? const Color(0xFF166534)
                                                    : paymentStatus
                                                              .toLowerCase() ==
                                                          'failed'
                                                    ? const Color(0xFF991B1B)
                                                    : const Color(0xFF92400E),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              "Payment Amount: ₹$paymentAmount",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            if (paymentId.isNotEmpty)
                                              Text(
                                                "Payment ID: $paymentId",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            if (paymentOrderId.isNotEmpty)
                                              Text(
                                                "Order ID: $paymentOrderId",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            if (transactionRef.isNotEmpty)
                                              Text(
                                                "Txn Ref: $transactionRef",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            if (paidAt.isNotEmpty)
                                              Text(
                                                "Paid At: $paidAt",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            if (paymentStatus.toLowerCase() !=
                                                'paid')
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 6,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _markBookingPaid(
                                                          booking,
                                                        ),
                                                    icon: const Icon(
                                                      Icons.verified,
                                                      size: 16,
                                                    ),
                                                    label: const Text(
                                                      'Mark as Paid',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 6),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: OutlinedButton.icon(
                                                onPressed: carId == 0
                                                    ? null
                                                    : () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                LiveBookingTrackingPage(
                                                                  carId: carId,
                                                                  carName: carName
                                                                      .toString(),
                                                                  fallbackLat:
                                                                      pickupLat,
                                                                  fallbackLng:
                                                                      pickupLng,
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                icon: const Icon(
                                                  Icons.location_on,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Track Car',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 8),
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

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal().toString();
    }
    return '';
  }
}
