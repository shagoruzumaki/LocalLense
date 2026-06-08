import '../model/restaurant.dart';
import '../model/dish.dart';
import '../repository/discovery_repository.dart';

class DiscoveryService {
  final DiscoveryRepository _repository = DiscoveryRepository();

  Future<List<RestaurantWithScore>> searchRestaurants(String query, {
    double? lat, 
    double? lng, 
    SortOption sortBy = SortOption.score,
    bool searchByDish = true,
  }) async {
    return _repository.searchRestaurants(
      query, 
      userLat: lat, 
      userLng: lng, 
      sortBy: sortBy,
      searchByDish: searchByDish,
    );
  }

  /// Search for specific dishes matching the query
  Future<List<Dish>> searchDishes(String query) async {
    return _repository.searchDishes(query);
  }

  Future<List<RestaurantWithScore>> getRanked({double? lat, double? lng, int? limit}) async {
    return _repository.getRanked(userLat: lat, userLng: lng, limit: limit);
  }

  Future<List<RestaurantWithScore>> getRestaurants(RestaurantFilters filters) async {
    return _repository.getRestaurants(filters);
  }

  Future<List<SearchSuggestion>> getSuggestions(String query) async {
    return _repository.getSuggest(query);
  }

  Future<List<RestaurantWithScore>> getNearby({
    required double lat,
    required double lng,
    double radiusKm = 2.0,
    bool openNow = false,
  }) async {
    return _repository.getNearby(
      userLat: lat,
      userLng: lng,
      radiusKm: radiusKm,
      openNow: openNow,
    );
  }

  Future<RestaurantWithScore?> getRestaurantDetail(String id, {double? lat, double? lng}) async {
    return _repository.getRestaurantDetail(id, userLat: lat, userLng: lng);
  }

  Future<AlgorithmScore?> getScoreBreakdown(String id) async {
    return _repository.getScoreBreakdown(id);
  }
}
