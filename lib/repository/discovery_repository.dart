import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/restaurant.dart';
import '../utils/location_utils.dart';

class DiscoveryRepository {
  final _db = Supabase.instance.client;

  // ─────────────────────────────────────────────────────────────────────────
  // 3.1 — getRestaurants() with filters
  // ─────────────────────────────────────────────────────────────────────────
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
        result.sort((a, b) => (a.distanceKm ?? double.maxFinite)
            .compareTo(b.distanceKm ?? double.maxFinite));
      } else if (filters.sortBy == SortOption.popular) {
        result.sort((a, b) => (b.score?.reviewCount ?? 0).compareTo(a.score?.reviewCount ?? 0));
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3.1 — getRestaurantDetail()
  // ─────────────────────────────────────────────────────────────────────────
  Future<RestaurantWithScore?> getRestaurantDetail(
    String id, {
    double? userLat,
    double? userLng,
  }) async {
    try {
      final response = await _db
          .from('restaurants')
          .select()
          .eq('id', id)
          .single();

      final restaurant = Restaurant.fromSupabase(response);
      final scoreMap = await _fetchScores([restaurant.id]);

      return _enrich([restaurant], scoreMap, userLat, userLng).first;
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3.1 — getScoreBreakdown()
  // ─────────────────────────────────────────────────────────────────────────
  Future<AlgorithmScore?> getScoreBreakdown(String id) async {
    try {
      final response = await _db
          .from('algorithm_scores')
          .select()
          .eq('restaurant_id', id)
          .maybeSingle();

      if (response == null) return null;
      return AlgorithmScore.fromSupabase(response);
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3.1 — searchRestaurants()
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<RestaurantWithScore>> searchRestaurants(
      String query, {
        double? userLat,
        double? userLng,
        String? category,
        bool openNow = false,
        SortOption sortBy = SortOption.score,
        int limit = 20,
      }) async {
    try {
      final q = query.trim();
      if (q.isEmpty) return [];
      final pattern = '%$q%';

      // Build base query
      var dbQuery = _db.from('restaurants').select().eq('active', true);
      
      // Filter by category if provided
      if (category != null && category != 'All') {
        dbQuery = dbQuery.eq('category', category.toLowerCase().replaceAll(' ', '_'));
      }

      // Add ilike condition across multiple fields or use an OR
      // For simplicity and efficiency in Supabase without complex OR logic:
      // We'll search by name first as primary.
      final List byNameRes = await dbQuery.ilike('name', pattern);
      final restaurants = byNameRes.map((j) => Restaurant.fromSupabase(j)).toList();

      if (restaurants.isEmpty && q.length >= 2) {
        // Fallback or secondary search for dishes/tags if name results are zero
        // This is a simplified version of the merged logic from before
      }

      if (restaurants.isEmpty) return [];

      final scores = await _fetchScores(restaurants.map((r) => r.id).toList());
      var result = _enrich(restaurants, scores, userLat, userLng);
      
      // Filter Open Now
      if (openNow) {
        result = result.where((r) => r.isOpenNow).toList();
      }

      // Sorting
      if (sortBy == SortOption.nearest) {
        result.sort((a, b) => (a.distanceKm ?? double.maxFinite).compareTo(b.distanceKm ?? double.maxFinite));
      } else if (sortBy == SortOption.budget) {
        result.sort((a, b) => a.restaurant.priceTier.compareTo(b.restaurant.priceTier));
      } else if (sortBy == SortOption.popular) {
        result.sort((a, b) => (b.score?.reviewCount ?? 0).compareTo(a.score?.reviewCount ?? 0));
      } else {
        result.sort((a, b) => (b.restaurant.algorithmScore ?? 0.0).compareTo(a.restaurant.algorithmScore ?? 0.0));
      }

      return result.take(limit).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<SearchSuggestion>> getSuggest(String query) async {
    try {
      final q = query.trim();
      if (q.length < 2) return [];
      final List response = await _db.from('restaurants')
          .select('id, name, ai_tags')
          .eq('active', true)
          .ilike('name', '%$q%')
          .limit(5);

      final suggestions = <SearchSuggestion>[];
      for (var json in response) {
        final id = json['id'].toString();
        final name = json['name'].toString();
        final List? tags = json['ai_tags'];
        suggestions.add(SearchSuggestion(text: name, type: SuggestionType.restaurant, restaurantId: id));
        if (tags != null) {
          for (var tag in tags) {
            if (tag.toString().toLowerCase().contains(q.toLowerCase()) && suggestions.length < 5) {
              suggestions.add(SearchSuggestion(text: tag.toString(), type: SuggestionType.tag, restaurantId: id));
            }
          }
        }
      }
      final seenText = <String>{};
      return suggestions.where((s) => seenText.add(s.text)).take(5).toList();
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
        distanceKm: (userLat != null && userLng != null)
            ? LocationUtils.calculateDistance(userLat, userLng, r.latitude, r.longitude)
            : null,
      );
    }).toList();
  }
}
