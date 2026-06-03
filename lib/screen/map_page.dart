import 'dart:async';
import '../services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/restaurant_service.dart';
import '../model/restaurant.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final RestaurantService _restaurantService = RestaurantService();
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();

  List<Restaurant> _spots = [];
  LatLng _userLocation = LatLng(23.8103, 90.4125);

  bool _isLoading = true;
  bool _mapStarted = false;

  @override
  void initState() {
    super.initState();
    _initMap(); // ✅ FIX: NOW IT RUNS
  }

  // ─────────────────────────────
  // INIT MAP + LIVE LOCATION
  // ─────────────────────────────
  Future<void> _initMap() async {
    try {
      final permissionOk = await _locationService.checkPermission();
      final serviceOk = await _locationService.isServiceEnabled();

      if (!permissionOk || !serviceOk) {
        throw Exception("Location permission/service not available");
      }

      // LIVE STREAM
      _locationService.getLocationStream().listen((newLocation) {
        if (!mounted) return;

        setState(() {
          _userLocation = newLocation;
        });

        _mapController.move(newLocation, 15.0);
      });

      _mapStarted = true;

    } catch (e) {
      debugPrint("Location error: $e");
    }

    await _fetchSpots();
  }

  // ─────────────────────────────
  // RESTAURANTS
  // ─────────────────────────────
  Future<void> _fetchSpots() async {
    try {
      final spots = await _restaurantService.fetchNearbyRestaurants();

      if (mounted) {
        setState(() {
          _spots = spots;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Restaurant fetch error: $e");

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─────────────────────────────
  // UI
  // ─────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Explore Nearby',
          style: TextStyle(color: Color(0xFFFFD700)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchSpots();
            },
          )
        ],
      ),

      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.local_lense.app',
              ),

              MarkerLayer(
                markers: [
                  // USER MARKER
                  Marker(
                    point: _userLocation,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),

                  // RESTAURANTS
                  ..._spots
                      .where((r) =>
                  r.latitude != 0.0 && r.longitude != 0.0)
                      .map((r) {
                    return Marker(
                      point: LatLng(r.latitude, r.longitude),
                      width: 45,
                      height: 45,
                      child: GestureDetector(
                        onTap: () => _showRestaurantPopup(r),
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFFFFD700),
                          size: 38,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFD700),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────
  // POPUP
  // ─────────────────────────────
  void _showRestaurantPopup(Restaurant r) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        color: const Color(0xFF1A1A1A),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              r.name,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              r.address,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  // ONLY ONE DISPOSE (optional cleanup not required here)
  @override
  void dispose() {
    super.dispose();
  }
}