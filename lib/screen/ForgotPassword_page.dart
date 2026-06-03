import 'package:flutter/material.dart';
import '../services/auth_services.dart';
import '../model/auth_result.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;

  // ── Brand colours (same as your login page) ──
  static const _bgColor = Color(0xFF1A1200);
  static const _cardColor = Color(0xFF2A1F00);
  static const _yellowColor = Color(0xFFFFD000);
  static const _hintColor = Color(0xFF8A7A50);
  static const _textColor = Colors.white;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final AuthResult result = await _authService.forgotPassword(
      email: _emailController.text,
    );

    setState(() {
      _isLoading = false;
      _emailSent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _emailSent ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),

          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: _textColor, size: 20),
          ),
          const SizedBox(height: 40),

          // Title
          const Text(
            'Forgot Password',
            style: TextStyle(
              color: _textColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your email and we\'ll send you a reset link.',
            style: TextStyle(color: _hintColor, fontSize: 15),
          ),
          const SizedBox(height: 40),

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: _textColor),
            decoration: InputDecoration(
              hintText: 'Email',
              hintStyle: const TextStyle(color: _hintColor),
              prefixIcon: const Icon(Icons.email_outlined, color: _hintColor),
              filled: true,
              fillColor: _cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _yellowColor, width: 1.5),
              ),
              errorStyle: const TextStyle(color: Colors.redAccent),
            ),
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Email is required' : null,
          ),
          const SizedBox(height: 32),

          // Send Reset Link button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendResetEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: _yellowColor,
                foregroundColor: Colors.black,
                disabledBackgroundColor: _yellowColor.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.black,
                ),
              )
                  : const Text(
                'SEND RESET LINK',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Back to login
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: RichText(
                text: const TextSpan(
                  text: 'Remember your password? ',
                  style: TextStyle(color: _hintColor, fontSize: 14),
                  children: [
                    TextSpan(
                      text: 'Sign In',
                      style: TextStyle(
                        color: _yellowColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 48),

        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios, color: _textColor, size: 20),
        ),
        const SizedBox(height: 80),

        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _yellowColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: _yellowColor,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 32),

        const Center(
          child: Text(
            'Check Your Email',
            style: TextStyle(
              color: _textColor,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),

        const Center(
          child: Text(
            'If that email exists, a reset link has been sent.\nCheck your inbox and spam folder.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _hintColor, fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 48),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _yellowColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'BACK TO SIGN IN',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}