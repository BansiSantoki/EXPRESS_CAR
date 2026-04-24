import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class CarLocationTrackingService {
  CarLocationTrackingService._();

  static final CarLocationTrackingService instance =
      CarLocationTrackingService._();

  StreamSubscription<Position>? _positionSubscription;

  bool get isTracking => _positionSubscription != null;

  Future<void> startTrackingForCurrentOwnerCars() async {
    if (isTracking) return;

    final hasPermission = await _ensurePermission();
    if (!hasPermission) return;

    final settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 30,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((
          position,
        ) async {
          await _pushLocationToOwnedCars(position);
        });
  }

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> _pushLocationToOwnedCars(Position position) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) return;

    final fireStore = FirebaseFirestore.instance;

    QuerySnapshot carsSnapshot = await fireStore
        .collection('cars')
        .where('owner_email', isEqualTo: user.email)
        .get();

    if (carsSnapshot.docs.isEmpty) {
      carsSnapshot = await fireStore
          .collection('cars')
          .where('owner_uid', isEqualTo: user.uid)
          .get();
    }

    QuerySnapshot fleetSnapshot = await fireStore
        .collection('fleet_items')
        .where('owner_email', isEqualTo: user.email)
        .get();

    if (fleetSnapshot.docs.isEmpty) {
      fleetSnapshot = await fireStore
          .collection('fleet_items')
          .where('owner_uid', isEqualTo: user.uid)
          .get();
    }

    if (carsSnapshot.docs.isEmpty && fleetSnapshot.docs.isEmpty) return;

    final batch = fireStore.batch();
    for (final carDoc in carsSnapshot.docs) {
      batch.update(carDoc.reference, {
        'current_location': GeoPoint(position.latitude, position.longitude),
        'location_lat': position.latitude,
        'location_lng': position.longitude,
        'location_accuracy_m': position.accuracy,
        'location_speed_mps': position.speed,
        'location_heading_deg': position.heading,
        'location_updated_at': FieldValue.serverTimestamp(),
      });
    }

    for (final fleetDoc in fleetSnapshot.docs) {
      batch.update(fleetDoc.reference, {
        'current_location': GeoPoint(position.latitude, position.longitude),
        'location_lat': position.latitude,
        'location_lng': position.longitude,
        'location_accuracy_m': position.accuracy,
        'location_speed_mps': position.speed,
        'location_heading_deg': position.heading,
        'location_updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
