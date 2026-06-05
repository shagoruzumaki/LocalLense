import 'dart:math' show cos, sqrt, asin, min, max;
import 'package:intl/intl.dart';
import '../model/restaurant.dart';

class LocationUtils {
  /// FIXED: Safe Haversine formula
  static double calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const p = 0.017453292519943295; // PI / 180
    final c = cos;

    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) *
            (1 - c((lon2 - lon1) * p)) / 2;

    // FIX: clamp value to avoid NaN
    final safeA = min(1.0, max(0.0, a));

    final distance = 12742 * asin(sqrt(safeA));

    return (distance * 100).round() / 100.0;
  }

  /// Radius check
  static bool isWithinRadius(
      double userLat,
      double userLng,
      double targetLat,
      double targetLng,
      double radiusKm,
      ) {
    return calculateDistance(
      userLat,
      userLng,
      targetLat,
      targetLng,
    ) <=
        radiusKm;
  }

  /// 500m geofence
  static bool isWithin500m(
      double userLat,
      double userLng,
      double targetLat,
      double targetLng,
      ) {
    return calculateDistance(
      userLat,
      userLng,
      targetLat,
      targetLng,
    ) <=
        0.5;
  }

  /// Format distance for UI
  static String formatDistance(double km) {
    if (km < 1.0) {
      return "${(km * 1000).round()} m";
    }
    return "${km.toStringAsFixed(1)} km";
  }

  /// FIXED: safer OpenNow logic
  static bool isOpenNow(Map<String, OpenHours>? openHours) {
    if (openHours == null || openHours.isEmpty) return true;

    final now = DateTime.now().toUtc().add(const Duration(hours: 6));
    final dayName = DateFormat('EEEE').format(now);

    final dayHours = openHours[dayName];
    if (dayHours == null) return false;

    try {
      final open = _parseTime(dayHours.open, now);
      var close = _parseTime(dayHours.close, now);

      // overnight handling
      if (close.isBefore(open)) {
        close = close.add(const Duration(days: 1));

        if (now.isBefore(open)) {
          final prevOpen = open.subtract(const Duration(days: 1));
          final prevClose = close.subtract(const Duration(days: 1));
          return now.isAfter(prevOpen) && now.isBefore(prevClose);
        }
      }

      return now.isAfter(open) && now.isBefore(close);
    } catch (_) {
      // FIX: safer fallback (don’t assume open)
      return false;
    }
  }

  static DateTime _parseTime(String timeStr, DateTime now) {
    final parts = timeStr.split(':');

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}