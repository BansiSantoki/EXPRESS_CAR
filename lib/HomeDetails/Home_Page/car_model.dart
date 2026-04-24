import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> carFallbackAssetPaths = [
  'assets/images/Honda City.jpg',
  'assets/images/Hyundai Verna.jpg',
  'assets/images/Hyundai Creta.jpg',
  'assets/images/Kia Seltos.jpg',
  'assets/images/Toyota Fortuner.jpg',
  'assets/images/Volkswagen.jpg',
  'assets/images/Hyundai i20.jpg',
  'assets/images/swift.jpg',
  'assets/images/Tata Altroz.jpeg',
  'assets/images/Tata Nexon.jpg',
  'assets/images/BMW 3 Series.jpg',
  'assets/images/Mercedes-Benz E-Class.jpg',
  'assets/images/AudiA6.jpg',
  'assets/images/Mahindra Scorpio1.jpg',
  'assets/images/Skoda Kushaq.jpg',
  'assets/images/FordMustang.jpg',
  'assets/images/Porsche911.jpg',
  'assets/images/Ferrari 12Cilindri.jpg',
  'assets/images/Tata TiagoEV.jpg',
  'assets/images/MGZSEV.jpg',
  'assets/images/Mahindra XUV400EV.jpg',
];

class Car {
  final int carId;
  final String name;
  final String model;
  final String type; // sedan, SUV, etc.
  final String numberPlate;
  final List<String> features;
  final String location;
  final int year;
  final double pricePerDay;
  final double? pricePerWeek;
  final double? pricePerMonth;
  final String description;
  final String? imageUrl; // Made nullable for safety
  final String? ownerEmail;
  final double? locationLat;
  final double? locationLng;
  final DateTime? locationUpdatedAt;
  final DateTime? createdAt;
  final String sourceCollection;
  final String sourceDocId;
  final String fleetType;

  Car({
    required this.carId,
    required this.name,
    required this.model,
    required this.type,
    required this.numberPlate,
    required this.features,
    required this.location,
    required this.year,
    required this.pricePerDay,
    this.pricePerWeek,
    this.pricePerMonth,
    required this.description,
    this.imageUrl,
    this.ownerEmail,
    this.locationLat,
    this.locationLng,
    this.locationUpdatedAt,
    this.createdAt,
    this.sourceCollection = 'cars',
    this.sourceDocId = '',
    this.fleetType = 'driverless',
  });

  bool get hasLiveLocation => locationLat != null && locationLng != null;

  double get effectivePricePerWeek => pricePerWeek ?? pricePerDay * 7;

  double get effectivePricePerMonth => pricePerMonth ?? pricePerDay * 30;

  String get trackingSubtitle {
    if (!hasLiveLocation) return location;

    final updated = locationUpdatedAt;
    if (updated == null) {
      return 'Live: ${locationLat!.toStringAsFixed(5)}, ${locationLng!.toStringAsFixed(5)}';
    }

    return 'Live @ ${updated.toLocal()}';
  }

  String get fallbackAssetPath {
    final index = carId.abs() % carFallbackAssetPaths.length;
    return carFallbackAssetPaths[index];
  }

  // Factory to create Car from Firestore data
  factory Car.fromFirestore(
    Map<String, dynamic> data, {
    String sourceCollection = 'cars',
    String sourceDocId = '',
  }) {
    try {
      final allKeys = data.keys.toList();
      print("📋 Document has ${allKeys.length} fields: $allKeys");

      final car = Car(
        carId: _parseIntField(data, 'car_id'),
        name: _parseStringFieldRequired(data, 'name', 'Unknown Car'),
        model: _parseStringFieldRequired(data, 'model', 'Unknown'),
        type: _parseStringFieldRequired(
          data,
          'type',
          'Sedan',
        ), // Default to Sedan if missing
        numberPlate: _parseStringFieldRequired(data, 'number_plate', 'N/A'),
        features: _parseFeaturesField(data),
        location: _parseStringFieldRequired(data, 'location', 'Unknown'),
        year: _parseIntField(data, 'year'),
        pricePerDay: _parseDoubleField(data, 'price_per_day'),
        pricePerWeek: _parseNullableDoubleField(data, 'price_per_week'),
        pricePerMonth: _parseNullableDoubleField(data, 'price_per_month'),
        description: _parseStringFieldRequired(
          data,
          'description',
          'No description',
        ),
        imageUrl: _parseImageUrlField(data),
        ownerEmail: _parseStringField(data, 'owner_email'),
        locationLat: _parseCoordinateField(
          data,
          'location_lat',
          'current_location',
          true,
        ),
        locationLng: _parseCoordinateField(
          data,
          'location_lng',
          'current_location',
          false,
        ),
        locationUpdatedAt: _parseTimestampField(data, 'location_updated_at'),
        createdAt:
            _parseTimestampField(data, 'created_at') ??
            _parseTimestampField(data, 'createdAt'),
        sourceCollection: sourceCollection,
        sourceDocId: sourceDocId,
        fleetType: _parseFleetType(data),
      );

      print(
        " Car created: ${car.name} (Type: ${car.type}, Price: ${car.pricePerDay}/day)",
      );
      return car;
    } catch (e) {
      print(" Error parsing car: $e");
      print("Data keys: ${data.keys}");
      rethrow;
    }
  }

