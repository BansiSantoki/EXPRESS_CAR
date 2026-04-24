import 'package:cloud_firestore/cloud_firestore.dart';
import 'car_model.dart';

const String _sedanImageUrl =
    'https://images.pexels.com/photos/170811/pexels-photo-170811.jpeg?auto=compress&cs=tinysrgb&w=1200';
const String _suvImageUrl =
    'https://images.pexels.com/photos/210019/pexels-photo-210019.jpeg?auto=compress&cs=tinysrgb&w=1200';
const String _hatchbackImageUrl =
    'https://images.pexels.com/photos/358070/pexels-photo-358070.jpeg?auto=compress&cs=tinysrgb&w=1200';
const String _vanImageUrl =
    'https://images.pexels.com/photos/164634/pexels-photo-164634.jpeg?auto=compress&cs=tinysrgb&w=1200';
const String _coupeImageUrl =
    'https://images.pexels.com/photos/112460/pexels-photo-112460.jpeg?auto=compress&cs=tinysrgb&w=1200';
const String _convertibleImageUrl =
    'https://images.pexels.com/photos/239909/pexels-photo-239909.jpeg?auto=compress&cs=tinysrgb&w=1200';

List<Car> cars = _fallbackCars();

List<Car> _fallbackCars() {
  return [
    Car(
      carId: 1,
      name: 'Honda City',
      model: 'ZX',
      type: 'Sedan',
      numberPlate: 'GJ01AB1001',
      features: ['Automatic gearbox', 'Air conditioning', 'Bluetooth'],
      location: 'Surat',
      year: 2023,
      pricePerDay: 3200,
      description: 'Comfortable city sedan with premium features.',
      imageUrl: _sedanImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 2,
      name: 'Hyundai Creta',
      model: 'SX',
      type: 'SUV',
      numberPlate: 'GJ01AB1002',
      features: ['Touchscreen', 'Rear camera', 'Cruise control'],
      location: 'Ahmedabad',
      year: 2024,
      pricePerDay: 4500,
      description: 'Popular SUV for family and travel.',
      imageUrl: _suvImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 3,
      name: 'Tata Nexon',
      model: 'XZ+',
      type: 'SUV',
      numberPlate: 'GJ01AB1003',
      features: ['6 airbags', 'Cruise control', 'Wireless Android Auto'],
      location: 'Surat',
      year: 2024,
      pricePerDay: 4100,
      description: 'Compact SUV with strong road presence.',
      imageUrl: _suvImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 4,
      name: 'Swift',
      model: 'VXI',
      type: 'Hatchback',
      numberPlate: 'GJ01AB1004',
      features: ['Power steering', 'AC', 'Bluetooth'],
      location: 'Rajkot',
      year: 2022,
      pricePerDay: 2500,
      description: 'Easy city driving hatchback.',
      imageUrl: _hatchbackImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 9,
      name: 'Baleno',
      model: 'Alpha',
      type: 'Hatchback',
      numberPlate: 'GJ01AB1009',
      features: ['SmartPlay Pro', '360 camera', 'LED headlamps'],
      location: 'Ahmedabad',
      year: 2024,
      pricePerDay: 2800,
      description: 'Comfortable hatchback with premium cabin feel.',
      imageUrl: _hatchbackImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 5,
      name: 'Mahindra XUV700',
      model: 'AX7',
      type: 'SUV',
      numberPlate: 'GJ01AB1005',
      features: ['Sunroof', 'Navigation', 'Airbags'],
      location: 'Vadodara',
      year: 2024,
      pricePerDay: 5200,
      description: 'Feature-packed SUV for long trips.',
      imageUrl: _suvImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 10,
      name: 'Toyota Fortuner',
      model: 'Legender',
      type: 'SUV',
      numberPlate: 'GJ01AB1010',
      features: ['4x4', 'Leather seats', 'Parking sensors'],
      location: 'Vadodara',
      year: 2024,
      pricePerDay: 7800,
      description: 'Premium SUV for long highway journeys.',
      imageUrl: _suvImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 6,
      name: 'Toyota Innova',
      model: 'Crysta',
      type: 'Van',
      numberPlate: 'GJ01AB1006',
      features: ['7 Seater', 'Automatic gearbox', 'Rear camera'],
      location: 'Surat',
      year: 2023,
      pricePerDay: 6000,
      description: 'Spacious car for group travel.',
      imageUrl: _vanImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 11,
      name: 'Kia Carnival',
      model: 'Premium',
      type: 'Van',
      numberPlate: 'GJ01AB1011',
      features: ['7 seater', 'Ventilated seats', 'Auto climate'],
      location: 'Mumbai',
      year: 2024,
      pricePerDay: 7000,
      description: 'Luxury van for family and business travel.',
      imageUrl: _vanImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 7,
      name: 'BMW 4 Series',
      model: '430i',
      type: 'Coupe',
      numberPlate: 'GJ01AB1007',
      features: ['Leather seats', 'Sport mode', 'Sunroof'],
      location: 'Ahmedabad',
      year: 2024,
      pricePerDay: 8500,
      description: 'Premium coupe with a sporty driving feel.',
      imageUrl: _coupeImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 12,
      name: 'Audi A5',
      model: 'Sportback',
      type: 'Coupe',
      numberPlate: 'GJ01AB1012',
      features: ['Quattro', 'Virtual cockpit', 'Ambient lighting'],
      location: 'Ahmedabad',
      year: 2024,
      pricePerDay: 8800,
      description: 'Elegant coupe with performance and style.',
      imageUrl: _coupeImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 8,
      name: 'Mazda MX-5',
      model: 'RF',
      type: 'Convertible',
      numberPlate: 'GJ01AB1008',
      features: ['Soft top', 'Sport seats', 'Cruise control'],
      location: 'Mumbai',
      year: 2024,
      pricePerDay: 9200,
      description: 'Compact convertible designed for open-air drives.',
      imageUrl: _convertibleImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 13,
      name: 'Porsche 718 Boxster',
      model: 'Base',
      type: 'Convertible',
      numberPlate: 'GJ01AB1013',
      features: ['Soft top', 'Paddle shifters', 'Sport chrono'],
      location: 'Mumbai',
      year: 2024,
      pricePerDay: 11000,
      description: 'Open-top sports car for premium drives.',
      imageUrl: _convertibleImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 14,
      name: 'Honda City Hybrid',
      model: 'e:HEV',
      type: 'Sedan',
      numberPlate: 'GJ01AB1014',
      features: ['Hybrid engine', 'Lane watch', 'Sunroof'],
      location: 'Surat',
      year: 2024,
      pricePerDay: 3800,
      description: 'Efficient sedan with a smooth hybrid drive.',
      imageUrl: _sedanImageUrl,
      ownerEmail: null,
    ),
    Car(
      carId: 15,
      name: 'Skoda Slavia',
      model: 'Style',
      type: 'Sedan',
      numberPlate: 'GJ01AB1015',
      features: ['Ventilated seats', 'Digital cockpit', 'Sunroof'],
      location: 'Ahmedabad',
      year: 2024,
      pricePerDay: 4300,
      description: 'Premium sedan with comfort-focused driving.',
      imageUrl: null,
      ownerEmail: null,
    ),
    Car(
      carId: 16,
      name: 'Jeep Compass',
      model: 'Limited',
      type: 'SUV',
      numberPlate: 'GJ01AB1016',
      features: ['4x4', 'Panoramic roof', 'Navigation'],
      location: 'Vadodara',
      year: 2024,
      pricePerDay: 6400,
      description: 'Urban SUV with capable highway performance.',
      imageUrl: null,
      ownerEmail: null,
    ),
    Car(
      carId: 17,
      name: 'Maruti Ertiga',
      model: 'ZXI+',
      type: 'MPV',
      numberPlate: 'GJ01AB1017',
      features: ['7 seater', 'Rear AC vents', 'Touchscreen'],
      location: 'Surat',
      year: 2023,
      pricePerDay: 3600,
      description: 'Practical family mover for daily and outstation trips.',
      imageUrl: null,
      ownerEmail: null,
    ),
  ];
}

