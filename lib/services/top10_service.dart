import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/restaurant.dart';

class Top10Service {
  final _supabase = Supabase.instance.client;

  /// Fetches every restaurant from Supabase for the All-Time Leaderboard.
  Future<List<Restaurant>> getAllTimeLeaderboard() async {
    try {
      final response = await _supabase
          .from('restaurants')
          .select('*')
          .eq('active', true)
          .order('algorithm_score', ascending: false);
      
      final results = (response as List).map((json) => Restaurant.fromSupabase(json)).toList();
      
      // Sort by rating descending (rating is derived from algorithm_score)
      results.sort((a, b) => b.rating.compareTo(a.rating));
      return results;
    } catch (e) {
      return [];
    }
  }

  /// Period-based fetch (Week/Month) for Restaurants
  Future<List<Restaurant>> getTopRestaurantsByPeriod({required String filter}) async {
    try {
      if (filter == 'alltime') {
        return await getAllTimeLeaderboard();
      }

      final days = filter == 'week' ? 7 : 30;
      final startDate = DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();

      // Aggregate ratings from reviews in the given period
      final reviewsResp = await _supabase
          .from('reviews')
          .select('restaurant_id, rating')
          .gte('created_at', startDate);
      
      final reviews = reviewsResp as List;
      
      // If no reviews in this period, fallback to all-time leaderboard
      if (reviews.isEmpty) return await getAllTimeLeaderboard();

      Map<String, List<double>> periodRatings = {};
      for (var r in reviews) {
        final id = r['restaurant_id'].toString();
        periodRatings.putIfAbsent(id, () => []).add((r['rating'] as num).toDouble());
      }

      var sortedIds = periodRatings.keys.toList();
      
      // Fetch restaurant data for these IDs
      final restaurantsResp = await _supabase
          .from('restaurants')
          .select('*')
          .inFilter('id', sortedIds)
          .eq('active', true);
          
      final results = (restaurantsResp as List).map((j) {
        final id = j['id'].toString();
        // Calculate the average rating specifically for this period
        final periodAvg = periodRatings[id]!.reduce((v, e) => v + e) / periodRatings[id]!.length;
        
        // Create a modified JSON to override all-time scores with period-specific performance
        final modifiedJson = Map<String, dynamic>.from(j);
        // Force the Restaurant.rating getter to use our calculated period average
        modifiedJson['algorithm_score'] = null; 
        modifiedJson['rating'] = periodAvg;
        
        return Restaurant.fromSupabase(modifiedJson);
      }).toList();
      
      // Sort by the period-specific rating
      results.sort((a, b) => b.rating.compareTo(a.rating));
      return results;
    } catch (e) {
      return await getAllTimeLeaderboard();
    }
  }

  /// Fetches Critics leaderboard (Lifetime or Period)
  Future<List<Map<String, dynamic>>> getTopCritics({String filter = 'alltime'}) async {
    try {
      if (filter == 'alltime') {
        final response = await _supabase
            .from('users')
            .select('*')
            .order('helpful_votes', ascending: false);
        
        return (response as List).map((u) {
          final user = Map<String, dynamic>.from(u);
          return {
            ...user,
            'rank_score': (user['helpful_votes'] as int? ?? 0) * _getTierMultiplier(user['tier']?.toString() ?? 'explorer'),
          };
        }).toList()..sort((a, b) => (b['rank_score'] as int).compareTo(a['rank_score'] as int));
      }

      final days = filter == 'week' ? 7 : 30;
      final startDate = DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();

      // For period-based critics, we look at helpful votes gained from reviews posted in that period
      final response = await _supabase
          .from('reviews')
          .select('user_id, helpful_votes')
          .gte('created_at', startDate);
      
      final reviews = response as List;
      if (reviews.isEmpty) return await getTopCritics(filter: 'alltime');

      Map<String, int> periodVotes = {};
      for (var r in reviews) {
        final uid = r['user_id'].toString();
        periodVotes[uid] = (periodVotes[uid] ?? 0) + (r['helpful_votes'] as int? ?? 0);
      }

      var topUids = periodVotes.keys.toList();

      final usersResp = await _supabase
          .from('users')
          .select('*')
          .inFilter('id', topUids);
      
      return (usersResp as List).map((u) {
        final user = Map<String, dynamic>.from(u);
        final votesInPeriod = periodVotes[user['id']] ?? 0;
        return {
          ...user,
          'helpful_votes': votesInPeriod, // Display votes gained in this period
          'rank_score': votesInPeriod * _getTierMultiplier(user['tier']?.toString() ?? 'explorer'),
        };
      }).toList()..sort((a, b) => (b['rank_score'] as int).compareTo(a['rank_score'] as int));

    } catch (e) {
      return [];
    }
  }

  int _getTierMultiplier(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum': return 4;
      case 'diamond': return 3;
      case 'expert': return 2;
      default: return 1;
    }
  }
}
