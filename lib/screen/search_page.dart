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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {}); // Update UI when tab changes
      }
    });
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
      // Perform both searches
      final resultsFuture = _discoveryService.searchRestaurants(
        query,
        lat: _userLat,
        lng: _userLng,
        searchByDish: false,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(25),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: (value) => _performSearch(),
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search for dishes or places...',
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
              suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
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
              border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFD70F64),
              indicatorWeight: 3,
              labelColor: const Color(0xFFD70F64),
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Restaurants'),
                Tab(text: 'Menu items'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD70F64)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRestaurantResults(),
                _buildDishResults(),
              ],
            ),
    );
  }

  Widget _buildRestaurantResults() {
    if (_searchController.text.isEmpty) return _buildInitialView();
    if (_results.isEmpty) return _buildNoResultsView();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildRestaurantCard(_results[index]),
    );
  }

  Widget _buildDishResults() {
    if (_searchController.text.isEmpty) return _buildInitialView();
    if (_dishResults.isEmpty) return _buildNoResultsView();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _dishResults.length,
      itemBuilder: (context, index) => _buildDishCard(_dishResults[index]),
    );
  }

  Widget _buildInitialView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text('Search for your favorite spots', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text('No results found', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildDishCard(Dish dish) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/dish-details', arguments: dish),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  dish.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey[100]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(dish.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text('Tk ${dish.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFD70F64))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text('${dish.restaurantName} • ${dish.restaurantAddress ?? "Sylhet"}', style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (dish.restaurantRating != null) ...[
                        const Icon(Icons.star, color: Colors.orange, size: 14),
                        const SizedBox(width: 2),
                        Text(dish.restaurantRating!.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
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
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(r.imageUrl, width: 70, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[100])),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(r.categoryDisplay, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.orange, size: 14),
                      const SizedBox(width: 2),
                      Text(r.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('• ${r.address}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
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