List<Car> fallbackCarsForUi() => _fallbackCars();

Future<void> fetchCarsFromFirestore() async {
  print("🔄 Starting to fetch cars and fleet items from Firestore...");

  final List<Car> loadedCars = [];

  try {
    final carsSnapshot = await FirebaseFirestore.instance
        .collection('cars')
        .get();
    print("📊 Retrieved ${carsSnapshot.docs.length} cars");

    for (final doc in carsSnapshot.docs) {
      final data = doc.data();
      try {
        final car = Car.fromFirestore(
          data,
          sourceCollection: 'cars',
          sourceDocId: doc.id,
        );
        loadedCars.add(car);
      } catch (e) {
        print("❌ Error creating car from cars/${doc.id}: $e");
      }
    }
  } catch (e) {
    print("❌ Error reading cars collection: $e");
  }

  try {
    // Fetch all fleet docs and filter in Dart so mixed status formats still work.
    final fleetSnapshot = await FirebaseFirestore.instance
        .collection('fleet_items')
        .get();
    print("📊 Retrieved ${fleetSnapshot.docs.length} fleet items");

    for (final doc in fleetSnapshot.docs) {
      final data = doc.data();
      if (!_isApprovedFleet(data)) {
        continue;
      }

      final fallbackCarId = doc.id.hashCode.abs();
      final carMap = <String, dynamic>{
        'car_id': data['car_id'] ?? fallbackCarId,
        'name': data['name'] ?? data['car_name'] ?? 'Fleet Car',
        'model': data['model'] ?? 'N/A',
        'type': data['type'] ?? data['category'] ?? 'SUV',
        'number_plate': data['number_plate'] ?? data['numberPlate'] ?? 'N/A',
        'features': data['features'] ?? const <String>[],
        'location': data['location'] ?? data['city'] ?? 'Unknown',
        'year': data['year'] ?? DateTime.now().year,
        'price_per_day': data['price_per_day'] ?? data['price'] ?? 2000,
        'description': data['notes'] ?? data['description'] ?? 'Fleet listing',
        'image_url':
            data['image_url'] ??
            data['imageUrl'] ??
            data['image'] ??
            data['display_url'] ??
            data['url'],
        'owner_email': data['owner_email'] ?? data['ownerEmail'] ?? '',
        'fleet_type': data['fleet_type'] ?? data['fleetType'] ?? 'driverless',
        'fleetType': data['fleetType'] ?? data['fleet_type'] ?? 'driverless',
      };

      try {
        final fleetCar = Car.fromFirestore(
          carMap,
          sourceCollection: 'fleet_items',
          sourceDocId: doc.id,
        );
        loadedCars.add(fleetCar);
      } catch (e) {
        print('❌ Error mapping fleet item ${doc.id}: $e');
      }
    }
  } catch (e) {
    print("❌ Error reading fleet_items collection: $e");
  }

  cars = loadedCars.isNotEmpty ? loadedCars : _fallbackCars();
  cars.sort(_compareCarsByCreatedAtDesc);
  print("✅ Successfully loaded ${cars.length} cars");
}

