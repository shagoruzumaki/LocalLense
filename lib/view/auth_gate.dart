import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AuthGate — sits at the root of the app.
/// Listens to Supabase auth state and routes accordingly.
/// Also handles the deep link for password reset.
class AuthGate extends StatefulWidget {
  final Widget homeScreen;
  final Widget loginScreen;
  final Widget resetPasswordScreen;

  const AuthGate({
    super.key,
    required this.homeScreen,
    required this.loginScreen,
    required this.resetPasswordScreen,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        final event = snapshot.data?.event;

        // User clicked password reset link — show reset screen
        if (event == AuthChangeEvent.passwordRecovery) {
          return widget.resetPasswordScreen;
        }

        // User is logged in — show home
        if (session != null) {
          return widget.homeScreen;
        }

        // Not logged in — show login
        return widget.loginScreen;
      },
    );
  }
}