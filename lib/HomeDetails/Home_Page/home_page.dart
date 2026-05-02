import 'dart:async';

import 'package:express_car/HomeDetails/Booking/Book_car.dart';
import 'package:express_car/HomeDetails/Booking/Booked_car.dart';
import 'package:express_car/HomeDetails/Favorite_car/Favorite.dart';
import 'package:express_car/HomeDetails/Menu/Menu.dart';
import 'package:express_car/HomeDetails/Menu/Menus_Files/ViewProfile.dart';
import 'package:express_car/HomeDetails/Home_Page/car_model.dart';
import 'package:express_car/HomeDetails/Home_Page/car_data.dart';
import 'package:express_car/Splash/get_start.dart' as getstart;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:express_car/Admin/admin_panel.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:express_car/theme/app_theme.dart';
import 'package:express_car/services/car_image_widget.dart';
import 'package:express_car/services/car_location_tracking_service.dart';
import 'package:express_car/services/user_presence_service.dart';

class _CategorySpec {
  final String name;
  final IconData icon;
  final Color color;

  const _CategorySpec({
    required this.name,
    required this.icon,
    required this.color,
  });
}

class _CategoryCarsGroup {
  final String name;
  final List<Car> cars;

  const _CategoryCarsGroup({required this.name, required this.cars});
}

class HomePage extends StatefulWidget {
  static List<Map<String, dynamic>> bookedCarsMaps = [];
  static var bookedCars;

  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  Car? _compareLeft;
  Car? _compareRight;
  String selectedCategory = "All";
  String searchQuery = "";
  Set<String> favoriteCars = {};
  final ScrollController _carListController = ScrollController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _carsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _fleetSubscription;
  List<Car> _liveCars = [];
  bool _liveCarsLoaded = false;

  static const List<_CategorySpec> _categorySpecs = [
    _CategorySpec(
      name: 'All',
      icon: Icons.apps_rounded,
      color: Color(0xFF121319),
    ),
    _CategorySpec(
      name: 'Sedan',
      icon: Icons.directions_car_rounded,
      color: Color(0xFF1C9D56),
    ),
    _CategorySpec(
      name: 'SUV',
      icon: Icons.terrain_rounded,
      color: Color(0xFF2266C9),
    ),
    _CategorySpec(
      name: 'Hatchback',
      icon: Icons.time_to_leave_rounded,
      color: Color(0xFFF28C28),
    ),
    _CategorySpec(
      name: 'Luxury',
      icon: Icons.diamond_rounded,
      color: Color(0xFF7C3AED),
    ),
    _CategorySpec(
      name: 'Electric (EV)',
      icon: Icons.electric_car_rounded,
      color: Color(0xFF0891B2),
    ),
    _CategorySpec(
      name: 'Sports',
      icon: Icons.sports_motorsports_rounded,
      color: Color(0xFFE11D48),
    ),
  ];

