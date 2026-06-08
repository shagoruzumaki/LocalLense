import 'package:flutter/material.dart';
import '../services/discovery_service.dart';
import '../services/location_service.dart';
import '../model/restaurant.dart';
import '../model/dish.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final DiscoveryService _discoveryService = DiscoveryService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late TabController _tabController;

  List<RestaurantWithScore> _results = [];
  List<Dish> _dishResults = [];
  bool _isLoading = false;
  double? _userLat;
  double? _userLng;

  // Filters
  SortOption _selectedSort = SortOption.score;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final hasPermission = await _locationService.checkPermission();
      if (hasPermission) {
        final pos = await _locationService.getCurrentLocation();
        if (mounted) {
          setState(() {
            _userLat = pos.latitude;
            _userLng = pos.longitude;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _dishResults = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Search for restaurants by NAME ONLY (searchByDish: false)
      final results = await _discoveryService.searchRestaurants(
        query,
        lat: _userLat,
        lng: _userLng,
        sortBy: _selectedSort,
        searchByDish: false, // Don't show restaurant cards for dish matches
      );
      
      // 2. Search for dishes specifically
      final dishes = await _discoveryService.searchDishes(query);

      if (mounted) {
        setState(() {
          _results = results;
          _dishResults = dishes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: (value) => _performSearch(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search for dishes or places...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.white54, size: 20),
              onPressed: () {
                _searchController.clear();
                _performSearch();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
                : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildFilterChip('Best Score', SortOption.score),
          const SizedBox(width: 8),
          _buildFilterChip('Nearest', SortOption.nearest),
          const SizedBox(width: 8),
          _buildFilterChip('Budget', SortOption.budget),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, SortOption option) {
    final isSelected = _selectedSort == option;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSort = option);
        _performSearch();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFFFFD700) : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            const Text(
              'What are you craving?',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty && _dishResults.isEmpty) {
      return const Center(
        child: Text('No results found', style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        if (_dishResults.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Dishes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
          ),
          ..._dishResults.map((dish) => _buildDishCard(dish)).toList(),
        ],
        if (_results.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Restaurants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'serif')),
          ),
          ..._results.map((item) => _buildRestaurantCard(item)).toList(),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildDishCard(Dish dish) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/dish-details', arguments: dish),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                dish.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.white10, child: const Icon(Icons.fastfood, size: 30, color: Colors.white38)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          dish.name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text(
                        'DEVELOPING',
                        style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dish.restaurantName ?? ''} • ${dish.restaurantAddress ?? ''}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('৳${dish.price.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('• ${dish.category ?? 'Main'}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                      const Spacer(),
                      const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        dish.restaurantRating?.toStringAsFixed(1) ?? '4.0',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(RestaurantWithScore item) {
    final r = item.restaurant;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                r.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.white10, child: const Icon(Icons.restaurant, size: 30, color: Colors.white38)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        item.scoreLabel.toUpperCase(),
                        style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.address,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('৳' * r.priceTier, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('• ${r.categoryDisplay}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                      if (item.distanceKm != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.near_me, color: Colors.white38, size: 10),
                        const SizedBox(width: 4),
                        Text('${item.distanceKm!.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                      const Spacer(),
                      const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        r.rating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
