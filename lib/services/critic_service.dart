import 'package:supabase_flutter/supabase_flutter.dart';

class CriticService {
  final _supabase = Supabase.instance.client;

  /// 3.3: GET /top10/critics
  /// Ranking formula: score = helpful_votes × tier_multiplier
  /// Platinum=4, Diamond=3, Expert=2, Explorer=1
  Future<List<Map<String, dynamic>>> fetchTopCritics() async {
    try {
      final response = await _supabase
          .from('users')
          .select('id, name, profile_photo_url, helpful_votes, tier')
          .eq('is_deleted', false)
          .order('helpful_votes', ascending: false)
          .limit(20); // Fetch more to calculate multiplier rankings

      final List critics = response as List;
      
      // Explicitly type the list as List<Map<String, dynamic>>
      final List<Map<String, dynamic>> rankedCritics = critics.map((c) {
        // Cast individual response items to Map<String, dynamic>
        final Map<String, dynamic> user = Map<String, dynamic>.from(c as Map);
        int multiplier = _getTierMultiplier(user['tier']?.toString() ?? 'explorer');
        
        return {
          ...user,
          'rank_score': (user['helpful_votes'] as int? ?? 0) * multiplier,
        };
      }).toList();

      // Sort descending by rank_score
      rankedCritics.sort((a, b) => (b['rank_score'] as int).compareTo(a['rank_score'] as int));
      
      // Return the top 10 as the correct type
      return rankedCritics.take(10).toList();
    } catch (e) {
      return []; // Return empty list on error
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
