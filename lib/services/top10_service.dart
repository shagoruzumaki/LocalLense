import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/restaurant.dart';

class Top10Service {
  final _supabase = Supabase.instance.client;

  /// Real-time stream for the All-Time restaurant leaderboard.
  Stream<List<Restaurant>> getTop10RestaurantsStream() {
    return _supabase
        .from('restaurants')
        .stream(primaryKey: ['id'])
        .eq('active', true)
        .asyncMap((data) async {
          List<Restaurant> results = data.map((json) => Restaurant.fromSupabase(json)).toList();
          results.sort((a, b) => b.rating.compareTo(a.rating));
          
          if (results.length < 10) {
            final fallback = await _fetchTopRatedFallback(limit: 20);
            for (var r in fallback) {
              if (results.length >= 10) break;
              if (!results.any((ex) => ex.id == r.id)) {
                results.add(r);
              }
            }
            results.sort((a, b) => b.rating.compareTo(a.rating));
          }
          return results.take(10).toList();
        });
  }

  /// Real-time stream for the Critics leaderboard (Lifetime).
  Stream<List<Map<String, dynamic>>> getTop10CriticsStream() {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .order('helpful_votes', ascending: false)
        .limit(10)
        .map((data) {
          return data.map((u) {
            final user = Map<String, dynamic>.from(u);
            int multiplier = _getTierMultiplier(user['tier']?.toString() ?? 'explorer');
            return {
              ...user,
              'rank_score': (user['helpful_votes'] as int? ?? 0) * multiplier,
            };
          }).toList();
        });
  }

  /// Period-based fetch (Week/Month) for Restaurants
  Future<List<Restaurant>> getTop10Restaurants({String filter = 'alltime'}) async {
    try {
      if (filter == 'alltime') {
        final response = await _supabase
            .from('restaurants')
            .select('*')
            .eq('active', true)
            .order('algorithm_score', ascending: false)
            .limit(20);
        
        List<Restaurant> results = (response as List).map((json) => Restaurant.fromSupabase(json)).toList();
        results.sort((a, b) => b.rating.compareTo(a.rating));
        return results.take(10).toList();
      }

      // ── PERIOD RANKING LOGIC ──
      final days = filter == 'week' ? 7 : 30;
      final startDate = DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();

      final reviewsResp = await _supabase
          .from('reviews')
          .select('restaurant_id, rating')
          .gte('created_at', startDate);
      
      final reviews = reviewsResp as List;
      if (reviews.isEmpty) return await getTop10Restaurants(filter: 'alltime');

      // Aggregate: Calculate average rating for this period
      Map<String, List<double>> periodRatings = {};
      for (var r in reviews) {
        final id = r['restaurant_id'].toString();
        periodRatings.putIfAbsent(id, () => []).add((r['rating'] as num).toDouble());
      }

      // Sort IDs by period average
      var sortedIds = periodRatings.keys.toList();
      sortedIds.sort((a, b) {
        double avgA = periodRatings[a]!.reduce((v, e) => v + e) / periodRatings[a]!.length;
        double avgB = periodRatings[b]!.reduce((v, e) => v + e) / periodRatings[b]!.length;
        return avgB.compareTo(avgA);
      });

      final restaurantsResp = await _supabase
          .from('restaurants')
          .select('*')
          .inFilter('id', sortedIds.take(20).toList())
          .eq('active', true);
          
      List<Restaurant> results = (restaurantsResp as List).map((j) => Restaurant.fromSupabase(j)).toList();
      
      // Ensure exactly 10
      if (results.length < 10) {
        final global = await _fetchTopRatedFallback(limit: 20);
        for (var r in global) {
          if (results.length >= 10) break;
          if (!results.any((ex) => ex.id == r.id)) results.add(r);
        }
      }

      results.sort((a, b) => b.rating.compareTo(a.rating));
      return results.take(10).toList();
    } catch (e) {
      return await _fetchTopRatedFallback(limit: 10);
    }
  }

  /// Period-based fetch (Week/Month) for Critics
  Future<List<Map<String, dynamic>>> getTop10Critics({String filter = 'alltime'}) async {
    try {
      if (filter == 'alltime') {
        final response = await _supabase
            .from('profiles')
            .select('*')
            .order('helpful_votes', ascending: false)
            .limit(10);
        
        return (response as List).map((u) {
          final user = Map<String, dynamic>.from(u);
          return {
            ...user,
            'rank_score': (user['helpful_votes'] as int? ?? 0) * _getTierMultiplier(user['tier']?.toString() ?? 'explorer'),
          };
        }).toList();
      }

      // ── PERIOD LOGIC: Rank by helpful votes received in period ──
      final days = filter == 'week' ? 7 : 30;
      final startDate = DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();

      final response = await _supabase
          .from('reviews')
          .select('user_id, helpful_votes')
          .gte('created_at', startDate);
      
      final reviews = response as List;
      if (reviews.isEmpty) return await getTop10Critics(filter: 'alltime');

      Map<String, int> periodVotes = {};
      for (var r in reviews) {
        final uid = r['user_id'].toString();
        periodVotes[uid] = (periodVotes[uid] ?? 0) + (r['helpful_votes'] as int? ?? 0);
      }

      var topUids = periodVotes.keys.toList();
      topUids.sort((a, b) => periodVotes[b]!.compareTo(periodVotes[a]!));

      final profilesResp = await _supabase
          .from('profiles')
          .select('*')
          .inFilter('id', topUids.take(10).toList());
      
      return (profilesResp as List).map((u) {
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

  Future<List<Restaurant>> _fetchTopRatedFallback({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('restaurants')
          .select('*')
          .eq('active', true)
          .order('algorithm_score', ascending: false)
          .limit(limit);
      return (response as List).map((json) => Restaurant.fromSupabase(json)).toList();
    } catch (_) { return []; }
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
