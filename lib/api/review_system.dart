import 'package:supabase_flutter/supabase_flutter.dart';
import '../algorithm/score.dart'; // 2.1 — RestaurantScoreCalculator

/// 2.2 Review System API
/// Owner: Kamonashish Dutta Hemel
/// All review-related operations for LocalLens
/// Connects to: 2.1 Score Algorithm (ScoreCalculator) after write operations

class ReviewApi {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────
  // HELPER: current logged-in user ID
  // ─────────────────────────────────────────────
  String get _currentUserId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.id;
  }

  // ─────────────────────────────────────────────
  // 1. POST /reviews
  // Submit a new review.
  // Requires: restaurant_id, mood_tag, rating, min 1 photo, body, dish_mentions
  // Triggers: score recalculation for the restaurant (2.1 hook)
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> submitReview({
    required String restaurantId,
    required String moodTag, // 'loved_it' | 'good' | 'average'
    required double rating, // 1.0 - 5.0
    required List<String> photoUrls, // min 1 required
    required String body,
    List<String> dishMentions = const [],
  }) async {
    // Validation
    if (photoUrls.isEmpty) {
      throw Exception('At least 1 photo is required to submit a review.');
    }
    if (rating < 1.0 || rating > 5.0) {
      throw Exception('Rating must be between 1.0 and 5.0.');
    }
    if (!['loved_it', 'good', 'average'].contains(moodTag)) {
      throw Exception('Invalid mood tag. Use: loved_it, good, or average.');
    }
    if (body.trim().isEmpty) {
      throw Exception('Review body cannot be empty.');
    }

    final response = await _supabase
        .from('reviews')
        .insert({
      'user_id': _currentUserId,
      'restaurant_id': restaurantId,
      'mood_tag': moodTag,
      'rating': rating,
      'photos': photoUrls,
      'dish_mentions': dishMentions,
      'body': body.trim(),
      'helpful_votes': 0,
      'flagged': false,
    })
        .select()
        .single();

    // ── 2.1 SCORE RECALCULATION ───────────────────────────────────────────
    // Fetch all reviews for this restaurant and recalculate score using
    // RestaurantScoreCalculator from score.dart (2.1)
    await _recalculateScore(restaurantId);
    // ──────────────────────────────────────────────────────────────────────

    return response;
  }

  // ─────────────────────────────────────────────
  // 2. GET /reviews/:id
  // Get a single review with author info and helpful vote count.
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getReview(String reviewId) async {
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
          )
        ''')
        .eq('id', reviewId)
        .single();

    return response;
  }

  // ─────────────────────────────────────────────
  // 3. DELETE /reviews/:id
  // Delete own review. Admin can delete any review.
  // Triggers: score recalculation for the restaurant (2.1 hook)
  // ─────────────────────────────────────────────
  Future<void> deleteReview(String reviewId) async {
    // Fetch review first to get restaurant_id and verify ownership
    final review = await _supabase
        .from('reviews')
        .select('user_id, restaurant_id')
        .eq('id', reviewId)
        .single();

    final isOwner = review['user_id'] == _currentUserId;
    final isAdmin = await _isAdmin();

    if (!isOwner && !isAdmin) {
      throw Exception('You can only delete your own reviews.');
    }

    final restaurantId = review['restaurant_id'] as String;

    await _supabase.from('reviews').delete().eq('id', reviewId);

    // ── 2.1 SCORE RECALCULATION ───────────────────────────────────────────
    // Recalculate score after review is deleted
    await _recalculateScore(restaurantId);
    // ──────────────────────────────────────────────────────────────────────
  }

  // ─────────────────────────────────────────────
  // 4. POST /reviews/:id/vote
  // Mark a review as helpful.
  // Increments reviewer's helpful_votes count.
  // Triggers: tier upgrade check (2.4 hook via 2.1)
  // ─────────────────────────────────────────────
  Future<void> voteReview(String reviewId) async {
    final voterId = _currentUserId;

    // Prevent self-voting: get review author
    final review = await _supabase
        .from('reviews')
        .select('user_id, helpful_votes')
        .eq('id', reviewId)
        .single();

    if (review['user_id'] == voterId) {
      throw Exception('You cannot vote on your own review.');
    }

    // Check if already voted (prevent duplicate votes)
    final existing = await _supabase
        .from('review_votes')
        .select('id')
        .eq('review_id', reviewId)
        .eq('voter_id', voterId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('You have already voted on this review.');
    }

    // Record the vote
    await _supabase.from('review_votes').insert({
      'review_id': reviewId,
      'voter_id': voterId,
    });

    // Increment helpful_votes on the review
    final currentVotes = review['helpful_votes'] as int;
    await _supabase
        .from('reviews')
        .update({'helpful_votes': currentVotes + 1}).eq('id', reviewId);

    // Increment helpful_votes on the reviewer's user record
    await _supabase.rpc('increment_helpful_votes', params: {
      'target_user_id': review['user_id'],
    });

    // ── 2.1 HOOK (Tier Upgrade) ────────────────────────────────────────────
    // TODO (2.1): Call TierUpgradeChecker.checkUpgrade(review['user_id'])
    // After every vote, check if the reviewer has crossed a tier threshold.
    // Thresholds: Explorer→Expert: 50 votes, Expert→Diamond: 200, Diamond→Platinum: 500
    // ──────────────────────────────────────────────────────────────────────
  }

  // ─────────────────────────────────────────────
  // 5. DELETE /reviews/:id/vote
  // Remove a helpful vote from a review.
  // ─────────────────────────────────────────────
  Future<void> unvoteReview(String reviewId) async {
    final voterId = _currentUserId;

    // Check vote exists
    final existing = await _supabase
        .from('review_votes')
        .select('id')
        .eq('review_id', reviewId)
        .eq('voter_id', voterId)
        .maybeSingle();

    if (existing == null) {
      throw Exception('You have not voted on this review.');
    }

    // Remove vote record
    await _supabase
        .from('review_votes')
        .delete()
        .eq('review_id', reviewId)
        .eq('voter_id', voterId);

    // Decrement helpful_votes on the review
    final review = await _supabase
        .from('reviews')
        .select('helpful_votes, user_id')
        .eq('id', reviewId)
        .single();

    final currentVotes = review['helpful_votes'] as int;
    final newVotes = currentVotes > 0 ? currentVotes - 1 : 0;

    await _supabase
        .from('reviews')
        .update({'helpful_votes': newVotes}).eq('id', reviewId);

    // Decrement helpful_votes on the reviewer's user record
    await _supabase.rpc('decrement_helpful_votes', params: {
      'target_user_id': review['user_id'],
    });
  }

  // ─────────────────────────────────────────────
  // 6. POST /reviews/:id/flag
  // Flag a review as inappropriate.
  // Adds to admin moderation queue.
  // ─────────────────────────────────────────────
  Future<void> flagReview(String reviewId) async {
    // Cannot flag your own review
    final review = await _supabase
        .from('reviews')
        .select('user_id, flagged')
        .eq('id', reviewId)
        .single();

    if (review['user_id'] == _currentUserId) {
      throw Exception('You cannot flag your own review.');
    }

    if (review['flagged'] == true) {
      throw Exception('This review has already been flagged.');
    }

    await _supabase
        .from('reviews')
        .update({'flagged': true}).eq('id', reviewId);
  }

  // ─────────────────────────────────────────────
  // 7. GET /restaurants/:id/reviews
  // All reviews for a restaurant.
  // Paginated (20 per page). Filter by mood_tag, rating, tier.
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getRestaurantReviews(
      String restaurantId, {
        int page = 1,
        int pageSize = 20,
        String? moodTagFilter, // 'loved_it' | 'good' | 'average'
        double? minRating,
        double? maxRating,
        String? tierFilter, // 'explorer' | 'expert' | 'diamond' | 'platinum'
      }) async {
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    // Build query with all filters BEFORE .order() and .range()
    // This is required because filters must chain on PostgrestFilterBuilder,
    // not on PostgrestTransformBuilder (which is what .range() returns).
    var query = _supabase
        .from('reviews')
        .select('''
          *,
          users (
            id,
            name,
            tier,
            verified,
            profile_photo_url
          )
        ''')
        .eq('restaurant_id', restaurantId)
        .eq('flagged', false);

    // Apply optional filters before ordering/paging
    if (moodTagFilter != null) {
      query = query.eq('mood_tag', moodTagFilter);
    }
    if (minRating != null) {
      query = query.gte('rating', minRating);
    }
    if (maxRating != null) {
      query = query.lte('rating', maxRating);
    }

    // Order and paginate LAST
    final response = await query
        .order('created_at', ascending: false)
        .range(from, to);

    // Filter by reviewer tier (client-side since it's a joined field)
    if (tierFilter != null) {
      return (response as List<dynamic>)
          .where((r) => r['users']['tier'] == tierFilter)
          .map((r) => r as Map<String, dynamic>)
          .toList();
    }

    return List<Map<String, dynamic>>.from(response);
  }

  // ─────────────────────────────────────────────
  // 8. GET /restaurants/:id/reviews/summary
  // Return cached AI summary text and keyword tags.
  // AI summary is generated by 2.3 (AI Summary Engine).
  // This endpoint just reads what 2.3 has already saved.
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>?> getRestaurantAiSummary(
      String restaurantId) async {
    final response = await _supabase
        .from('restaurants')
        .select('ai_summary, ai_tags')
        .eq('id', restaurantId)
        .single();

    // If fewer than 5 reviews exist, ai_summary is null — return null
    if (response['ai_summary'] == null) {
      return null;
    }

    return {
      'ai_summary': response['ai_summary'],
      'ai_tags': response['ai_tags'] ?? [],
    };
  }

  // ─────────────────────────────────────────────
  // PRIVATE HELPER: Recalculate restaurant score
  // Fetches all reviews → builds ReviewInput list →
  // calls RestaurantScoreCalculator.calculate() →
  // saves result to algorithm_scores table
  // Popularity is kept from existing record (owned by Member 3)
  // Proximity is per-user at request time (not stored here)
  // ─────────────────────────────────────────────
  Future<void> _recalculateScore(String restaurantId) async {
    // Step 1: Fetch all non-flagged reviews for this restaurant
    final rawReviews = await _supabase
        .from('reviews')
        .select('rating, users(tier)')
        .eq('restaurant_id', restaurantId)
        .eq('flagged', false);

    // Step 2: Convert to List<ReviewInput> for RestaurantScoreCalculator
    final reviewInputs = (rawReviews as List<dynamic>).map((r) {
      return ReviewInput(
        tier: r['users']['tier'] as String,
        rating: (r['rating'] as num).toDouble(),
      );
    }).toList();

    // Step 3: Get existing popularity score from algorithm_scores table
    // Popularity is owned by Member 3 — we never overwrite it here
    double existingPopularity = 50.0; // default if no record exists yet
    try {
      final existing = await _supabase
          .from('algorithm_scores')
          .select('popularity_score')
          .eq('restaurant_id', restaurantId)
          .maybeSingle();
      if (existing != null) {
        existingPopularity =
            (existing['popularity_score'] as num).toDouble();
      }
    } catch (_) {
      // keep default 50.0 if record not found
    }

    // Step 4: Proximity is per-user at request time (Member 3 handles it)
    // We use 50.0 as a neutral placeholder — final score shown to user
    // will use real proximity when Member 3 calls the algorithm at runtime
    const double proximityPlaceholder = 50.0;

    // Step 5: Run the score calculation
    final result = RestaurantScoreCalculator.calculate(
      reviews: reviewInputs,
      popularity: existingPopularity,
      proximity: proximityPlaceholder,
    );

    // Step 6: Save quality, trust, final score and review count
    // to algorithm_scores table (upsert = insert or update)
    await _supabase.from('algorithm_scores').upsert({
      'restaurant_id': restaurantId,
      'quality_score': result.qualityScore,
      'trust_score': result.trustScore,
      'popularity_score': existingPopularity, // unchanged
      'review_count': reviewInputs.length,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'restaurant_id');

    // Step 7: Also update the cached algorithm_score on restaurants table
    await _supabase.from('restaurants').update({
      'algorithm_score': result.finalScore,
      'score_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', restaurantId);
  }

  // ─────────────────────────────────────────────
  // PRIVATE HELPER: Check if current user is admin
  // ─────────────────────────────────────────────
  Future<bool> _isAdmin() async {
    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', _currentUserId)
          .single();
      return response['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }
}
