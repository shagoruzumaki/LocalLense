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
          
          // If we have less than 10, fill with top rated fallback first
          if (results.length < 10) {
            final fallback = await _fetchTopRatedFallback();
            for (var r in fallback) {
              if (results.length >= 10) break;
              if (!results.any((ex) => ex.id == r.id)) {
                results.add(r);
              }
            }
          }
          
          // STRICT GLOBAL SORT: Prioritize Algorithm Score (which is reflected in the .rating getter)
          results.sort((a, b) => b.rating.compareTo(a.rating));
          
          return results.take(10).toList();
        });
  }

  /// Real-time stream for the Critics leaderboard.
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

  /// Period-based fetch (Week/Month) which requires aggregation
  Future<List<Restaurant>> getTop10Restaurants({String filter = 'alltime'}) async {
    try {
      List<Restaurant> results = [];
      
      if (filter == 'alltime') {
        final response = await _supabase
            .from('restaurants')
            .select('*')
            .eq('active', true);
        
        results = (response as List).map((json) => Restaurant.fromSupabase(json)).toList();
      } else {
        final days = filter == 'week' ? 7 : 30;
        final startDate = DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();

        final reviewsResp = await _supabase
            .from('reviews')
            .select('restaurant_id')
            .gte('created_at', startDate);
        
        final reviews = reviewsResp as List;
        
        if (reviews.isEmpty) {
          // If no recent activity, fallback to the all-time list
          return await getTop10Restaurants(filter: 'alltime');
        } else {
          Set<String> recentIds = reviews.map((r) => r['restaurant_id'].toString()).toSet();
          final restaurantsResp = await _supabase
              .from('restaurants')
              .select('*')
              .inFilter('id', recentIds.toList())
              .eq('active', true);
              
          results = (restaurantsResp as List).map((j) => Restaurant.fromSupabase(j)).toList();
        }
      }

      // If we don't have enough results for a Top 10, fill from general top rated
      if (results.length < 10) {
        final fallback = await _fetchTopRatedFallback();
        for (var r in fallback) {
          if (results.length >= 10) break;
          if (!results.any((ex) => ex.id == r.id)) {
            results.add(r);
          }
        }
      }

      // FINAL GLOBAL SORT: This ensures #1 is always the highest rating/score
      results.sort((a, b) => b.rating.compareTo(a.rating));
      
      return results.take(10).toList();
    } catch (e) {
      return await _fetchTopRatedFallback();
    }
  }

  /// Helper to fetch high-quality restaurants for fill-ins
  Future<List<Restaurant>> _fetchTopRatedFallback() async {
    try {
      final response = await _supabase
          .from('restaurants')
          .select('*')
          .eq('active', true)
          .order('rating', ascending: false)
          .limit(20);
      
      return (response as List).map((json) => Restaurant.fromSupabase(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTop10Critics({String filter = 'alltime'}) async {
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

  int _getTierMultiplier(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum': return 4;
      case 'diamond': return 3;
      case 'expert': return 2;
      default: return 1;
    }
  }
}
