import 'package:supabase_flutter/supabase_flutter.dart';

/// 3.1 & 3.2: User Management Service
class UserService {
  final _supabase = Supabase.instance.client;

  String get _currentUserId => _supabase.auth.currentUser!.id;

  /// GET /users/:id
  Future<UserResult> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('*, reviews(count)')
          .eq('id', userId)
          .eq('is_deleted', false)
          .single();

      return UserResult.success(data: response);
    } catch (e) {
      return UserResult.failure('User not found.');
    }
  }

  /// PATCH /users/:id
  Future<UserResult> updateProfile({
    String? name,
    String? bio,
    String? profilePhotoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name.trim();
      if (bio != null) updates['bio'] = bio.trim();
      if (profilePhotoUrl != null) updates['profile_photo_url'] = profilePhotoUrl;

      if (updates.isEmpty) return UserResult.failure('No changes provided.');

      final response = await _supabase
          .from('users')
          .update(updates)
          .eq('id', _currentUserId)
          .select()
          .single();

      return UserResult.success(data: response, message: 'Profile updated.');
    } catch (e) {
      return UserResult.failure('Failed to update profile.');
    }
  }

  /// 3.3: GET /top10/critics
  Future<UserResult> getTopCritics() async {
    try {
      final List response = await _supabase
          .from('users')
          .select('id, name, tier, helpful_votes, profile_photo_url')
          .eq('is_deleted', false)
          .order('helpful_votes', ascending: false)
          .limit(20); // Fetch more to apply multiplier locally

      final tierMultipliers = {'platinum': 4, 'diamond': 3, 'expert': 2, 'explorer': 1};

      final ranked = response.map((u) {
        final multiplier = tierMultipliers[u['tier']?.toString().toLowerCase()] ?? 1;
        return {
          ...u,
          'ranking_score': (u['helpful_votes'] as int? ?? 0) * multiplier,
        };
      }).toList();

      ranked.sort((a, b) => (b['ranking_score'] as int).compareTo(a['ranking_score'] as int));

      return UserResult.success(data: {'critics': ranked.take(10).toList()});
    } catch (e) {
      return UserResult.failure('Failed to load top critics.');
    }
  }

  Future<UserResult> deleteAccount() async {
    try {
      await _supabase.from('users').update({'is_deleted': true}).eq('id', _currentUserId);
      await _supabase.auth.signOut();
      return UserResult.success(message: 'Account deleted.');
    } catch (e) {
      return UserResult.failure('Deletion failed.');
    }
  }
}

class UserResult {
  final bool isSuccess;
  final String message;
  final Map<String, dynamic>? data;
  UserResult._({required this.isSuccess, required this.message, this.data});
  factory UserResult.success({Map<String, dynamic>? data, String message = 'Success'}) =>
      UserResult._(isSuccess: true, message: message, data: data);
  factory UserResult.failure(String message) => UserResult._(isSuccess: false, message: message);
}
