class Dish {
  final String id;
  final String restaurantId;
  final String name;
  final String? description;
  final double price;
  final String? photoUrl;
  final bool isAvailable;
  final String? category;
  
  // Joined data
  final String? restaurantName;
  final double? restaurantRating;
  final String? restaurantAddress;

  // Trending Metrics
  final double trendingScore;
  final int mentionCount;

  Dish({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description,
    required this.price,
    this.photoUrl,
    this.isAvailable = true,
    this.category,
    this.restaurantName,
    this.restaurantRating,
    this.restaurantAddress,
    this.trendingScore = 0.0,
    this.mentionCount = 0,
  });

  factory Dish.fromSupabase(Map<String, dynamic> json) {
    var resData = json['restaurants'] ?? json['restaurant'];
    Map<String, dynamic>? restaurant;
    
    if (resData is Map) {
      restaurant = Map<String, dynamic>.from(resData);
    } else if (resData is List && resData.isNotEmpty) {
      restaurant = Map<String, dynamic>.from(resData.first);
    }
    
    return Dish(
      id: json['id']?.toString() ?? '',
      restaurantId: json['restaurant_id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      photoUrl: json['photo_url'],
      isAvailable: json['is_available'] ?? true,
      category: json['category'],
      restaurantName: restaurant?['name'],
      restaurantRating: restaurant != null 
          ? (restaurant['algorithm_score'] != null 
              ? (restaurant['algorithm_score'] as num).toDouble() / 20.0 
              : (restaurant['rating'] as num?)?.toDouble())
          : null,
      restaurantAddress: restaurant?['address'],
      trendingScore: (json['trending_score'] as num?)?.toDouble() ?? 0.0,
      mentionCount: json['mention_count'] ?? 0,
    );
  }

  Dish copyWith({double? trendingScore, int? mentionCount}) {
    return Dish(
      id: id,
      restaurantId: restaurantId,
      name: name,
      description: description,
      price: price,
      photoUrl: photoUrl,
      isAvailable: isAvailable,
      category: category,
      restaurantName: restaurantName,
      restaurantRating: restaurantRating,
      restaurantAddress: restaurantAddress,
      trendingScore: trendingScore ?? this.trendingScore,
      mentionCount: mentionCount ?? this.mentionCount,
    );
  }

  String get imageUrl => (photoUrl != null && photoUrl!.isNotEmpty)
      ? photoUrl!
      : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=400&auto=format&fit=crop';
}
