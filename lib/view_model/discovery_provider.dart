import 'dart:async';
import 'package:flutter/material.dart';
import '../model/restaurant.dart';
import '../repository/discovery_repository.dart';

class DiscoveryProvider with ChangeNotifier {
  final DiscoveryRepository _repository = DiscoveryRepository();

  // ── State variables ────────────────────────────────────────────────────────

  RestaurantState _restaurantState = RestaurantLoading();
  RestaurantState get restaurantState => _restaurantState;

  RestaurantState _rankedState = RestaurantLoading();
  RestaurantState get rankedState => _rankedState;

  RestaurantState _nearbyState = RestaurantLoading();
  RestaurantState get nearbyState => _nearbyState;

  RestaurantState _searchState = RestaurantSuccess([]);
  RestaurantState get searchState => _searchState;

  List<SearchSuggestion> _suggestions = [];
  List<SearchSuggestion> get suggestions => _suggestions;

  RestaurantFilters _activeFilters = RestaurantFilters();
  RestaurantFilters get activeFilters => _activeFilters;

  double? _userLat;
  double? _userLng;

  Timer? _searchDebounce;

  // ── Initialization ─────────────────────────────────────────────────────────

  void init() {
    loadRestaurants();
    loadRanked();
  }

  // ── getRestaurants() ─────────────────────────────────────────────────────

  Future<void> loadRestaurants({RestaurantFilters? filters}) async {
    _restaurantState = RestaurantLoading();
    if (filters != null) _activeFilters = filters;
    notifyListeners();

    try {
      final results = await _repository.getRestaurants(_activeFilters);
      _restaurantState = RestaurantSuccess(results);
    } catch (e) {
      _restaurantState = RestaurantError(e.toString());
    }
    notifyListeners();
  }

  // ── getRanked() ──────────────────────────────────────────────────────────

  Future<void> loadRanked({int? limit}) async {
    _rankedState = RestaurantLoading();
    notifyListeners();

    try {
      final results = await _repository.getRanked(
        userLat: _userLat,
        userLng: _userLng,
        limit: limit,
      );
      _rankedState = RestaurantSuccess(results);
    } catch (e) {
      _rankedState = RestaurantError(e.toString());
    }
    notifyListeners();
  }

  // ── getNearby() ──────────────────────────────────────────────────────────

  Future<void> loadNearby({double radiusKm = 2.0, bool openNow = false}) async {
    if (_userLat == null || _userLng == null) {
      _nearbyState = RestaurantError("Location not available. Please enable GPS.");
      notifyListeners();
      return;
    }

    _nearbyState = RestaurantLoading();
    notifyListeners();

    try {
      final results = await _repository.getNearby(
        userLat: _userLat!,
        userLng: _userLng!,
        radiusKm: radiusKm,
        openNow: openNow,
      );
      _nearbyState = RestaurantSuccess(results);
    } catch (e) {
      _nearbyState = RestaurantError(e.toString());
    }
    notifyListeners();
  }

  // ── searchRestaurants() with Debounce ─────────────────────────────────────

  void onSearchQueryChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (query.trim().length >= 2) {
        fetchSuggestions(query);
        searchRestaurants(query);
      } else {
        _suggestions = [];
        _searchState = RestaurantSuccess([]);
        notifyListeners();
      }
    });
  }

  Future<void> searchRestaurants(String query) async {
    _searchState = RestaurantLoading();
    notifyListeners();

    try {
      final results = await _repository.searchRestaurants(
        query,
        userLat: _userLat,
        userLng: _userLng,
      );
      _searchState = RestaurantSuccess(results);
    } catch (e) {
      _searchState = RestaurantError(e.toString());
    }
    notifyListeners();
  }

  Future<void> fetchSuggestions(String query) async {
    try {
      _suggestions = await _repository.getSuggest(query);
      notifyListeners();
    } catch (_) {
      _suggestions = [];
    }
  }

  // ── Location + Filter Helpers ─────────────────────────────────────────────

  void setUserLocation(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    _activeFilters = _activeFilters.copyWith(userLat: lat, userLng: lng);
    loadRestaurants();
    loadRanked();
    loadNearby();
  }

  void filterByCategory(String? category) => 
      loadRestaurants(filters: _activeFilters.copyWith(category: category));

  void filterByPriceTier(int? tier) => 
      loadRestaurants(filters: _activeFilters.copyWith(priceTier: tier));

  void toggleOpenNow() => 
      loadRestaurants(filters: _activeFilters.copyWith(openNow: !_activeFilters.openNow));

  void setSortBy(SortOption sort) => 
      loadRestaurants(filters: _activeFilters.copyWith(sortBy: sort));

  void clearAllFilters() => loadRestaurants(filters: RestaurantFilters());

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
