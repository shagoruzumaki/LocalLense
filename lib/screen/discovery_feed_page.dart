import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/discovery_service.dart';
import '../services/top10_service.dart';
import '../services/location_service.dart';
import '../services/restaurant_service.dart';
import '../model/restaurant.dart';
import '../model/dish.dart';

class DiscoveryFeedPage extends StatefulWidget {
  const DiscoveryFeedPage({super.key});

  @override
  State<DiscoveryFeedPage> createState() => _DiscoveryFeedPageState();
}

class _DiscoveryFeedPageState extends State<DiscoveryFeedPage> {
  final DiscoveryService _discoveryService = DiscoveryService();
  final Top10Service _top10Service = Top10Service();
  final LocationService _locationService = LocationService();
  final RestaurantService _restaurantService = RestaurantService();
  final TextEditingController _searchController = TextEditingController();

  List<RestaurantWithScore> _topRankedNearYou = [];
  List<Restaurant> _top10Restaurants = [];
  List<Map<String, dynamic>> _top10Critics = [];
  List<Dish> _budgetEats = [];
  List<RestaurantWithScore> _searchResults = [];
  
  bool _isLoading = true;
  bool _isSearching = false;
  String _selectedFilter = 'All';
  String _currentLocationName = 'Loading...';
  double? _userLat;
  double? _userLng;

