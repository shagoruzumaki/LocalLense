/// LocalLens Input Validation
/// Validates all user inputs before sending to Supabase
/// Replaces Joi/Zod (those are Node.js libraries)
/// Member 1 — Ismail Hossain Shagor
library;

class Validators {

  // ─────────────────────────────────────────────
  // EMAIL
  // ─────────────────────────────────────────────
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // PASSWORD
  // Min 8 chars, 1 uppercase, 1 number
  // ─────────────────────────────────────────────
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Add at least 1 uppercase letter.';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Add at least 1 number.';
    return null;
  }

  // ─────────────────────────────────────────────
  // CONFIRM PASSWORD
  // ─────────────────────────────────────────────
  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  // ─────────────────────────────────────────────
  // NAME
  // ─────────────────────────────────────────────
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required.';
    if (value.trim().length < 2) return 'Name must be at least 2 characters.';
    if (value.trim().length > 100) return 'Name is too long.';
    // No special characters except spaces and hyphens
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value.trim())) {
      return 'Name can only contain letters, spaces, and hyphens.';
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // BIO
  // ─────────────────────────────────────────────
  static String? bio(String? value) {
    if (value == null) return null; // bio is optional
    if (value.length > 300) return 'Bio must be under 300 characters.';
    return null;
  }

  // ─────────────────────────────────────────────
  // REVIEW BODY
  // ─────────────────────────────────────────────
  static String? reviewBody(String? value) {
    if (value == null || value.trim().isEmpty) return 'Review text is required.';
    if (value.trim().length < 20) return 'Review must be at least 20 characters.';
    if (value.trim().length > 2000) return 'Review must be under 2000 characters.';
    return null;
  }

  // ─────────────────────────────────────────────
  // RATING (1.0 - 5.0)
  // ─────────────────────────────────────────────
  static String? rating(double? value) {
    if (value == null) return 'Rating is required.';
    if (value < 1.0 || value > 5.0) return 'Rating must be between 1 and 5.';
    return null;
  }

  // ─────────────────────────────────────────────
  // PHONE NUMBER
  // ─────────────────────────────────────────────
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value.trim())) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // REQUIRED FIELD (generic)
  // ─────────────────────────────────────────────
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // SANITIZE — strip dangerous characters from
  // any string before sending to Supabase
  // Supabase uses parameterized queries so SQL injection
  // is already prevented, but this adds extra safety
  // ─────────────────────────────────────────────
  static String sanitize(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[<>]'), '') // strip HTML tags
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), ''); // strip JS
  }

  // ─────────────────────────────────────────────
  // UUID format check (for IDs passed in URLs)
  // ─────────────────────────────────────────────
  static bool isValidUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}