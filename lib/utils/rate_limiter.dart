/// LocalLens Rate Limiter
/// Client-side rate limiting for sensitive actions
/// Prevents spam tapping on login, register, forgot password
/// Supabase handles server-side rate limiting automatically
/// Member 1 — Ismail Hossain Shagor
library;

class RateLimiter {
  // Stores last attempt timestamps per action key
  static final Map<String, List<DateTime>> _attempts = {};

  // ─────────────────────────────────────────────
  // Check if action is allowed
  // key: unique identifier e.g. 'login', 'register'
  // maxAttempts: max allowed in the time window
  // windowSeconds: time window in seconds
  // ─────────────────────────────────────────────
  static bool isAllowed({
    required String key,
    required int maxAttempts,
    required int windowSeconds,
  }) {
    final now = DateTime.now();
    final window = Duration(seconds: windowSeconds);

    // Get existing attempts for this key
    final attempts = _attempts[key] ?? [];

    // Remove attempts outside the window
    attempts.removeWhere((t) => now.difference(t) > window);

    // Check if under limit
    if (attempts.length >= maxAttempts) {
      return false; // blocked
    }

    // Record this attempt
    attempts.add(now);
    _attempts[key] = attempts;
    return true; // allowed
  }

  // ─────────────────────────────────────────────
  // Get seconds remaining until next allowed attempt
  // ─────────────────────────────────────────────
  static int secondsUntilAllowed({
    required String key,
    required int windowSeconds,
  }) {
    final attempts = _attempts[key];
    if (attempts == null || attempts.isEmpty) return 0;

    final oldest = attempts.first;
    final elapsed = DateTime.now().difference(oldest).inSeconds;
    final remaining = windowSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  // ─────────────────────────────────────────────
  // Reset attempts for a key (e.g. after successful login)
  // ─────────────────────────────────────────────
  static void reset(String key) {
    _attempts.remove(key);
  }

  // ─────────────────────────────────────────────
  // PRESET RULES — matches your security spec
  // ─────────────────────────────────────────────

  /// Max 5 login attempts per minute
  static bool canAttemptLogin() => isAllowed(
    key: 'login',
    maxAttempts: 5,
    windowSeconds: 60,
  );

  /// Max 3 register attempts per minute
  static bool canAttemptRegister() => isAllowed(
    key: 'register',
    maxAttempts: 3,
    windowSeconds: 60,
  );

  /// Max 3 forgot password requests per 15 minutes
  static bool canRequestPasswordReset() => isAllowed(
    key: 'forgot_password',
    maxAttempts: 3,
    windowSeconds: 900,
  );

  /// Max 2 verification submissions per hour
  static bool canSubmitVerification() => isAllowed(
    key: 'verification',
    maxAttempts: 2,
    windowSeconds: 3600,
  );

  static int loginCooldownSeconds() =>
      secondsUntilAllowed(key: 'login', windowSeconds: 60);
}