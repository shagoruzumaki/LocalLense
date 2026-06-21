import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/restaurant.dart';

class Top10Service {
  final _supabase = Supabase.instance.client;

  /// Fetches All-Time Leaderboard, optionally filtered by neighbourhood
  Future<List<Restaurant>> getAllTimeLeaderboard({String? neighbourhood, int limit = 1000}) async {
    try {
      var query = _supabase
          .from('restaurants')
          .select('*')
          .eq('active', true);
      
      if (neighbourhood != null && neighbourhood != 'Global' && neighbourhood != 'Nearby') {
        query = query.ilike('address', '%$neighbourhood%');
      }

      // Sort by the master algorithm score for the leaderboard
      final response = await query
          .order('algorithm_score', ascending: false)
          .limit(limit);
      
      final results = (response as List).map((json) => Restaurant.fromSupabase(json)).toList();
      // We keep the database order (algorithm_score) for the leaderboard
      return results;
    } catch (e) {
      return [];
    }
  }

  /// Period-based fetch (Week/Month) with Fallback to All-Time
  Future<List<Restaurant>> getTopRestaurantsByPeriod({required String filter, String? neighbourhood}) async {
    try {
      if (filter == 'alltime') {
        return await getAllTimeLeaderboard(neighbourhood: neighbourhood);
      }

      final days = filter == 'week' ? 7 : 30;
      final startDate = DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();

      // 1. Get IDs of all restaurants in this neighbourhood first (to filter reviews efficiently)
      List<String>? localIds;
      if (neighbourhood != null && neighbourhood != 'Global' && neighbourhood != 'Nearby') {
        final localRes = await _supabase
            .from('restaurants')
            .select('id')
            .ilike('address', '%$neighbourhood%');
        localIds = (localRes as List).map((r) => r['id'].toString()).toList();
      }

      // 2. Fetch reviews in the period
      var reviewsQuery = _supabase
          .from('reviews')
          .select('restaurant_id, rating')
          .gte('created_at', startDate);
      
      if (localIds != null) {
        reviewsQuery = reviewsQuery.inFilter('restaurant_id', localIds);
      }

      final reviewsResp = await reviewsQuery;
      final reviews = reviewsResp as List;

      // 3. Process period ratings
      Map<String, List<double>> periodRatings = {};
      for (var r in reviews) {
        final id = r['restaurant_id'].toString();
        periodRatings.putIfAbsent(id, () => []).add((r['rating'] as num).toDouble());
      }

      // 4. Fetch the restaurant details for those with recent reviews
      List<Restaurant> activeResults = [];
      if (periodRatings.isNotEmpty) {
        final restaurantsResp = await _supabase
            .from('restaurants')
            .select('*')
            .inFilter('id', periodRatings.keys.toList())
            .eq('active', true);

        activeResults = (restaurantsResp as List).map((j) {
          final id = j['id'].toString();
          final periodAvg = periodRatings[id]!.reduce((v, e) => v + e) / periodRatings[id]!.length;
          final modifiedJson = Map<String, dynamic>.from(j);
          // For trending, we use the period average to sort
          modifiedJson['rating'] = periodAvg;
          return Restaurant.fromSupabase(modifiedJson);
        }).toList();
        activeResults.sort((a, b) => b.rating.compareTo(a.rating));
      }

      // 5. FILLER LOGIC: If less than 10, fill from All-Time
      if (activeResults.length < 10) {
        final allTime = await getAllTimeLeaderboard(neighbourhood: neighbourhood, limit: 20);
        for (var r in allTime) {
          if (activeResults.length >= 10) break;
          // Avoid duplicates
          if (!activeResults.any((active) => active.id == r.id)) {
            activeResults.add(r);
          }
        }
      }

      return activeResults;
    } catch (e) {
      return await getAllTimeLeaderboard(neighbourhood: neighbourhood);
    }
  }

  /// Period-based fetch for Critics with Fallback
  Future<List<Map<String, dynamic>>> getTopCritics({String filter = 'alltime', String? neighbourhood}) async {
    try {
      if (filter == 'alltime') {
        final response = await _supabase
            .from('users')
            .select('*')
            .order('helpful_votes', ascending: false)
            .limit(1000);
        
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

      final response = await _supabase
          .from('reviews')
          .select('user_id, helpful_votes')
          .gte('created_at', startDate);
      
      final reviews = response as List;
      
      Map<String, int> periodVotes = {};
      for (var r in reviews) {
        final uid = r['user_id'].toString();
        periodVotes[uid] = (periodVotes[uid] ?? 0) + (r['helpful_votes'] as int? ?? 0);
      }

      List<Map<String, dynamic>> activeCritics = [];
      if (periodVotes.isNotEmpty) {
        var sortedUids = periodVotes.keys.toList()
          ..sort((a, b) => periodVotes[b]!.compareTo(periodVotes[a]!));
        
        final usersResp = await _supabase
            .from('users')
            .select('*')
            .inFilter('id', sortedUids.take(100).toList());
        
        activeCritics = (usersResp as List).map((u) {
          final user = Map<String, dynamic>.from(u);
          final votes = periodVotes[user['id']] ?? 0;
          return {
            ...user,
            'helpful_votes': votes,
            'rank_score': votes * _getTierMultiplier(user['tier']?.toString() ?? 'explorer'),
          };
        }).toList()..sort((a, b) => (b['rank_score'] as int).compareTo(a['rank_score'] as int));
      }

      // FILLER LOGIC: If less than 10, fill from All-Time
      if (activeCritics.length < 10) {
        final allTime = await getTopCritics(filter: 'alltime');
        for (var c in allTime) {
          if (activeCritics.length >= 10) break;
          if (!activeCritics.any((active) => active['id'] == c['id'])) {
            activeCritics.add(c);
          }
        }
      }

      return activeCritics;
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
