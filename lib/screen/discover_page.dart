import 'package:flutter/material.dart';
import '../services/discovery_service.dart';
import '../services/location_service.dart';
import '../services/restaurant_service.dart';
import '../model/restaurant.dart';
import '../model/dish.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DiscoverPageContent();
  }
}

class _DiscoverPageContent extends StatefulWidget {
  const _DiscoverPageContent();

  @override
  State<_DiscoverPageContent> createState() => _DiscoverPageContentState();
}

class _DiscoverPageContentState extends State<_DiscoverPageContent> {
  final DiscoveryService _discoveryService = DiscoveryService();
  final LocationService _locationService = LocationService();
  final RestaurantService _restaurantService = RestaurantService();
  
  // Dynamic Data Lists
  List<Dish> _trendingDishes = [];
  List<Dish> _popularDishes = [];
  List<RestaurantWithScore> _topRated = [];
  List<RestaurantWithScore> _nearbyNow = [];
  List<Dish> _budgetEats = [];
  List<RestaurantWithScore> _recommended = [];
  List<RestaurantWithScore> _hiddenGems = [];
  List<RestaurantWithScore> _newlyAdded = [];
  List<String> _areas = [];
  
  bool _isLoading = true;
  String _currentLocationName = 'Nearby Spots';
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _fetchDiscoveryData();
  }

  Future<void> _fetchDiscoveryData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final hasPermission = await _locationService.checkPermission();
      if (hasPermission) {
        final position = await _locationService.getCurrentLocation();
        _userLat = position.latitude;
        _userLng = position.longitude;
        _currentLocationName = await _restaurantService.getNeighbourhoodName(_userLat!, _userLng!);
      } else {
        _userLat = null;
        _userLng = null;
        _currentLocationName = 'Global';
      }

      // Fetch all dynamic sections in parallel with live location
      final results = await Future.wait([
        _discoveryService.getTrendingDishes(lat: _userLat, lng: _userLng),
        _discoveryService.getPopularDishes(lat: _userLat, lng: _userLng),
        _discoveryService.getTopRated(lat: _userLat, lng: _userLng),
        (_userLat != null && _userLng != null) 
            ? _discoveryService.getNearbyNow(lat: _userLat!, lng: _userLng!)
            : Future.value(<RestaurantWithScore>[]),
        _discoveryService.getBudgetEats(lat: _userLat, lng: _userLng),
        _discoveryService.getRecommended(lat: _userLat, lng: _userLng),
        _discoveryService.getHiddenGems(lat: _userLat, lng: _userLng),
        _discoveryService.getNewlyAdded(lat: _userLat, lng: _userLng),
        _discoveryService.getAreas(lat: _userLat, lng: _userLng), // Pass live location here
      ]);

      if (mounted) {
        setState(() {
          _trendingDishes = results[0] as List<Dish>;
          _popularDishes = results[1] as List<Dish>;
          _topRated = results[2] as List<RestaurantWithScore>;
          _nearbyNow = results[3] as List<RestaurantWithScore>;
          _budgetEats = results[4] as List<Dish>;
          _recommended = results[5] as List<RestaurantWithScore>;
          _hiddenGems = results[6] as List<RestaurantWithScore>;
          _newlyAdded = results[7] as List<RestaurantWithScore>;
          _areas = results[8] as List<String>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentLocationName = 'Global';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: Color(0xFFFFD700), size: 16),
              const SizedBox(width: 4),
              Text(_currentLocationName, style: TextStyle(color: colors.onSurface, fontSize: 14)),
              Icon(Icons.keyboard_arrow_down, color: colors.onSurfaceVariant, size: 16),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchDiscoveryData,
            icon: Icon(Icons.refresh, color: colors.onSurface),
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : RefreshIndicator(
              onRefresh: _fetchDiscoveryData,
              color: const Color(0xFFFFD700),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDishSection('🔥 Trending Dishes This Week', _trendingDishes),
                    _buildDishSection('🍽️ Popular Dishes Near You', _popularDishes),
                    _buildRestaurantSection('⭐ Top Rated Restaurants', _topRated),
                    _buildRestaurantSection('🚶 Nearby Right Now', _nearbyNow),
                    _buildDishSection('💰 Best Budget Eats', _budgetEats),
                    _buildRestaurantSection('🎯 Recommended For You', _recommended),
                    _buildRestaurantSection('💎 Hidden Gems', _hiddenGems),
                    _buildRestaurantSection('🆕 Newly Added', _newlyAdded),
                    _buildAreaSection('🗺️ Explore by Area', _areas),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDishSection(String title, List<Dish> dishes) {
    if (dishes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: dishes.length,
            itemBuilder: (context, index) => _buildDishCard(dishes[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantSection(String title, List<RestaurantWithScore> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: items.length,
            itemBuilder: (context, index) => _buildRestaurantCard(items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaSection(String title, List<String> areas) {
    final colors = Theme.of(context).colorScheme;
    if (areas.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: areas.length,
            itemBuilder: (context, index) => Container(
              margin: const EdgeInsets.only(right: 12),
              child: ActionChip(
                backgroundColor: colors.surfaceContainerLow,
                side: BorderSide(color: colors.outlineVariant),
                label: Text(areas[index], style: TextStyle(color: colors.onSurfaceVariant)),
                onPressed: () {
                  Navigator.pushNamed(context, '/search', arguments: areas[index]);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
      child: Text(
        title, 
        style: TextStyle(color: colors.onSurface, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif')
      ),
    );
  }

  Widget _buildDishCard(Dish dish) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/dish-details', arguments: dish),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                dish.imageUrl, 
                height: 100, 
                width: 160, 
                fit: BoxFit.cover, 
                errorBuilder: (_, __, ___) => Container(color: colors.surfaceContainerHighest, height: 100, child: Icon(Icons.fastfood, color: colors.onSurfaceVariant))
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.name, style: TextStyle(color: colors.onSurface, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(dish.restaurantName ?? '', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text('৳${dish.price.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(RestaurantWithScore item) {
    final colors = Theme.of(context).colorScheme;
    final r = item.restaurant;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
      child: Container(
        width: 250,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                image: DecorationImage(
                  image: NetworkImage(r.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: TextStyle(color: colors.onSurface, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${r.categoryDisplay} • ${r.address}', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                          const SizedBox(width: 4),
                          Text(r.rating.toStringAsFixed(1), style: TextStyle(color: colors.onSurface, fontSize: 12)),
                        ],
                      ),
                      Text(item.scoreLabel, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
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
