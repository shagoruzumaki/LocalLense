import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// LocalLens File Storage & Media Service
/// Covers: profile photo upload, review photo upload (up to 10),
///         thumbnail generation, signed URLs for private docs
/// Member 1 — Ismail Hossain Shagor

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _currentUserId => _supabase.auth.currentUser!.id;

  // ─────────────────────────────────────────────
  // POST /upload/profile-photo
  // Resize to 400×400px equivalent, WebP compress
  // Store in profile-photos bucket (public)
  // Returns CDN URL saved to users.profile_photo_url
  // Used by: profile_page.dart (edit mode)
  // ─────────────────────────────────────────────
  Future<StorageResult> uploadProfilePhoto({
    required Uint8List fileBytes,
    required String fileExtension, // 'jpg', 'png', 'webp'
  }) async {
    try {
      _validateFileSize(fileBytes, maxMb: 5);

      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final filePath = 'avatars/$_currentUserId/$fileName';

      await _supabase.storage
          .from('profile-photos')
          .uploadBinary(
        filePath,
        fileBytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: 'image/$fileExtension',
        ),
      );

      final publicUrl = _supabase.storage
          .from('profile-photos')
          .getPublicUrl(filePath);

      // Save URL to users table
      await _supabase
          .from('users')
          .update({'profile_photo_url': publicUrl})
          .eq('id', _currentUserId);

      return StorageResult.success(
        url: publicUrl,
        message: 'Profile photo uploaded.',
      );
    } on StorageException catch (e) {
      return StorageResult.failure('Storage error: ${e.message}');
    } on FileValidationException catch (e) {
      return StorageResult.failure(e.message);
    } catch (e) {
      return StorageResult.failure('Failed to upload profile photo.');
    }
  }

  // ─────────────────────────────────────────────
  // POST /upload/review-photos
  // Accept up to 10 images, each max 1MB
  // Store in review-photos bucket (public)
  // Returns list of CDN URLs
  // Used by: when Member 2's review submit is built
  // ─────────────────────────────────────────────
  Future<StorageResult> uploadReviewPhotos({
    required List<Uint8List> photoBytesList,
    required List<String> fileExtensions,
    required String restaurantId,
  }) async {
    try {
      // Max 10 photos per review
      if (photoBytesList.length > 10) {
        return StorageResult.failure('Maximum 10 photos allowed per review.');
      }

      if (photoBytesList.isEmpty) {
        return StorageResult.failure('At least 1 photo is required.');
      }

      if (photoBytesList.length != fileExtensions.length) {
        return StorageResult.failure('File list mismatch.');
      }

      final List<String> uploadedUrls = [];

      for (int i = 0; i < photoBytesList.length; i++) {
        final bytes = photoBytesList[i];
        final ext = fileExtensions[i];

        // Each photo max 1MB
        _validateFileSize(bytes, maxMb: 1);

        final fileName =
            'review_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        final filePath =
            'reviews/$restaurantId/$_currentUserId/$fileName';

        await _supabase.storage
            .from('review-photos')
            .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: 'image/$ext',
          ),
        );

        final publicUrl = _supabase.storage
            .from('review-photos')
            .getPublicUrl(filePath);

        uploadedUrls.add(publicUrl);
      }

      return StorageResult.success(
        urls: uploadedUrls,
        message: '${uploadedUrls.length} photo(s) uploaded.',
      );
    } on FileValidationException catch (e) {
      return StorageResult.failure(e.message);
    } on StorageException catch (e) {
      return StorageResult.failure('Storage error: ${e.message}');
    } catch (e) {
      return StorageResult.failure('Failed to upload review photos.');
    }
  }

  // ─────────────────────────────────────────────
  // POST /upload/id-document
  // AES-256 encrypted private storage
  // Returns internal storage path only (never public URL)
  // Used by: verification_service.dart internally
  // NOTE: actual upload logic lives in verification_service.dart
  //       this method is a convenience wrapper if needed separately
  // ─────────────────────────────────────────────
  Future<StorageResult> uploadIdDocument({
    required Uint8List fileBytes,
    required String fileExtension,
    required String folder, // 'front' | 'back' | 'selfie'
  }) async {
    try {
      _validateFileSize(fileBytes, maxMb: 5);

      final fileName =
          '${folder}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final filePath =
          'verification/$_currentUserId/$folder/$fileName';

      await _supabase.storage
          .from('id-documents') // private bucket
          .uploadBinary(
        filePath,
        fileBytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: 'image/$fileExtension',
        ),
      );

      // Return internal path only — never expose as public URL
      return StorageResult.success(
        url: filePath, // internal path, not CDN URL
        message: 'Document uploaded securely.',
      );
    } on FileValidationException catch (e) {
      return StorageResult.failure(e.message);
    } on StorageException catch (e) {
      return StorageResult.failure('Storage error: ${e.message}');
    } catch (e) {
      return StorageResult.failure('Failed to upload document.');
    }
  }

  // ─────────────────────────────────────────────
  // THUMBNAIL GENERATION
  // Supabase Storage has built-in image transformation
  // Append ?width=200&height=200 to any public URL
  // Used for restaurant card images (200×200)
  // ─────────────────────────────────────────────

  /// Returns a 200×200 thumbnail URL for any Supabase Storage image
  /// Use this for restaurant cards and review photo previews
  String getThumbnailUrl(String originalUrl) {
    // Supabase image transformation API
    // Appends transform params to the URL
    if (originalUrl.contains('supabase')) {
      return '$originalUrl?width=200&height=200&resize=cover';
    }
    return originalUrl; // fallback: return original if not Supabase URL
  }

  /// Returns a 400×400 version for profile photos
  String getProfilePhotoUrl(String originalUrl) {
    if (originalUrl.contains('supabase')) {
      return '$originalUrl?width=400&height=400&resize=cover';
    }
    return originalUrl;
  }

  // ─────────────────────────────────────────────
  // SIGNED URL — for private bucket files
  // Expires in 15 minutes
  // Used by: admin to view ID documents
  // ─────────────────────────────────────────────
  Future<StorageResult> getSignedUrl({
    required String storagePath,
    int expiresInSeconds = 900, // 15 minutes
  }) async {
    try {
      final signedUrl = await _supabase.storage
          .from('id-documents')
          .createSignedUrl(storagePath, expiresInSeconds);

      return StorageResult.success(url: signedUrl);
    } catch (e) {
      return StorageResult.failure('Failed to generate signed URL.');
    }
  }

  // ─────────────────────────────────────────────
  // DELETE a file from storage
  // Used when user deletes a review or updates photo
  // ─────────────────────────────────────────────
  Future<StorageResult> deleteFile({
    required String bucket,
    required String filePath,
  }) async {
    try {
      await _supabase.storage.from(bucket).remove([filePath]);
      return StorageResult.success(message: 'File deleted.');
    } catch (e) {
      return StorageResult.failure('Failed to delete file.');
    }
  }

  // ─────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────

  /// Throws FileValidationException if file exceeds max size
  void _validateFileSize(Uint8List bytes, {required int maxMb}) {
    final maxBytes = maxMb * 1024 * 1024;
    if (bytes.length > maxBytes) {
      throw FileValidationException(
        'File too large. Maximum size is ${maxMb}MB.',
      );
    }
  }
}


// ─────────────────────────────────────────────
// RESULT WRAPPER
// ─────────────────────────────────────────────
class StorageResult {
  final bool isSuccess;
  final String message;
  final String? url;           // single URL (profile photo, signed URL)
  final List<String>? urls;   // multiple URLs (review photos)

  StorageResult._({
    required this.isSuccess,
    required this.message,
    this.url,
    this.urls,
  });

  factory StorageResult.success({
    String message = 'Success.',
    String? url,
    List<String>? urls,
  }) {
    return StorageResult._(
      isSuccess: true,
      message: message,
      url: url,
      urls: urls,
    );
  }

  factory StorageResult.failure(String message) {
    return StorageResult._(isSuccess: false, message: message);
  }
}


// ─────────────────────────────────────────────
// CUSTOM EXCEPTION
// ─────────────────────────────────────────────
class FileValidationException implements Exception {
  final String message;
  FileValidationException(this.message);
}