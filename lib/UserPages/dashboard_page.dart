import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../Authentication/signin_page.dart';
import '../HomeDetails/Home_Page/home_page.dart';
import 'package:express_car/services/user_presence_service.dart';
import '../HomeDetails/Home_Page/car_data.dart';
import '../HomeDetails/Home_Page/car_model.dart';
import 'package:express_car/theme/app_theme.dart';
import 'package:express_car/services/car_image_widget.dart';
import '../HomeDetails/Home_Page/compare_result_page.dart'; // 🚀 NEW IMPORT

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Car? _left;
  Car? _right;

  void _openHome() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  void _logout() async {
    await UserPresenceService.markCurrentUserOffline();
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => SignInPage()),
      (route) => false,
    );
  }

  // 🚀 UPGRADED: Premium Car Picker Bottom Sheet (Matches Home Page)
  void _showCarPicker(bool isLeft) async {
    final selected = await showModalBottomSheet<Car?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String localSearchQuery = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final list = cars.where((car) {
              final query = localSearchQuery.toLowerCase();
              return car.name.toLowerCase().contains(query) ||
                  car.model.toLowerCase().contains(query) ||
                  car.type.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: AppTheme.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Select Car to Compare',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search cars...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppTheme.primary,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          localSearchQuery = val;
                        });
                      },
                    ),
                  ),
                  // Car List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: list.length,
                      itemBuilder: (c, i) {
                        final car = list[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(8),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 80,
                                height: 60,
                                // 🚀 FIX: Using CarApiImage
                                child: CarApiImage(
                                  imageUrl: car.imageUrl,
                                  fallbackAssetPath: car.fallbackAssetPath,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            title: Text(
                              car.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            subtitle: Text(
                              '${car.year} • ${car.type}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Text(
                              '₹${car.pricePerDay.toInt()}/day',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                            onTap: () => Navigator.of(ctx).pop(car),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == null) return;
    setState(() {
      if (isLeft)
        _left = selected;
      else
        _right = selected;
    });
  }

  // 🚀 UPGRADED: Navigate to the new premium CompareResultPage
  void _compareNow() {
    if (_left == null || _right == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select two cars to compare')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompareResultPage(leftCar: _left!, rightCar: _right!),
      ),
    );
  }

  Widget _compareCard(Car? car, bool isLeft) {
    return Expanded(
      child: InkWell(
        onTap: () => _showCarPicker(isLeft),
        child: Container(
          height: 142,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (car == null) ...[
                const Icon(
                  Icons.directions_car_outlined,
                  size: 36,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select Car',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                SizedBox(
                  height: 46,
                  width: 46,
                  // 🚀 FIX: Using CarApiImage
                  child: CarApiImage(
                    imageUrl: car.imageUrl,
                    fallbackAssetPath: car.fallbackAssetPath,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  car.name,
                  style: const TextStyle(
                    color: Color(0xFF1E88E5),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPopularComparisons() {
    final List<Widget> rows = [];
    final list = cars;
    for (var i = 0; i + 1 < list.length && rows.length < 4; i += 2) {
      final left = list[i];
      final right = list[i + 1];
      rows.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 78,
                      // 🚀 FIX: Using CarApiImage
                      child: CarApiImage(
                        imageUrl: left.imageUrl,
                        fallbackAssetPath: left.fallbackAssetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      left.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Rs. ${left.pricePerDay.toStringAsFixed(0)}/day',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFF8E8E3),
                  child: Text(
                    'VS',
                    style: TextStyle(fontSize: 11, color: Color(0xFFE87A5A)),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 78,
                      // 🚀 FIX: Using CarApiImage
                      child: CarApiImage(
                        imageUrl: right.imageUrl,
                        fallbackAssetPath: right.fallbackAssetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      right.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Rs. ${right.pricePerDay.toStringAsFixed(0)}/day',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Log Out',
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good ${DateTime.now().hour < 12 ? 'Morning' : 'Evening'},',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? 'No email',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Go to Home',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Compare area
            const Text(
              'Compare Cars',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _compareCard(_left, true),
                _compareCard(_right, false),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Add Car pressed')),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Car'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _compareNow,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: const Color(0xFFE53916),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Compare',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'POPULAR CAR COMPARISONS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._buildPopularComparisons(),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
