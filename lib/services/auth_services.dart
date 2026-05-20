import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_lense/model/auth_result.dart';

/// LocalLens Auth Service
/// Covers: register, login, logout, refresh, forgot password,
///         reset password, verify email
/// Member 1 — Ismail Hossain Shagor

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────
  // CURRENT USER HELPERS
  // ─────────────────────────────────────────────

  /// Returns the currently logged-in user, or null
  User? get currentUser => _supabase.auth.currentUser;

  /// Returns true if a user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Stream that emits auth state changes (login, logout, token refresh)
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // ─────────────────────────────────────────────
  // POST /auth/register
  // ─────────────────────────────────────────────

  /// Register a new user with email and password.
  /// - Validates password policy (min 8 chars, 1 uppercase, 1 number)
  /// - Supabase sends a verification email automatically
  /// - Trigger in DB auto-inserts into public.users table
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    // Password policy: min 8 chars, 1 uppercase, 1 number
    final policyError = _validatePassword(password);
    if (policyError != null) {
      return AuthResult.failure(policyError);
    }

    try {
      final response = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'name': name.trim()}, // stored in raw_user_meta_data
        // trigger reads this to populate public.users
      );

      if (response.user == null) {
        return AuthResult.failure('Registration failed. Please try again.');
      }

      return AuthResult.success(
        user: response.user!,
        message: 'Account created! Please check your email to verify your account.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred.');
    }
  }

  // ─────────────────────────────────────────────
  // POST /auth/login
  // ─────────────────────────────────────────────

  /// Login with email and password.
  /// Returns access token (15 min) + refresh token (7 days) automatically.
  /// Supabase handles token storage on device.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (response.user == null) {
        return AuthResult.failure('Invalid email or password.');
      }

      // Optional: check if email is verified
      if (response.user!.emailConfirmedAt == null) {
        return AuthResult.failure(
          'Please verify your email before logging in. Check your inbox.',
        );
      }

      return AuthResult.success(
        user: response.user!,
        session: response.session,
        message: 'Login successful.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred.');
    }
  }

  // ─────────────────────────────────────────────
  // POST /auth/logout
  // ─────────────────────────────────────────────

  /// Logout — invalidates the refresh token on Supabase server
  /// and clears the session from device storage.
  Future<AuthResult> logout() async {
    try {
      await _supabase.auth.signOut();
      return AuthResult.success(message: 'Logged out successfully.');
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('Logout failed. Please try again.');
    }
  }

  // ─────────────────────────────────────────────
  // POST /auth/refresh
  // ─────────────────────────────────────────────

  /// Refresh the access token using the stored refresh token.
  /// Supabase auto-refreshes tokens in the background — you normally
  /// don't need to call this manually. Use it only if you need to
  /// force a refresh (e.g. after a long background period).
  Future<AuthResult> refreshSession() async {
    try {
      final response = await _supabase.auth.refreshSession();

      if (response.session == null) {
        return AuthResult.failure('Session expired. Please log in again.');
      }

      return AuthResult.success(
        user: response.user,
        session: response.session,
        message: 'Session refreshed.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('Session refresh failed.');
    }
  }

  // ─────────────────────────────────────────────
  // POST /auth/forgot-password
  // ─────────────────────────────────────────────

  /// Send a password reset email.
  /// Link expires in 1 hour (configured in Supabase dashboard).
  Future<AuthResult> forgotPassword({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: 'locallens://reset-password', // deep link back to app
      );

      // Always return success (don't reveal if email exists — security best practice)
      return AuthResult.success(
        message: 'If that email exists, a reset link has been sent. Check your inbox.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('Failed to send reset email. Try again.');
    }
  }

  // ─────────────────────────────────────────────
  // POST /auth/reset-password
  // ─────────────────────────────────────────────

  /// Update password after user clicks the reset link.
  /// This is called AFTER Supabase redirects back to the app
  /// and the user is in a recovery session.
  /// Must validate password policy again.
  Future<AuthResult> resetPassword({required String newPassword}) async {
    final policyError = _validatePassword(newPassword);
    if (policyError != null) {
      return AuthResult.failure(policyError);
    }

    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user == null) {
        return AuthResult.failure('Password reset failed. Please try again.');
      }

      return AuthResult.success(
        user: response.user,
        message: 'Password updated successfully. Please log in.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('Password reset failed.');
    }
  }

  // ─────────────────────────────────────────────
  // POST /auth/verify-email
  // ─────────────────────────────────────────────

  /// Resend the email verification link if user didn't receive it.
  /// Supabase auto-verifies when user clicks the link — no manual
  /// token handling needed.
  Future<AuthResult> resendVerificationEmail({required String email}) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
      );

      return AuthResult.success(
        message: 'Verification email resent. Check your inbox.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('Failed to resend verification email.');
    }
  }

  // ─────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────

  /// Password policy: min 8 chars, at least 1 uppercase, at least 1 number
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least 1 uppercase letter.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least 1 number.';
    }
    return null; // valid
  }

  /// Map Supabase error messages to user-friendly strings
  String _mapAuthError(String message) {
    final msg = message.toLowerCase();

    if (msg.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('email already registered') || msg.contains('already been registered')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email before logging in.';
    }
    if (msg.contains('too many requests')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (msg.contains('token expired') || msg.contains('session expired')) {
      return 'Your session has expired. Please log in again.';
    }
    if (msg.contains('network')) {
      return 'Network error. Check your internet connection.';
    }

    return 'Something went wrong. Please try again.';
  }
}