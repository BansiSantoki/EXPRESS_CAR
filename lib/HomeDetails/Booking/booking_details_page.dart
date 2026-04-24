import 'package:flutter/material.dart';
import 'package:express_car/HomeDetails/Booking/live_booking_tracking_page.dart';
import 'package:express_car/services/car_image_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingDetailsPage extends StatelessWidget {
  final Map<String, dynamic> booking;

  const BookingDetailsPage({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    const mint = Color(0xFF9CEB76);
    const ink = Color(0xFF121319);
    final now = DateTime.now();
    final bookingId = booking['booking_id']?.toString() ?? '-';
    final carName = booking['car_name']?.toString() ?? 'Car';
    final imageUrl = booking['image_url']?.toString() ?? '';
    final carId = _toInt(booking['car_id']);
    final rentalUnit = booking['rental_unit']?.toString() ?? 'day';
    final rentalQty = booking['rental_quantity']?.toString() ?? '0';
    final unitPrice = booking['unit_price']?.toString() ?? '0';
    final baseUnitPrice = booking['base_unit_price']?.toString() ?? unitPrice;
    final driverlessSurchargePerUnit =
        _toInt(booking['driverless_surcharge_per_unit']) ?? 0;
    final driverlessSurchargeTotal =
        _toInt(booking['driverless_surcharge_total']) ?? 0;
    final totalAmount = booking['total_amount']?.toString() ?? '0';
    final startDate = booking['start_date']?.toString() ?? '-';
    final endDate = booking['end_date']?.toString() ?? '-';
    final pickupLocation = booking['pickup_location']?.toString() ?? '-';
    final pickupLat = _toDouble(booking['pickup_lat']);
    final pickupLng = _toDouble(booking['pickup_lng']);
    final fleetType =
        (booking['fleet_type'] ?? booking['fleetType'] ?? 'driverless')
            .toString();
    final driverDocuments = booking['driver_documents'];
    final aadharNumber = _readDriverDoc(
      driverDocuments,
      booking['driver_aadhar_card'],
      'aadhar_card',
    );
    final licenseNumber = _readDriverDoc(
      driverDocuments,
      booking['driver_license_number'],
      'license_number',
    );
    final panNumber = _readDriverDoc(
      driverDocuments,
      booking['driver_pan_card'],
      'pan_card',
    );
    final isActive = _isBookingActive(booking, now);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Car Detail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          carName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 34,
                            height: 1,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4D8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: Color(0xFFFFB000),
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '4.5',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking['car_year']?.toString() ??
                        startDate.split('-').first,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CarApiImage(
                      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
                      fallbackAssetPath: 'assets/images/Honda City.jpg',
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Technical specifications',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _specCard(
                    icon: Icons.local_gas_station_outlined,
                    title: 'Fuel',
                    value: fleetType == 'with_driver' ? 'Petrol' : 'Standard',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _specCard(
                    icon: Icons.event_seat_outlined,
                    title: 'Seats',
                    value: '2 seats',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _specCard(
                    icon: Icons.bolt_outlined,
                    title: 'Power',
                    value: '250kW',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _line('Booking ID', bookingId),
            _line(
              'Rental Type',
              fleetType == 'with_driver' ? 'With Driver' : 'Driverless',
            ),
            _line(
              'Rental Unit',
              '$rentalQty $rentalUnit @ Rs $unitPrice/$rentalUnit',
            ),
            if (driverlessSurchargePerUnit > 0)
              _line(
                'Price Split',
                'Base Rs $baseUnitPrice + Surcharge Rs $driverlessSurchargePerUnit/$rentalUnit',
              ),
            if (driverlessSurchargeTotal > 0)
              _line('Driverless Surcharge', 'Rs $driverlessSurchargeTotal'),
            _line('Start Date', startDate),
            _line('End Date', endDate),
            _line('Pickup Location', pickupLocation),
            if (fleetType == 'driverless') ...[
              _line('Aadhar Card', aadharNumber),
              _line('License', licenseNumber),
              _line('PAN Card', panNumber),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: carId == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveBookingTrackingPage(
                                carId: carId,
                                carName: carName,
                                fallbackLat: pickupLat,
                                fallbackLng: pickupLng,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.location_on),
                  label: Text(
                    isActive
                        ? 'Track Location'
                        : 'Track Location (shows latest available)',
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.45),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Rs $totalAmount',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(160, 48),
                        backgroundColor: mint,
                        foregroundColor: ink,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildRatingSection(context),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection(BuildContext context) {
    final existingRating = _toInt(booking['user_rating']) ?? 0;
    final existingReview = booking['user_review']?.toString().trim() ?? '';
    final paymentStatus =
        booking['payment_status']?.toString().trim().toLowerCase() ?? 'pending';
    final canRate = paymentStatus == 'paid';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rating & Review',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF121319),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 1; i <= 5; i++)
                Icon(
                  i <= existingRating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFFB000),
                  size: 22,
                ),
              const SizedBox(width: 10),
              Text(
                existingRating > 0
                    ? '$existingRating/5'
                    : 'No rating submitted yet',
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (existingReview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              existingReview,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (!canRate)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Complete payment first to add rating and review.',
                style: TextStyle(
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canRate ? () => _openRatingDialog(context) : null,
              icon: const Icon(Icons.rate_review_outlined),
              label: Text(existingRating > 0 ? 'Edit Rating' : 'Add Rating'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRatingDialog(BuildContext context) async {
    final bookingId = booking['booking_id']?.toString().trim() ?? '';
    if (bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing booking ID for review save.')),
      );
      return;
    }

    int selectedRating = _toInt(booking['user_rating']) ?? 0;
    final reviewController = TextEditingController(
      text: booking['user_review']?.toString() ?? '',
    );
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogBuilderContext, setDialogState) {
            return AlertDialog(
              title: const Text('Rate Your Booking'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 4,
                      children: [
                        for (int i = 1; i <= 5; i++)
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: isSaving
                                ? null
                                : () {
                                    setDialogState(() => selectedRating = i);
                                  },
                            icon: Icon(
                              i <= selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: const Color(0xFFFFB000),
                            ),
                          ),
                      ],
                    ),
                    TextField(
                      controller: reviewController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Review',
                        hintText: 'Write your feedback...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (selectedRating < 1 || selectedRating > 5) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please select a rating first.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          try {
                            await _saveRatingAndReview(
                              bookingId: bookingId,
                              rating: selectedRating,
                              review: reviewController.text.trim(),
                            );

                            booking['user_rating'] = selectedRating;
                            booking['user_review'] = reviewController.text
                                .trim();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Rating saved successfully.'),
                                ),
                              );
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save rating: $e'),
                                ),
                              );
                            }
                            setDialogState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    reviewController.dispose();
  }

  Future<void> _saveRatingAndReview({
    required String bookingId,
    required int rating,
    required String review,
  }) async {
    final existingRating = _toInt(booking['user_rating']) ?? 0;
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('bookings').doc(bookingId).set({
      'user_rating': rating,
      'user_review': review,
      'reviewed_at': FieldValue.serverTimestamp(),
      'review_by_uid': user?.uid ?? '',
      'review_by_email': user?.email ?? '',
    }, SetOptions(merge: true));

    final sourceCollection = (booking['car_source_collection'] ?? 'cars')
        .toString();
    final sourceDocId = (booking['car_source_doc_id'] ?? '').toString();
    if (sourceCollection != 'cars' || sourceDocId.isEmpty) {
      return;
    }

    final carRef = FirebaseFirestore.instance
        .collection(sourceCollection)
        .doc(sourceDocId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(carRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() ?? {};
        final currentTotal = _toDouble(data['rating_total']) ?? 0;
        final currentCount = _toInt(data['review_count']) ?? 0;

        double nextTotal = currentTotal;
        int nextCount = currentCount;

        if (existingRating > 0) {
          nextTotal = currentTotal - existingRating + rating;
        } else {
          nextTotal = currentTotal + rating;
          nextCount = currentCount + 1;
        }

        if (nextCount < 0) nextCount = 0;
        final average = nextCount == 0 ? 0 : (nextTotal / nextCount);

        transaction.update(carRef, {
          'rating_total': nextTotal,
          'review_count': nextCount,
          'average_rating': average,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException {
      // Booking review save should still succeed even if aggregate update is blocked.
    }
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _specCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  bool _isBookingActive(Map<String, dynamic> payload, DateTime now) {
    final start = _parseDate(payload['start_date']);
    final end = _parseDate(payload['end_date']);
    if (start == null || end == null) return false;

    final status =
        payload['status']?.toString().toLowerCase() ??
        payload['booking_status']?.toString().toLowerCase() ??
        '';
    if (status == 'cancelled' || status == 'completed') return false;

    return !now.isBefore(start) && !now.isAfter(end);
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return DateTime.tryParse(raw.toString());
  }

  int? _toInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }

  double? _toDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  String _readDriverDoc(dynamic docs, dynamic fallbackValue, String key) {
    final fallback = fallbackValue?.toString().trim() ?? '';
    if (fallback.isNotEmpty) {
      return fallback;
    }

    if (docs is Map<String, dynamic>) {
      final value = docs[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '-';
  }
}
