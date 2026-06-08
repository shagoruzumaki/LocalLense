import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/restaurant.dart';
import '../model/dish.dart';
import '../utils/location_utils.dart';

class DiscoveryRepository {
  final _db = Supabase.instance.client;

  Future<List<RestaurantWithScore>> getRestaurants(RestaurantFilters filters) async {
    try {
      dynamic query = _db.from('restaurants').select();
      query = query.eq('active', true);
      if (filters.category != null && filters.category != 'All') {
        query = query.eq('category', filters.category!);
      }
      if (filters.priceTier != null) {
        query = query.eq('price_tier', filters.priceTier!);
      }
      if (filters.sortBy == SortOption.budget) {
        query = query.order('price_tier', ascending: true);
      } else if (filters.sortBy == SortOption.score) {
        query = query.order('algorithm_score', ascending: false, nullsFirst: false);
      }
      final List response = await query.limit(100); 
      final restaurants = response.map((json) => Restaurant.fromSupabase(json)).toList();
      final scores = await _fetchScores(restaurants.map((r) => r.id).toList());
      var result = _enrich(restaurants, scores, filters.userLat, filters.userLng);
      if (filters.openNow) result = result.where((r) => r.isOpenNow).toList();
      if (filters.sortBy == SortOption.nearest) {
        result.sort((a, b) => (a.distanceKm ?? double.maxFinite).compareTo(b.distanceKm ?? double.maxFinite));
      }
      return result;
    } catch (e) { rethrow; }
  }

