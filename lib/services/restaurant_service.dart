import 'dart:convert';
import 'dart:math' show cos, sqrt, asin;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../model/restaurant.dart';

class RestaurantService {
  final _supabase = Supabase.instance.client;
  
  // Replace this with your key if you have one. Otherwise, it uses OpenStreetMap.
  static const String _googleApiKey = 'YOUR_GOOGLE_PLACES_API_KEY';
  static const String _interpreterUrl = 'https://overpass-api.de/api/interpreter';
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org';

  // --- 3.1 RESTAURANT DISCOVERY APIs ---

  /// Updated to accept optional coordinates
  Future<List<Restaurant>> fetchNearbyRestaurants({double? latitude, double? longitude}) async {
    if (_googleApiKey != 'YOUR_GOOGLE_PLACES_API_KEY' && _googleApiKey.isNotEmpty) {
      return _fetchNearbyFromGoogle(latitude: latitude, longitude: longitude);
    }
    return _fetchNearbyFromOSM(latitude: latitude, longitude: longitude);
  }

  Future<List<Restaurant>> _fetchNearbyFromGoogle({double? latitude, double? longitude}) async {
    try {
      double lat = latitude ?? 0;
      double lng = longitude ?? 0;

      if (latitude == null || longitude == null) {
        Position position = await _determinePosition();
        lat = position.latitude;
        lng = position.longitude;
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng'
        '&radius=5000&type=restaurant&key=$_googleApiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        return results.map((json) => Restaurant.fromGoogleJson(json)).toList();
      }
    } catch (_) {}
    return _fetchNearbyFromOSM(latitude: latitude, longitude: longitude);
  }

  Future<List<Restaurant>> _fetchNearbyFromOSM({double? latitude, double? longitude}) async {
    try {
      double lat = latitude ?? 0;
      double lng = longitude ?? 0;

      if (latitude == null || longitude == null) {
        Position pos = await _determinePosition();
        lat = pos.latitude;
        lng = pos.longitude;
      }

      final query = '''
      [out:json][timeout:30];
      (
        node["amenity"~"restaurant|cafe|fast_food|food_court|ice_cream|pub|bar"](around:5000,$lat,$lng);
        way["amenity"~"restaurant|cafe|fast_food|food_court|ice_cream|pub|bar"](around:5000,$lat,$lng);
      );
      out center;
      ''';
      
      final response = await http.get(Uri.parse('$_interpreterUrl?data=${Uri.encodeComponent(query)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List elements = data['elements'] ?? [];
        if (elements.isEmpty) return [];

        List<Restaurant> spots = elements.map((e) => Restaurant.fromOverpassJson(e)).toList();
        
        // Sort by proximity using provided or fetched coordinates
        spots.sort((a, b) {
          double distA = _calculateDistance(lat, lng, a.latitude, a.longitude);
          double distB = _calculateDistance(lat, lng, b.latitude, b.longitude);
          return distA.compareTo(distB);
        });
        
        return spots;
      }
    } catch (e) {
      print('OSM Fetch Error: $e');
    }
    return [];
  }

  // --- 3.2 MAPS & LOCATION SERVICES ---

  Future<String> getNeighbourhoodName(double lat, double lng) async {
    try {
      final url = '$_nominatimUrl/reverse?format=jsonv2&lat=$lat&lon=$lng';
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'LocalLensApp'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        return address['suburb'] ?? address['neighbourhood'] ?? address['village'] ?? address['town'] ?? address['city'] ?? 'Nearby';
      }
    } catch (_) {}
    return 'Nearby';
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> openMapDirections(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  // --- HELPERS ---

  Future<Position> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _defaultFallback();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return _defaultFallback();
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium)
          .timeout(const Duration(seconds: 8), onTimeout: () => _defaultFallback());
    } catch (_) {
      return _defaultFallback();
    }
  }

  Position _defaultFallback() => Position(
    latitude: 0.0, longitude: 0.0, timestamp: DateTime.now(),
    accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0,
    altitudeAccuracy: 0, headingAccuracy: 0,
  );
}