  List<String> get categories =>
      _categorySpecs.map((spec) => spec.name).toList();

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _ensureCurrentUserDoc();
    _loadFavoritesFromFirestore();
    _startLiveCarsListener();
    fetchCarsFromFirestore().then((_) {
      if (!mounted) return;
      setState(() {
        if (!categories.contains(selectedCategory)) {
          selectedCategory = 'All';
        }
      });
      _scrollCarsToTop();
    });
    _startLocationTracking();
  }

  void _showComparePicker(bool isLeft) async {
    final selected = await showModalBottomSheet<Car?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final list = _baseCars;
        return SafeArea(
          child: ListView.separated(
            padding: EdgeInsets.all(12),
            itemBuilder: (c, i) {
              final car = list[i];
              return ListTile(
                leading: SizedBox(
                  width: 72,
                  height: 48,
                  child: car.imageUrl != null
                      ? Image.network(car.imageUrl!, fit: BoxFit.cover)
                      : Image.asset(car.fallbackAssetPath, fit: BoxFit.cover),
                ),
                title: Text(car.name),
                subtitle: Text('Rs ${car.pricePerDay.toStringAsFixed(0)}/day'),
                onTap: () => Navigator.of(ctx).pop(car),
              );
            },
            separatorBuilder: (_, __) => Divider(),
            itemCount: list.length,
          ),
        );
      },
    );

    if (selected == null) return;
    setState(() {
      if (isLeft)
        _compareLeft = selected;
      else
        _compareRight = selected;
    });
  }

  void _compareNow() {
    if (_compareLeft == null || _compareRight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select two cars to compare')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Compare'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_compareLeft!.name}  VS  ${_compareRight!.name}'),
            SizedBox(height: 12),
            Text(_compareLeft!.description),
            SizedBox(height: 8),
            Text(_compareRight!.description),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _startLiveCarsListener() {
    _syncLiveCarsFromFirestore();

    _carsSubscription = FirebaseFirestore.instance
        .collection('cars')
        .snapshots()
        .listen(
          (_) {
            _syncLiveCarsFromFirestore();
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _liveCars = fallbackCarsForUi();
              _liveCarsLoaded = true;
            });
          },
        );

    _fleetSubscription = FirebaseFirestore.instance
        .collection('fleet_items')
        .where('approvalStatus', isEqualTo: 'approved')
        .snapshots()
        .listen(
          (_) {
            _syncLiveCarsFromFirestore();
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _liveCars = fallbackCarsForUi();
              _liveCarsLoaded = true;
            });
          },
        );
  }

  Future<void> _syncLiveCarsFromFirestore() async {
    try {
      await fetchCarsFromFirestore();
      if (!mounted) return;
      final safeCars = cars.isNotEmpty ? cars : fallbackCarsForUi();
      setState(() {
        _liveCars = List<Car>.from(safeCars);
        _liveCarsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liveCars = fallbackCarsForUi();
        _liveCarsLoaded = true;
      });
    }
  }

  Future<void> _ensureCurrentUserDoc() async {
    final user = currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    final data = snapshot.data();
    final displayName = _resolveDisplayName(user, data);
    final photoUrl = _resolvePhotoUrl(user, data);

    await docRef.set({
      'displayName': displayName,
      'photoURL': photoUrl,
      'email': user.email ?? data?['email'] ?? '',
      'role': (data?['role'] ?? 'user').toString(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _loadFavoritesFromFirestore() async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = userDoc.data();
      final storedFavorites = data?['favorites'];

      if (storedFavorites is List) {
        final loaded = storedFavorites
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet();

        if (!mounted) return;
        setState(() {
          favoriteCars = loaded;
        });
      }
    } catch (e) {
      print('Failed to load favorites: $e');
    }
  }

  String _favoriteKey(Car car) {
    final source = car.sourceCollection.trim().isEmpty
        ? 'cars'
        : car.sourceCollection.trim();
    final docOrId = car.sourceDocId.trim().isNotEmpty
        ? car.sourceDocId.trim()
        : car.carId.toString();
    return '$source:$docOrId';
  }

  bool _isFavorite(Car car) {
    final key = _favoriteKey(car);
    return favoriteCars.contains(key) || favoriteCars.contains(car.name);
  }

  String _resolveDisplayName(User user, Map<String, dynamic>? data) {
    final candidates = [
      data?['displayName'],
      data?['name'],
      data?['fullName'],
      data?['username'],
      user.displayName,
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final text = candidate.toString().trim();
      if (text.isNotEmpty) return text;
    }

    final email = (user.email ?? data?['email']?.toString() ?? '').trim();
    if (email.contains('@')) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) return localPart;
    }

    return 'Guest User';
  }

  String _resolvePhotoUrl(User user, Map<String, dynamic>? data) {
    final candidates = [
      data?['photoURL'],
      data?['photoUrl'],
      data?['avatar'],
      data?['image'],
      user.photoURL,
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final text = candidate.toString().trim();
      if (text.isNotEmpty) return text;
    }

    return '';
  }

  String _timeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    }
    if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    }
    if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    }
    return 'Good Night';
  }

  void _scrollCarsToTop() {
    if (!_carListController.hasClients) return;
    _carListController.jumpTo(0);
  }

  Future<void> _showFleetOptionsAndOpenBooking(Car car) async {
    String selectedFleetType = car.fleetType;

    final chosenType = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 6),
                    Text(
                      'Choose your rental type',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      children: [
                        ChoiceChip(
                          label: const Text('Driverless'),
                          selected: selectedFleetType == 'driverless',
                          onSelected: (_) {
                            setModalState(
                              () => selectedFleetType = 'driverless',
                            );
                          },
                        ),
                        ChoiceChip(
                          label: const Text('With Driver'),
                          selected: selectedFleetType == 'with_driver',
                          onSelected: (_) {
                            setModalState(
                              () => selectedFleetType = 'with_driver',
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        selectedFleetType == 'with_driver'
                            ? 'With Driver: Professional driver included. Good for long routes and hassle-free travel.'
                            : 'Driverless: You drive the car yourself. Flexible and private self-drive option.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(sheetContext, selectedFleetType);
                            },
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || chosenType == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingPage(
          car: car,
          selectedFleetType: chosenType,
          onCarBooked: (details) {},
        ),
      ),
    );
  }

  Future<void> _startLocationTracking() async {
    try {
      await CarLocationTrackingService.instance
          .startTrackingForCurrentOwnerCars();
    } catch (e) {
      print('Location tracking start error: $e');
    }
  }

  void onToggleFavorite(Car car) async {
    final key = _favoriteKey(car);

    setState(() {
      if (favoriteCars.contains(key) || favoriteCars.contains(car.name)) {
        favoriteCars.remove(key);
        favoriteCars.remove(car.name);
      } else {
        favoriteCars.add(key);
      }
    });

    //Optional: Persist to Firestore (Favorites)
    try {
      final uid = currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'favorites': favoriteCars.toList(),
        });
      }
    } catch (e) {
      print("⚠️ Failed to save favorites: $e");
    }
  }

  List<Car> get _baseCars {
    final sourceCars = _liveCarsLoaded && _liveCars.isNotEmpty
        ? _liveCars
        : cars;
    return sourceCars.isNotEmpty ? sourceCars : fallbackCarsForUi();
  }

  _CategorySpec _categorySpecFor(String category) {
    final normalizedCategory = _normalizeCarType(category).toLowerCase();

    return _categorySpecs.firstWhere(
      (spec) => spec.name.toLowerCase() == normalizedCategory,
      orElse: () => _categorySpecs.first,
    );
  }

  String _normalizeCarType(String rawType) {
    final cleaned = rawType.trim();
    if (cleaned.isEmpty) return 'Sedan';

    final normalized = cleaned.toLowerCase();
    if (normalized == 'all') return 'All';

    if (normalized.contains('suv')) return 'SUV';
    if (normalized == 'sedan') return 'Sedan';
    if (normalized.contains('hatch')) return 'Hatchback';
    if (normalized.contains('lux')) return 'Luxury';
    if (normalized.contains('electric') ||
        normalized.contains('ev') ||
        normalized.contains('battery')) {
      return 'Electric (EV)';
    }
    if (normalized.contains('sport') ||
        normalized == 'supercar' ||
        normalized == 'performance' ||
        normalized == 'coupe' ||
        normalized == 'convertible' ||
        normalized == 'cabriolet' ||
        normalized == 'roadster') {
      return 'Sports';
    }

    return 'Sedan';
  }

  List<Car> _carsForCategory(
    String category, {
    bool applySearch = true,
    bool limitToPreview = true,
  }) {
    final normalizedCategory = _normalizeCarType(category).toLowerCase();
    final normalizedQuery = searchQuery.trim().toLowerCase();

    final categoryCars = normalizedCategory == 'all'
        ? _baseCars
        : _baseCars
              .where(
                (car) =>
                    _normalizeCarType(car.type).toLowerCase() ==
                    normalizedCategory,
              )
              .toList();

    if (!applySearch || normalizedQuery.isEmpty) {
      return limitToPreview ? categoryCars.take(3).toList() : categoryCars;
    }

    final filtered = categoryCars
        .where((car) => _matchesSearchQuery(car, normalizedQuery))
        .toList();

    // When searching, show every matched result instead of 3-item preview.
    return filtered;
  }

  bool _matchesSearchQuery(Car car, String normalizedQuery) {
    final fields = <String>[
      car.name,
      car.model,
      car.type,
      car.location,
      car.numberPlate,
      car.year.toString(),
      car.features.join(' '),
      car.description,
    ].map((value) => value.toLowerCase());

    for (final value in fields) {
      if (value.contains(normalizedQuery)) {
        return true;
      }
    }

    return false;
  }

  List<_CategoryCarsGroup> get _visibleCategoryGroups {
    final normalizedSelected = _normalizeCarType(
      selectedCategory,
    ).toLowerCase();

    if (normalizedSelected != 'all') {
      final selectedGroupName = _normalizeCarType(selectedCategory);
      final carsForSelection = _carsForCategory(
        selectedGroupName,
        limitToPreview: false,
      );
      if (carsForSelection.isEmpty) return const [];
      return [
        _CategoryCarsGroup(name: selectedGroupName, cars: carsForSelection),
      ];
    }

    final groups = <_CategoryCarsGroup>[];
    final seenCategoryNames = <String>{};

    for (final spec in _categorySpecs.where((spec) => spec.name != 'All')) {
      final carsForCategory = _carsForCategory(spec.name, limitToPreview: true);
      if (carsForCategory.isEmpty) continue;

      seenCategoryNames.add(spec.name.toLowerCase());
      groups.add(_CategoryCarsGroup(name: spec.name, cars: carsForCategory));
    }

    return groups;
  }

  int get _visibleCarsCount => _visibleCategoryGroups.fold(
    0,
    (total, group) => total + group.cars.length,
  );

  Widget _buildCategoryChip(_CategorySpec spec) {
    const selectedChipColor = Color(0xFF9DDCFF);
    final isSelected =
        _normalizeCarType(selectedCategory).toLowerCase() ==
        spec.name.trim().toLowerCase();
    final count = _carsForCategory(
      spec.name,
      applySearch: false,
      limitToPreview: false,
    ).length;

    return GestureDetector(
      onTap: () {
        setState(() => selectedCategory = spec.name);
        _scrollCarsToTop();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedChipColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedChipColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.55)
                    : spec.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                spec.icon,
                size: 16,
                color: isSelected ? const Color(0xFF0D3A5B) : spec.color,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? const Color(0xFF0D3A5B)
                        : Colors.black.withValues(alpha: 0.82),
                  ),
                ),
                Text(
                  count == 1 ? '1 car' : '$count cars',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFF0D3A5B).withValues(alpha: 0.8)
                        : Colors.black.withValues(alpha: 0.48),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(_CategoryCarsGroup group) {
    final spec = _categorySpecFor(group.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: spec.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(spec.icon, color: spec.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  group.cars.length == 1
                      ? '1 car available'
                      : '${group.cars.length} cars available',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarCard(Car car) {
    final isFavorite = _isFavorite(car);
    final normalizedType = _normalizeCarType(car.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CarApiImage(
                    imageUrl: car.imageUrl,
                    fallbackAssetPath: car.fallbackAssetPath,
                    height: 108,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => onToggleFavorite(car),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_outline,
                    size: 18,
                    color: isFavorite ? Colors.redAccent : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${car.year} • $normalizedType',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Rs ${car.pricePerDay.toInt()}/day',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1C9D56),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _detailPill(Icons.local_gas_station, normalizedType),
              const SizedBox(width: 8),
              _detailPill(Icons.speed, car.hasLiveLocation ? 'Live' : 'Static'),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(96, 38),
                  padding: EdgeInsets.zero,
                  elevation: 0,
                  backgroundColor: const Color(0xFF9DDCFF),
                  foregroundColor: const Color(0xFF0D3A5B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showFleetOptionsAndOpenBooking(car),
                child: const Text(
                  'Book Now',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCarsView() {
    if (_visibleCategoryGroups.isEmpty) {
      return _buildEmptyCarsState();
    }

    return ListView(
      key: ValueKey(
        'cars_${_visibleCarsCount}_${selectedCategory}_${searchQuery.trim()}',
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      children: [
        for (final group in _visibleCategoryGroups) ...[
          _buildCategoryHeader(group),
          for (final car in group.cars) _buildCarCard(car),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildEmptyCarsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Total cars: $_visibleCarsCount',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No cars available in this category',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTopSection() {
    const ink = Color(0xFF121319);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: currentUser == null
            ? null
            : FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser!.uid)
                  .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final firestoreData = snapshot.data?.data();
          final user = currentUser;
          final name = user == null
              ? 'Guest User'
              : _resolveDisplayName(user, firestoreData);
          final photoURL = user == null
              ? ''
              : _resolvePhotoUrl(user, firestoreData);
          final role = (firestoreData?['role'] ?? 'user').toString();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'India',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'logout') {
                        await _logout(context);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'logout', child: Text('Logout')),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ViewProfilePage()),
                  );
                },
                child: Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${_timeBasedGreeting()},\n',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.42),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: '$name ',
                              style: const TextStyle(
                                color: ink,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const TextSpan(
                              text: '👋',
                              style: TextStyle(fontSize: 28),
                            ),
                          ],
                        ),
                      ),
                    ),
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: photoURL.isEmpty
                          ? const AssetImage('assets/images/profile.jpg')
                                as ImageProvider
                          : NetworkImage(photoURL),
                    ),
                  ],
                ),
              ),
              if (role == 'admin') ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminPanelPage()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF8E8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: Color(0xFF2A8F44),
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Go to Admin Panel',
                          style: TextStyle(
                            color: Color(0xFF2A8F44),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search here...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF0F1F3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => searchQuery = value),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    // await FirebaseAuth.instance.signOut();

    // // Navigate back to AuthWrapper
    // // Check if the widget is still mounted before using its context for navigation.
    // if (context.mounted) {
    //   Navigator.of(context).pushAndRemoveUntil(
    //     MaterialPageRoute(builder: (_) => const AuthWrapper()),
    //     (route) => false,
    //   );
    // }

    await CarLocationTrackingService.instance.stopTracking();
    await UserPresenceService.markCurrentUserOffline();
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    // Add a check to ensure the widget is still mounted before using its context.
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => getstart.GetStart()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _carsSubscription?.cancel();
    _fleetSubscription?.cancel();
    _carListController.dispose();
    CarLocationTrackingService.instance.stopTracking();
    super.dispose();
  }

  Widget buildHomePage() {
    return Column(
      children: [
        _buildHomeTopSection(),
        Expanded(
          child: ListView(
            controller: _carListController,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Refreshing cars...')),
                        );
                        await fetchCarsFromFirestore();
                        if (!mounted) return;
                        final safeCars = cars.isNotEmpty
                            ? cars
                            : fallbackCarsForUi();
                        setState(() {
                          _liveCars = List<Car>.from(safeCars);
                          _liveCarsLoaded = true;
                          if (!categories.contains(selectedCategory)) {
                            selectedCategory = 'All';
                          }
                        });
                        _scrollCarsToTop();
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Choose a category to see matching cars and their logos.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.52),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 74,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categorySpecs.length,
                  itemBuilder: (context, index) {
                    return _buildCategoryChip(_categorySpecs[index]);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Cars by category',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Text(
                      selectedCategory,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ),
              ),
              _buildGroupedCarsView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF3C3F49)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3C3F49),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparePage() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => selectedIndex = 0),
                  icon: const Icon(Icons.menu_rounded),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Compare Cars',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showComparePicker(true),
                        child: Container(
                          height: 142,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 46,
                                width: 46,
                                child: CarApiImage(
                                  imageUrl: _compareLeft?.imageUrl,
                                  fallbackAssetPath:
                                      _compareLeft?.fallbackAssetPath ??
                                      'assets/images/Kia Seltos.jpg',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _compareLeft?.name ?? 'Select Car',
                                style: const TextStyle(
                                  color: Color(0xFF1E88E5),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showComparePicker(false),
                        child: Container(
                          height: 142,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 46,
                                width: 46,
                                child: CarApiImage(
                                  imageUrl: _compareRight?.imageUrl,
                                  fallbackAssetPath:
                                      _compareRight?.fallbackAssetPath ??
                                      'assets/images/Kia Seltos.jpg',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _compareRight?.name ?? 'Select Car',
                                style: const TextStyle(
                                  color: Color(0xFF1E88E5),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
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
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'POPULAR CAR COMPARISONS',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 14),
                ..._buildPopularComparisons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPopularComparisons() {
    final rows = <Widget>[];
    final list = _baseCars;
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
                      'Rs. ${left.pricePerDay.toStringAsFixed(0)} Lakh onwards',
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
                      'Rs. ${right.pricePerDay.toStringAsFixed(0)} Lakh onwards',
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

  Widget buildFavoritesPage() {
    final favoriteList = _baseCars.where(_isFavorite).toList();
    return FavoritePage(
      favoriteCars: favoriteList,
      onToggleFavorite: onToggleFavorite,
    );
  }

  Widget buildMenuPage() => MenuPage();

  Widget buildBookedPage() => BookedCar(bookedCars: HomePage.bookedCarsMaps);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: [
          buildHomePage(),
          _buildComparePage(),
          buildBookedPage(),
          buildFavoritesPage(),
          buildMenuPage(),
        ][selectedIndex],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF101217),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: selectedIndex,
          onTap: (index) async {
            setState(() => selectedIndex = index);
            if (index == 0) {
              await fetchCarsFromFirestore();
              if (!mounted) return;
              final safeCars = cars.isNotEmpty ? cars : fallbackCarsForUi();
              setState(() {
                _liveCars = List<Car>.from(safeCars);
                _liveCarsLoaded = true;
              });
              _scrollCarsToTop();
            }
          },
          selectedItemColor: const Color(0xFF9CEB76),
          unselectedItemColor: Colors.white.withValues(alpha: 0.65),
          showSelectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(
              icon: Icon(Icons.compare_arrows),
              label: "Compare",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car),
              label: "Booking",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              label: "Favorite",
            ),
            BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
          ],
        ),
      ),
    );
  }
}