  // 🔥 Trending Dishes This Week - Combined Trending Score Approach
  Future<List<Dish>> getTrendingDishes({int limit = 10}) async {
    try {
      final List response = await _db.from('dishes')
          .select('*, restaurants!inner(*)')
          .eq('is_available', true)
          .order('restaurants(algorithm_score)', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return response.map((json) => Dish.fromSupabase(json)).toList();
    } catch (e) { 
       try {
        final List response = await _db.from('dishes')
            .select('*, restaurants!inner(*)')
            .eq('is_available', true)
            .limit(limit);
        return response.map((json) => Dish.fromSupabase(json)).toList();
      } catch (_) {
        return []; 
      }
    }
  }

  // 🍽️ Popular Dishes Near You
  Future<List<Dish>> getPopularDishes({double? userLat, double? userLng, int limit = 10}) async {
    try {
      final List response = await _db.from('dishes')
          .select('*, restaurants!inner(*)')
          .eq('is_available', true)
          .order('restaurants(algorithm_score)', ascending: false)
          .limit(limit);
      return response.map((json) => Dish.fromSupabase(json)).toList();
    } catch (e) { return []; }
  }

  // ⭐ Top Rated Restaurants
  Future<List<RestaurantWithScore>> getTopRated({double? userLat, double? userLng, int limit = 10}) async {
    return getRanked(userLat: userLat, userLng: userLng, limit: limit);
  }

  // 🚶 Nearby Right Now
  Future<List<RestaurantWithScore>> getNearbyNow({required double userLat, required double userLng, int limit = 10}) async {
    return getNearby(userLat: userLat, userLng: userLng, openNow: true, limit: limit);
  }

  // 💰 Best Budget Eats
  Future<List<Dish>> getBudgetEats({double? userLat, double? userLng, int limit = 10}) async {
    try {
      final List response = await _db.from('dishes')
          .select('*, restaurants!inner(*)')
          .eq('is_available', true)
          .lte('price', 200) 
          .order('price', ascending: true)
          .limit(limit);
      return response.map((json) => Dish.fromSupabase(json)).toList();
    } catch (e) { return []; }
  }

  // 🎯 Recommended For You
  Future<List<RestaurantWithScore>> getRecommended({double? userLat, double? userLng, int limit = 10}) async {
    try {
      final List response = await _db.from('restaurants')
          .select()
          .eq('active', true)
          .order('algorithm_score', ascending: false)
          .limit(limit);
      final restaurants = response.map((json) => Restaurant.fromSupabase(json)).toList();
      final scores = await _fetchScores(restaurants.map((r) => r.id).toList());
      return _enrich(restaurants, scores, userLat, userLng);
    } catch (e) { return []; }
  }

  // 💎 Hidden Gems
  Future<List<RestaurantWithScore>> getHiddenGems({double? userLat, double? userLng, int limit = 10}) async {
    try {
      final List response = await _db.from('restaurants')
          .select()
          .eq('active', true)
          .gt('algorithm_score', 70)
          .order('algorithm_score', ascending: false)
          .limit(50);

      final restaurants = response.map((json) => Restaurant.fromSupabase(json)).toList();
      final scores = await _fetchScores(restaurants.map((r) => r.id).toList());
      var enriched = _enrich(restaurants, scores, userLat, userLng);
      enriched = enriched.where((e) => (e.score?.reviewCount ?? 0) < 30).toList();
      return enriched.take(limit).toList();
    } catch (e) { return []; }
  }

  // 🆕 Newly Added
  Future<List<RestaurantWithScore>> getNewlyAdded({double? userLat, double? userLng, int limit = 10}) async {
    try {
      final List response = await _db.from('restaurants')
          .select()
          .eq('active', true)
          .order('created_at', ascending: false)
          .limit(limit);
      final restaurants = response.map((json) => Restaurant.fromSupabase(json)).toList();
      final scores = await _fetchScores(restaurants.map((r) => r.id).toList());
      return _enrich(restaurants, scores, userLat, userLng);
    } catch (e) { return []; }
  }

  // 🎉 Offers & Deals - Returns Restaurants that have offers
  Future<List<RestaurantWithScore>> getOffersAndDeals({int limit = 10}) async {
    try {
      // Find restaurants that have dishes with offers in name or description
      final List dishResponse = await _db.from('dishes')
          .select('restaurant_id')
          .eq('is_available', true)
          .or('description.ilike.%off%,description.ilike.%deal%,description.ilike.%discount%,name.ilike.%off%,name.ilike.%deal%,name.ilike.%discount%');
      
      final restaurantIds = dishResponse.map((d) => d['restaurant_id'].toString()).toSet().toList();
      
      if (restaurantIds.isEmpty) return [];

      final List resResponse = await _db.from('restaurants')
          .select()
          .inFilter('id', restaurantIds)
          .limit(limit);
      
      final restaurants = resResponse.map((json) => Restaurant.fromSupabase(json)).toList();
      final scores = await _fetchScores(restaurants.map((r) => r.id).toList());
      return _enrich(restaurants, scores, null, null);
    } catch (e) { 
      return []; 
    }
  }

  // 🗺️ Explore by Area - Improved for live location formatting
  Future<List<String>> getAreas({double? userLat, double? userLng}) async {
    try {
      final List response = await _db.from('restaurants')
          .select('address, latitude, longitude')
          .eq('active', true);
      
      final List<Map<String, dynamic>> records = List<Map<String, dynamic>>.from(response);
      
      if (userLat != null && userLng != null) {
        // Sort by proximity
        records.sort((a, b) {
          final dA = LocationUtils.calculateDistance(userLat, userLng, (a['latitude'] as num).toDouble(), (a['longitude'] as num).toDouble());
          final dB = LocationUtils.calculateDistance(userLat, userLng, (b['latitude'] as num).toDouble(), (b['longitude'] as num).toDouble());
          return dA.compareTo(dB);
        });
      }

      final List<String> areas = [];
      for (var record in records) {
        final address = record['address'].toString();
        final parts = address.split(',');
        if (parts.length >= 2) {
          final city = parts.last.trim();
          final area = parts[parts.length - 2].trim();
          final display = "$city ($area)";
          if (area.isNotEmpty && !areas.contains(display)) {
            areas.add(display);
          }
        }
      }

      return areas.take(15).toList();
    } catch (e) { return ['Sylhet (Zindabazar)', 'Sylhet (Kumarpara)', 'Sylhet (Amberkhana)', 'Sylhet (Bondorbazar)']; }
  }

  Future<List<RestaurantWithScore>> getAllTimeLeaderboard() async {
    try {
      final List response = await _db.from('restaurants').select().eq('active', true).order('algorithm_score', ascending: false);
      final restaurants = response.map((json) => Restaurant.fromSupabase(json)).toList();
      final scores = await _fetchScores(restaurants.map((r) => r.id).toList());
      var result = _enrich(restaurants, scores, null, null);
      result.sort((a, b) => b.restaurant.rating.compareTo(a.restaurant.rating));
      return result;
    } catch (e) { return []; }
  }

  Future<RestaurantWithScore?> getRestaurantDetail(String id, {double? userLat, double? userLng}) async {
    try {
      final response = await _db.from('restaurants').select().eq('id', id).single();
      final restaurant = Restaurant.fromSupabase(response);
      final scoreMap = await _fetchScores([restaurant.id]);
      return _enrich([restaurant], scoreMap, userLat, userLng).first;
    } catch (e) { return null; }
  }

  Future<AlgorithmScore?> getScoreBreakdown(String id) async {
    try {
      final response = await _db.from('algorithm_scores').select().eq('restaurant_id', id).maybeSingle();
      if (response == null) return null;
      return AlgorithmScore.fromSupabase(response);
    } catch (e) { return null; }
  }

  Future<List<RestaurantWithScore>> searchRestaurants(
      String query, {
        double? userLat,
        double? userLng,
        String? category,
        bool openNow = false,
        SortOption sortBy = SortOption.score,
        int limit = 20,
        bool searchByDish = true,
      }) async {
    try {
      final q = query.trim();
      if (q.isEmpty) return [];
      
      String? cityPart;
      String? areaPart;
      if (q.contains('(') && q.contains(')')) {
        cityPart = q.split('(')[0].trim();
        final match = RegExp(r'\(([^)]+)\)').firstMatch(q);
        if (match != null) areaPart = match.group(1);
      }

      var baseQuery = _db.from('restaurants').select().eq('active', true);
      if (category != null && category != 'All') {
        baseQuery = baseQuery.eq('category', category.toLowerCase().replaceAll(' ', '_'));
      }
      
      List response;
      if (areaPart != null && cityPart != null) {
        response = await baseQuery
            .ilike('address', '%$areaPart%')
            .ilike('address', '%$cityPart%');
        
        if (response.isEmpty) {
          response = await _db.from('restaurants').select().eq('active', true).or('address.ilike.%$areaPart%,address.ilike.%$cityPart%');
        }
      } else {
        response = await baseQuery.or('name.ilike.%$q%,address.ilike.%$q%');
      }

      final Map<String, Restaurant> mergedRestaurants = {};
      for (var j in response) {
        final r = Restaurant.fromSupabase(j);
        mergedRestaurants[r.id] = r;
      }

      if (searchByDish && areaPart == null) {
        final List dishMatches = await _db.from('dishes').select('restaurant_id').ilike('name', '%$q%');
        final dishRestaurantIds = dishMatches.map((d) => d['restaurant_id'].toString()).toSet();
        if (dishRestaurantIds.isNotEmpty) {
          final List byDishRes = await _db.from('restaurants').select().eq('active', true).inFilter('id', dishRestaurantIds.toList());
          for (var j in byDishRes) {
            final r = Restaurant.fromSupabase(j);
            mergedRestaurants[r.id] = r;
          }
        }
      }

      if (mergedRestaurants.isEmpty) return [];
      final restaurants = mergedRestaurants.values.toList();
      final scores = await _fetchScores(restaurants.map((r) => r.id).toList());
      var result = _enrich(restaurants, scores, userLat, userLng);
      
      if (openNow) result = result.where((r) => r.isOpenNow).toList();
      if (sortBy == SortOption.nearest) {
        result.sort((a, b) => (a.distanceKm ?? double.maxFinite).compareTo(b.distanceKm ?? double.maxFinite));
      } else {
        result.sort((a, b) => (b.restaurant.algorithmScore ?? 0.0).compareTo(a.restaurant.algorithmScore ?? 0.0));
      }
      return result.take(limit).toList();
    } catch (e) { return []; }
  }

  Future<List<Dish>> searchDishes(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    
    String? areaPart;
    if (q.contains('(') && q.contains(')')) {
      final match = RegExp(r'\(([^)]+)\)').firstMatch(q);
      if (match != null) areaPart = match.group(1);
    }

    try {
      if (areaPart != null) {
        final List restaurantsResponse = await _db.from('restaurants').select('id').ilike('address', '%$areaPart%');
        final restaurantIds = restaurantsResponse.map((r) => r['id'].toString()).toList();
        if (restaurantIds.isEmpty) return [];
        
        final List response = await _db.from('dishes')
            .select('*, restaurants(*)')
            .inFilter('restaurant_id', restaurantIds)
            .limit(limit);
        return response.map((json) => Dish.fromSupabase(json)).toList();
      } else {
        final List response = await _db.from('dishes')
            .select('*, restaurants(*)') 
            .ilike('name', '%$q%')
            .limit(limit);
        return response.map((json) => Dish.fromSupabase(json)).toList();
      }
    } catch (e) {
       return [];
    }
  }

  Future<List<SearchSuggestion>> getSuggest(String query) async {
    try {
      final q = query.trim();
      if (q.length < 2) return [];
      final List response = await _db.from('restaurants').select('id, name, ai_tags').eq('active', true).ilike('name', '%$q%').limit(5);
      final suggestions = <SearchSuggestion>[];
      for (var json in response) {
        suggestions.add(SearchSuggestion(text: json['name'].toString(), type: SuggestionType.restaurant, restaurantId: json['id'].toString()));
      }
      return suggestions;
    } catch (e) { return []; }
  }

  Future<List<RestaurantWithScore>> getRanked({double? userLat, double? userLng, int? limit}) async {
    try {
      dynamic query = _db.from('restaurants').select().eq('active', true).order('algorithm_score', ascending: false, nullsFirst: false);
      if (limit != null) query = query.limit(limit);
      final List response = await query;
      final restaurants = response.map((json) => Restaurant.fromSupabase(json)).toList();
      final scores = await _fetchScores(restaurants.map((r) => r.id).toList());
      return _enrich(restaurants, scores, userLat, userLng);
    } catch (e) { rethrow; }
  }

  Future<List<RestaurantWithScore>> getNearby({required double userLat, required double userLng, double radiusKm = 2.0, bool openNow = false, int limit = 20}) async {
    try {
      final List response = await _db.from('restaurants').select().eq('active', true).limit(100);
      final restaurants = response.map((json) => Restaurant.fromSupabase(json)).toList();
      final scores = await _fetchScores(restaurants.map((r) => r.id).toList());
      var result = _enrich(restaurants, scores, userLat, userLng).where((item) => (item.distanceKm ?? double.maxFinite) <= radiusKm).toList();
      if (openNow) result = result.where((r) => r.isOpenNow).toList();
      result.sort((a, b) => (a.distanceKm ?? double.maxFinite).compareTo(b.distanceKm ?? double.maxFinite));
      return result.take(limit).toList();
    } catch (e) { rethrow; }
  }

  Future<Map<String, AlgorithmScore>> _fetchScores(List<String> ids) async {
    if (ids.isEmpty) return {};
    final List response = await _db.from('algorithm_scores').select().inFilter('restaurant_id', ids); 
    return { for (var json in response) json['restaurant_id'].toString(): AlgorithmScore.fromSupabase(json) };
  }

  List<RestaurantWithScore> _enrich(List<Restaurant> restaurants, Map<String, AlgorithmScore> scores, double? userLat, double? userLng) {
    return restaurants.map((r) {
      return RestaurantWithScore(
        restaurant: r,
        score: scores[r.id],
        isOpenNow: LocationUtils.isOpenNow(r.openHours),
        distanceKm: (userLat != null && userLng != null) ? LocationUtils.calculateDistance(userLat, userLng, r.latitude, r.longitude) : null,
      );
    }).toList();
  }
}
