import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;

  /// Live location stream (LatLng output)
  Stream<LatLng> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).map((Position position) {
      return LatLng(position.latitude, position.longitude);
    });
  }

  /// Check & request permission
  Future<bool> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Check GPS enabled
  Future<bool> isServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get single position (optional use)
  Future<LatLng> getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLng(position.latitude, position.longitude);
  }

  /// Stop stream (cleanup)
  void dispose() {
    _positionSubscription?.cancel();
  }
}