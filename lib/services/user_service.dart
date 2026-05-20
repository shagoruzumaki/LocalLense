import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

/// LocalLens User Management Service
/// Covers: GET profile, PATCH profile, GET reviews,
///         GET visited, GET rewards, GET top critics, DELETE account
/// Member 1 — Ismail Hossain Shagor

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────
  // HELPER — current logged in user's ID
  // ─────────────────────────────────────────────
  String get _currentUserId => _supabase.auth.currentUser!.id;

  // ─────────────────────────────────────────────
  // GET /users/:id
  // Public profile — name, tier, verified badge,
  // review count, helpful votes
  // Used by: profile_page.dart, reviewer_profile_page.dart
  // ─────────────────────────────────────────────
  Future<UserResult> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('''
            id,
            name,
            tier,
            verified,
            helpful_votes,
            profile_photo_url,
            bio,
            created_at
          ''')
          .eq('id', userId)
          .eq('is_deleted', false)
          .single();

      // Also get review count separately
      final reviewCount = await _supabase
          .from('reviews')
          .select('id')
          .eq('user_id', userId);

      final data = {
        ...response,
        'review_count': reviewCount.length,
      };

      return UserResult.success(data: data);
    } catch (e) {
      return UserResult.failure('User not found.');
    }
  }

  // ─────────────────────────────────────────────
  // PATCH /users/:id
  // Update own profile — name, bio, profile photo
  // Auth required — can only update own profile
  // Used by: profile_page.dart (edit mode)
  // ─────────────────────────────────────────────
  Future<UserResult> updateProfile({
    String? name,
    String? bio,
    String? profilePhotoUrl,
  }) async {
    try {
      // Build only the fields that were passed
      final updates = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) updates['name'] = name.trim();
      if (bio != null) updates['bio'] = bio.trim();
      if (profilePhotoUrl != null) updates['profile_photo_url'] = profilePhotoUrl;

      if (updates.isEmpty) {
        return UserResult.failure('No changes to update.');
      }

      final response = await _supabase
          .from('users')
          .update(updates)
          .eq('id', _currentUserId)
          .select()
          .single();

      return UserResult.success(
        data: response,
        message: 'Profile updated successfully.',
      );
    } catch (e) {
      return UserResult.failure('Failed to update profile.');
    }
  }

  // ─────────────────────────────────────────────
  // POST /upload/profile-photo (File Storage)
  // Upload profile photo to Supabase Storage
  // Returns the CDN URL to save in users table
  // Used by: profile_page.dart (edit mode)
  // ─────────────────────────────────────────────
  Future<UserResult> uploadProfilePhoto(List<int> fileBytes, String fileName) async {
    try {
      final filePath = 'avatars/$_currentUserId/$fileName';

      await _supabase.storage
          .from('profile-photos')
          .uploadBinary(
        filePath,
        Uint8List.fromList(fileBytes),
        fileOptions: const FileOptions(
          upsert: true, // overwrite if exists
          contentType: 'image/webp',
        ),
      );

      // Get public CDN URL
      final publicUrl = _supabase.storage
          .from('profile-photos')
          .getPublicUrl(filePath);

      // Save URL to users table
      return await updateProfile(profilePhotoUrl: publicUrl);
    } catch (e) {
      return UserResult.failure('Failed to upload photo.');
    }
  }

  // ─────────────────────────────────────────────
  // GET /users/:id/reviews
  // All reviews by a user — paginated 20 per page
  // Sorted by newest first
  // Used by: profile_page.dart (Reviews tab)
  // ─────────────────────────────────────────────
  Future<UserResult> getUserReviews(
      String userId, {
        int page = 1,
        int pageSize = 20,
      }) async {
    try {
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;

      final response = await _supabase
          .from('reviews')
          .select('''
            id,
            mood_tag,
            rating,
            photos,
            dish_mentions,
            body,
            helpful_votes,
            created_at,
            restaurants (
              id,
              name,
              category,
              photos
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);

      return UserResult.success(data: {'reviews': response, 'page': page});
    } catch (e) {
      return UserResult.failure('Failed to load reviews.');
    }
  }

  // ─────────────────────────────────────────────
  // GET /users/:id/visited
  // Places the user has reviewed (unique restaurants)
  // Used by: profile_page.dart (Visited tab)
  // ─────────────────────────────────────────────
  Future<UserResult> getVisitedPlaces(String userId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('''
            restaurants (
              id,
              name,
              category,
              address,
              photos,
              algorithm_score,
              price_tier
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // De-duplicate restaurants (user may have reviewed same place twice)
      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (final row in response) {
        final restaurant = row['restaurants'] as Map<String, dynamic>;
        final id = restaurant['id'] as String;
        if (seen.add(id)) {
          unique.add(restaurant);
        }
      }

      return UserResult.success(data: {'visited': unique});
    } catch (e) {
      return UserResult.failure('Failed to load visited places.');
    }
  }

  // ─────────────────────────────────────────────
  // GET /users/:id/rewards
  // Active and redeemed rewards for logged-in user
  // Used by: profile_page.dart (Rewards tab)
  // ─────────────────────────────────────────────
  Future<UserResult> getUserRewards() async {
    try {
      final response = await _supabase
          .from('user_rewards')
          .select('''
            id,
            redeemed,
            redeemed_at,
            assigned_at,
            rewards (
              id,
              type,
              value,
              description,
              expiry_date,
              tier_required,
              restaurants (
                id,
                name,
                photos
              )
            )
          ''')
          .eq('user_id', _currentUserId)
          .order('assigned_at', ascending: false);

      // Split into active and redeemed
      final active = response.where((r) => r['redeemed'] == false).toList();
      final redeemed = response.where((r) => r['redeemed'] == true).toList();

      return UserResult.success(data: {
        'active': active,
        'redeemed': redeemed,
      });
    } catch (e) {
      return UserResult.failure('Failed to load rewards.');
    }
  }

  // ─────────────────────────────────────────────
  // GET /users/top-critics
  // Top 10 critics sorted by helpful_votes × tier multiplier
  // Used by: ranking_page.dart
  // ─────────────────────────────────────────────
  Future<UserResult> getTopCritics() async {
    try {
      final response = await _supabase
          .from('users')
          .select('''
            id,
            name,
            tier,
            verified,
            helpful_votes,
            profile_photo_url
          ''')
          .eq('is_deleted', false)
          .eq('is_banned', false)
          .order('helpful_votes', ascending: false)
          .limit(10);

      // Apply tier multiplier for final ranking score display
      // Platinum=4x, Diamond=3x, Expert=2x, Explorer=1x
      final tierMultipliers = {
        'platinum': 4,
        'diamond': 3,
        'expert': 2,
        'explorer': 1,
      };

      final ranked = response.map((user) {
        final multiplier = tierMultipliers[user['tier']] ?? 1;
        return {
          ...user,
          'ranking_score': (user['helpful_votes'] as int) * multiplier,
        };
      }).toList();

      // Sort by ranking score descending
      ranked.sort((a, b) =>
          (b['ranking_score'] as int).compareTo(a['ranking_score'] as int));

      return UserResult.success(data: {'critics': ranked});
    } catch (e) {
      return UserResult.failure('Failed to load top critics.');
    }
  }

  // ─────────────────────────────────────────────
  // GET /users/top-critics/month
  // Top critics for current calendar month only
  // Used by: ranking_page.dart (month filter)
  // ─────────────────────────────────────────────
  Future<UserResult> getTopCriticsThisMonth() async {
    try {
      // Get start of current month
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

      // Get users who reviewed this month + their helpful vote count this month
      final response = await _supabase
          .from('reviews')
          .select('''
            user_id,
            helpful_votes,
            users (
              id,
              name,
              tier,
              verified,
              profile_photo_url
            )
          ''')
          .gte('created_at', startOfMonth);

      // Aggregate helpful_votes per user for this month
      final Map<String, Map<String, dynamic>> userMap = {};
      for (final row in response) {
        final userId = row['user_id'] as String;
        final user = row['users'] as Map<String, dynamic>;
        final votes = row['helpful_votes'] as int;

        if (userMap.containsKey(userId)) {
          userMap[userId]!['monthly_votes'] =
              (userMap[userId]!['monthly_votes'] as int) + votes;
        } else {
          userMap[userId] = {
            ...user,
            'monthly_votes': votes,
          };
        }
      }

      // Apply tier multiplier and sort
      final tierMultipliers = {
        'platinum': 4,
        'diamond': 3,
        'expert': 2,
        'explorer': 1,
      };

      final ranked = userMap.values.map((user) {
        final multiplier = tierMultipliers[user['tier']] ?? 1;
        return {
          ...user,
          'ranking_score': (user['monthly_votes'] as int) * multiplier,
        };
      }).toList();

      ranked.sort((a, b) =>
          (b['ranking_score'] as int).compareTo(a['ranking_score'] as int));

      return UserResult.success(data: {'critics': ranked.take(10).toList()});
    } catch (e) {
      return UserResult.failure('Failed to load monthly top critics.');
    }
  }

  // ─────────────────────────────────────────────
  // DELETE /users/:id
  // Soft-delete own account (sets is_deleted = true)
  // Auth required
  // ─────────────────────────────────────────────
  Future<UserResult> deleteAccount() async {
    try {
      // Soft delete in public.users
      await _supabase
          .from('users')
          .update({'is_deleted': true})
          .eq('id', _currentUserId);

      // Sign out from Supabase Auth
      await _supabase.auth.signOut();

      return UserResult.success(message: 'Account deleted successfully.');
    } catch (e) {
      return UserResult.failure('Failed to delete account.');
    }
  }
}


// ─────────────────────────────────────────────
// RESULT WRAPPER
// ─────────────────────────────────────────────
class UserResult {
  final bool isSuccess;
  final String message;
  final Map<String, dynamic>? data;

  UserResult._({
    required this.isSuccess,
    required this.message,
    this.data,
  });

  factory UserResult.success({
    Map<String, dynamic>? data,
    String message = 'Success.',
  }) {
    return UserResult._(isSuccess: true, message: message, data: data);
  }

  factory UserResult.failure(String message) {
    return UserResult._(isSuccess: false, message: message);
  }
}