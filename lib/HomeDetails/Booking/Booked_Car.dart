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
  // The bookingTrigger is no longer needed.
  // final int bookingTrigger;

  const BookedCar({Key? key, required this.bookedCars}) : super(key: key);

  @override
  State<BookedCar> createState() => _BookedCarState();
}

class _BookedCarState extends State<BookedCar> {
  late List<Map<String, dynamic>> localBookedCars;

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
      await _firestore.collection('bookings').doc(bookingDocId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${car is Car ? car.name : 'Booking'} booking cancelled',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      print('Failed to delete booking doc $bookingDocId: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to cancel booking: $e')));
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
              const Text(
                "Booked Car",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
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
      stream: _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No Cars Booked Yet",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            return _buildBookingCard(doc);
          }).toList(),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDE3EE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 380;

              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Start Date : ${startDate.isNotEmpty ? startDate.substring(0, 10) : 'N/A'}",
                    style: const TextStyle(color: AppTheme.ink, fontSize: 14),
                  ),
                  Text(
                    "End Date : ${endDate.isNotEmpty ? endDate.substring(0, 10) : 'N/A'}",
                    style: const TextStyle(color: AppTheme.ink, fontSize: 14),
                  ),
                  Text(
                    "Location : ${car.location}",
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  Text(
                    "Type : ${fleetType == 'with_driver' ? 'With Driver' : 'Driverless'}",
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  _buildPaymentStatusBadge(paymentStatus),
                  if (!isPaid)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Payment Mode: Cash on Pickup',
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
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9DDCFF),
                    foregroundColor: const Color(0xFF0D3A5B),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => cancelBooking(bookingDocId, car),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
                    'Payment Option',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CarApiImage(
                        imageUrl: car.imageUrl,
                        fallbackAssetPath: car.fallbackAssetPath,
                        width: double.infinity,
                        height: 126,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    details,
                    const SizedBox(height: 6),
                    trackButton,
                    const SizedBox(height: 6),
                    if (!isPaid) ...[paymentButton, const SizedBox(height: 6)],
                    if (isPaid) ...[paidBadge, const SizedBox(height: 6)],
                    ratingButton,
                    const SizedBox(height: 6),
                    cancelButton,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CarApiImage(
                      imageUrl: car.imageUrl,
                      fallbackAssetPath: car.fallbackAssetPath,
                      width: 126,
                      height: 126,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        details,
                        const SizedBox(height: 6),
                        trackButton,
                        const SizedBox(height: 6),
                        if (!isPaid) ...[
                          paymentButton,
                          const SizedBox(height: 6),
                        ],
                        if (isPaid) ...[paidBadge, const SizedBox(height: 6)],
                        ratingButton,
                        const SizedBox(height: 6),
                        cancelButton,
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
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
