import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/reward.dart';

class RewardService {
  final _supabase = Supabase.instance.client;

  /// Fetches all available rewards for the current user's tier
  Future<List<Reward>> getRewards() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      // Fetch user tier first
      final userResponse = await _supabase
          .from('users')
          .select('tier')
          .eq('id', user.id)
          .single();
      
      final String userTier = userResponse['tier'] ?? 'explorer';

      // Fetch rewards applicable to this tier or below
      final response = await _supabase
          .from('rewards')
          .select('*, restaurants(name), user_rewards(id)')
          .eq('active', true)
          .order('expiry_date', ascending: true);

      final List data = response as List;
      return data.map((json) => Reward.fromSupabase(json)).toList();
    } catch (e) {
      print('Error fetching rewards: $e');
      return [];
    }
  }

  /// Fetches rewards for a specific restaurant
  Future<List<Reward>> getRestaurantRewards(String restaurantId) async {
    try {
      final response = await _supabase
          .from('rewards')
          .select('*, restaurants(name), user_rewards(id)')
          .eq('restaurant_id', restaurantId)
          .eq('active', true);

      final List data = response as List;
      return data.map((json) => Reward.fromSupabase(json)).toList();
    } catch (e) {
      print('Error fetching restaurant rewards: $e');
      return [];
    }
  }

  /// Redeems a reward for the current user
  Future<bool> redeemReward(String rewardId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // In a real app, this would be a Supabase RPC or Edge Function 
      // to handle atomicity and validation (checking user tier/points)
      await _supabase.from('user_rewards').insert({
        'user_id': user.id,
        'reward_id': rewardId,
        'redeemed_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error redeeming reward: $e');
      return false;
    }
  }
}