  StreamSubscription? _reviewSubscription;
  StreamSubscription? _restaurantSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _reviewSubscription?.cancel();
    _restaurantSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Real-time updates: Automatically refresh data
  // when any review or restaurant record changes
  // ─────────────────────────────────────────────
  void _setupRealtime() {
    final supabase = Supabase.instance.client;
    
    // Listen for new reviews or changes to trigger refresh
    _reviewSubscription = supabase
        .from('reviews')
        .stream(primaryKey: ['id'])
        .listen((_) => _loadData(silent: true));

    // Listen for restaurant changes (score updates, etc.)
    _restaurantSubscription = supabase
        .from('restaurants')
        .stream(primaryKey: ['id'])
        .listen((_) => _loadData(silent: true));
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
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

      final results = await Future.wait([
        _userLat != null 
          ? _discoveryService.getNearby(lat: _userLat!, lng: _userLng!, radiusKm: 10)
          : Future.value(<RestaurantWithScore>[]),
        _top10Service.getTopRestaurantsByPeriod(filter: 'alltime'),
        _top10Service.getTopCritics(filter: 'alltime'),
        _discoveryService.getBudgetEats(lat: _userLat, lng: _userLng),
      ]);

      if (mounted) {
        setState(() {
          _topRankedNearYou = (results[0] as List<RestaurantWithScore>).take(10).toList();
          _top10Restaurants = (results[1] as List<Restaurant>).take(10).toList();
          _top10Critics = (results[2] as List<Map<String, dynamic>>).take(10).toList();
          _budgetEats = results[3] as List<Dish>;
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

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _discoveryService.searchRestaurants(query, lat: _userLat, lng: _userLng);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _applyFilter(String filter) async {
    setState(() {
      _selectedFilter = filter;
      _isLoading = true;
    });
    
    try {
      final filters = RestaurantFilters(
        category: filter == 'All' ? null : filter,
        userLat: _userLat,
        userLng: _userLng,
      );
      final results = await _discoveryService.getRestaurants(filters);
      
      if (mounted) {
        setState(() {
          _topRankedNearYou = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
            icon: Icon(Icons.notifications_outlined, color: colors.onSurface),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.tune, color: colors.onSurface),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
        : RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFFFFD700),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    onChanged: _handleSearch,
                    decoration: InputDecoration(
                      hintText: 'Search for dishes or places...',
                      hintStyle: TextStyle(color: colors.onSurfaceVariant),
                      prefixIcon: Icon(Icons.search, color: colors.onSurfaceVariant),
                      filled: true,
                      fillColor: colors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isSearching) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Search Results',
                          style: TextStyle(color: colors.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: colors.onSurfaceVariant, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _handleSearch('');
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 15),
                    _searchResults.isEmpty 
                      ? Text('No results found', style: TextStyle(color: colors.onSurfaceVariant))
                      : Column(
                          children: _searchResults.map((r) => _buildRankingMiniItem(
                            '', 
                            r.restaurant.name, 
                            r.restaurant.categoryDisplay, 
                            r.restaurant.rating.toStringAsFixed(1),
                            imageUrl: r.restaurant.imageUrl,
                            onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.restaurant.id),
                          )).toList(),
                        ),
                    const SizedBox(height: 30),
                  ] else ...[
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildFilterChip('All', isSelected: _selectedFilter == 'All'),
                          _buildFilterChip('Restaurants', isSelected: _selectedFilter == 'Restaurants'),
                          _buildFilterChip('Cafes', isSelected: _selectedFilter == 'Cafes'),
                          _buildFilterChip('Street Food', isSelected: _selectedFilter == 'Street Food'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Icon(Icons.emoji_events_outlined, color: colors.primary, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Top 10',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "This week's best in $_currentLocationName",
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    _buildTop10Section('Top 10 Restaurants', _top10Restaurants.asMap().entries.map((entry) {
                      int idx = entry.key;
                      Restaurant r = entry.value;
                      return _buildRankingMiniItem(
                        '#${idx + 1}', 
                        r.name, 
                        r.categoryDisplay, 
                        r.rating.toStringAsFixed(1),
                        imageUrl: r.imageUrl,
                        onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
                      );
                    }).toList()),
                    const SizedBox(height: 20),
                    _buildTop10Section('Top 10 Critics', _top10Critics.map((c) {
                      return _buildCriticMiniItem(
                        c['name'] ?? 'Unknown', 
                        '${c['helpful_votes'] ?? 0} Votes', 
                        '${c['rank_score'] ?? 0} Points', 
                        (c['tier'] ?? 'EXPLORER').toString().toUpperCase(),
                        photoUrl: c['profile_photo_url'],
                      );
                    }).toList(), icon: Icons.verified_user_outlined),
                    const SizedBox(height: 30),
                    
                    // ─────────────────────────────────────────────
                    // TOP RANKED NEAR YOU
                    // ─────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Top Ranked Near You',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/ranking'),
                          child: const Text(
                            'SEE ALL',
                            style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 200,
                      child: _topRankedNearYou.isEmpty 
                        ? Center(child: Text('No restaurants nearby', style: TextStyle(color: colors.onSurfaceVariant)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _topRankedNearYou.length,
                            itemBuilder: (context, index) {
                              final r = _topRankedNearYou[index];
                              return _buildNearYouCard(
                                r.restaurant.name, 
                                '${r.restaurant.categoryDisplay} • ${r.restaurant.address}', 
                                r.restaurant.rating.toStringAsFixed(1), 
                                r.scoreLabel.toUpperCase(),
                                imageUrl: r.restaurant.imageUrl,
                                onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.restaurant.id),
                              );
                            },
                          ),
                    ),
                    const SizedBox(height: 30),

                    // ─────────────────────────────────────────────
                    // 💰 BEST BUDGET EATS
                    // ─────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text('💰', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 8),
                            Text(
                              'Best Budget Eats',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'serif',
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'UNDER ৳ 250',
                          style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 220,
                      child: _budgetEats.isEmpty 
                        ? Center(child: Text('No budget eats found', style: TextStyle(color: colors.onSurfaceVariant)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _budgetEats.length,
                            itemBuilder: (context, index) {
                              final dish = _budgetEats[index];
                              return _buildDishCard(
                                dish.name,
                                dish.restaurantName ?? 'Unknown',
                                '৳ ${dish.price.toStringAsFixed(0)}',
                                dish.restaurantRating?.toStringAsFixed(1) ?? '0.0',
                                imageUrl: dish.imageUrl,
                                onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: dish.restaurantId),
                              );
                            },
                          ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false}) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _applyFilter(label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colors.onPrimary : colors.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTop10Section(String title, List<Widget> items, {IconData icon = Icons.restaurant}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(color: colors.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Icon(icon, color: colors.primary, size: 18),
            ],
          ),
          const SizedBox(height: 15),
          ...items,
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/ranking'),
              icon: const Text('See Full List', style: TextStyle(color: Color(0xFFFFD700))),
              label: const Icon(Icons.arrow_forward, color: Color(0xFFFFD700), size: 16),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingMiniItem(String rank, String title, String category, String rating, {String? imageUrl, VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            if (rank.isNotEmpty) ...[
              SizedBox(width: 25, child: Text(rank, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12))),
              const SizedBox(width: 4),
            ],
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: colors.surfaceContainerHighest,
                image: imageUrl != null ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('$category • $rating ★', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticMiniItem(String name, String reviews, String points, String level, {String? photoUrl}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20, 
            backgroundColor: colors.surfaceContainerHighest,
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: (photoUrl == null || photoUrl.isEmpty) ? Icon(Icons.person, size: 16, color: colors.onSurfaceVariant) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle, color: Colors.green, size: 14),
                  ],
                ),
                Text('$reviews • $points', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
            ),
            child: Text(
              level,
              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearYouCard(String title, String subtitle, String rating, String badge, {String? imageUrl, VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
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
            Stack(
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    color: colors.surfaceContainerHighest,
                    image: imageUrl != null ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
                  ),
                ),
                if (badge.isNotEmpty)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(title, style: TextStyle(color: colors.onSurface, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                          Text(rating, style: TextStyle(color: colors.onSurface, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishCard(String title, String restaurant, String price, String rating, {String? imageUrl, VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
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
                color: colors.surfaceContainerHighest,
                image: imageUrl != null ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: colors.onSurface, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(restaurant, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(price, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFFFD700), size: 12),
                          const SizedBox(width: 2),
                          Text(rating, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
                        ],
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
