class Reward {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String title;
  final String description;
  final String requiredTier;
  final String qrCodeData;
  final DateTime expiryDate;
  final bool isRedeemed;

  Reward({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.title,
    required this.description,
    required this.requiredTier,
    required this.qrCodeData,
    required this.expiryDate,
    this.isRedeemed = false,
  });

  factory Reward.fromSupabase(Map<String, dynamic> json) {
    return Reward(
      id: json['id'].toString(),
      restaurantId: json['restaurant_id'].toString(),
      restaurantName: json['restaurants']?['name'] ?? 'Restaurant',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      requiredTier: json['required_tier'] ?? 'explorer',
      qrCodeData: json['qr_code_string'] ?? '',
      expiryDate: DateTime.parse(json['expiry_date']),
      isRedeemed: json['user_rewards'] != null && (json['user_rewards'] as List).isNotEmpty,
    );
  }
}
