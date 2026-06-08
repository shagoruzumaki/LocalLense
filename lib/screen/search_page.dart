import 'package:flutter/material.dart';
import '../services/discovery_service.dart';
import '../services/location_service.dart';
import '../model/restaurant.dart';

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
  List<Map<String, dynamic>> _dishResults = [];
  bool _isLoading = false;
  double? _userLat;
  double? _userLng;

  // Filters
  SortOption _selectedSort = SortOption.score;
  bool _filterOpenNow = false;

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
      final results = await _discoveryService.searchRestaurants(
        query,
        lat: _userLat,
        lng: _userLng,
        sortBy: _selectedSort,
      );
      
      final dishes = await _discoveryService.searchDishes(query);

      if (mounted) {
        setState(() {
          _results = _filterOpenNow 
              ? results.where((r) => r.isOpenNow).toList()
              : results;
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: (value) => _performSearch(),
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search for restaurants, cuisines and dishes',
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
              onPressed: () {
                _searchController.clear();
                _performSearch();
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD70F64),
          labelColor: const Color(0xFFD70F64),
          unselectedLabelColor: Colors.grey[600],
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Restaurants'),
            Tab(text: 'Shops'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(color: Colors.black12, height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD70F64)))
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
          _buildFilterIconChip(),
          const SizedBox(width: 8),
          _buildPillChip('Delivery', isSelected: true),
          const SizedBox(width: 8),
          _buildPillChip('Pick-Up'),
          const SizedBox(width: 8),
          _buildDropdownChip('Sort'),
          const SizedBox(width: 8),
          _buildPillChip('Free delivery'),
          const SizedBox(width: 8),
          _buildFilterChip('Best Rated', SortOption.score),
        ],
      ),
    );
  }

  Widget _buildFilterIconChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Icon(Icons.tune, size: 18, color: Colors.grey[700]),
    );
  }

  Widget _buildPillChip(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? Colors.black87 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? Colors.black87 : Colors.grey[300]!),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[800],
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildDropdownChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey[700]),
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
          color: isSelected ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.black87 : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
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
            Icon(Icons.search, size: 80, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text(
              'Search for your favorite spots',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty && _dishResults.isEmpty) {
      return Center(
        child: Text('No results found', style: TextStyle(color: Colors.grey[400])),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ..._results.map((item) => _buildRestaurantCard(item)).toList(),
        if (_dishResults.isNotEmpty) _buildRecommendedSection(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRestaurantCard(RestaurantWithScore item) {
    final r = item.restaurant;
    final bool isClosed = !item.isOpenNow;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          r.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.restaurant, color: Colors.grey)),
                        ),
                        if (isClosed)
                          Container(
                            color: Colors.black.withOpacity(0.4),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Opens at Tue, 11:00 am',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                        // Badge on image
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${r.name.split(' ').first} • Tk60',
                              style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        // Pagination dots
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) => Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == 0 ? Colors.white : Colors.white.withOpacity(0.5),
                              ),
                            )),
                          ),
                        ),
                        // Ad label
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Ad', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Heart icon
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_border, size: 18, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          // Promo bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFD70F64).withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium, color: Color(0xFFD70F64), size: 14),
                const SizedBox(width: 8),
                Text(
                  'PRO Tk50 off delivery with Tk350 spend',
                  style: TextStyle(color: const Color(0xFFD70F64), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        r.name,
                        style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          r.rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          ' (5k+)',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'From 65 min • ৳৳৳ • Bangladeshi • Price Match',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.delivery_dining, color: Color(0xFFD70F64), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'From Tk64 with Saver',
                      style: TextStyle(color: Colors.grey[800], fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_up, color: Colors.orange, size: 14),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection() {
    final query = _searchController.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Recommended "$query" for you',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _dishResults.length,
            itemBuilder: (context, index) {
              final dish = _dishResults[index];
              final restaurant = dish['restaurants'] as Map<String, dynamic>? ?? {};
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        dish['photo_url'] ?? 'https://via.placeholder.com/100',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  restaurant['name'] ?? '',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.orange, size: 12),
                                  const SizedBox(width: 2),
                                  Text(
                                    (restaurant['algorithm_score'] ?? 0.0 / 20.0).toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dish['name'] ?? '',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tk${dish['price']}',
                            style: TextStyle(color: Colors.grey[800], fontSize: 13),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.grey, size: 12),
                              const SizedBox(width: 4),
                              Text('20 mins', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                              const SizedBox(width: 8),
                              const Icon(Icons.delivery_dining, color: Colors.grey, size: 12),
                              const SizedBox(width: 4),
                              Text('Tk 71', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
