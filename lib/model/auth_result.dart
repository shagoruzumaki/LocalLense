import 'package:supabase_flutter/supabase_flutter.dart';

/// Result wrapper for all auth operations.
/// Every AuthService method returns this — never throws directly.
class AuthResult {
  final bool isSuccess;
  final String message;
  final User? user;
  final Session? session;

  AuthResult._({
    required this.isSuccess,
    required this.message,
    this.user,
    this.session,
  });

  factory AuthResult.success({
    String message = 'Success.',
    User? user,
    Session? session,
  }) {
    return AuthResult._(
      isSuccess: true,
      message: message,
      user: user,
      session: session,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(
      isSuccess: false,
      message: message,
    );
  }
}