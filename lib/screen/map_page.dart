import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

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
  LatLng _userLocation = const LatLng(0, 0); // Start at 0,0 to detect if we haven't found user yet
  List<LatLng> _routePoints = [];
  
  Restaurant? _currentTarget;
  double? _roadDistanceKm;
  double? _roadDurationMin;
  
  bool _isLoading = true;
  bool _isFollowingUser = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentTarget = widget.targetRestaurant;
    _initMap();
  }

  Future<void> _initMap() async {
    try {
      final permissionOk = await _locationService.checkPermission();
      if (!permissionOk) {
        setState(() {
          _errorMessage = "Location permissions are required to use the map.";
          _isLoading = false;
        });
        return;
      }

      final serviceOk = await _locationService.isServiceEnabled();
      if (!serviceOk) {
        setState(() {
          _errorMessage = "Please enable GPS/Location services.";
          _isLoading = false;
        });
        return;
      }

      // Try to get current location
      try {
        final initialPos = await _locationService.getCurrentLocation();
        if (mounted) {
          setState(() {
            _userLocation = initialPos;
            _isLoading = false;
          });

          if (_currentTarget != null) {
            _isFollowingUser = false;
            await _getRoute(); 
            _fitBounds();
          } else {
            _mapController.move(_userLocation, 15.0);
          }
        }
      } catch (e) {
        debugPrint("Initial location fetch failed: $e");
        // Don't stop here, the stream might still provide location
      }

      _locationSubscription = _locationService.getLocationStream().listen(
        (newLocation) {
          if (!mounted) return;
          
          bool wasZero = _userLocation.latitude == 0 && _userLocation.longitude == 0;

          double distMoved = wasZero ? 0 : LocationUtils.calculateDistance(
            _userLocation.latitude, _userLocation.longitude,
            newLocation.latitude, newLocation.longitude
          );

          setState(() {
            _userLocation = newLocation;
            _isLoading = false; // Successfully got a location
            if (_isFollowingUser || wasZero) {
              _mapController.move(_userLocation, _mapController.camera.zoom < 5 ? 15.0 : _mapController.camera.zoom);
            }
          });
          
          if (_currentTarget != null && (distMoved > 0.02 || wasZero)) { 
             _getRoute(); 
          }
        },
        onError: (e) {
          debugPrint("Location Stream Error: $e");
          if (mounted && _userLocation.latitude == 0) {
            setState(() => _errorMessage = "Could not get your location. Please check your GPS settings.");
          }
        }
      );

      await _fetchSpots();
    } catch (e) {
      debugPrint("General Map Error: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Something went wrong initializing the map.";
          _isLoading = false;
        });
        _fetchSpots();
      }
    }
  }

  Future<void> _getRoute() async {
    if (_currentTarget == null || (_userLocation.latitude == 0 && _userLocation.longitude == 0)) return;

    try {
      final target = LatLng(_currentTarget!.latitude, _currentTarget!.longitude);
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${_userLocation.longitude},${_userLocation.latitude};'
        '${target.longitude},${target.latitude}'
        '?overview=full&geometries=geojson'
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final List coords = route['geometry']['coordinates'];
          
          if (mounted) {
            setState(() {
              _routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
              _roadDistanceKm = (route['distance'] as num) / 1000.0;
              _roadDurationMin = (route['duration'] as num) / 60.0;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Routing Error: $e");
      setState(() {
        _routePoints = [_userLocation, LatLng(_currentTarget!.latitude, _currentTarget!.longitude)];
      });
    }
  }

  void _fitBounds() {
    if (_currentTarget == null || (_userLocation.latitude == 0 && _userLocation.longitude == 0)) return;
    
    final target = LatLng(_currentTarget!.latitude, _currentTarget!.longitude);
    final bounds = LatLngBounds.fromPoints([_userLocation, target]);
    
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(top: 80, bottom: 260, left: 50, right: 50),
      ),
    );
  }

  Future<void> _fetchSpots() async {
    if (_userLocation.latitude == 0) return;
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _currentTarget != null ? 'Live Road Directions' : 'Explore Nearby',
          style: const TextStyle(
            color: Color(0xFFFFD700), 
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
          ),
        ),
        actions: [
          if (_currentTarget != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: "Clear Route",
              onPressed: () {
                setState(() {
                  _currentTarget = null;
                  _routePoints = [];
                  _roadDistanceKm = null;
                  _roadDurationMin = null;
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
              initialCenter: _userLocation.latitude == 0 ? const LatLng(0, 0) : _userLocation,
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
                userAgentPackageName: 'com.example.local_lense',
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
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFFFFD700),
                      strokeWidth: 6,
                      borderColor: Colors.black.withValues(alpha: 0.5),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // LIVE USER DOT
                  if (_userLocation.latitude != 0)
                    Marker(
                      point: _userLocation,
                      width: 40,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // DESTINATION
                  if (_currentTarget != null)
                    Marker(
                      point: LatLng(_currentTarget!.latitude, _currentTarget!.longitude),
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on, color: Color(0xFFFFD700), size: 45),
                    ),
                  // NEARBY PLACES
                  ..._spots.where((s) => s.restaurant.id != _currentTarget?.id).map((item) => Marker(
                    point: LatLng(item.restaurant.latitude, item.restaurant.longitude),
                    width: 45,
                    height: 45,
                    child: GestureDetector(
                      onTap: () => _showRestaurantPopup(item),
                      child: Icon(
                        Icons.location_on, 
                        color: const Color(0xFFFFD700), // Changed to solid yellow for all markers
                        size: 38
                      ),
                    ),
                  )),
                ],
              ),
            ],
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFFFD700)),
                    SizedBox(height: 16),
                    Text("Fetching your location...", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          
          if (_errorMessage != null)
             Center(
               child: Container(
                 margin: const EdgeInsets.all(24),
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   color: const Color(0xFF1A1A1A),
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                 ),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     const Icon(Icons.location_off, color: Colors.redAccent, size: 48),
                     const SizedBox(height: 16),
                     Text(
                       _errorMessage!,
                       textAlign: TextAlign.center,
                       style: const TextStyle(color: Colors.white, fontSize: 16),
                     ),
                     const SizedBox(height: 24),
                     ElevatedButton(
                       style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
                       onPressed: () {
                         setState(() {
                           _errorMessage = null;
                           _isLoading = true;
                         });
                         _initMap();
                       },
                       child: const Text("Retry", style: TextStyle(color: Colors.black)),
                     ),
                   ],
                 ),
               ),
             ),
          
          // DIRECTION INFO CARD
          if (_currentTarget != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 15, spreadRadius: 2)],
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restaurant, color: Color(0xFFFFD700), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentTarget!.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_roadDistanceKm != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Text(
                                    "${_roadDistanceKm!.toStringAsFixed(1)} km",
                                    style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "• ${_roadDurationMin!.toStringAsFixed(0)} min drive",
                                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                        elevation: 4,
                      ),
                      onPressed: () => _restaurantService.openMapDirections(
                        _currentTarget!.latitude, 
                        _currentTarget!.longitude
                      ),
                      child: const Icon(Icons.navigation),
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
          if (_currentTarget != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: FloatingActionButton.small(
                heroTag: 'fit',
                backgroundColor: Colors.black.withValues(alpha: 0.8),
                shape: const CircleBorder(),
                child: const Icon(Icons.zoom_out_map, color: Colors.white, size: 20),
                onPressed: _fitBounds,
              ),
            ),
          FloatingActionButton(
            heroTag: 'location',
            backgroundColor: _isFollowingUser ? Colors.blue : const Color(0xFFFFD700),
            foregroundColor: _isFollowingUser ? Colors.white : Colors.black,
            shape: const CircleBorder(),
            child: Icon(_isFollowingUser ? Icons.gps_fixed : Icons.my_location),
            onPressed: () {
              if (_userLocation.latitude != 0) {
                setState(() => _isFollowingUser = true);
                _mapController.move(_userLocation, 15.0);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRestaurantPopup(RestaurantWithScore item) {
    final r = item.restaurant;
    final distStr = item.distanceKm != null 
        ? LocationUtils.formatDistance(item.distanceKm!) 
        : "Nearby";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: item.isOpenNow 
                                  ? Colors.green.withValues(alpha: 0.1) 
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.isOpenNow ? "OPEN NOW" : "CLOSED",
                              style: TextStyle(
                                color: item.isOpenNow ? Colors.green : Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(distStr, style: const TextStyle(color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    const Text(
                      "SCORE",
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    Text(
                      r.rating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Text('VIEW DETAILS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    onPressed: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    padding: const EdgeInsets.all(16),
                    icon: const Icon(Icons.directions_rounded, color: Color(0xFFFFD700), size: 28),
                    onPressed: () {
                      Navigator.pop(context); 
                      setState(() {
                        _currentTarget = r;
                        _isLoading = true;
                      });
                      _getRoute().then((_) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          _fitBounds();
                        }
                      });
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
