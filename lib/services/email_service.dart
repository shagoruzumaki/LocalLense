import 'package:supabase_flutter/supabase_flutter.dart';

/// LocalLens Email Service
/// Calls the Supabase Edge Function 'send-email'
/// Verification + password reset emails are handled
/// automatically by Supabase Auth — no code needed for those.
/// This service handles: verification approved/rejected, tier upgrade.
/// Member 1 — Ismail Hossain Shagor

class EmailService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────
  // PRIVATE — calls the edge function
  // ─────────────────────────────────────────────
  Future<EmailResult> _sendEmail({
    required String type,
    required String toEmail,
    required String userName,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-email',
        body: {
          'type': type,
          'to': toEmail,
          'userName': userName,
          if (data != null) 'data': data,
        },
      );

      return EmailResult.success();
    } on FunctionException catch (e) {
      return EmailResult.failure('Email failed: ${e.details}');
    } catch (e) {
      return EmailResult.failure('Failed to send email.');
    }
  }

  // ─────────────────────────────────────────────
  // Verification approved email
  // Called from: verification_service.dart → approveVerification()
  // "Your account is now verified. Badge added to profile."
  // ─────────────────────────────────────────────
  Future<EmailResult> sendVerificationApproved({
    required String toEmail,
    required String userName,
  }) async {
    return _sendEmail(
      type: 'verification_approved',
      toEmail: toEmail,
      userName: userName,
    );
  }

  // ─────────────────────────────────────────────
  // Verification rejected email with reason
  // Called from: verification_service.dart → rejectVerification()
  // ─────────────────────────────────────────────
  Future<EmailResult> sendVerificationRejected({
    required String toEmail,
    required String userName,
    required String rejectionReason,
  }) async {
    return _sendEmail(
      type: 'verification_rejected',
      toEmail: toEmail,
      userName: userName,
      data: {'reason': rejectionReason},
    );
  }

  // ─────────────────────────────────────────────
  // Tier upgrade email
  // Called from: Member 2's tier upgrade logic
  // ─────────────────────────────────────────────
  Future<EmailResult> sendTierUpgrade({
    required String toEmail,
    required String userName,
    required String newTier, // 'expert' | 'diamond' | 'platinum'
  }) async {
    return _sendEmail(
      type: 'tier_upgrade',
      toEmail: toEmail,
      userName: userName,
      data: {'newTier': newTier},
    );
  }

// ─────────────────────────────────────────────
// NOTE: These are handled AUTOMATICALLY by Supabase Auth
// You do NOT need to code these manually:
//
// ✅ Email verification link on registration
//    → Supabase sends this when user signs up
//    → Customize template in: Auth → Email Templates → Confirm signup
//
// ✅ Password reset link (expires 1 hour)
//    → Supabase sends this on forgotPassword()
//    → Customize template in: Auth → Email Templates → Reset password
// ─────────────────────────────────────────────
}


// ─────────────────────────────────────────────
// RESULT WRAPPER
// ─────────────────────────────────────────────
class EmailResult {
  final bool isSuccess;
  final String message;

  EmailResult._({required this.isSuccess, required this.message});

  factory EmailResult.success() =>
      EmailResult._(isSuccess: true, message: 'Email sent.');

  factory EmailResult.failure(String message) =>
      EmailResult._(isSuccess: false, message: message);
}