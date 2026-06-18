import 'package:flutter/material.dart';
import '../services/discovery_service.dart';
import '../services/location_service.dart';
import '../model/restaurant.dart';
import '../model/dish.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery;
  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _performSearch();
    }

    _initLocation().then((_) {
      if (widget.initialQuery != null) {
        _performSearch();
      }
    });

    if (widget.initialQuery == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocus.requestFocus();
      });
    }
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
      final resultsFuture = _discoveryService.searchRestaurants(
        query,
        lat: _userLat,
        lng: _userLng,
        searchByDish: true,
      );

      final dishesFuture = _discoveryService.searchDishes(query);

      final responses = await Future.wait([resultsFuture, dishesFuture]);

      if (mounted) {
        setState(() {
          _results = responses[0] as List<RestaurantWithScore>;
          _dishResults = responses[1] as List<Dish>;
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
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: (value) => _performSearch(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search for dishes or places...',
              hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white30,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.cancel,
                        color: Colors.white30,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white10, width: 0.5),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFD70F64),
              indicatorWeight: 3,
              labelColor: const Color(0xFFD70F64),
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Restaurants'),
                Tab(text: 'Menu items'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildRestaurantResults(), _buildDishResults()],
            ),
    );
  }

  Widget _buildRestaurantResults() {
    if (_searchController.text.isEmpty) return _buildInitialView();
    if (_results.isEmpty) return _buildNoResultsView();

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildRestaurantCard(_results[index]),
    );
  }

  Widget _buildDishResults() {
    if (_searchController.text.isEmpty) return _buildInitialView();
    if (_dishResults.isEmpty) return _buildNoResultsView();

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _dishResults.length,
      itemBuilder: (context, index) => _buildDishCard(_dishResults[index]),
    );
  }

  Widget _buildInitialView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            'Search for your favorite spots',
            style: TextStyle(color: Colors.white.withOpacity(0.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 100,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No results found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We couldn\'t find any restaurants or dishes matching "${_searchController.text}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishCard(Dish dish) {
    final dishRating = dish.avgRating;
    final dishReviewCount = dish.reviewCount;

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/dish-details', arguments: dish),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white10,
                  child: const Icon(
                    Icons.fastfood,
                    size: 30,
                    color: Colors.white38,
                  ),
                ),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '৳${dish.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dish.restaurantName ?? ''} • ${dish.restaurantAddress ?? ''}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFD700),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dishRating != null && dishReviewCount > 0
                            ? '${dishRating.toStringAsFixed(1)} ($dishReviewCount)'
                            : 'No ratings yet',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white24,
                        size: 12,
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
      onTap: () =>
          Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white10,
                  child: const Icon(
                    Icons.restaurant,
                    size: 30,
                    color: Colors.white38,
                  ),
                ),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        item.scoreLabel.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.address,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '৳' * r.priceTier,
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• ${r.categoryDisplay}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                      if (item.distanceKm != null) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.near_me,
                          color: Colors.white38,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const Spacer(),
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFD700),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        r.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
