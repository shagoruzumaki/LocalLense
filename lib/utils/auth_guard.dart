import 'package:supabase_flutter/supabase_flutter.dart';

/// LocalLens RBAC — Role Based Access Control
/// Checks user role before allowing access to admin features
/// Replaces Express RBAC middleware
/// Member 1 — Ismail Hossain Shagor

class AuthGuard {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────
  // Check if user is logged in
  // Use this before any protected action
  // ─────────────────────────────────────────────
  static bool get isLoggedIn => _supabase.auth.currentUser != null;

  static String? get currentUserId => _supabase.auth.currentUser?.id;

  // ─────────────────────────────────────────────
  // Check if the current user is an admin
  // Admin role is stored in Supabase Auth metadata
  // Set via Supabase dashboard or service role key
  // ─────────────────────────────────────────────
  static bool get isAdmin {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final role = user.appMetadata['role'];
    return role == 'admin';
  }

  // ─────────────────────────────────────────────
  // Check user's tier from public.users table
  // ─────────────────────────────────────────────
  static Future<String?> getUserTier() async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      final response = await _supabase
          .from('users')
          .select('tier')
          .eq('id', userId)
          .single();

      return response['tier'] as String?;
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // Check if user meets minimum tier requirement
  // Used for reward redemption and tier-locked features
  // tierOrder: explorer(0) < expert(1) < diamond(2) < platinum(3)
  // ─────────────────────────────────────────────
  static Future<bool> meetsMinTier(String requiredTier) async {
    final tierOrder = {
      'explorer': 0,
      'expert': 1,
      'diamond': 2,
      'platinum': 3,
    };

    final userTier = await getUserTier();
    if (userTier == null) return false;

    final userLevel = tierOrder[userTier] ?? 0;
    final requiredLevel = tierOrder[requiredTier] ?? 99;

    return userLevel >= requiredLevel;
  }

  // ─────────────────────────────────────────────
  // Require login — call this at the top of any
  // service method that needs authentication
  // Returns error message if not logged in, null if OK
  // ─────────────────────────────────────────────
  static String? requireLogin() {
    if (!isLoggedIn) return 'Please log in to continue.';
    return null;
  }

  // ─────────────────────────────────────────────
  // Require admin — call this before any admin action
  // Returns error message if not admin, null if OK
  // ─────────────────────────────────────────────
  static String? requireAdmin() {
    if (!isLoggedIn) return 'Please log in to continue.';
    if (!isAdmin) return 'You do not have permission to do this.';
    return null;
  }

  // ─────────────────────────────────────────────
  // Require ownership — check if current user owns
  // the resource (review, profile, etc.)
  // ─────────────────────────────────────────────
  static String? requireOwnership(String resourceOwnerId) {
    if (!isLoggedIn) return 'Please log in to continue.';
    if (currentUserId != resourceOwnerId && !isAdmin) {
      return 'You do not have permission to modify this.';
    }
    return null;
  }
}