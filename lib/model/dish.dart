import 'restaurant.dart';

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
  });

  factory Dish.fromSupabase(Map<String, dynamic> json) {
    // Supabase can return joined data as a Map or a List containing a Map
    // and the key might be singular 'restaurant' or plural 'restaurants'
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
    );
  }

  String get imageUrl => (photoUrl != null && photoUrl!.isNotEmpty)
      ? photoUrl!
      : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=400&auto=format&fit=crop';
}