  static int _parseIntField(
    Map<String, dynamic> data,
    String key, [
    int defaultValue = 0,
  ]) {
    try {
      final value = data[key];
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    } catch (e) {
      print("⚠️ Error parsing $key as int: $e");
      return defaultValue;
    }
  }

  static double _parseDoubleField(
    Map<String, dynamic> data,
    String key, [
    double defaultValue = 0.0,
  ]) {
    try {
      final value = data[key];
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    } catch (e) {
      print("⚠️ Error parsing $key as double: $e");
      return defaultValue;
    }
  }

  static double? _parseNullableDoubleField(
    Map<String, dynamic> data,
    String key,
  ) {
    try {
      final value = data[key];
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    } catch (e) {
      print("⚠️ Error parsing $key as nullable double: $e");
      return null;
    }
  }

  static String _parseStringFieldRequired(
    Map<String, dynamic> data,
    String key,
    String defaultValue,
  ) {
    try {
      final value = data[key];
      if (value == null) return defaultValue;
      return value.toString();
    } catch (e) {
      print("⚠️ Error parsing $key as string: $e");
      return defaultValue;
    }
  }

  static String? _parseStringField(
    Map<String, dynamic> data,
    String key, [
    String? defaultValue,
  ]) {
    try {
      final value = data[key];
      if (value == null) return defaultValue;
      return value.toString();
    } catch (e) {
      print("⚠️ Error parsing $key as string: $e");
      return defaultValue;
    }
  }

  static String? _parseImageUrlField(Map<String, dynamic> data) {
    const candidateKeys = [
      'image_url',
      'imageUrl',
      'image',
      'imageUrlString',
      'display_url',
      'url',
      'photoURL',
      'thumbnail_url',
      'thumbnail',
    ];

    for (final key in candidateKeys) {
      final raw = data[key];
      if (raw == null) continue;

      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty) return trimmed;
        continue;
      }

      if (raw is Map<String, dynamic>) {
        final nested = raw['url'] ?? raw['display_url'];
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }
    }

    return null;
  }

  static List<String> _parseFeaturesField(Map<String, dynamic> data) {
    try {
      final value = data['features'];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      print("⚠️ Error parsing features: $e");
      return [];
    }
  }

  static double? _parseCoordinateField(
    Map<String, dynamic> data,
    String key,
    String geoPointKey,
    bool isLat,
  ) {
    final value = data[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);

    final geo = data[geoPointKey];
    if (geo is GeoPoint) {
      return isLat ? geo.latitude : geo.longitude;
    }

    return null;
  }

  static DateTime? _parseTimestampField(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _parseFleetType(Map<String, dynamic> data) {
    final raw = (data['fleet_type'] ?? data['fleetType'] ?? 'driverless')
        .toString()
        .trim()
        .toLowerCase();
    if (raw == 'with_driver' || raw == 'with driver' || raw == 'driver') {
      return 'with_driver';
    }
    return 'driverless';
  }

  // Convert Car to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'car_id': carId,
      'name': name,
      'model': model,
      'type': type,
      'number_plate': numberPlate,
      'features': features,
      'location': location,
      'year': year,
      'price_per_day': pricePerDay,
      'price_per_week': pricePerWeek,
      'price_per_month': pricePerMonth,
      'description': description,
      'image_url': imageUrl,
      'owner_email': ownerEmail,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'location_updated_at': locationUpdatedAt,
      'created_at': createdAt,
    };
  }
}
