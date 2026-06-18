import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../algorithm/score.dart';
import 'ai_summary.dart';
import 'tier_upgrade_api.dart';

class ReviewApi {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _currentUserId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.id;
  }

  /// Submit a new review with strict duplicate prevention
  Future<Map<String, dynamic>> submitReview({
    required String restaurantId,
    required String moodTag,
    required double rating,
    required List<String> photoUrls,
    required String body,
    List<String> dishMentions = const [],
  }) async {
    // 1. Validation
    if (photoUrls.isEmpty) throw Exception('At least 1 photo is required.');
    if (body.trim().isEmpty) throw Exception('Review body cannot be empty.');

    // 2. PREVENT DUPLICATE REVIEWS: One review per user per restaurant
    final existing = await _supabase
        .from('reviews')
        .select('id')
        .eq('user_id', _currentUserId)
        .eq('restaurant_id', restaurantId);

    if ((existing as List).isNotEmpty) {
      throw Exception(
        'You have already submitted a review for this restaurant. Edit or delete your old one to post again.',
      );
    }

    // 3. Clean and deduplicate dish mentions
    final uniqueDishes = dishMentions
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();

    // 4. Insert the review
    final response = await _supabase
        .from('reviews')
        .insert({
          'user_id': _currentUserId,
          'restaurant_id': restaurantId,
          'mood_tag': moodTag,
          'rating': rating,
          'photos': photoUrls,
          'dish_mentions': uniqueDishes,
          'body': body.trim(),
          'helpful_votes': 0,
          'flagged': false,
        })
        .select()
        .single();

    // 5. Trigger updates
    await _insertDishReviews(
      restaurantId: restaurantId,
      dishNames: uniqueDishes,
      rating: rating,
      comment: body.trim(),
      photoUrls: photoUrls,
    );
    await _updateDishMetrics(restaurantId, uniqueDishes, rating);
    await _recalculateScore(restaurantId);

    final aiSummary = AiSummaryApi();
    await aiSummary.checkAndGenerateSummary(restaurantId);

    return response;
  }

  Future<void> _insertDishReviews({
    required String restaurantId,
    required List<String> dishNames,
    required double rating,
    required String comment,
    required List<String> photoUrls,
  }) async {
    if (dishNames.isEmpty) return;

    final rows = <Map<String, dynamic>>[];
    for (final name in dishNames) {
      final dish = await _supabase
          .from('dishes')
          .select('id')
          .eq('restaurant_id', restaurantId)
          .ilike('name', name)
          .maybeSingle();

      if (dish == null) {
        debugPrint(
          'Dish review skipped: no dish named "$name" for $restaurantId',
        );
        continue;
      }

      rows.add({
        'dish_id': dish['id'],
        'restaurant_id': restaurantId,
        'user_id': _currentUserId,
        'rating': rating,
        'comment': comment,
        'photos': photoUrls,
      });
    }

    if (rows.isNotEmpty) {
      await _supabase.from('dish_reviews').insert(rows);
    }
  }

  Future<void> _updateDishMetrics(
    String restaurantId,
    List<String> dishNames,
    double reviewRating,
  ) async {
    for (final name in dishNames) {
      try {
        final dish = await _supabase
            .from('dishes')
            .select('id, mention_count, trending_score')
            .eq('restaurant_id', restaurantId)
            .ilike('name', name)
            .maybeSingle();

        if (dish != null) {
          final int oldCount = (dish['mention_count'] as int?) ?? 0;
          final double oldScore =
              (dish['trending_score'] as num?)?.toDouble() ?? 0.0;
          final int newCount = oldCount + 1;
          final double normalizedRating = reviewRating * 20.0;
          final double newScore =
              ((oldScore * oldCount) + normalizedRating) / newCount;

          await _supabase
              .from('dishes')
              .update({'mention_count': newCount, 'trending_score': newScore})
              .eq('id', dish['id']);
        }
      } catch (e) {
        debugPrint('Metric Update Error: $e');
      }
    }
  }

  Future<Map<String, dynamic>> getReview(String reviewId) async {
    final response = await _supabase
        .from('reviews')
        .select('*, users (id, name, tier, verified, profile_photo_url)')
        .eq('id', reviewId)
        .single();
    return response;
  }

  /// Public helper for score recalculation (used by AdminApi)
  Future<void> recalculateScorePublic(String restaurantId) async {
    await _recalculateScore(restaurantId);
  }

  /// Public helper for rolling back dish metrics (used by AdminApi)
  Future<void> rollbackDishMetricsPublic(
    String restaurantId,
    List<String> dishNames,
    double rating,
  ) async {
    await _rollbackDishMetrics(restaurantId, dishNames, rating);
  }

  Future<void> deleteReview(String reviewId) async {
    final review = await _supabase
        .from('reviews')
        .select('user_id, restaurant_id, dish_mentions, rating')
        .eq('id', reviewId)
        .single();

    if (review['user_id'] != _currentUserId) {
      // Admin check would go here if needed, but deleteReview is user-facing
      throw Exception('Unauthorized');
    }

    final restaurantId = review['restaurant_id'] as String;
    final List<String> mentions = List<String>.from(
      review['dish_mentions'] ?? [],
    );
    final double rating = (review['rating'] as num).toDouble();

    await _deleteDishReviewsForCurrentUser(restaurantId);
    await _supabase.from('reviews').delete().eq('id', reviewId);
    await _rollbackDishMetrics(restaurantId, mentions, rating);
    await _recalculateScore(restaurantId);
  }

  Future<void> _deleteDishReviewsForCurrentUser(String restaurantId) async {
    await _supabase
        .from('dish_reviews')
        .delete()
        .eq('restaurant_id', restaurantId)
        .eq('user_id', _currentUserId);
  }

  Future<void> _rollbackDishMetrics(
    String restaurantId,
    List<String> dishNames,
    double reviewRating,
  ) async {
    for (final name in dishNames) {
      try {
        final dish = await _supabase
            .from('dishes')
            .select('id, mention_count, trending_score')
            .eq('restaurant_id', restaurantId)
            .ilike('name', name)
            .maybeSingle();

        if (dish != null) {
          final int oldCount = (dish['mention_count'] as int?) ?? 1;
          final double currentScore =
              (dish['trending_score'] as num?)?.toDouble() ?? 0.0;

          if (oldCount <= 1) {
            await _supabase
                .from('dishes')
                .update({'mention_count': 0, 'trending_score': 0.0})
                .eq('id', dish['id']);
          } else {
            final int newCount = oldCount - 1;
            final double normalizedRating = reviewRating * 20.0;
            final double newScore =
                ((currentScore * oldCount) - normalizedRating) / newCount;
            await _supabase
                .from('dishes')
                .update({
                  'mention_count': newCount,
                  'trending_score': newScore.clamp(0.0, 100.0),
                })
                .eq('id', dish['id']);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> voteReview(String reviewId) async {
    final voterId = _currentUserId;
    final existing = await _supabase
        .from('review_votes')
        .select('id')
        .eq('review_id', reviewId)
        .eq('voter_id', voterId)
        .maybeSingle();
    if (existing != null) throw Exception('You already voted.');

    await _supabase.from('review_votes').insert({
      'review_id': reviewId,
      'voter_id': voterId,
    });
    final review = await _supabase
        .from('reviews')
        .select('helpful_votes, user_id')
        .eq('id', reviewId)
        .single();
    await _supabase
        .from('reviews')
        .update({'helpful_votes': (review['helpful_votes'] as int) + 1})
        .eq('id', reviewId);
    await _supabase.rpc(
      'increment_helpful_votes',
      params: {'target_user_id': review['user_id']},
    );
    await TierUpgradeApi().checkUpgrade(review['user_id'] as String);
  }

  Future<void> unvoteReview(String reviewId) async {
    await _supabase
        .from('review_votes')
        .delete()
        .eq('review_id', reviewId)
        .eq('voter_id', _currentUserId);
    final review = await _supabase
        .from('reviews')
        .select('helpful_votes, user_id')
        .eq('id', reviewId)
        .single();
    await _supabase
        .from('reviews')
        .update({
          'helpful_votes': (review['helpful_votes'] as int) > 0
              ? (review['helpful_votes'] as int) - 1
              : 0,
        })
        .eq('id', reviewId);
    await _supabase.rpc(
      'decrement_helpful_votes',
      params: {'target_user_id': review['user_id']},
    );
  }

  Future<void> flagReview(String reviewId) async {
    await _supabase
        .from('reviews')
        .update({'flagged': true})
        .eq('id', reviewId);
  }

  Future<List<Map<String, dynamic>>> getRestaurantReviews(
    String restaurantId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;
    final response = await _supabase
        .from('reviews')
        .select('*, users (id, name, tier, verified, profile_photo_url)')
        .eq('restaurant_id', restaurantId)
        .eq('flagged', false)
        .order('created_at', ascending: false)
        .range(from, to);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getUserReviews(String userId) async {
    final response = await _supabase
        .from('reviews')
        .select('*, restaurants (id, name, photos)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Set<String>> getCurrentUserVotedReviewIds(
    List<String> reviewIds,
  ) async {
    if (reviewIds.isEmpty) return {};

    final response = await _supabase
        .from('review_votes')
        .select('review_id')
        .eq('voter_id', _currentUserId)
        .inFilter('review_id', reviewIds);

    return (response as List<dynamic>)
        .map((vote) => vote['review_id']?.toString())
        .whereType<String>()
        .toSet();
  }

  Future<void> _recalculateScore(String restaurantId) async {
    final rawReviews = await _supabase
        .from('reviews')
        .select('rating, users(tier)')
        .eq('restaurant_id', restaurantId)
        .eq('flagged', false);
    final reviewInputs = (rawReviews as List<dynamic>)
        .map(
          (r) => ReviewInput(
            tier: r['users']['tier'] as String,
            rating: (r['rating'] as num).toDouble(),
          ),
        )
        .toList();

    double popularity = 50.0;
    try {
      final existing = await _supabase
          .from('algorithm_scores')
          .select('popularity_score')
          .eq('restaurant_id', restaurantId)
          .maybeSingle();
      if (existing != null)
        popularity = (existing['popularity_score'] as num).toDouble();
    } catch (_) {}

    final result = RestaurantScoreCalculator.calculate(
      reviews: reviewInputs,
      popularity: popularity,
      proximity: 50.0,
    );
    await _supabase.from('algorithm_scores').upsert({
      'restaurant_id': restaurantId,
      'quality_score': result.qualityScore,
      'trust_score': result.trustScore,
      'popularity_score': popularity,
      'review_count': reviewInputs.length,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'restaurant_id');

    await _supabase
        .from('restaurants')
        .update({
          'algorithm_score': result.finalScore,
          'score_updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', restaurantId);
  }
}
