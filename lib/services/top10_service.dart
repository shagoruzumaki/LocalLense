import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/restaurant.dart';

class Top10Service {
  final _supabase = Supabase.instance.client;

  /// 3.3 Top 10 Restaurants
  /// Filters: 'week', 'month', 'alltime'
  Future<List<Restaurant>> getTop10Restaurants({String filter = 'alltime'}) async {
    try {
      if (filter == 'alltime') {
        final response = await _supabase
            .from('restaurants')
            .select('*')
            .eq('active', true)
            .order('algorithm_score', ascending: false)
            .limit(10);
        
        return (response as List).map((json) => Restaurant.fromSupabase(json)).toList();
      } else {
        // For week/month, we calculate based on review average in that period
        final days = filter == 'week' ? 7 : 30;
        final startDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();

        // 1. Fetch reviews in the period
        final reviewsResponse = await _supabase
            .from('reviews')
            .select('restaurant_id, rating')
            .gte('created_at', startDate)
            .eq('flagged', false);

        final reviews = reviewsResponse as List;
        if (reviews.isEmpty) return getTop10Restaurants(filter: 'alltime');

        // 2. Aggregate
        Map<String, List<double>> restaurantRatings = {};
        for (var r in reviews) {
          final id = r['restaurant_id'] as String;
          final rating = (r['rating'] as num).toDouble();
          restaurantRatings.putIfAbsent(id, () => []).add(rating);
        }

        // 3. Calculate average and sort
        var sortedIds = restaurantRatings.keys.toList();
        sortedIds.sort((a, b) {
          double avgA = restaurantRatings[a]!.reduce((a, b) => a + b) / restaurantRatings[a]!.length;
          double avgB = restaurantRatings[b]!.reduce((a, b) => a + b) / restaurantRatings[b]!.length;
          return avgB.compareTo(avgA);
        });

        final top10Ids = sortedIds.take(10).toList();

        // 4. Fetch restaurant details
        final restaurantsResponse = await _supabase
            .from('restaurants')
            .select('*')
            .inFilter('id', top10Ids);

        final List<Restaurant> result = (restaurantsResponse as List)
            .map((json) => Restaurant.fromSupabase(json))
            .toList();
        
        // Re-sort because inFilter doesn't preserve order
        result.sort((a, b) => top10Ids.indexOf(a.id).compareTo(top10Ids.indexOf(b.id)));
        
        return result;
      }
    } catch (e) {
      print('Error in getTop10Restaurants: $e');
      return [];
    }
  }

  /// 3.3 Top 10 Critics
  /// Ranking formula: score = helpful_votes_in_period × tier_multiplier
  /// Platinum=4, Diamond=3, Expert=2, Explorer=1
  Future<List<Map<String, dynamic>>> getTop10Critics({String filter = 'alltime'}) async {
    try {
      if (filter == 'alltime') {
        final response = await _supabase
            .from('users')
            .select('id, name, profile_photo_url, helpful_votes, tier')
            .eq('is_deleted', false)
            .order('helpful_votes', ascending: false)
            .limit(10);

        return (response as List).map((c) {
          final user = Map<String, dynamic>.from(c as Map);
          int multiplier = _getTierMultiplier(user['tier']?.toString() ?? 'explorer');
          return {
            ...user,
            'rank_score': (user['helpful_votes'] as int? ?? 0) * multiplier,
          };
        }).toList();
      } else {
        final days = filter == 'week' ? 7 : 30;
        final startDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();

        // Count votes received by users in this period
        // review_votes table: review_id, voter_id, created_at
        // reviews table: id, user_id (author)
        final response = await _supabase
            .from('review_votes')
            .select('reviews(user_id)')
            .gte('created_at', startDate);

        final votes = response as List;
        Map<String, int> userVotes = {};
        for (var v in votes) {
          final authorId = v['reviews']['user_id'] as String;
          userVotes[authorId] = (userVotes[authorId] ?? 0) + 1;
        }

        if (userVotes.isEmpty) return getTop10Critics(filter: 'alltime');

        // Fetch user details for these authors
        final userIds = userVotes.keys.toList();
        final usersResponse = await _supabase
            .from('users')
            .select('id, name, profile_photo_url, tier')
            .inFilter('id', userIds);

        final List<Map<String, dynamic>> rankedCritics = (usersResponse as List).map((u) {
          final user = Map<String, dynamic>.from(u as Map);
          int multiplier = _getTierMultiplier(user['tier']?.toString() ?? 'explorer');
          int periodVotes = userVotes[user['id']] ?? 0;
          
          return {
            ...user,
            'helpful_votes': periodVotes, // for this period
            'rank_score': periodVotes * multiplier,
          };
        }).toList();

        rankedCritics.sort((a, b) => (b['rank_score'] as int).compareTo(a['rank_score'] as int));
        return rankedCritics.take(10).toList();
      }
    } catch (e) {
      print('Error in getTop10Critics: $e');
      return [];
    }
  }

  int _getTierMultiplier(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum': return 4;
      case 'diamond': return 3;
      case 'expert': return 2;
      case 'explorer':
      default: return 1;
    }
  }
}
