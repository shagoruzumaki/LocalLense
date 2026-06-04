import 'restaurant.dart';

enum SortOption { bestMatch, nearest, budget }

class RestaurantFilters {
  final String? category;
  final String? priceTier;
  final bool openNow;
  final SortOption sortBy;
  final double? userLat;
  final double? userLng;

  RestaurantFilters({
    this.category,
    this.priceTier,
    this.openNow = false,
    this.sortBy = SortOption.bestMatch,
    this.userLat,
    this.userLng,
  });
}

class RestaurantWithScore {
  final Restaurant restaurant;
  final Map<String, dynamic>? score;
  final bool isOpenNow;
  final double? distanceKm;

  RestaurantWithScore({
    required this.restaurant,
    this.score,
    required this.isOpenNow,
    this.distanceKm,
  });
}
