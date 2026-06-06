import 'package:flutter/foundation.dart';
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
      
      // Define tier hierarchy for filtering
      final tiers = ['explorer', 'local', 'elite'];
      final userTierIndex = tiers.indexOf(userTier);
      final allowedTiers = userTierIndex == -1 
          ? ['explorer'] 
          : tiers.sublist(0, userTierIndex + 1);

      // Fetch rewards applicable to this tier or below
      // Fixed: 'in_' is now 'inFilter' in Supabase 2.x
      final response = await _supabase
          .from('rewards')
          .select('*, restaurants(name), user_rewards(id)')
          .inFilter('required_tier', allowedTiers)
          .eq('active', true)
          .order('expiry_date', ascending: true);

      final List data = response as List;
      return data.map((json) => Reward.fromSupabase(json)).toList();
    } catch (e) {
      debugPrint('Error fetching rewards: $e');
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
      debugPrint('Error fetching restaurant rewards: $e');
      return [];
    }
  }

  /// Fetches detailed info for a single reward, including QR code data
  Future<Reward?> getRewardDetail(String rewardId) async {
    try {
      final response = await _supabase
          .from('rewards')
          .select('*, restaurants(name), user_rewards(id)')
          .eq('id', rewardId)
          .single();

      return Reward.fromSupabase(response);
    } catch (e) {
      debugPrint('Error fetching reward detail: $e');
      return null;
    }
  }

  /// Redeems a reward for the current user with validation
  Future<bool> redeemReward(String rewardId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // 1. Validation: Check if already redeemed
      final existingRedemption = await _supabase
          .from('user_rewards')
          .select()
          .eq('user_id', user.id)
          .eq('reward_id', rewardId)
          .maybeSingle();

      if (existingRedemption != null) {
        debugPrint('Reward already redeemed');
        return false;
      }

      // 2. Validation: Check tier requirements
      final reward = await getRewardDetail(rewardId);
      if (reward == null) return false;

      final userResponse = await _supabase
          .from('users')
          .select('tier')
          .eq('id', user.id)
          .single();
      
      final String userTier = userResponse['tier'] ?? 'explorer';
      final tiers = ['explorer', 'local', 'elite'];
      
      if (tiers.indexOf(userTier) < tiers.indexOf(reward.requiredTier)) {
        debugPrint('Insufficient tier for this reward');
        return false;
      }

      // 3. Insert redemption record
      await _supabase.from('user_rewards').insert({
        'user_id': user.id,
        'reward_id': rewardId,
        'redeemed_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('Error redeeming reward: $e');
      return false;
    }
  }
}
