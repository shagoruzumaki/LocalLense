import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_lense/services/email_service.dart';



/// LocalLens ID Verification Service
/// Covers: submit verification, check status,
///         admin list pending, approve, reject
/// Member 1 — Ismail Hossain Shagor

class VerificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _currentUserId => _supabase.auth.currentUser!.id;

  // ─────────────────────────────────────────────
  // HELPER — Upload ID document to private bucket
  // Returns internal storage path (NOT a public URL)
  // Files are private — only accessible via signed URL
  // ─────────────────────────────────────────────
  Future<String> _uploadIdDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String folder, // 'front' | 'back' | 'selfie'
  }) async {
    final filePath = 'verification/$_currentUserId/$folder/$fileName';

    await _supabase.storage
        .from('id-documents') // private bucket
        .uploadBinary(
      filePath,
      fileBytes,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'image/jpeg',
      ),
    );

    // Return the internal path — NOT a public URL
    // Admin uses signed URLs to view these (see getSignedUrl below)
    return filePath;
  }

  // ─────────────────────────────────────────────
  // POST /verification/submit
  // Upload front image, back image, selfie
  // Create verification_requests row with status=pending
  // Used by: verification_page.dart
  // ─────────────────────────────────────────────
  Future<VerificationResult> submitVerification({
    required Uint8List frontImageBytes,
    required Uint8List backImageBytes,
    required Uint8List selfieBytes,
    required String idType, // 'nid' or 'student_id'
    required String fileExtension, // 'jpg' or 'png'
  }) async {
    try {
      // Check if user already has a pending or approved request
      final existing = await _supabase
          .from('verification_requests')
          .select('id, status')
          .eq('user_id', _currentUserId)
          .order('created_at', ascending: false)
          .limit(1);

      if (existing.isNotEmpty) {
        final status = existing[0]['status'];
        if (status == 'pending') {
          return VerificationResult.failure(
            'You already have a pending verification request.',
          );
        }
        if (status == 'approved') {
          return VerificationResult.failure(
            'Your account is already verified.',
          );
        }
        // If rejected, allow resubmission
      }

      // Upload all 3 images to private storage
      final frontPath = await _uploadIdDocument(
        fileBytes: frontImageBytes,
        fileName: 'front.$fileExtension',
        folder: 'front',
      );

      final backPath = await _uploadIdDocument(
        fileBytes: backImageBytes,
        fileName: 'back.$fileExtension',
        folder: 'back',
      );

      final selfiePath = await _uploadIdDocument(
        fileBytes: selfieBytes,
        fileName: 'selfie.$fileExtension',
        folder: 'selfie',
      );

      // Insert verification request row
      await _supabase.from('verification_requests').insert({
        'user_id': _currentUserId,
        'id_type': idType,
        'front_image_url': frontPath,
        'back_image_url': backPath,
        'selfie_url': selfiePath,
        'status': 'pending',
      });

      return VerificationResult.success(
        message: 'Verification submitted successfully. We will review within 24 hours.',
      );
    } catch (e) {
      return VerificationResult.failure(
        'Failed to submit verification. Please try again.',
      );
    }
  }

  // ─────────────────────────────────────────────
  // GET /verification/status
  // Returns current verification status for logged-in user
  // Used by: verification_page.dart, profile_page.dart
  // ─────────────────────────────────────────────
  Future<VerificationResult> getVerificationStatus() async {
    try {
      final response = await _supabase
          .from('verification_requests')
          .select('id, status, id_type, rejection_reason, created_at, reviewed_at')
          .eq('user_id', _currentUserId)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return VerificationResult.success(
          data: {'status': 'not_submitted'},
          message: 'No verification request found.',
        );
      }

      return VerificationResult.success(data: response[0]);
    } catch (e) {
      return VerificationResult.failure('Failed to fetch verification status.');
    }
  }

  // ─────────────────────────────────────────────
  // ADMIN — GET /admin/verifications/pending
  // List all pending verification requests
  // Only call this from admin screens
  // ─────────────────────────────────────────────
  Future<VerificationResult> getPendingVerifications() async {
    try {
      final response = await _supabase
          .from('verification_requests')
          .select('''
            id,
            id_type,
            status,
            created_at,
            front_image_url,
            back_image_url,
            selfie_url,
            users (
              id,
              name,
              email,
              tier
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: true); // oldest first

      return VerificationResult.success(
        data: {'requests': response},
      );
    } catch (e) {
      return VerificationResult.failure('Failed to load pending verifications.');
    }
  }

  // ─────────────────────────────────────────────
  // ADMIN — Signed URL to view private ID document
  // Expires in 15 minutes
  // Call this when admin clicks to view a document
  // ─────────────────────────────────────────────
  Future<VerificationResult> getSignedUrl(String storagePath) async {
    try {
      final response = await _supabase.storage
          .from('id-documents')
          .createSignedUrl(storagePath, 900); // 900 seconds = 15 min

      return VerificationResult.success(
        data: {'signed_url': response},
      );
    } catch (e) {
      return VerificationResult.failure('Failed to generate document URL.');
    }
  }

  // ─────────────────────────────────────────────
  // ADMIN — PATCH /admin/verifications/:id/approve
  // Sets status=approved, users.verified=true
  // ─────────────────────────────────────────────
  Future<VerificationResult> approveVerification(String requestId) async {
    try {
      // Get the user_id from this request
      final request = await _supabase
          .from('verification_requests')
          .select('user_id, id_type')
          .eq('id', requestId)
          .single();

      final userId = request['user_id'];
      final idType = request['id_type'];

      final userData = await _supabase
          .from('users')
          .select('email, full_name')
          .eq('id', userId)
          .single();

      final userEmail = userData['email'];
      final userName = userData['full_name'];

      // Update verification request status
      await _supabase.from('verification_requests').update({
        'status': 'approved',
        'reviewed_by': _currentUserId,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // Update user as verified
      await _supabase.from('users').update({
        'verified': true,
        'id_type': idType,
      }).eq('id', userId);

      final emailService = EmailService();
         await emailService.sendVerificationApproved(
               toEmail: userEmail,
               userName: userName,
         );
      // TODO: trigger push notification via Rahat's notification service

      return VerificationResult.success(
        message: 'Verification approved.',
      );
    } catch (e) {
      return VerificationResult.failure('Failed to approve verification.');
    }
  }

  // ─────────────────────────────────────────────
  // ADMIN — PATCH /admin/verifications/:id/reject
  // Sets status=rejected, stores rejection_reason
  // ─────────────────────────────────────────────
  Future<VerificationResult> rejectVerification({
    required String requestId,
    required String rejectionReason,
  }) async {
    try {
      if (rejectionReason.trim().isEmpty) {
        return VerificationResult.failure('Rejection reason is required.');
      }
      final request = await _supabase
          .from('verification_requests')
          .select('user_id')
          .eq('id', requestId)
          .single();

      final userId = request['user_id'];

      final userData = await _supabase
          .from('users')
          .select('email, full_name')
          .eq('id', userId)
          .single();

      final userEmail = userData['email'];
      final userName = userData['full_name'];

      await _supabase.from('verification_requests').update({
        'status': 'rejected',
        'reviewed_by': _currentUserId,
        'reviewed_at': DateTime.now().toIso8601String(),
        'rejection_reason': rejectionReason.trim(),
      }).eq('id', requestId);

      await EmailService().sendVerificationRejected(
               toEmail: userEmail,
               userName: userName,
               rejectionReason: rejectionReason,
      );

      return VerificationResult.success(
        message: 'Verification rejected.',
      );
    } catch (e) {
      return VerificationResult.failure('Failed to reject verification.');
    }
  }
}


// ─────────────────────────────────────────────
// RESULT WRAPPER
// ─────────────────────────────────────────────
class VerificationResult {
  final bool isSuccess;
  final String message;
  final Map<String, dynamic>? data;

  VerificationResult._({
    required this.isSuccess,
    required this.message,
    this.data,
  });

  factory VerificationResult.success({
    Map<String, dynamic>? data,
    String message = 'Success.',
  }) {
    return VerificationResult._(isSuccess: true, message: message, data: data);
  }

  factory VerificationResult.failure(String message) {
    return VerificationResult._(isSuccess: false, message: message);
  }
}