import 'package:flutter/material.dart';
import '../services/discovery_service.dart';
import '../services/location_service.dart';
import '../services/restaurant_service.dart';
import '../services/top10_service.dart';
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
  final Top10Service _top10Service = Top10Service();
  
  List<RestaurantWithScore> _restaurants = [];
  List<Dish> _dishResults = [];
  List<Restaurant> _trendingRestaurants = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _currentLocationName = 'Nearby Spots';
  double? _userLat;
  double? _userLng;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      final hasPermission = await _locationService.checkPermission();
      if (hasPermission) {
        final position = await _locationService.getCurrentLocation();
        _userLat = position.latitude;
        _userLng = position.longitude;
        _currentLocationName = await _restaurantService.getNeighbourhoodName(_userLat!, _userLng!);
      } else {
        _userLat = 23.8103;
        _userLng = 90.4125;
        _currentLocationName = 'Dhaka';
      }

      final results = await Future.wait([
        _discoveryService.getNearby(lat: _userLat!, lng: _userLng!, radiusKm: 10),
        _top10Service.getTopRestaurantsByPeriod(filter: 'week'),
      ]);

      if (mounted) {
        setState(() {
          _restaurants = results[0] as List<RestaurantWithScore>;
          _trendingRestaurants = (results[1] as List<Restaurant>).take(10).toList();
          _dishResults = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentLocationName = 'Nearby';
        });
      }
    }
  }

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) {
      _fetchInitialData();
      return;
    }
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        _discoveryService.searchRestaurants(query, lat: _userLat, lng: _userLng),
        _discoveryService.searchDishes(query),
      ]);

      if (mounted) {
        setState(() {
          _restaurants = results[0] as List<RestaurantWithScore>;
          _dishResults = results[1] as List<Dish>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });
    final filters = RestaurantFilters(
      category: category == 'All' ? null : category.toLowerCase().replaceAll(' ', '_'),
      userLat: _userLat,
      userLng: _userLng,
    );
    final results = await _discoveryService.getRestaurants(filters);
    if (mounted) {
      setState(() {
        _restaurants = results;
        _dishResults = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: Color(0xFFFFD700), size: 16),
              const SizedBox(width: 4),
              Text(_currentLocationName, style: const TextStyle(color: Colors.white, fontSize: 14)),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchInitialData,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: _handleSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search for dishes or places...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () { _searchController.clear(); _fetchInitialData(); }) : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip('All', isSelected: _selectedCategory == 'All'),
                  _buildFilterChip('Restaurant', isSelected: _selectedCategory == 'Restaurant'),
                  _buildFilterChip('Cafe', isSelected: _selectedCategory == 'Cafe'),
                  _buildFilterChip('Street Food', isSelected: _selectedCategory == 'Street Food'),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFFFFD700))))
            else ...[
              if (_dishResults.isNotEmpty) ...[
                const Text('Menu Items', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                const SizedBox(height: 15),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dishResults.length,
                    itemBuilder: (context, index) => _buildDishCard(_dishResults[index]),
                  ),
                ),
                const SizedBox(height: 30),
              ],
              
              Text(
                _searchController.text.isEmpty ? 'Real Spots Near You' : 'Restaurants',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif'),
              ),
              const SizedBox(height: 15),
              _restaurants.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No restaurants found', style: TextStyle(color: Colors.white54))))
                  : SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _restaurants.length,
                        itemBuilder: (context, index) => _buildNearYouCard(_restaurants[index]),
                      ),
                    ),
            ],

            const SizedBox(height: 30),
            if (_searchController.text.isEmpty)
              _buildTop10Section('Trending This Week', _trendingRestaurants.asMap().entries.map((entry) {
                int idx = entry.key;
                Restaurant r = entry.value;
                return _buildRankingMiniItem(
                  '#${idx + 1}', 
                  r.name, 
                  r.categoryDisplay, 
                  r.rating.toStringAsFixed(1),
                  onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
                );
              }).toList()),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildDishCard(Dish dish) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/dish-details', arguments: dish),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(dish.imageUrl, height: 100, width: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white10, height: 100, child: const Icon(Icons.fastfood, color: Colors.white38))),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(dish.restaurantName ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
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

  Widget _buildNearYouCard(RestaurantWithScore item) {
    final r = item.restaurant;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
      child: Container(
        width: 250,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
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
                  Text(
                    r.name,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.categoryDisplay} • ${r.address}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                          const SizedBox(width: 4),
                          Text(r.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 12)),
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

  Widget _buildTop10Section(String title, List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/ranking'),
                child: const Text('SEE ALL', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (items.isEmpty)
            const Center(child: Text('Loading trends...', style: TextStyle(color: Colors.white38)))
          else
            ...items,
        ],
      ),
    );
  }

  Widget _buildRankingMiniItem(String rank, String title, String category, String rating, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Text(rank, style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 12),
            const Icon(Icons.restaurant, color: Color(0xFFFFD700), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('$category • $rating ★', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false}) {
    return GestureDetector(
      onTap: () => _applyFilter(label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
