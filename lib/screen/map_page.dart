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
  final Restaurant? targetRestaurant;
  const MapPage({super.key, this.targetRestaurant});

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
  bool _isFollowingUser = true;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    try {
      final permissionOk = await _locationService.checkPermission();
      final serviceOk = await _locationService.isServiceEnabled();

      if (!permissionOk || !serviceOk) {
        throw Exception("Location services disabled or permission denied");
      }

      final initialPos = await _locationService.getCurrentLocation();
      
      if (mounted) {
        setState(() {
          _userLocation = initialPos;
          _isLoading = false;
        });

        if (widget.targetRestaurant != null) {
          // If we have a target, fit both on screen
          _fitBounds();
          _isFollowingUser = false; // Don't auto-follow if we're looking at a route
        } else {
          _mapController.move(_userLocation, 15.0);
        }
      }

      _locationSubscription = _locationService.getLocationStream().listen((newLocation) {
        if (!mounted) return;
        setState(() {
          _userLocation = newLocation;
          if (_isFollowingUser) {
            _mapController.move(_userLocation, _mapController.camera.zoom);
          }
        });
      });

      await _fetchSpots();
    } catch (e) {
      debugPrint("Location Error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        _fetchSpots();
      }
    }
  }

  void _fitBounds() {
    if (widget.targetRestaurant == null) return;
    
    final target = LatLng(widget.targetRestaurant!.latitude, widget.targetRestaurant!.longitude);
    final bounds = LatLngBounds.fromPoints([_userLocation, target]);
    
    // Add some padding
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  Future<void> _fetchSpots() async {
    try {
      final spots = await _discoveryService.getNearby(
        lat: _userLocation.latitude,
        lng: _userLocation.longitude,
        radiusKm: 5.0,
      );
      if (mounted) setState(() => _spots = spots);
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.targetRestaurant != null 
        ? LatLng(widget.targetRestaurant!.latitude, widget.targetRestaurant!.longitude) 
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.targetRestaurant != null ? 'Directions' : 'Explore Nearby',
          style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 15,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _isFollowingUser) {
                  setState(() => _isFollowingUser = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                tileBuilder: (context, tileWidget, tile) => ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    -1.0, 0.0, 0.0, 0.0, 255.0,
                    0.0, -1.0, 0.0, 0.0, 255.0,
                    0.0, 0.0, -1.0, 0.0, 255.0,
                    0.0, 0.0, 0.0, 1.0, 0.0,
                  ]),
                  child: tileWidget,
                ),
              ),
              if (target != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_userLocation, target],
                      color: const Color(0xFFFFD700),
                      strokeWidth: 4,
                      isDotted: true,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // User Marker
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
                      child: const Icon(Icons.my_location, color: Colors.blue, size: 24),
                    ),
                  ),
                  // Target Restaurant Marker (if any)
                  if (widget.targetRestaurant != null)
                    Marker(
                      point: target!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on, color: Color(0xFFFFD700), size: 45),
                    ),
                  // Other Nearby Restaurants
                  ..._spots.where((s) => s.restaurant.id != widget.targetRestaurant?.id).map((item) => Marker(
                    point: LatLng(item.restaurant.latitude, item.restaurant.longitude),
                    width: 45,
                    height: 45,
                    child: GestureDetector(
                      onTap: () => _showRestaurantPopup(item),
                      child: Icon(
                        Icons.location_on, 
                        color: item.isOpenNow ? const Color(0xFFFFD700) : Colors.white38, 
                        size: 38
                      ),
                    ),
                  )),
                ],
              ),
            ],
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
          
          if (widget.targetRestaurant != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant, color: Color(0xFFFFD700)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.targetRestaurant!.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.targetRestaurant!.address,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.navigation_outlined, color: Color(0xFFFFD700)),
                      onPressed: () => _restaurantService.openMapDirections(
                        widget.targetRestaurant!.latitude, 
                        widget.targetRestaurant!.longitude
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.targetRestaurant != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FloatingActionButton(
                heroTag: 'fit',
                backgroundColor: Colors.white10,
                child: const Icon(Icons.zoom_out_map, color: Colors.white),
                onPressed: _fitBounds,
              ),
            ),
          FloatingActionButton(
            heroTag: 'location',
            backgroundColor: _isFollowingUser ? Colors.blue : const Color(0xFFFFD700),
            foregroundColor: Colors.black,
            child: Icon(_isFollowingUser ? Icons.gps_fixed : Icons.my_location),
            onPressed: () {
              setState(() => _isFollowingUser = true);
              _mapController.move(_userLocation, 15.0);
            },
          ),
        ],
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
