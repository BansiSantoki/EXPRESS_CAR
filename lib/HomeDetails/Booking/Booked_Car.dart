import 'package:flutter/material.dart';
import 'package:express_car/HomeDetails/Home_Page/car_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:express_car/theme/app_theme.dart';
import 'package:express_car/services/car_image_widget.dart';
import 'package:express_car/HomeDetails/Booking/live_booking_tracking_page.dart';
import 'package:express_car/HomeDetails/Booking/booking_details_page.dart';
import 'package:express_car/HomeDetails/Booking/payment_page.dart';

class BookedCar extends StatefulWidget {
  final List<Map<String, dynamic>> bookedCars;

  const BookedCar({super.key, required this.bookedCars});

  @override
  State<BookedCar> createState() => _BookedCarState();
}

class _BookedCarState extends State<BookedCar> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> cancelBooking(String bookingDocId, Car? car) async {
    if (bookingDocId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to cancel: booking id missing.')),
      );
      return;
    }

    try {
      // Instead of deleting, we update the status to 'cancelled' to keep the record
      await _firestore.collection('bookings').doc(bookingDocId).update({
        'booking_status': 'cancelled',
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${car != null ? car.name : 'Booking'} cancelled successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Failed to cancel booking doc $bookingDocId: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to cancel booking: $e')));
    }
  }

  // Helper to parse dates for local sorting
  DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String)
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
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
              const Text(
                "My Bookings",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Track, manage, and review your rentals.",
                style: TextStyle(color: AppTheme.primaryDark, fontSize: 14),
              ),
              const SizedBox(height: 20),

              Expanded(child: _buildBookingsStream()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in to see your bookings."));
    }

    return StreamBuilder<QuerySnapshot>(
      // 🚀 FIX: Removed .orderBy() to prevent the missing index crash.
      // We will sort the documents locally in Dart instead.
      stream: _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint(snapshot.error.toString());
          return const Center(child: Text("Unable to load bookings."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 60,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                const Text(
                  "No Cars Booked Yet",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        // 🚀 FIX: Sort documents locally by created_at descending
        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = _parseDateTime(
            aData['created_at'] ?? aData['createdAt'],
          );
          final bTime = _parseDateTime(
            bData['created_at'] ?? bData['createdAt'],
          );
          return bTime.compareTo(aTime); // Descending order
        });

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _buildBookingCard(docs[index]);
          },
        );
      },
    );
  }

  Widget _buildBookingCard(DocumentSnapshot bookingDoc) {
    final booking = bookingDoc.data() as Map<String, dynamic>;
    final carId = booking['car_id'];
    final bookingDocId = bookingDoc.id;
    final sourceCollection =
        booking['car_source_collection']?.toString() ?? 'cars';
    final sourceDocId = booking['car_source_doc_id']?.toString() ?? '';
    final pickupLat = _toDouble(booking['pickup_lat']);
    final pickupLng = _toDouble(booking['pickup_lng']);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadBookedCarData(
        carId: carId,
        sourceCollection: sourceCollection,
        sourceDocId: sourceDocId,
      ),
      builder: (context, carSnapshot) {
        if (!carSnapshot.hasData) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final carData = carSnapshot.data;
        final Car car = carData != null
            ? Car.fromFirestore(carData)
            : Car.fromFirestore({}); // Fallback for missing car

        final startDate = booking['start_date'] ?? '';
        final endDate = booking['end_date'] ?? '';
        final fleetType =
            (booking['fleet_type'] ?? booking['fleetType'] ?? car.fleetType)
                .toString();
        final paymentStatus = _normalizePaymentStatus(
          booking['payment_status'],
        );
        final isPaid = paymentStatus == 'paid';
        final paymentAmount =
            (booking['payment_amount'] as num?) ??
            (booking['total_amount'] as num?) ??
            0;
        final paymentMethod =
            booking['payment_method']?.toString().trim().isNotEmpty == true
            ? booking['payment_method'].toString().trim()
            : 'cash_on_pickup';

        final bookingStatus =
            booking['booking_status']?.toString().toLowerCase() ?? 'pending';
        final isCancelled = bookingStatus == 'cancelled';

        // Driver & Verification Info
        final driverName = booking['driver_name']?.toString() ?? '';
        final driverPhone = booking['driver_details']?.toString() ?? '';
        final verificationStatus =
            booking['driver_verification_status']?.toString() ?? 'pending';

        Widget driverInfoWidget = const SizedBox.shrink();

        if (fleetType == 'with_driver') {
          if (driverName.isNotEmpty) {
            driverInfoWidget = Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_pin,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver: $driverName',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppTheme.ink,
                          ),
                        ),
                        if (driverPhone.isNotEmpty)
                          Text(
                            'Phone: $driverPhone',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            driverInfoWidget = Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                'Driver: Pending Assignment',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
        } else if (fleetType == 'driverless') {
          Color vColor = verificationStatus == 'approved'
              ? const Color(0xFF166534)
              : (verificationStatus == 'rejected'
                    ? const Color(0xFF991B1B)
                    : const Color(0xFF92400E));
          driverInfoWidget = Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              'Docs Verification: ${verificationStatus.toUpperCase()}',
              style: TextStyle(
                fontSize: 12,
                color: vColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 380;

              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          car.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isCancelled ? Colors.grey : AppTheme.ink,
                            decoration: isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (isCancelled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CANCELLED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Dates: ${startDate.isNotEmpty ? startDate.substring(0, 10) : 'N/A'} to ${endDate.isNotEmpty ? endDate.substring(0, 10) : 'N/A'}",
                    style: const TextStyle(
                      color: AppTheme.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Location: ${car.location}",
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Type: ${fleetType == 'with_driver' ? 'With Driver' : 'Driverless'}",
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),

                  driverInfoWidget,

                  const SizedBox(height: 6),
                  _buildPaymentStatusBadge(paymentStatus),
                  if (!isPaid && !isCancelled)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Payment Mode: Cash on Pickup/Delivery',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              );

              final paidBadge = Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 16, color: Color(0xFF166534)),
                      SizedBox(width: 6),
                      Text(
                        'Paid',
                        style: TextStyle(
                          color: Color(0xFF166534),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final cancelButton = Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => cancelBooking(bookingDocId, car),
                  child: const Text(
                    "Cancel Booking",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              );

              final ratingButton = Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D3A5B),
                    side: const BorderSide(color: Color(0xFFBFD7FF)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (!isPaid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please complete payment before rating.',
                          ),
                        ),
                      );
                      return;
                    }

                    final bookingPayload = Map<String, dynamic>.from(booking);
                    bookingPayload['booking_id'] =
                        bookingPayload['booking_id']
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true
                        ? bookingPayload['booking_id']
                        : bookingDocId;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            BookingDetailsPage(booking: bookingPayload),
                      ),
                    );
                  },
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: const Text(
                    'Rate & Review',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );

              final trackButton = Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D3A5B),
                    side: const BorderSide(color: Color(0xFF9DDCFF)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveBookingTrackingPage(
                          carId: car.carId,
                          carName: car.name,
                          fallbackLat: car.locationLat ?? pickupLat,
                          fallbackLng: car.locationLng ?? pickupLng,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on, size: 16),
                  label: const Text(
                    'Track',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );

              final paymentButton = Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentPage(
                          bookingId: bookingDocId,
                          amount: paymentAmount,
                          paymentMethod: paymentMethod,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text(
                    'Pay Online',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CarApiImage(
                        imageUrl: car.imageUrl,
                        fallbackAssetPath: car.fallbackAssetPath,
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    details,
                    const SizedBox(height: 12),
                    if (!isCancelled) ...[
                      trackButton,
                      const SizedBox(height: 8),
                      if (!isPaid) ...[
                        paymentButton,
                        const SizedBox(height: 8),
                      ],
                      if (isPaid) ...[paidBadge, const SizedBox(height: 8)],
                      ratingButton,
                      const SizedBox(height: 8),
                      cancelButton,
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CarApiImage(
                      imageUrl: car.imageUrl,
                      fallbackAssetPath: car.fallbackAssetPath,
                      width: 130,
                      height: 130,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        details,
                        const SizedBox(height: 12),
                        if (!isCancelled) ...[
                          trackButton,
                          const SizedBox(height: 8),
                          if (!isPaid) ...[
                            paymentButton,
                            const SizedBox(height: 8),
                          ],
                          if (isPaid) ...[paidBadge, const SizedBox(height: 8)],
                          ratingButton,
                          const SizedBox(height: 4),
                          cancelButton,
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _loadBookedCarData({
    required dynamic carId,
    required String sourceCollection,
    required String sourceDocId,
  }) async {
    if (sourceCollection == 'fleet_items' && sourceDocId.isNotEmpty) {
      final fleetDoc = await _firestore
          .collection('fleet_items')
          .doc(sourceDocId)
          .get();
      if (fleetDoc.exists) {
        final data = fleetDoc.data();
        if (data != null) {
          return {
            'car_id': data['car_id'] ?? carId,
            'name': data['name'] ?? 'Fleet Car',
            'model': data['model'] ?? 'N/A',
            'type': data['type'] ?? 'SUV',
            'number_plate': data['number_plate'] ?? 'N/A',
            'features': data['features'] ?? const <String>[],
            'location': data['location'] ?? 'Unknown',
            'year': data['year'] ?? DateTime.now().year,
            'price_per_day': data['price_per_day'] ?? data['price'] ?? 2000,
            'description':
                data['notes'] ?? data['description'] ?? 'Fleet listing',
            'image_url': data['image_url'],
            'owner_email': data['owner_email'] ?? 'admin@expresscar.com',
          };
        }
      }
    }

    final carsDoc = await _firestore
        .collection('cars')
        .doc(carId.toString())
        .get();
    if (carsDoc.exists) {
      return carsDoc.data();
    }

    final fleetByCarId = await _firestore
        .collection('fleet_items')
        .where('car_id', isEqualTo: carId)
        .limit(1)
        .get();
    if (fleetByCarId.docs.isNotEmpty) {
      final data = fleetByCarId.docs.first.data();
      return {
        'car_id': data['car_id'] ?? carId,
        'name': data['name'] ?? 'Fleet Car',
        'model': data['model'] ?? 'N/A',
        'type': data['type'] ?? 'SUV',
        'number_plate': data['number_plate'] ?? 'N/A',
        'features': data['features'] ?? const <String>[],
        'location': data['location'] ?? 'Unknown',
        'year': data['year'] ?? DateTime.now().year,
        'price_per_day': data['price_per_day'] ?? data['price'] ?? 2000,
        'description': data['notes'] ?? data['description'] ?? 'Fleet listing',
        'image_url': data['image_url'],
        'owner_email': data['owner_email'] ?? 'admin@expresscar.com',
      };
    }

    return null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _normalizePaymentStatus(dynamic rawStatus) {
    final status = rawStatus?.toString().trim().toLowerCase() ?? 'pending';
    if (status == 'paid') {
      return status;
    }
    return 'pending';
  }

  Widget _buildPaymentStatusBadge(String status) {
    final Color bg;
    final Color border;
    final Color fg;
    final String text;

    switch (status) {
      case 'paid':
        bg = const Color(0xFFDCFCE7);
        border = const Color(0xFF86EFAC);
        fg = const Color(0xFF166534);
        text = 'Payment: Paid';
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        border = const Color(0xFFFCD34D);
        fg = const Color(0xFF92400E);
        text = 'Payment: Pending';
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
