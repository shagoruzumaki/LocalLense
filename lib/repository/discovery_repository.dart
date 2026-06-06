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
      } else {
        query = query.order('algorithm_score', ascending: false, nullsFirst: false);
      }

      final List response = await query.limit(50); // Added safety limit
      final restaurants = response.map((json) => Restaurant.fromSupabase(json)).toList();

      final scores = await _fetchScores(restaurants.map((r) => r.id).toList());
      var result = _enrich(restaurants, scores, filters.userLat, filters.userLng);

      if (filters.openNow) result = result.where((r) => r.isOpenNow).toList();

      if (filters.sortBy == SortOption.nearest) {
        result.sort((a, b) => (a.distanceKm ?? double.maxFinite)
            .compareTo(b.distanceKm ?? double.maxFinite));
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
        int limit = 20,
      }) async {
    try {
      final q = query.trim();
      if (q.length < 2) return [];
      final pattern = '%$q%';

      // ── 1. Search by restaurant name ──────────────────────────────────
      final List byNameRes = await _db
          .from('restaurants')
          .select()
          .eq('active', true)
          .ilike('name', pattern)
          .order('algorithm_score', ascending: false);
      final byName = byNameRes.map((j) => Restaurant.fromSupabase(j)).toList();

      // ── 2. Search by dish name in dishes table ────────────────────────
      // This is the main fix — searches the new dishes table
      List<Restaurant> byDish = [];
      try {
        final List dishRes = await _db
            .from('dishes')
            .select('restaurant_id')
            .ilike('name', pattern)  // ilike = case-insensitive partial match
            .eq('is_available', true);

        if (dishRes.isNotEmpty) {
          final dishRestaurantIds = dishRes
              .map((r) => r['restaurant_id'].toString())
              .toSet()
              .toList();

          final List byDishRes = await _db
              .from('restaurants')
              .select()
              .eq('active', true)
              .inFilter('id', dishRestaurantIds)
              .order('algorithm_score', ascending: false);

          byDish = byDishRes.map((j) => Restaurant.fromSupabase(j)).toList();
        }
      } catch (_) {
        // dishes table may not exist yet — silently skip
      }

      // ── 3. Search by ai_tags ──────────────────────────────────────────
      final List byTagsRes = await _db
          .from('restaurants')
          .select()
          .eq('active', true)
          .contains('ai_tags', [q.toLowerCase()])
          .order('algorithm_score', ascending: false);
      final byTags = byTagsRes.map((j) => Restaurant.fromSupabase(j)).toList();

      // ── 4. Search by address ──────────────────────────────────────────
      final List byAddrRes = await _db
          .from('restaurants')
          .select()
          .eq('active', true)
          .ilike('address', pattern)
          .order('algorithm_score', ascending: false);
      final byAddress = byAddrRes.map((j) => Restaurant.fromSupabase(j)).toList();

      // ── 5. Search dish_mentions in reviews (partial match) ────────────
      // Fixed: use ilike on text cast instead of exact array contains
      List<Restaurant> byReviewDish = [];
      try {
        final List matchingReviews = await _db
            .from('reviews')
            .select('restaurant_id, dish_mentions')
            .filter('dish_mentions', 'cs', '{${q.toLowerCase()}}');

        // Also try partial match via raw text search on dish_mentions
        if (matchingReviews.isEmpty) {
          // fallback: get all reviews and filter client-side for partial match
          final List allReviews = await _db
              .from('reviews')
              .select('restaurant_id, dish_mentions')
              .not('dish_mentions', 'is', null);

          final matchedIds = <String>{};
          for (final review in allReviews) {
            final mentions = (review['dish_mentions'] as List<dynamic>?) ?? [];
            for (final dish in mentions) {
              if (dish.toString().toLowerCase().contains(q.toLowerCase())) {
                matchedIds.add(review['restaurant_id'].toString());
                break;
              }
            }
          }

          if (matchedIds.isNotEmpty) {
            final List res = await _db
                .from('restaurants')
                .select()
                .eq('active', true)
                .inFilter('id', matchedIds.toList());
            byReviewDish = res.map((j) => Restaurant.fromSupabase(j)).toList();
          }
        } else {
          final ids = matchingReviews
              .map((r) => r['restaurant_id'].toString())
              .toSet()
              .toList();
          final List res = await _db
              .from('restaurants')
              .select()
              .eq('active', true)
              .inFilter('id', ids);
          byReviewDish = res.map((j) => Restaurant.fromSupabase(j)).toList();
        }
      } catch (_) {}

      // ── Merge all results (priority: name > dish > tags > address) ────
      final seen = <String>{};
      final merged = <Restaurant>[];

      void addIfNew(List<Restaurant> list) {
        for (var r in list) {
          if (seen.add(r.id)) merged.add(r);
        }
      }

      addIfNew(byName);       // highest priority — name match
      addIfNew(byDish);       // dishes table match
      addIfNew(byReviewDish); // review dish_mentions match
      addIfNew(byTags);       // ai_tags match
      addIfNew(byAddress);    // lowest priority — address match

      if (merged.isEmpty) return [];

      final scores = await _fetchScores(merged.map((r) => r.id).toList());
      var result = _enrich(merged, scores, userLat, userLng);
      result.sort((a, b) =>
          (b.restaurant.algorithmScore ?? 0.0)
              .compareTo(a.restaurant.algorithmScore ?? 0.0));

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
      // Fetch a healthy pool to calculate distance from
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
