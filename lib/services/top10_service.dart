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
      if (reviews.isEmpty) return await getAllTimeLeaderboard();

      Map<String, List<double>> periodRatings = {};
      for (var r in reviews) {
        final id = r['restaurant_id'].toString();
        periodRatings.putIfAbsent(id, () => []).add((r['rating'] as num).toDouble());
      }

      var sortedIds = periodRatings.keys.toList();
      sortedIds.sort((a, b) {
        double avgA = periodRatings[a]!.reduce((v, e) => v + e) / periodRatings[a]!.length;
        double avgB = periodRatings[b]!.reduce((v, e) => v + e) / periodRatings[b]!.length;
        return avgB.compareTo(avgA);
      });

      final restaurantsResp = await _supabase
          .from('restaurants')
          .select('*')
          .inFilter('id', sortedIds)
          .eq('active', true);
          
      final results = (restaurantsResp as List).map((j) => Restaurant.fromSupabase(j)).toList();
      results.sort((a, b) => b.rating.compareTo(a.rating));
      return results;
    } catch (e) {
      return await getAllTimeLeaderboard();
    }
  }

  /// Fetches Critics leaderboard (Lifetime)
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
        }).toList();
      }

      final days = filter == 'week' ? 7 : 30;
      final startDate = DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();

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
      topUids.sort((a, b) => periodVotes[b]!.compareTo(periodVotes[a]!));

      final usersResp = await _supabase
          .from('users')
          .select('*')
          .inFilter('id', topUids);
      
      return (usersResp as List).map((u) {
        final user = Map<String, dynamic>.from(u);
        return {
          ...user,
          'rank_score': periodVotes[user['id']] ?? 0,
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
