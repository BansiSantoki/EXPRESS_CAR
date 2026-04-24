import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:express_car/services/car_location_tracking_service.dart';
import 'package:express_car/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LiveBookingTrackingPage extends StatefulWidget {
  final int carId;
  final String carName;
  final double? fallbackLat;
  final double? fallbackLng;

  const LiveBookingTrackingPage({
    super.key,
    required this.carId,
    required this.carName,
    this.fallbackLat,
    this.fallbackLng,
  });

  @override
  State<LiveBookingTrackingPage> createState() =>
      _LiveBookingTrackingPageState();
}

class _LiveBookingTrackingPageState extends State<LiveBookingTrackingPage> {
  final MapController _mapController = MapController();
  bool _didAutoCenter = false;
  StreamSubscription<Position>? _userLocationSubscription;
  LatLng? _userPosition;
  bool _userLocationDenied = false;

  @override
  void initState() {
    super.initState();
    // Reuse the app's existing tracking service so owner-side location updates
    // continue publishing to Firestore while this screen is open.
    CarLocationTrackingService.instance.startTrackingForCurrentOwnerCars();
    _startUserLocationTracking();
  }

  @override
  void dispose() {
    _userLocationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _startUserLocationTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _userLocationDenied = true);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final hasPermission =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (!hasPermission) {
        if (!mounted) return;
        setState(() => _userLocationDenied = true);
        return;
      }

      final current = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userPosition = LatLng(current.latitude, current.longitude);
        _userLocationDenied = false;
      });

      _userLocationSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((position) {
            if (!mounted) return;
            setState(() {
              _userPosition = LatLng(position.latitude, position.longitude);
            });
          });
    } catch (_) {
      if (!mounted) return;
      setState(() => _userLocationDenied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: const Text('Live Tracking')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cars')
            .where('car_id', isEqualTo: widget.carId)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _CenteredMessage(
              message: 'Failed to load live location.',
              detail: snapshot.error?.toString(),
            );
          }

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final carDoc = snapshot.data!.docs.first;
            final data = carDoc.data() as Map<String, dynamic>? ?? {};
            return _buildTrackingContent(data);
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('fleet_items')
                .where('car_id', isEqualTo: widget.carId)
                .limit(1)
                .snapshots(),
            builder: (context, fleetSnapshot) {
              if (fleetSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (fleetSnapshot.hasError) {
                return _CenteredMessage(
                  message: 'Failed to load live location.',
                  detail: fleetSnapshot.error?.toString(),
                );
              }

              if (!fleetSnapshot.hasData || fleetSnapshot.data!.docs.isEmpty) {
                return const _CenteredMessage(
                  message: 'Car not found for tracking.',
                  detail: 'Please try again later.',
                );
              }

              final fleetDoc = fleetSnapshot.data!.docs.first;
              final data = fleetDoc.data() as Map<String, dynamic>? ?? {};
              return _buildTrackingContent(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildTrackingContent(Map<String, dynamic> data) {
    final lat = _readDouble(data['location_lat']);
    final lng = _readDouble(data['location_lng']);
    final fallbackLat = widget.fallbackLat;
    final fallbackLng = widget.fallbackLng;
    final updatedAt = _formatTimestamp(data['location_updated_at']);
    final accuracy = _readDouble(data['location_accuracy_m']);
    final speed = _readDouble(data['location_speed_mps']);

    final carPoint = lat != null && lng != null
        ? LatLng(lat, lng)
        : (fallbackLat != null && fallbackLng != null
              ? LatLng(fallbackLat, fallbackLng)
              : null);

    final mapCenter = carPoint ?? _userPosition;

    if (mapCenter == null) {
      return _CenteredMessage(
        message: 'Live location not available yet.',
        detail: _userLocationDenied
            ? 'Location permission denied on this phone. Enable permission to view your live location on map.'
            : 'Waiting for car or user location. Please keep location ON and try again.',
      );
    }

    if (!_didAutoCenter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(mapCenter, 15);
      });
      _didAutoCenter = true;
    }

    final markerList = <Marker>[];
    if (carPoint != null) {
      markerList.add(
        Marker(
          point: carPoint,
          width: 48,
          height: 48,
          child: const Icon(
            Icons.location_on,
            size: 44,
            color: AppTheme.primary,
          ),
        ),
      );
    }
    if (_userPosition != null) {
      markerList.add(
        Marker(
          point: _userPosition!,
          width: 36,
          height: 36,
          child: const Icon(Icons.my_location, size: 28, color: Colors.red),
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.carName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                carPoint != null
                    ? 'Car: ${carPoint.latitude.toStringAsFixed(6)}, ${carPoint.longitude.toStringAsFixed(6)}'
                    : 'Car live location not available',
                style: const TextStyle(color: AppTheme.primaryDark),
              ),
              if (_userPosition != null)
                Text(
                  'You: ${_userPosition!.latitude.toStringAsFixed(6)}, ${_userPosition!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 2),
              Text(
                'Updated: $updatedAt',
                style: const TextStyle(color: Colors.grey),
              ),
              if ((accuracy != null || speed != null) && carPoint != null)
                Text(
                  'Accuracy: ${accuracy?.toStringAsFixed(1) ?? '-'} m | Speed: ${speed?.toStringAsFixed(1) ?? '-'} m/s',
                  style: const TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: mapCenter, initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.express_car',
                  ),
                  MarkerLayer(markers: markerList),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _mapController.move(mapCenter, _mapController.camera.zoom);
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Recenter to latest location'),
            ),
          ),
        ),
      ],
    );
  }

  double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate().toLocal();
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return 'Unknown';
  }
}

class _CenteredMessage extends StatelessWidget {
  final String message;
  final String? detail;

  const _CenteredMessage({required this.message, this.detail});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 44, color: AppTheme.primary),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
