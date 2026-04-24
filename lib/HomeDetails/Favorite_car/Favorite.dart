// ignore_for_file: file_names

import 'package:express_car/HomeDetails/Home_Page/car_model.dart';
import 'package:express_car/HomeDetails/Booking/Book_car.dart';
import 'package:express_car/services/car_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:express_car/theme/app_theme.dart';

class FavoritePage extends StatelessWidget {
  final List<Car> favoriteCars;
  final Function(Car) onToggleFavorite;

  const FavoritePage({
    super.key,
    required this.favoriteCars,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final favoriteNames = favoriteCars
        .map((car) => car.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    return Container(
      color: const Color(0xFFF6F8FC),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDDE3EE)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Favorites',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${favoriteCars.length} saved cars',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.58),
                      ),
                    ),
                    if (favoriteNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        favoriteNames.join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: favoriteCars.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_outline,
                            size: 46,
                            color: Colors.black38,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No favorite cars yet',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: favoriteCars.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.68,
                          ),
                      itemBuilder: (context, index) {
                        final car = favoriteCars[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFDDE3EE)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(14),
                                    ),
                                    child: CarApiImage(
                                      imageUrl: car.imageUrl,
                                      fallbackAssetPath: car.fallbackAssetPath,
                                      height: 94,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: InkWell(
                                      onTap: () => onToggleFavorite(car),
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.favorite,
                                          size: 16,
                                          color: Color(0xFFFF4338),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    8,
                                    10,
                                    8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        car.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        car.location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${car.pricePerDay.toInt()}/day',
                                        style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const Spacer(),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF9DDCFF,
                                            ),
                                            foregroundColor: const Color(
                                              0xFF0D3A5B,
                                            ),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            minimumSize: const Size(0, 34),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    BookingPage(
                                                      car: car,
                                                      selectedFleetType:
                                                          car.fleetType,
                                                      onCarBooked:
                                                          (
                                                            Map<String, dynamic>
                                                            bookingDetails,
                                                          ) {},
                                                    ),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Book Now',
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
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
