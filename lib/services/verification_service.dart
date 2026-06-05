import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_service.dart';
import 'notification_service.dart';

/// 3.2 & 3.5: ID Verification & Status Management
class VerificationService {
  final _supabase = Supabase.instance.client;

  String get _currentUserId => _supabase.auth.currentUser!.id;

  /// POST /verification/submit
  Future<VerificationResult> submitVerification({
    required Uint8List frontImageBytes,
    required Uint8List backImageBytes,
    required Uint8List selfieBytes,
    required String idType,
    required String fileExtension,
  }) async {
    try {
      final existing = await _supabase
          .from('verification_requests')
          .select('status')
          .eq('user_id', _currentUserId)
          .maybeSingle();

      if (existing != null && (existing['status'] == 'pending' || existing['status'] == 'approved')) {
        return VerificationResult.failure('Request already ${existing['status']}.');
      }

      // Upload logic (Simplified for brevity, assuming storage handles buckets)
      final frontPath = await _uploadToPrivate('front.$fileExtension', frontImageBytes);
      final backPath = await _uploadToPrivate('back.$fileExtension', backImageBytes);
      final selfiePath = await _uploadToPrivate('selfie.$fileExtension', selfieBytes);

      await _supabase.from('verification_requests').insert({
        'user_id': _currentUserId,
        'id_type': idType,
        'front_image_url': frontPath,
        'back_image_url': backPath,
        'selfie_url': selfiePath,
        'status': 'pending',
      });

      return VerificationResult.success(message: 'Verification pending review.');
    } catch (e) {
      return VerificationResult.failure('Submission failed.');
    }
  }

  /// ADMIN: Approve Verification (Requirement 3.5 Notification Trigger)
  Future<VerificationResult> approveVerification(String requestId) async {
    try {
      final request = await _supabase
          .from('verification_requests')
          .select('user_id, id_type, users(email, name)')
          .eq('id', requestId)
          .single();

      final userId = request['user_id'];
      final userEmail = request['users']['email'];
      final userName = request['users']['name'];

      await _supabase.from('verification_requests').update({
        'status': 'approved',
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      await _supabase.from('users').update({
        'verified': true,
      }).eq('id', userId);

      // 3.5: Trigger email and push notification
      EmailService().sendVerificationApproved(toEmail: userEmail, userName: userName);
      NotificationService.showNotification(
        title: 'Account Verified! ✅',
        body: 'Badge added to your profile.',
      );

      return VerificationResult.success(message: 'Verification approved.');
    } catch (e) {
      return VerificationResult.failure('Approval failed.');
    }
  }

  Future<String> _uploadToPrivate(String name, Uint8List bytes) async {
    final path = 'verification/$_currentUserId/$name';
    await _supabase.storage.from('id-documents').uploadBinary(path, bytes);
    return path;
  }
}

class VerificationResult {
  final bool isSuccess;
  final String message;
  VerificationResult._({required this.isSuccess, required this.message});
  factory VerificationResult.success({String message = 'Success'}) =>
      VerificationResult._(isSuccess: true, message: message);
  factory VerificationResult.failure(String message) =>
      VerificationResult._(isSuccess: false, message: message);
}
