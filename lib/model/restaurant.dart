
/// ─────────────────────────────────────────────────────────────────────────────
/// Matches the `restaurants` table in Supabase exactly.
/// ─────────────────────────────────────────────────────────────────────────────
class Restaurant {
  final String id;
  final String name;
  final String category; // restaurant | cafe | street_food | fine_dining
  final String address;
  final double latitude;
  final double longitude;
  final int priceTier; // 1=budget 4=luxury
  final Map<String, OpenHours>? openHours;
  final List<String>? photos;
  final String? aiSummary;
  final List<String>? aiTags;
  final double? algorithmScore;
  final double? ratingFromSupabase;
  final bool active;
  final DateTime? scoreUpdatedAt;

  Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.priceTier,
    this.openHours,
    this.photos,
    this.aiSummary,
    this.aiTags,
    this.algorithmScore,
    this.ratingFromSupabase,
    this.active = true,
    this.scoreUpdatedAt,
  });

  // Getters to fix UI errors and maintain compatibility
  double? get lat => latitude;
  double? get lng => longitude;
  double get lensScore => algorithmScore ?? 0.0;
  
  /// Star rating (1-5). Used for both display and sorting.
  /// Priority: 1. Algorithm Score (converted), 2. DB Rating, 3. Default 4.0
  double get rating {
    double r = 4.0;
    if (algorithmScore != null && algorithmScore! > 0) {
      r = algorithmScore! / 20.0;
    } else if (ratingFromSupabase != null && ratingFromSupabase! > 0) {
      r = ratingFromSupabase!;
    }
    // Return a stable double for comparison
    return double.parse(r.toStringAsFixed(1));
  }

  String get imageUrl => (photos != null && photos!.isNotEmpty)
      ? photos!.first
      : 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400&auto=format&fit=crop';

  String get categoryDisplay {
    if (category.isEmpty) return 'Restaurant';
    // Convert snake_case to Title Case
    return category.split('_').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  factory Restaurant.fromSupabase(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      category: json['category'] ?? 'restaurant',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      priceTier: json['price_tier'] ?? 1,
      openHours: json['open_hours'] != null
          ? (json['open_hours'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, OpenHours.fromJson(v)),
            )
          : null,
      photos: json['photos'] != null ? List<String>.from(json['photos']) : null,
      aiSummary: json['ai_summary'],
      aiTags: json['ai_tags'] != null ? List<String>.from(json['ai_tags']) : null,
      algorithmScore: (json['algorithm_score'] as num?)?.toDouble(),
      ratingFromSupabase: (json['rating'] as num?)?.toDouble(),
      active: json['active'] ?? true,
      scoreUpdatedAt: json['score_updated_at'] != null
          ? DateTime.parse(json['score_updated_at'])
          : null,
    );
  }

  factory Restaurant.fromOverpassJson(Map<String, dynamic> json) {
    final tags = json['tags'] ?? {};
    final center = json['center'] ?? {};
    double lat = json['lat']?.toDouble() ?? center['lat']?.toDouble() ?? 0.0;
    double lon = json['lon']?.toDouble() ?? center['lon']?.toDouble() ?? 0.0;

    return Restaurant(
      id: json['id'].toString(),
      name: tags['name'] ?? 'Local Eatery',
      category: tags['cuisine']?.toString().toLowerCase() ?? 'restaurant',
      address: tags['addr:street'] ?? 'Nearby Dhaka',
      latitude: lat,
      longitude: lon,
      priceTier: 2,
      algorithmScore: 85.0,
    );
  }

  factory Restaurant.fromGoogleJson(Map<String, dynamic> json) {
    final location = json['geometry']?['location'] ?? {};
    double lat = location['lat']?.toDouble() ?? 0.0;
    double lon = location['lng']?.toDouble() ?? 0.0;
    double ratingValue = (json['rating'] ?? 0.0).toDouble();

    return Restaurant(
      id: json['place_id'] ?? '',
      name: json['name'] ?? 'Unknown Spot',
      category: (json['types'] as List?)?.first?.toString().toLowerCase() ?? 'restaurant',
      address: json['vicinity'] ?? json['formatted_address'] ?? 'Address Hidden',
      latitude: lat,
      longitude: lon,
      priceTier: json['price_level'] ?? 2,
      algorithmScore: ratingValue * 20.0,
      ratingFromSupabase: ratingValue,
    );
  }
}

class OpenHours {
  final String open;
  final String close;
  OpenHours({required this.open, required this.close});
  factory OpenHours.fromJson(Map<String, dynamic> json) =>
      OpenHours(open: json['open'] ?? '00:00', close: json['close'] ?? '00:00');
}

class AlgorithmScore {
  final String restaurantId;
  final double? qualityScore;
  final double? trustScore;
  final double? popularityScore;
  final int reviewCount;

  AlgorithmScore({
    required this.restaurantId,
    this.qualityScore,
    this.trustScore,
    this.popularityScore,
    this.reviewCount = 0,
  });

  factory AlgorithmScore.fromSupabase(Map<String, dynamic> json) {
    return AlgorithmScore(
      restaurantId: json['restaurant_id'].toString(),
      qualityScore: (json['quality_score'] as num?)?.toDouble(),
      trustScore: (json['trust_score'] as num?)?.toDouble(),
      popularityScore: (json['popularity_score'] as num?)?.toDouble(),
      reviewCount: json['review_count'] ?? 0,
    );
  }
}

class RestaurantWithScore {
  final Restaurant restaurant;
  final AlgorithmScore? score;
  final bool isOpenNow;
  final double? distanceKm;

  RestaurantWithScore({
    required this.restaurant,
    this.score,
    required this.isOpenNow,
    this.distanceKm,
  });

  String get scoreLabel {
    final s = restaurant.algorithmScore ?? 0.0;
    if (s >= 90) return "Elite";
    if (s >= 75) return "Excellent";
    if (s >= 60) return "Good";
    return "Developing";
  }

  String get priceDisplay => "৳" * restaurant.priceTier;
}

class RestaurantFilters {
  final String? category;
  final int? priceTier;
  final bool openNow;
  final SortOption sortBy;
  final double? userLat;
  final double? userLng;

  RestaurantFilters({
    this.category,
    this.priceTier,
    this.openNow = false,
    this.sortBy = SortOption.score,
    this.userLat,
    this.userLng,
  });

  RestaurantFilters copyWith({
    String? category, int? priceTier, bool? openNow, SortOption? sortBy, double? userLat, double? userLng,
  }) => RestaurantFilters(
    category: category ?? this.category,
    priceTier: priceTier ?? this.priceTier,
    openNow: openNow ?? this.openNow,
    sortBy: sortBy ?? this.sortBy,
    userLat: userLat ?? this.userLat,
    userLng: userLng ?? this.userLng,
  );
}

enum SortOption { score, nearest, budget }

enum SuggestionType { restaurant, tag }

class SearchSuggestion {
  final String text;
  final SuggestionType type;
  final String restaurantId;
  SearchSuggestion({required this.text, required this.type, required this.restaurantId});
}

abstract class RestaurantState {}
class RestaurantLoading extends RestaurantState {}
class RestaurantSuccess extends RestaurantState {
  final List<RestaurantWithScore> data;
  RestaurantSuccess(this.data);
}
class RestaurantError extends RestaurantState {
  final String message;
  RestaurantError(this.message);
}
