import 'package:supabase_flutter/supabase_flutter.dart';

/// 2.4 Tier Upgrade Logic
/// Owner: Kamonashish Dutta Hemel
/// Runs after every helpful vote is received.
/// Checks if the reviewer has crossed a tier threshold and upgrades accordingly.
///
/// Thresholds:
/// Explorer  → Expert   : 50  helpful votes
/// Expert    → Diamond  : 200 helpful votes
/// Diamond   → Platinum : 500 helpful votes

class TierUpgradeApi {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Threshold map: current tier → votes needed to upgrade
  static const Map<String, int> _upgradeThresholds = {
    'explorer': 50,
    'expert': 200,
    'diamond': 500,
  };

  // Next tier map
  static const Map<String, String> _nextTier = {
    'explorer': 'expert',
    'expert': 'diamond',
    'diamond': 'platinum',
  };

  // ─────────────────────────────────────────────
  // MAIN: Check and apply tier upgrade if deserved
  // Called from review_api.dart after every voteReview()
  // ─────────────────────────────────────────────
  Future<void> checkUpgrade(String userId) async {
    // Step 1: Fetch current tier and helpful_votes for this user
    final userResponse = await _supabase
        .from('users')
        .select('tier, helpful_votes')
        .eq('id', userId)
        .single();

    final String currentTier = userResponse['tier'] as String;
    final int helpfulVotes = userResponse['helpful_votes'] as int;

    // Step 2: If already Platinum — no upgrade possible, stop here
    if (currentTier == 'platinum') return;

    // Step 3: Check if votes have crossed the threshold for next tier
    final int? threshold = _upgradeThresholds[currentTier];
    if (threshold == null) return;

    final bool shouldUpgrade = helpfulVotes >= threshold;
    if (!shouldUpgrade) return;

    // Step 4: Apply the upgrade
    final String newTier = _nextTier[currentTier]!;
    await _applyUpgrade(
      userId: userId,
      oldTier: currentTier,
      newTier: newTier,
      votesAtUpgrade: helpfulVotes,
    );
  }

  // ─────────────────────────────────────────────
  // PRIVATE: Apply the tier upgrade
  // Updates users.tier and triggers notification hook
  // ─────────────────────────────────────────────
  Future<void> _applyUpgrade({
    required String userId,
    required String oldTier,
    required String newTier,
    required int votesAtUpgrade,
  }) async {
    // Step 1: Update tier in users table
    await _supabase
        .from('users')
        .update({'tier': newTier}).eq('id', userId);

    // Step 2: Build notification message based on new tier
    /*
    final String notificationMessage = _buildNotificationMessage(newTier);

    // ── MEMBER 3 HOOK — Push Notification ─────────────────────────────────
    // TODO (Member 3): Call NotificationService.send(
    //   userId: userId,
    //   type: 'tier_upgrade',
    //   title: 'You've been upgraded!',
    //   body: notificationMessage,
    // )
    // Member 3 owns the push notification service (FCM)
    // This runs after tier is updated in DB
    print('[TierUpgradeApi] Notification to send: $notificationMessage');
    // ──────────────────────────────────────────────────────────────────────

    // ── REWARDS HOOK ──────────────────────────────────────────────────────
    // TODO (later): Unlock rewards for new tier
    // await RewardsApi.unlockRewardsForTier(userId: userId, tier: newTier);
    // Skipped for now — rewards system owned by Member 3
    // ──────────────────────────────────────────────────────────────────────
  }

  // ─────────────────────────────────────────────
  // PRIVATE: Build notification message per tier
  // ─────────────────────────────────────────────
  String _buildNotificationMessage(String newTier) {
    switch (newTier) {
      case 'expert':
        return "You've reached Expert! Discount rewards are now unlocked.";
      case 'diamond':
        return "You've reached Diamond! New rewards and free items unlocked.";
      case 'platinum':
        return "You've reached Platinum! VIP access and top rewards unlocked.";
      default:
        return "You've been upgraded to ${newTier[0].toUpperCase()}${newTier.substring(1)}!";
    }
    */

  }



  // ─────────────────────────────────────────────
  // PUBLIC: Get current tier info for a user
  // Returns tier, helpful_votes, and votes needed for next upgrade
  // Useful for the progress bar shown on the reviewer profile screen
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getTierInfo(String userId) async {
    final userResponse = await _supabase
        .from('users')
        .select('tier, helpful_votes')
        .eq('id', userId)
        .single();

    final String currentTier = userResponse['tier'] as String;
    final int helpfulVotes = userResponse['helpful_votes'] as int;

    // Calculate votes needed for next upgrade
    final int? threshold = _upgradeThresholds[currentTier];
    final String? next = _nextTier[currentTier];

    return {
      'current_tier': currentTier,
      'helpful_votes': helpfulVotes,
      'next_tier': next ?? 'none', // null means already Platinum
      'votes_needed': threshold != null
          ? (threshold - helpfulVotes).clamp(0, threshold)
          : 0, // already Platinum
      'threshold': threshold ?? 500,
    };
  }
}