int _compareCarsByCreatedAtDesc(Car left, Car right) {
  final leftTime = left.createdAt;
  final rightTime = right.createdAt;

  if (leftTime == null && rightTime == null) return 0;
  if (leftTime == null) return 1;
  if (rightTime == null) return -1;

  return rightTime.compareTo(leftTime);
}

bool _isApprovedFleet(Map<String, dynamic> data) {
  final rawStatus =
      data['approvalStatus'] ??
      data['approval_status'] ??
      data['status'] ??
      data['state'];

  if (rawStatus == null) {
    final isApproved = data['isApproved'];
    if (isApproved is bool) return isApproved;
    return true;
  }

  final normalized = rawStatus.toString().trim().toLowerCase();
  return normalized == 'approved' ||
      normalized == 'active' ||
      normalized == 'published';
}

// Get car by ID
Car? getCarById(int carId) {
  try {
    return cars.firstWhere((car) => car.carId == carId);
  } catch (e) {
    print("Car with ID $carId not found");
    return null;
  }
}

// Get cars by type (category)
List<Car> getCarsByType(String type) {
  return cars
      .where((car) => car.type.toLowerCase() == type.toLowerCase())
      .toList();
}

// Get cars by owner email
List<Car> getCarsByOwner(String ownerEmail) {
  return cars.where((car) => car.ownerEmail == ownerEmail).toList();
}
