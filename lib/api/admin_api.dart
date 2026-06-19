import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'review_system.dart';       // reuse _recalculateScore()
import 'ai_summary.dart';   // reuse generateAndSaveSummary()

/// 2.5 Admin Panel APIs
/// Owner: Kamonashish Dutta Hemel
/// All admin-only operations for LocalLens
/// Protected by RBAC — only users with role=admin can call these

class AdminApi {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ReviewApi _reviewApi = ReviewApi();
  final AiSummaryApi _aiSummaryApi = AiSummaryApi();

  // ─────────────────────────────────────────────
  // RBAC GUARD
  Future<void> _requireAdmin() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated.');

    final response = await _supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .single();

    if (response['role'] != 'admin') {
      throw Exception('Access denied. Admin only.');
    }
  }

  // ─────────────────────────────────────────────
  // 1. GET /admin/dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    await _requireAdmin();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day).toIso8601String();

    final results = await Future.wait([
      _supabase.from('users').select('id'),
      _supabase.from('reviews').select('id').gte('created_at', todayStart),
      _supabase.from('users').select('id').gte('created_at', todayStart),
      _supabase.from('verification_requests').select('id').eq('status', 'pending'),
      _supabase.from('reviews').select('id').eq('flagged', true),
    ]);

    return {
      'total_users': (results[0] as List).length,
      'reviews_today': (results[1] as List).length,
      'new_signups_today': (results[2] as List).length,
      'pending_verifications': (results[3] as List).length,
      'flagged_reviews': (results[4] as List).length,
    };
  }

  // ─────────────────────────────────────────────
  // 2. GET /admin/reviews/flagged
  Future<List<Map<String, dynamic>>> getFlaggedReviews({int page = 1, int pageSize = 20}) async {
    await _requireAdmin();
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    final response = await _supabase
        .from('reviews')
        .select('*, users (id, name, tier, verified, profile_photo_url), restaurants (id, name)')
        .eq('flagged', true)
        .order('created_at', ascending: false)
        .range(from, to);

    return List<Map<String, dynamic>>.from(response);
  }

  // ─────────────────────────────────────────────
  // 2b. GET /admin/reviews — ALL reviews (not just flagged), for the Reviews
  // management screen. Optionally scoped to a single restaurant.
  Future<List<Map<String, dynamic>>> getAllReviews({
    String? restaurantId,
    int page = 1,
    int pageSize = 20,
  }) async {
    await _requireAdmin();
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    var query = _supabase
        .from('reviews')
        .select('*, users (id, name, tier, verified, profile_photo_url), restaurants (id, name)');

    if (restaurantId != null) {
      query = query.eq('restaurant_id', restaurantId);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(from, to);

    return List<Map<String, dynamic>>.from(response);
  }

  // ─────────────────────────────────────────────
  // 3. PATCH /admin/reviews/:id/approve
  Future<void> approveReview(String reviewId) async {
    await _requireAdmin();
    await _supabase.from('reviews').update({'flagged': false}).eq('id', reviewId);
    debugPrint('[AdminApi] Review $reviewId approved — flag cleared.');
  }

  // ─────────────────────────────────────────────
  // 4. PATCH /admin/reviews/:id/remove
  // Triggers score recalculation and dish metric rollbacks.
  // ─────────────────────────────────────────────
  Future<void> removeReview(String reviewId) async {
    await _requireAdmin();

    // 1. Get restaurant_id, mentions, and rating before deleting
    final review = await _supabase
        .from('reviews')
        .select('restaurant_id, dish_mentions, rating')
        .eq('id', reviewId)
        .single();

    final restaurantId = review['restaurant_id'] as String;
    final List<String> mentions = List<String>.from(review['dish_mentions'] ?? []);
    final double rating = (review['rating'] as num).toDouble();

    // 2. Delete the review
    await _supabase.from('reviews').delete().eq('id', reviewId);

    // 3. Rollback dish metrics (trending scores)
    await _reviewApi.rollbackDishMetricsPublic(restaurantId, mentions, rating);

    // 4. Recalculate restaurant scores
    await _reviewApi.recalculateScorePublic(restaurantId);

    debugPrint('[AdminApi] Review $reviewId removed by admin. Metrics and scores updated.');
  }

  // ─────────────────────────────────────────────
  // 5. GET /admin/restaurants
  Future<List<Map<String, dynamic>>> getAllRestaurants() async {
    await _requireAdmin();
    final response = await _supabase
        .from('restaurants')
        .select('id, name, category, address, active, algorithm_score, score_updated_at, algorithm_scores (review_count, quality_score, trust_score, popularity_score)')
        .order('algorithm_score', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ─────────────────────────────────────────────
  // 6. POST /admin/restaurants
  Future<Map<String, dynamic>> addRestaurant({
    required String name,
    required String category,
    required String address,
    required double latitude,
    required double longitude,
    required int priceTier,
    String? phone,
    Map<String, dynamic>? openHours,
  }) async {
    await _requireAdmin();
    final response = await _supabase.from('restaurants').insert({
      'name': name, 'category': category, 'address': address, 'latitude': latitude, 'longitude': longitude,
      'price_tier': priceTier, 'phone': phone, 'open_hours': openHours ?? {}, 'active': true, 'algorithm_score': 0.0,
    }).select().single();
    return response;
  }

  // ─────────────────────────────────────────────
  // 7. PATCH /admin/restaurants/:id
  Future<void> updateRestaurant(String restaurantId, Map<String, dynamic> fields) async {
    await _requireAdmin();
    if (fields.isEmpty) throw Exception('No fields provided to update.');
    await _supabase.from('restaurants').update(fields).eq('id', restaurantId);
  }

  // ─────────────────────────────────────────────
  // 8. DELETE /admin/restaurants/:id
  Future<void> softDeleteRestaurant(String restaurantId) async {
    await _requireAdmin();
    await _supabase.from('restaurants').update({'active': false}).eq('id', restaurantId);
    debugPrint('[AdminApi] Restaurant $restaurantId soft deleted.');
  }

  // ─────────────────────────────────────────────
  // 8b. PATCH /admin/restaurants/:id/restore — undo a soft delete
  Future<void> restoreRestaurant(String restaurantId) async {
    await _requireAdmin();
    await _supabase.from('restaurants').update({'active': true}).eq('id', restaurantId);
    debugPrint('[AdminApi] Restaurant $restaurantId restored.');
  }

  // ─────────────────────────────────────────────
  // 9. PATCH /admin/users/:id/ban
  Future<void> banUser(String userId) async {
    await _requireAdmin();
    final currentUserId = _supabase.auth.currentUser?.id;
    if (userId == currentUserId) throw Exception('You cannot ban your own account.');
    await _supabase.from('users').update({'banned': true}).eq('id', userId);
    await _supabase.auth.admin.deleteUser(userId);
    debugPrint('[AdminApi] User $userId banned.');
  }

  // ─────────────────────────────────────────────
  // 10. PATCH /admin/users/:id/unban
  Future<void> unbanUser(String userId) async {
    await _requireAdmin();
    await _supabase.from('users').update({'banned': false}).eq('id', userId);
    debugPrint('[AdminApi] User $userId unbanned.');
  }

  // ─────────────────────────────────────────────
  // 11. PATCH /admin/scores/:id/override
  Future<void> overrideScore(String restaurantId, double newScore) async {
    await _requireAdmin();
    if (newScore < 0 || newScore > 100) throw Exception('Score must be between 0 and 100.');
    await _supabase.from('restaurants').update({'algorithm_score': newScore, 'score_updated_at': DateTime.now().toIso8601String()}).eq('id', restaurantId);
    debugPrint('[AdminApi] Score for $restaurantId overridden to $newScore.');
  }

  // ─────────────────────────────────────────────
  // 12. POST /admin/restaurants/:id/regenerate-summary
  Future<void> regenerateSummary(String restaurantId) async {
    await _requireAdmin();
    await _aiSummaryApi.generateAndSaveSummary(restaurantId);
    debugPrint('[AdminApi] Summary regenerated for $restaurantId.');
  }

  // ─────────────────────────────────────────────
  // 13. GET /admin/restaurants/:id/dishes
  // Used by the Dishes management screen after admin picks a restaurant.
  Future<List<Map<String, dynamic>>> getDishesByRestaurant(String restaurantId) async {
    await _requireAdmin();
    final response = await _supabase
        .from('dishes')
        .select('*')
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ─────────────────────────────────────────────
  // 14. POST /admin/dishes
  Future<Map<String, dynamic>> addDish({
    required String restaurantId,
    required String name,
    String? description,
    double? price,
    String? photoUrl,
    String? category,
    bool isAvailable = true,
  }) async {
    await _requireAdmin();
    final response = await _supabase.from('dishes').insert({
      'restaurant_id': restaurantId,
      'name': name,
      'description': description,
      'price': price,
      'photo_url': photoUrl,
      'category': category,
      'is_available': isAvailable,
      'avg_rating': 0,
      'review_count': 0,
      'is_popular': false,
    }).select().single();
    debugPrint('[AdminApi] Dish "$name" added to restaurant $restaurantId.');
    return response;
  }

  // ─────────────────────────────────────────────
  // 15. PATCH /admin/dishes/:id
  Future<void> updateDish(String dishId, Map<String, dynamic> fields) async {
    await _requireAdmin();
    if (fields.isEmpty) throw Exception('No fields provided to update.');
    await _supabase.from('dishes').update(fields).eq('id', dishId);
    debugPrint('[AdminApi] Dish $dishId updated.');
  }

  // ─────────────────────────────────────────────
  // 16. DELETE /admin/dishes/:id
  // Dishes have no `active` flag in the schema, so this is a hard delete.
  // If dish_reviews reference this dish, those rows are removed first to
  // avoid an FK violation (mirrors the rollback pattern used for reviews).
  Future<void> deleteDish(String dishId) async {
    await _requireAdmin();
    await _supabase.from('dish_reviews').delete().eq('dish_id', dishId);
    await _supabase.from('dishes').delete().eq('id', dishId);
    debugPrint('[AdminApi] Dish $dishId permanently deleted.');
  }

  // ─────────────────────────────────────────────
  // 17. PATCH /admin/dishes/:id/toggle-availability
  Future<void> toggleDishAvailability(String dishId, bool isAvailable) async {
    await _requireAdmin();
    await _supabase.from('dishes').update({'is_available': isAvailable}).eq('id', dishId);
    debugPrint('[AdminApi] Dish $dishId availability set to $isAvailable.');
  }
}
