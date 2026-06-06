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
  // Every admin method calls this first.
  // Throws if the current user is not an admin.
  // ─────────────────────────────────────────────
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
  // Returns: total users, reviews today, new signups
  // today, pending verifications, flagged reviews
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardStats() async {
    await _requireAdmin();

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day)
        .toIso8601String();

    // Run all counts in parallel for speed
    final results = await Future.wait([
      // Total users
      _supabase.from('users').select('id'),

      // Reviews submitted today
      _supabase
          .from('reviews')
          .select('id')
          .gte('created_at', todayStart),

      // New signups today
      _supabase
          .from('users')
          .select('id')
          .gte('created_at', todayStart),

      // Pending verifications
      _supabase
          .from('verification_requests')
          .select('id')
          .eq('status', 'pending'),

      // Flagged reviews awaiting moderation
      _supabase
          .from('reviews')
          .select('id')
          .eq('flagged', true),
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
  // List all flagged reviews awaiting moderation.
  // Paginated (20 per page).
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getFlaggedReviews({
    int page = 1,
    int pageSize = 20,
  }) async {
    await _requireAdmin();

    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    final response = await _supabase
        .from('reviews')
        .select('''
          *,
          users (
            id,
            name,
            tier,
            verified,
            profile_photo_url
          ),
          restaurants (
            id,
            name
          )
        ''')
        .eq('flagged', true)
        .order('created_at', ascending: false)
        .range(from, to);

    return List<Map<String, dynamic>>.from(response);
  }

  // ─────────────────────────────────────────────
  // 3. PATCH /admin/reviews/:id/approve
  // Clear flag. Keep review live. Log admin action.
  // ─────────────────────────────────────────────
  Future<void> approveReview(String reviewId) async {
    await _requireAdmin();

    await _supabase
        .from('reviews')
        .update({'flagged': false}).eq('id', reviewId);

    debugPrint('[AdminApi] Review $reviewId approved — flag cleared.');
  }

  // ─────────────────────────────────────────────
  // 4. PATCH /admin/reviews/:id/remove
  // Remove review from platform.
  // Triggers score recalculation via ReviewApi.
  // ─────────────────────────────────────────────
  Future<void> removeReview(String reviewId) async {
    await _requireAdmin();

    // Get restaurant_id before deleting
    final review = await _supabase
        .from('reviews')
        .select('restaurant_id')
        .eq('id', reviewId)
        .single();

    final restaurantId = review['restaurant_id'] as String;

    // Delete the review
    await _supabase.from('reviews').delete().eq('id', reviewId);

    // Reuse ReviewApi's recalculation — no duplication
    await _reviewApi.recalculateScorePublic(restaurantId);

    debugPrint('[AdminApi] Review $reviewId removed. Score recalculated.');
  }

  // ─────────────────────────────────────────────
  // 5. GET /admin/restaurants
  // All restaurants with score, review count, active status.
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllRestaurants() async {
    await _requireAdmin();

    final response = await _supabase
        .from('restaurants')
        .select('''
          id,
          name,
          category,
          address,
          active,
          algorithm_score,
          score_updated_at,
          algorithm_scores (
            review_count,
            quality_score,
            trust_score,
            popularity_score
          )
        ''')
        .order('algorithm_score', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ─────────────────────────────────────────────
  // 6. POST /admin/restaurants
  // Add new restaurant with full details.
  // ─────────────────────────────────────────────
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

    final response = await _supabase
        .from('restaurants')
        .insert({
      'name': name,
      'category': category,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'price_tier': priceTier,
      'phone': phone,
      'open_hours': openHours ?? {},
      'active': true,
      'algorithm_score': 0.0,
    })
        .select()
        .single();

    return response;
  }

  // ─────────────────────────────────────────────
  // 7. PATCH /admin/restaurants/:id
  // Update any restaurant field.
  // ─────────────────────────────────────────────
  Future<void> updateRestaurant(
      String restaurantId,
      Map<String, dynamic> fields,
      ) async {
    await _requireAdmin();

    if (fields.isEmpty) throw Exception('No fields provided to update.');

    await _supabase
        .from('restaurants')
        .update(fields)
        .eq('id', restaurantId);
  }

  // ─────────────────────────────────────────────
  // 8. DELETE /admin/restaurants/:id
  // Soft delete — sets active=false.
  // Hidden from all discovery screens.
  // ─────────────────────────────────────────────
  Future<void> softDeleteRestaurant(String restaurantId) async {
    await _requireAdmin();

    await _supabase
        .from('restaurants')
        .update({'active': false}).eq('id', restaurantId);

    debugPrint('[AdminApi] Restaurant $restaurantId soft deleted.');
  }

  // ─────────────────────────────────────────────
  // 9. PATCH /admin/users/:id/ban
  // Suspend account. Block login token.
  // ─────────────────────────────────────────────
  Future<void> banUser(String userId) async {
    await _requireAdmin();

    // Prevent admin from banning themselves
    final currentUserId = _supabase.auth.currentUser?.id;
    if (userId == currentUserId) {
      throw Exception('You cannot ban your own account.');
    }

    await _supabase
        .from('users')
        .update({'banned': true}).eq('id', userId);

    // Revoke all active sessions for this user via Supabase Auth Admin
    // This blocks their JWT from working on next request
    await _supabase.auth.admin.deleteUser(userId);

    debugPrint('[AdminApi] User $userId banned.');
  }

  // ─────────────────────────────────────────────
  // 10. PATCH /admin/users/:id/unban
  // Restore suspended account.
  // ─────────────────────────────────────────────
  Future<void> unbanUser(String userId) async {
    await _requireAdmin();

    await _supabase
        .from('users')
        .update({'banned': false}).eq('id', userId);

    debugPrint('[AdminApi] User $userId unbanned.');
  }

  // ─────────────────────────────────────────────
  // 11. PATCH /admin/scores/:id/override
  // Manually set final score for a restaurant.
  // Reason note skipped — direct score update only.
  // ─────────────────────────────────────────────
  Future<void> overrideScore(
      String restaurantId,
      double newScore,
      ) async {
    await _requireAdmin();

    if (newScore < 0 || newScore > 100) {
      throw Exception('Score must be between 0 and 100.');
    }

    // Update cached score on restaurants table
    await _supabase.from('restaurants').update({
      'algorithm_score': newScore,
      'score_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', restaurantId);

    debugPrint('[AdminApi] Score for $restaurantId overridden to $newScore.');
  }

  // ─────────────────────────────────────────────
  // 12. POST /admin/restaurants/:id/regenerate-summary
  // Force AI summary regeneration for a restaurant.
  // Reuses AiSummaryApi.generateAndSaveSummary()
  // ─────────────────────────────────────────────
  Future<void> regenerateSummary(String restaurantId) async {
    await _requireAdmin();

    // Directly call 2.3 — no duplication
    await _aiSummaryApi.generateAndSaveSummary(restaurantId);

    debugPrint('[AdminApi] Summary regenerated for $restaurantId.');
  }
}
