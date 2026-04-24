import 'dart:math' as math;

import 'package:express_car/HomeDetails/Home_Page/car_model.dart';
import 'package:express_car/HomeDetails/Home_Page/home_page.dart';
import 'package:express_car/Authentication/auth_wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:express_car/theme/app_theme.dart';
import 'package:express_car/services/car_image_widget.dart';
import 'package:express_car/HomeDetails/Booking/booking_details_page.dart';

class BookingPage extends StatefulWidget {
  final Car car;
  final String selectedFleetType;
  final Function(Map<String, dynamic> bookingDetails) onCarBooked;

  const BookingPage({
    super.key,
    required this.car,
    required this.selectedFleetType,
    required this.onCarBooked,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime? startDate;
  DateTime? endDate;
  bool _isBooking = false;
  String _rentalUnit = 'day';
  late String _selectedFleetType;
  final TextEditingController _pickupLocationController =
      TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverDetailsController =
      TextEditingController();
  final TextEditingController _aadharController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _panController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedFleetType = widget.selectedFleetType;
    _pickupLocationController.text = widget.car.location == 'Unknown'
        ? ''
        : widget.car.location;
  }

  @override
  void dispose() {
    _pickupLocationController.dispose();
    _driverNameController.dispose();
    _driverDetailsController.dispose();
    _aadharController.dispose();
    _licenseController.dispose();
    _panController.dispose();
    super.dispose();
  }

  bool _validateBookingDetails() {
    final pickupLocation = _pickupLocationController.text.trim();

    if (pickupLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter pickup location.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  int _calculateRentalQuantity(int rentalDays) {
    if (rentalDays <= 0) return 0;
    switch (_rentalUnit) {
      case 'week':
        return (rentalDays / 7).ceil();
      case 'month':
        return (rentalDays / 30).ceil();
      default:
        return rentalDays;
    }
  }

  int _calculateBaseUnitPrice(Car car) {
    switch (_rentalUnit) {
      case 'week':
        return car.effectivePricePerWeek.toInt();
      case 'month':
        return car.effectivePricePerMonth.toInt();
      default:
        return car.pricePerDay.toInt();
    }
  }

  int _calculateDriverlessSurcharge(int baseUnitPrice) {
    if (_selectedFleetType != 'driverless') {
      return 0;
    }
    // Driverless requires extra verification and risk coverage.
    return math.max(100, (baseUnitPrice * 0.15).ceil());
  }

  bool _validateDriverDocuments() {
    if (_selectedFleetType != 'driverless') {
      return true;
    }

    final driverName = _driverNameController.text.trim();
    final driverDetails = _driverDetailsController.text.trim();
    final aadhar = _aadharController.text.trim();
    final license = _licenseController.text.trim();
    final pan = _panController.text.trim().toUpperCase();

    final isDriverNameValid = driverName.isNotEmpty;
    final isDriverDetailsValid = driverDetails.isNotEmpty;
    final isAadharValid = RegExp(r'^\d{12}$').hasMatch(aadhar);
    final isLicenseValid = license.length >= 8;
    final isPanValid = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan);

    if (isDriverNameValid &&
        isDriverDetailsValid &&
        isAadharValid &&
        isLicenseValid &&
        isPanValid) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'For Driverless booking, Driver name/details plus valid Aadhar (12 digits), License, and PAN are required.',
        ),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }

  Future<void> pickDate({required bool isStart}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;

          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = null;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("End date reset because it's before Start date"),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          if (startDate != null && picked.isBefore(startDate!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("End date cannot be before Start date"),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            endDate = picked;
          }
        }
      });
    }
  }

  /// -------------------------------------------------------------
  /// REAL-TIME BOOKING CHECK (NO UI CHANGE)
  /// -------------------------------------------------------------
  int _generateBookingId() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  bool isCarAlreadyBooked(DateTime start, DateTime end) {
    for (var booking in HomePage.bookedCarsMaps) {
      final int? bookedCarId = _extractBookedCarId(booking);
      if (bookedCarId != widget.car.carId) {
        continue;
      }

      final DateTime? s = _extractBookedDate(
        booking,
        primaryKey: 'startDate',
        fallbackKey: 'start_date',
      );
      final DateTime? e = _extractBookedDate(
        booking,
        primaryKey: 'endDate',
        fallbackKey: 'end_date',
      );

      if (s == null || e == null) {
        continue;
      }

      // If date range overlaps → reject
      if (start.isBefore(e) && end.isAfter(s)) {
        return true;
      }
    }
    return false;
  }

  int? _extractBookedCarId(Map<String, dynamic> booking) {
    final dynamic carObj = booking['car'];
    if (carObj is Car) {
      return carObj.carId;
    }

    final dynamic carIdValue = booking['car_id'] ?? booking['carId'];
    if (carIdValue is int) {
      return carIdValue;
    }

    return int.tryParse(carIdValue?.toString() ?? '');
  }

  DateTime? _extractBookedDate(
    Map<String, dynamic> booking, {
    required String primaryKey,
    required String fallbackKey,
  }) {
    final dynamic raw = booking[primaryKey] ?? booking[fallbackKey];
    if (raw is DateTime) {
      return raw;
    }

    if (raw == null) {
      return null;
    }

    return DateTime.tryParse(raw.toString());
  }

  Future<User?> _ensureSignedIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return user;

    if (!mounted) return null;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign in required'),
        content: const Text(
          'You need to sign in again before confirming a booking.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthWrapper()),
                (route) => false,
              );
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );

    return null;
  }

  /// -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    // Calculate rental days and total dynamically
    int rentalDays = 0;
    if (startDate != null && endDate != null) {
      if (!endDate!.isBefore(startDate!)) {
        rentalDays = endDate!.difference(startDate!).inDays + 1;
      }
    }
    final int rentalQuantity = _calculateRentalQuantity(rentalDays);
    final int baseUnitPrice = _calculateBaseUnitPrice(car);
    final int driverlessSurchargePerUnit = _calculateDriverlessSurcharge(
      baseUnitPrice,
    );
    final int unitPrice = baseUnitPrice + driverlessSurchargePerUnit;
    final int totalAmount = rentalQuantity * unitPrice;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text(
          'Booking',
          style: TextStyle(
            color: AppTheme.ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Car Image
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  child: CarApiImage(
                    imageUrl: car.imageUrl,
                    fallbackAssetPath: car.fallbackAssetPath,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                /// Car Name & Details
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${car.model} • ${car.year}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'Rental Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: [
                          ChoiceChip(
                            label: const Text('Driverless'),
                            selected: _selectedFleetType == 'driverless',
                            onSelected: (_) {
                              setState(() => _selectedFleetType = 'driverless');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('With Driver'),
                            selected: _selectedFleetType == 'with_driver',
                            onSelected: (_) {
                              setState(
                                () => _selectedFleetType = 'with_driver',
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _selectedFleetType == 'with_driver'
                            ? 'With Driver selected: A professional driver will be assigned with this booking.'
                            : 'Driverless selected: You will self-drive the car with mandatory document verification and extra charge.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_selectedFleetType == 'driverless') ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Driver Documents (Required)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.ink,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildDocumentField(
                                label: 'Driver Name',
                                hint: 'Enter driver name',
                                controller: _driverNameController,
                              ),
                              const SizedBox(height: 10),
                              _buildDocumentField(
                                label: 'Driver Details',
                                hint: 'Enter driver details',
                                controller: _driverDetailsController,
                              ),
                              const SizedBox(height: 10),
                              _buildDocumentField(
                                label: 'Aadhar Card Number',
                                hint: '12-digit Aadhar number',
                                controller: _aadharController,
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 10),
                              _buildDocumentField(
                                label: 'Driving License Number',
                                hint: 'Enter license number',
                                controller: _licenseController,
                              ),
                              const SizedBox(height: 10),
                              _buildDocumentField(
                                label: 'PAN Card Number',
                                hint: 'ABCDE1234F',
                                controller: _panController,
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(),

                /// Trip Dates
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: buildDateColumn("Starting Date", startDate, () {
                          pickDate(isStart: true);
                        }),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: buildDateColumn("Ending Date", endDate, () {
                          pickDate(isStart: false);
                        }),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                /// Location
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        "Pickup & Return Location",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pickupLocationController,
                        decoration: InputDecoration(
                          hintText: 'Enter pickup and return location',
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            color: AppTheme.primary,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.primary,
                              width: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                /// Features
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        "Car Basics & Features",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: car.features.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 20,
                              childAspectRatio: 4,
                            ),
                        itemBuilder: (context, index) {
                          final f = car.features[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 7,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  f,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF4B5563),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),

                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "Description",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    car.description,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                ),
                const Divider(),

                /// Warning
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Warning",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Payment will be required at the time of car pick-up.",
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Rental Unit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink,
                          ),
                        ),
                        const Spacer(),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _rentalUnit,
                            items: const [
                              DropdownMenuItem(
                                value: 'day',
                                child: Text('Day'),
                              ),
                              DropdownMenuItem(
                                value: 'week',
                                child: Text('Week'),
                              ),
                              DropdownMenuItem(
                                value: 'month',
                                child: Text('Month'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _rentalUnit = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (rentalDays > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Text(
                      'Duration: $rentalDays day(s) • Billable: $rentalQuantity $_rentalUnit(s) @ ₹$unitPrice/$_rentalUnit',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (rentalDays > 0 && driverlessSurchargePerUnit > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Text(
                      'Driverless surcharge: ₹$driverlessSurchargePerUnit/$_rentalUnit (included in total)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                /// Book Button
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: _isBooking
                        ? null
                        : () async {
                            final user = await _ensureSignedIn();
                            if (user == null) return;
                            if (!_validateBookingDetails()) return;
                            if (!_validateDriverDocuments()) return;

                            if (startDate != null && endDate != null) {
                              /// ----------------------------
                              /// REAL-TIME DATE CHECK
                              /// ----------------------------
                              if (isCarAlreadyBooked(startDate!, endDate!)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Car already booked for selected dates",
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              // compute booking details
                              final startIso = DateTime(
                                startDate!.year,
                                startDate!.month,
                                startDate!.day,
                              ).toIso8601String();
                              final endIso = DateTime(
                                endDate!.year,
                                endDate!.month,
                                endDate!.day,
                              ).toIso8601String();

                              setState(() => _isBooking = true);

                              try {
                                final bookingId = _generateBookingId();
                                final userEmail = user.email ?? 'unknown';
                                final driverlessSurchargeTotal =
                                    driverlessSurchargePerUnit * rentalQuantity;

                                final bookingData = {
                                  'booking_id': bookingId,
                                  'car_id': widget.car.carId,
                                  'car_name': widget.car.name,
                                  'image_url': widget.car.imageUrl,
                                  'car_source_collection':
                                      widget.car.sourceCollection,
                                  'car_source_doc_id': widget.car.sourceDocId,
                                  'fleet_type': _selectedFleetType,
                                  'fleetType': _selectedFleetType,
                                  'user_mail': userEmail,
                                  'userId': user.uid,
                                  'owner_email': widget.car.ownerEmail ?? '',
                                  'rental_unit': _rentalUnit,
                                  'rental_quantity': rentalQuantity,
                                  'base_unit_price': baseUnitPrice,
                                  'driverless_surcharge_per_unit':
                                      driverlessSurchargePerUnit,
                                  'driverless_surcharge_total':
                                      driverlessSurchargeTotal,
                                  'unit_price': unitPrice,
                                  'start_date': startIso,
                                  'end_date': endIso,
                                  'pickup_location': _pickupLocationController
                                      .text
                                      .trim(),
                                  'car_year': widget.car.year,
                                  'pickup_lat': widget.car.locationLat,
                                  'pickup_lng': widget.car.locationLng,
                                  'location_tracking_enabled': true,
                                  'driver_documents_required':
                                      _selectedFleetType == 'driverless',
                                  'total_amount': totalAmount,
                                  'payment_status': 'pending',
                                  'payment_method': 'cash_on_pickup',
                                  'payment_amount': totalAmount,
                                  'payment_id': '',
                                  'payment_order_id': '',
                                  'transaction_ref': '',
                                  'payment_time': null,
                                  'paid_at': null,
                                  'created_at': FieldValue.serverTimestamp(),
                                  if (_selectedFleetType == 'driverless')
                                    'driver_name': _driverNameController.text
                                        .trim(),
                                  if (_selectedFleetType == 'driverless')
                                    'driver_details': _driverDetailsController
                                        .text
                                        .trim(),
                                  if (_selectedFleetType == 'driverless')
                                    'driver_documents': {
                                      'driver_name': _driverNameController.text
                                          .trim(),
                                      'driver_details': _driverDetailsController
                                          .text
                                          .trim(),
                                      'aadhar_card': _aadharController.text
                                          .trim(),
                                      'license_number': _licenseController.text
                                          .trim(),
                                      'pan_card': _panController.text
                                          .trim()
                                          .toUpperCase(),
                                    },
                                };

                                // Save booking to Firestore under 'bookings' collection
                                await FirebaseFirestore.instance
                                    .collection('bookings')
                                    .doc(bookingId.toString())
                                    .set(bookingData);

                                if (!mounted) return;
                                await Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingDetailsPage(
                                      booking: bookingData,
                                    ),
                                  ),
                                );
                              } on FirebaseException catch (e) {
                                // Handle Firestore permission errors specifically
                                final isPermissionError =
                                    e.code == 'permission-denied' ||
                                    (e.message != null &&
                                        e.message!.toLowerCase().contains(
                                          'permission',
                                        ));

                                if (isPermissionError) {
                                  // Show a blocking dialog with guidance
                                  if (mounted) {
                                    await showDialog<void>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Permission Denied'),
                                        content: const Text(
                                          'Cloud Firestore: permission denied — caller does not have permission to perform this operation.\n\nCheck your Firestore security rules or ensure the user is authenticated.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  // Also log for debugging
                                  print(
                                    'Firestore permission denied: ${e.message}',
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to save booking: ${e.message}',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to save booking: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } finally {
                                if (mounted) setState(() => _isBooking = false);
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please select both start and end dates",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    child: _isBooking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            // Show dynamic total when both dates are selected, otherwise show 0
                            startDate != null &&
                                    endDate != null &&
                                    rentalQuantity > 0
                                ? "Total ₹$totalAmount (${rentalQuantity} ${_rentalUnit}${rentalQuantity > 1 ? 's' : ''})"
                                : "Total ₹0",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildDateColumn(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null
                      ? "${date.day}/${date.month}/${date.year}"
                      : "Select Date",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: AppTheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF111827),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}
