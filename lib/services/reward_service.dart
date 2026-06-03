import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/reward.dart';

/// 3.4: Rewards System API implementation
class RewardService {
  final _supabase = Supabase.instance.client;

  /// GET /rewards
  /// Returns rewards with restaurant names. 
  /// Logic: Shows all active rewards; UI handles the "Locked" status based on userTier.
  Future<List<Reward>> fetchAllRewards() async {
    try {
      final List response = await _supabase
          .from('rewards')
          .select('*, restaurants(name)')
          .eq('active', true);
      
      return response.map((json) => Reward.fromSupabase(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// GET /restaurants/:id/rewards
  Future<List<Reward>> fetchRewardsByRestaurant(String restaurantId) async {
    try {
      final List response = await _supabase
          .from('rewards')
          .select('*, restaurants(name)')
          .eq('restaurant_id', restaurantId)
          .eq('active', true);
      
      return response.map((json) => Reward.fromSupabase(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// POST /rewards/:id/redeem
  /// Mark as redeemed. Validates one-time redemption.
  Future<bool> redeemReward(String rewardId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Mark as redeemed in user_rewards join table
      await _supabase.from('user_rewards').insert({
        'reward_id': rewardId,
        'user_id': userId,
        'redeemed_at': DateTime.now().toUtc().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }
}
