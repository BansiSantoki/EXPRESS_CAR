import 'package:flutter/material.dart';
import 'package:express_car/HomeDetails/Home_Page/car_model.dart';
import 'package:express_car/theme/app_theme.dart';
import 'package:express_car/services/car_image_widget.dart';
import 'package:express_car/HomeDetails/Booking/Book_car.dart';

class CompareResultPage extends StatelessWidget {
  final Car leftCar;
  final Car rightCar;

  const CompareResultPage({
    super.key,
    required this.leftCar,
    required this.rightCar,
  });

  void _bookCar(BuildContext context, Car car) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingPage(
          car: car,
          selectedFleetType: car.fleetType,
          onCarBooked: (details) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extract all unique features from both cars for the checklist
    final Set<String> allFeatures = {...leftCar.features, ...rightCar.features};
    final List<String> sortedFeatures = allFeatures.toList()..sort();

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('Comparison Result'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Images Row
                    Row(
                      children: [
                        Expanded(child: _buildCarHeader(leftCar)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildCarHeader(rightCar)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 2. Core Specs Section
                    const Text(
                      'Core Specifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          _buildSpecRow(
                            'Type',
                            leftCar.type,
                            rightCar.type,
                            isEven: true,
                          ),
                          _buildSpecRow(
                            'Year',
                            leftCar.year.toString(),
                            rightCar.year.toString(),
                            isEven: false,
                          ),
                          _buildSpecRow(
                            'Location',
                            leftCar.location,
                            rightCar.location,
                            isEven: true,
                          ),
                          _buildSpecRow(
                            'Model',
                            leftCar.model,
                            rightCar.model,
                            isEven: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3. Features Checklist Section
                    const Text(
                      'Features & Amenities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: sortedFeatures.asMap().entries.map((entry) {
                          final index = entry.key;
                          final feature = entry.value;
                          final leftHas = leftCar.features.contains(feature);
                          final rightHas = rightCar.features.contains(feature);
                          return _buildFeatureRow(
                            feature,
                            leftHas,
                            rightHas,
                            isEven: index % 2 == 0,
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 4. Bottom Action Bar (Book Now Buttons)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _bookCar(context, leftCar),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Book Left',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _bookCar(context, rightCar),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF1C9D56,
                        ), // Green for distinction
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Book Right',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarHeader(Car car) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: CarApiImage(
              imageUrl: car.imageUrl,
              fallbackAssetPath: car.fallbackAssetPath,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          car.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F4EA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '₹${car.pricePerDay.toInt()}/day',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF166534),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecRow(
    String label,
    String leftValue,
    String rightValue, {
    required bool isEven,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFF8F9FA) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              leftValue,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              rightValue,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
    String feature,
    bool leftHas,
    bool rightHas, {
    required bool isEven,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFF8F9FA) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Icon(
              leftHas ? Icons.check_circle : Icons.remove_circle_outline,
              color: leftHas ? const Color(0xFF1C9D56) : Colors.grey.shade300,
              size: 20,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              feature,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Icon(
              rightHas ? Icons.check_circle : Icons.remove_circle_outline,
              color: rightHas ? const Color(0xFF1C9D56) : Colors.grey.shade300,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
