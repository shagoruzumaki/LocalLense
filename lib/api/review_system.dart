import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../algorithm/score.dart';   // 2.1 — RestaurantScoreCalculator
import 'ai_summary.dart';       // 2.3 — AI Summary Engine
import 'tier_upgrade_api.dart';     // 2.4 — Tier Upgrade Logic

/// 2.2 Review System API
/// Owner: Kamonashish Dutta Hemel
/// All review-related operations for LocalLens
/// Connects to: 2.1 Score Algorithm after write operations
/// Connects to: 2.3 AI Summary Engine after every new review
/// Connects to: 2.4 Tier Upgrade Logic after every helpful vote

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

    // ── DYNAMIC DISH RANKING ─────────────────────────────────────────────
    // Update mention count and trending score for each dish
    await _updateDishMetrics(restaurantId, dishMentions, rating);
    // ──────────────────────────────────────────────────────────────────────

    // ── 2.1 SCORE RECALCULATION ───────────────────────────────────────────
    // Recalculate quality + trust scores using score.dart (2.1)
    await _recalculateScore(restaurantId);
    // ──────────────────────────────────────────────────────────────────────

    // ── 2.3 AI SUMMARY ENGINE ─────────────────────────────────────────────
    // Check if summary should regenerate
    final aiSummary = AiSummaryApi();
    await aiSummary.checkAndGenerateSummary(restaurantId);
    // ──────────────────────────────────────────────────────────────────────

    return response;
  }

  /// Updates dish metrics for ranking purposes
  Future<void> _updateDishMetrics(String restaurantId, List<String> dishNames, double reviewRating) async {
    for (final name in dishNames) {
      try {
        // 1. Find the dish by name and restaurant_id
        final dish = await _supabase
            .from('dishes')
            .select('id, mention_count, trending_score')
            .eq('restaurant_id', restaurantId)
            .ilike('name', name.trim())
            .maybeSingle();

        if (dish != null) {
          final int oldCount = (dish['mention_count'] as int?) ?? 0;
          final double oldScore = (dish['trending_score'] as num?)?.toDouble() ?? 0.0;
          
          final int newCount = oldCount + 1;
          
          // Trending algorithm: 
          // Convert 1-5 rating to 0-100 scale (rating * 20)
          // Use a weighted average to update the trending score
          final double normalizedRating = reviewRating * 20.0;
          final double newScore = ((oldScore * oldCount) + normalizedRating) / newCount;

          await _supabase.from('dishes').update({
            'mention_count': newCount,
            'trending_score': newScore,
          }).eq('id', dish['id']);
        } else {
          // If the dish doesn't exist, we could potentially create it as an "unverified" dish
          // For now, we'll just log it or skip to keep data clean
          debugPrint('Dish not found in menu: $name. Skipping dynamic metric update.');
        }
      } catch (e) {
        debugPrint('Error updating metrics for dish $name: $e');
      }
    }
  }

  // ─────────────────────────────────────────────
  // 2. GET /reviews/:id
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
  // ─────────────────────────────────────────────
  Future<void> deleteReview(String reviewId) async {
    final review = await _supabase
        .from('reviews')
        .select('user_id, restaurant_id, dish_mentions, rating')
        .eq('id', reviewId)
        .single();

    final isOwner = review['user_id'] == _currentUserId;
    final isAdmin = await _isAdmin();

    if (!isOwner && !isAdmin) {
      throw Exception('You can only delete your own reviews.');
    }

    final restaurantId = review['restaurant_id'] as String;
    final List<String> mentions = List<String>.from(review['dish_mentions'] ?? []);
    final double rating = (review['rating'] as num).toDouble();

    await _supabase.from('reviews').delete().eq('id', reviewId);

    // Rollback dish metrics
    await _rollbackDishMetrics(restaurantId, mentions, rating);

    await _recalculateScore(restaurantId);
  }

  Future<void> _rollbackDishMetrics(String restaurantId, List<String> dishNames, double reviewRating) async {
    for (final name in dishNames) {
      try {
        final dish = await _supabase
            .from('dishes')
            .select('id, mention_count, trending_score')
            .eq('restaurant_id', restaurantId)
            .ilike('name', name.trim())
            .maybeSingle();

        if (dish != null) {
          final int oldCount = (dish['mention_count'] as int?) ?? 1;
          final double currentScore = (dish['trending_score'] as num?)?.toDouble() ?? 0.0;
          
          if (oldCount <= 1) {
            await _supabase.from('dishes').update({
              'mention_count': 0,
              'trending_score': 0.0,
            }).eq('id', dish['id']);
          } else {
            final int newCount = oldCount - 1;
            final double normalizedRating = reviewRating * 20.0;
            final double newScore = ((currentScore * oldCount) - normalizedRating) / newCount;

            await _supabase.from('dishes').update({
              'mention_count': newCount,
              'trending_score': newScore.clamp(0.0, 100.0),
            }).eq('id', dish['id']);
          }
        }
      } catch (e) {
        debugPrint('Error rolling back metrics for dish $name: $e');
      }
    }
  }

  // ─────────────────────────────────────────────
  // 4. POST /reviews/:id/vote
  // ─────────────────────────────────────────────
  Future<void> voteReview(String reviewId) async {
    final voterId = _currentUserId;

    final review = await _supabase
        .from('reviews')
        .select('user_id, helpful_votes')
        .eq('id', reviewId)
        .single();

    if (review['user_id'] == voterId) {
      throw Exception('You cannot vote on your own review.');
    }

    final existing = await _supabase
        .from('review_votes')
        .select('id')
        .eq('review_id', reviewId)
        .eq('voter_id', voterId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('You have already voted on this review.');
    }

    await _supabase.from('review_votes').insert({
      'review_id': reviewId,
      'voter_id': voterId,
    });

    final currentVotes = review['helpful_votes'] as int;
    await _supabase
        .from('reviews')
        .update({'helpful_votes': currentVotes + 1}).eq('id', reviewId);

    await _supabase.rpc('increment_helpful_votes', params: {
      'target_user_id': review['user_id'],
    });

    final tierUpgrade = TierUpgradeApi();
    await tierUpgrade.checkUpgrade(review['user_id'] as String);
  }

  // ─────────────────────────────────────────────
  // 5. DELETE /reviews/:id/vote
  // ─────────────────────────────────────────────
  Future<void> unvoteReview(String reviewId) async {
    final voterId = _currentUserId;

    final existing = await _supabase
        .from('review_votes')
        .select('id')
        .eq('review_id', reviewId)
        .eq('voter_id', voterId)
        .maybeSingle();

    if (existing == null) {
      throw Exception('You have not voted on this review.');
    }

    await _supabase
        .from('review_votes')
        .delete()
        .eq('review_id', reviewId)
        .eq('voter_id', voterId);

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

    await _supabase.rpc('decrement_helpful_votes', params: {
      'target_user_id': review['user_id'],
    });
  }

  // ─────────────────────────────────────────────
  // 6. POST /reviews/:id/flag
  // ─────────────────────────────────────────────
  Future<void> flagReview(String reviewId) async {
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
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getRestaurantReviews(
      String restaurantId, {
        int page = 1,
        int pageSize = 20,
        String? moodTagFilter,
        double? minRating,
        double? maxRating,
        String? tierFilter,
      }) async {
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

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

    if (moodTagFilter != null) {
      query = query.eq('mood_tag', moodTagFilter);
    }
    if (minRating != null) {
      query = query.gte('rating', minRating);
    }
    if (maxRating != null) {
      query = query.lte('rating', maxRating);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(from, to);

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
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>?> getRestaurantAiSummary(
      String restaurantId) async {
    final response = await _supabase
        .from('restaurants')
        .select('ai_summary, ai_tags')
        .eq('id', restaurantId)
        .single();

    if (response['ai_summary'] == null) {
      return null;
    }

    return {
      'ai_summary': response['ai_summary'],
      'ai_tags': response['ai_tags'] ?? [],
    };
  }
  
  Future<List<Map<String, dynamic>>> getUserReviews(String userId) async {
    final response = await _supabase
        .from('reviews')
        .select('''
      *,
      restaurants (
        id,
        name,
        photos
      )
    ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> recalculateScorePublic(String restaurantId) async {
    await _recalculateScore(restaurantId);
  }

  Future<void> _recalculateScore(String restaurantId) async {
    final rawReviews = await _supabase
        .from('reviews')
        .select('rating, users(tier)')
        .eq('restaurant_id', restaurantId)
        .eq('flagged', false);

    final reviewInputs = (rawReviews as List<dynamic>).map((r) {
      return ReviewInput(
        tier: r['users']['tier'] as String,
        rating: (r['rating'] as num).toDouble(),
      );
    }).toList();

    double existingPopularity = 50.0; 
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
    } catch (_) {}

    const double proximityPlaceholder = 50.0;

    final result = RestaurantScoreCalculator.calculate(
      reviews: reviewInputs,
      popularity: existingPopularity,
      proximity: proximityPlaceholder,
    );

    await _supabase.from('algorithm_scores').upsert({
      'restaurant_id': restaurantId,
      'quality_score': result.qualityScore,
      'trust_score': result.trustScore,
      'popularity_score': existingPopularity,
      'review_count': reviewInputs.length,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'restaurant_id');

    await _supabase.from('restaurants').update({
      'algorithm_score': result.finalScore,
      'score_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', restaurantId);
  }

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
