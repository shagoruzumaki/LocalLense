import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/discovery_service.dart';
import '../services/restaurant_service.dart';
import '../model/restaurant.dart';
import '../utils/location_utils.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final DiscoveryService _discoveryService = DiscoveryService();
  final RestaurantService _restaurantService = RestaurantService();
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  StreamSubscription<LatLng>? _locationSubscription;

  List<RestaurantWithScore> _spots = [];
  LatLng _userLocation = const LatLng(23.8103, 90.4125); // Default: Dhaka

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initMap();
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

      // Get Initial location and move map to it
      final initialPos = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _userLocation = initialPos;
        });
        _mapController.move(_userLocation, 14.0);
      }

      // Start live stream to update marker position
      _locationSubscription = _locationService.getLocationStream().listen((newLocation) {
        if (!mounted) return;
        setState(() {
          _userLocation = newLocation;
        });
      });

      await _fetchSpots();
    } catch (e) {
      debugPrint("Map initialization error: $e");
      await _fetchSpots(); // Fetch anyway using default (Dhaka)
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────
  // RESTAURANTS
  // ─────────────────────────────
  Future<void> _fetchSpots() async {
    try {
      final spots = await _discoveryService.getNearby(
        lat: _userLocation.latitude,
        lng: _userLocation.longitude,
        radiusKm: 5.0,
      );

      if (mounted) {
        setState(() {
          _spots = spots;
        });
      }
    } catch (e) {
      debugPrint("Restaurant fetch error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Explore Nearby',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchSpots().then((_) {
                if (mounted) setState(() => _isLoading = false);
              });
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
                tileBuilder: (context, tileWidget, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      -1.0, 0.0, 0.0, 0.0, 255.0,
                      0.0, -1.0, 0.0, 0.0, 255.0,
                      0.0, 0.0, -1.0, 0.0, 255.0,
                      0.0, 0.0, 0.0, 1.0, 0.0,
                    ]),
                    child: tileWidget,
                  );
                },
              ),
              MarkerLayer(
                markers: [
                  // LIVE USER MARKER
                  Marker(
                    point: _userLocation,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                  ),

                  // RESTAURANTS
                  ..._spots.map((item) {
                    final r = item.restaurant;
                    final isOpen = item.isOpenNow;
                    return Marker(
                      point: LatLng(r.latitude, r.longitude),
                      width: 45,
                      height: 45,
                      child: GestureDetector(
                        onTap: () => _showRestaurantPopup(item),
                        child: Icon(
                          Icons.location_on,
                          color: isOpen ? const Color(0xFFFFD700) : Colors.white38,
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: Colors.black,
        child: const Icon(Icons.my_location),
        onPressed: () {
          _mapController.move(_userLocation, 15.0);
        },
      ),
    );
  }

  void _showRestaurantPopup(RestaurantWithScore item) {
    final r = item.restaurant;
    final dist = item.distanceKm != null 
        ? LocationUtils.formatDistance(item.distanceKm!) 
        : "Nearby";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.isOpenNow 
                                  ? Colors.green.withOpacity(0.2) 
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.isOpenNow ? "OPEN NOW" : "CLOSED",
                              style: TextStyle(
                                color: item.isOpenNow ? Colors.green : Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(dist, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      item.scoreLabel.toUpperCase(),
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      r.rating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              r.categoryDisplay.toUpperCase(),
              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, letterSpacing: 1.1),
            ),
            const SizedBox(height: 12),
            Text(
              r.address,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Text('VIEW DETAILS', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.directions, color: Color(0xFFFFD700)),
                    onPressed: () {
                      _restaurantService.openMapDirections(r.latitude, r.longitude);
                    },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}
