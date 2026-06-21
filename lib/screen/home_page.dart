import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/restaurant_service.dart';
import '../services/top10_service.dart';
import '../services/location_service.dart';
import '../services/discovery_service.dart';
import '../services/user_service.dart';
import '../model/restaurant.dart';
import '../model/dish.dart';
import 'ranking_page.dart';
import 'reviewer_profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final RestaurantService _restaurantService = RestaurantService();
  final Top10Service _top10Service = Top10Service();
  final LocationService _locationService = LocationService();
  final DiscoveryService _discoveryService = DiscoveryService();
  final UserService _userService = UserService();

  late Future<List<RestaurantWithScore>> _nearbyRestaurantsFuture;
  late Future<List<Restaurant>> _top10RestaurantsFuture;
  late Future<List<Map<String, dynamic>>> _top10CriticsFuture;
  late TabController _searchTabController;

  String _neighbourhood = 'Nearby';
  double? _userLat;
  double? _userLng;
  String? _userPhotoUrl;

  final TextEditingController _searchController = TextEditingController();
  List<RestaurantWithScore> _searchResults = [];
  List<Dish> _dishResults = [];
  bool _isSearching = false;
  bool _isLoadingSearch = false;
  SortOption _currentSort = SortOption.score;

  @override
  void initState() {
    super.initState();
    _searchTabController = TabController(length: 2, vsync: this);
    _searchTabController.addListener(() {
      if (!_searchTabController.indexIsChanging) {
        setState(() {});
      }
    });

    // Initial placeholders
    _top10RestaurantsFuture = Future.value([]);
    _top10CriticsFuture = Future.value([]);
    _nearbyRestaurantsFuture = Future.value([]);

    _loadData();
    _fetchUserPhoto();
  }

  @override
  void dispose() {
    _searchTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserPhoto() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final result = await _userService.getUserProfile(user.id);
      if (result.isSuccess && result.data != null) {
        if (mounted) {
          setState(() {
            _userPhotoUrl = result.data!['profile_photo_url'];
          });
        }
      }
    }
  }

  Future<void> _loadData() async {
    double? lat;
    double? lng;
    String currentNeighbourhood = 'Global';

    try {
      final hasPermission = await _locationService.checkPermission();
      if (hasPermission) {
        final pos = await _locationService.getCurrentLocation();
        lat = pos.latitude;
        lng = pos.longitude;
        _userLat = lat;
        _userLng = lng;
        currentNeighbourhood = await _restaurantService.getNeighbourhoodName(
          lat,
          lng,
        );
      }
    } catch (_) {
      currentNeighbourhood = 'Global';
    }

    if (mounted) {
      setState(() {
        _neighbourhood = currentNeighbourhood;
        if (lat != null && lng != null) {
          _nearbyRestaurantsFuture = _discoveryService.getNearby(
            lat: lat,
            lng: lng,
            radiusKm: 10,
          );
        } else {
          _nearbyRestaurantsFuture = Future.value([]);
        }

        // Show All-Time Top 10 on Home Page
        _top10RestaurantsFuture = _top10Service.getTopRestaurantsByPeriod(
          filter: 'alltime',
          neighbourhood: currentNeighbourhood == 'Global'
              ? null
              : currentNeighbourhood,
        );
        _top10CriticsFuture = _top10Service.getTopCritics(
          filter: 'alltime',
          neighbourhood: currentNeighbourhood == 'Global'
              ? null
              : currentNeighbourhood,
        );
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _dishResults = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _isLoadingSearch = true;
    });
    try {
      final results = await _discoveryService.searchRestaurants(
        query,
        lat: _userLat,
        lng: _userLng,
        sortBy: _currentSort,
        searchByDish: false,
      );
      final dishes = await _discoveryService.searchDishes(
        query,
        lat: _userLat,
        lng: _userLng,
        sortBy: _currentSort,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _dishResults = dishes;
          _isLoadingSearch = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSearch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadData();
            await _fetchUserPhoto();
          },
          color: const Color(0xFFFFD700),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFFFFD700),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _neighbourhood,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.notifications_outlined,
                        color: colors.onSurface,
                        size: 28,
                      ),
                      const SizedBox(width: 15),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: colors.surfaceContainerHighest,
                          backgroundImage:
                              (_userPhotoUrl != null &&
                                  _userPhotoUrl!.isNotEmpty)
                              ? NetworkImage(_userPhotoUrl!)
                              : null,
                          child:
                              (_userPhotoUrl == null || _userPhotoUrl!.isEmpty)
                              ? Icon(
                                  Icons.person,
                                  size: 18,
                                  color: colors.onSurfaceVariant,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'What are you craving?',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _performSearch,
                    decoration: InputDecoration(
                      hintText: 'Search for dishes or places...',
                      hintStyle: TextStyle(color: colors.onSurfaceVariant),
                      prefixIcon: Icon(
                        Icons.search,
                        color: colors.onSurfaceVariant,
                      ),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: Icon(
                                Icons.close,
                                color: colors.onSurfaceVariant,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _isSearching = false;
                                  _searchResults = [];
                                  _dishResults = [];
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_isSearching) ...[
                  const SizedBox(height: 10),
                  TabBar(
                    controller: _searchTabController,
                    indicatorColor: const Color(0xFFFFD700),
                    indicatorWeight: 3,
                    labelColor: const Color(0xFFFFD700),
                    unselectedLabelColor: colors.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Restaurants'),
                      Tab(text: 'Menu items'),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildSortChip('Best Score', SortOption.score),
                        const SizedBox(width: 10),
                        _buildSortChip('Nearest', SortOption.nearest),
                        const SizedBox(width: 10),
                        _buildSortChip('Budget', SortOption.budget),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSearchResults(),
                ] else ...[
                  const SizedBox(height: 30),
                  _buildMainContent(),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(canvasColor: colors.surface),
        child: BottomNavigationBar(
          backgroundColor: colors.surface,
          selectedItemColor: const Color(0xFFFFD700),
          unselectedItemColor: colors.onSurfaceVariant,
          type: BottomNavigationBarType.fixed,
          currentIndex: 0,
          onTap: (index) {
            if (index == 1) Navigator.pushNamed(context, '/discover');
            if (index == 2) Navigator.pushNamed(context, '/map');
            if (index == 3) Navigator.pushNamed(context, '/profile');
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'HOME',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              label: 'DISCOVER',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              label: 'MAP',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'PROFILE',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, SortOption option) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = _currentSort == option;
    return GestureDetector(
      onTap: () {
        setState(() => _currentSort = option);
        _performSearch(_searchController.text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : colors.surfaceContainerLow,
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
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final colors = Theme.of(context).colorScheme;
    if (_isLoadingSearch)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        ),
      );

    if (_searchTabController.index == 0) {
      if (_searchResults.isEmpty)
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              'No restaurants found',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        );
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final item = _searchResults[index];
          final r = item.restaurant;
          return _buildOpenNowItem(
            context: context,
            title: r.name,
            location: r.address,
            priceText: '৳' * r.priceTier,
            category: r.categoryDisplay,
            rating: r.rating.toStringAsFixed(1),
            imageUrl: r.imageUrl,
            scoreLabel: item.scoreLabel.toUpperCase(),
            distance: item.distanceKm,
            onTap: () => Navigator.pushNamed(
              context,
              '/restaurant-details',
              arguments: r.id,
            ),
          );
        },
      );
    } else {
      if (_dishResults.isEmpty)
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              'No menu items found',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        );
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _dishResults.length,
        itemBuilder: (context, index) =>
            _buildDishItem(context: context, dish: _dishResults[index]),
      );
    }
  }

  Widget _buildMainContent() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          '🏆',
          'Top 10 Leaderboard',
          'The absolute best spots in $_neighbourhood',
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: FutureBuilder<List<Restaurant>>(
              future: _top10RestaurantsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const SizedBox(
                    height: 150,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  );
                final topList = snapshot.data ?? [];
                final displayList = topList.take(10).toList();
                return Column(
                  children: [
                    _buildListHeader('Top 10 Restaurants', Icons.auto_awesome),
                    Divider(color: colors.outlineVariant, height: 1),
                    if (displayList.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No rankings available',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      )
                    else
                      ...displayList.asMap().entries.map((entry) {
                        int idx = entry.key;
                        Restaurant r = entry.value;
                        return _buildTop10RestaurantRow(
                          rank: '#${idx + 1}',
                          name: r.name,
                          category: r.categoryDisplay,
                          rating: r.rating.toStringAsFixed(1),
                          imageUrl: r.imageUrl,
                          isLast: idx == displayList.length - 1,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/restaurant-details',
                            arguments: r.id,
                          ),
                        );
                      }),
                    _buildSeeMoreButton(
                      'See Full List',
                      () => Navigator.pushNamed(context, '/ranking'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('💎', 'Elite Critics', 'Top reviewers of all time'),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _top10CriticsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const SizedBox(
                    height: 120,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  );
                final critics = snapshot.data ?? [];
                final displayCritics = critics.take(10).toList();
                return Column(
                  children: [
                    _buildListHeader(
                      'Top 10 Critics',
                      Icons.verified_user_outlined,
                    ),
                    Divider(color: colors.outlineVariant, height: 1),
                    if (displayCritics.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No critics ranked yet',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      )
                    else
                      ...displayCritics.asMap().entries.map((entry) {
                        int idx = entry.key;
                        var c = entry.value;
                        return _buildTop10CriticRow(
                          rank: '#${idx + 1}',
                          name: c['name'] ?? 'Critic',
                          tier: (c['tier'] ?? 'EXPLORER')
                              .toString()
                              .toUpperCase(),
                          points: '${c['helpful_votes'] ?? 0} Pts',
                          photoUrl: c['profile_photo_url'],
                          isLast: idx == displayCritics.length - 1,
                          onTap: () {
                            if (c['id'] != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ReviewerProfilePage(userId: c['id']),
                                ),
                              );
                            }
                          },
                        );
                      }),
                    _buildSeeMoreButton('View Leaderboard', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const RankingPage(initialIndex: 1),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.circle, color: Colors.green, size: 10),
                  const SizedBox(width: 6),
                  Text(
                    'Found Near You',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/discover'),
                child: Text(
                  'SEE ALL',
                  style: TextStyle(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        FutureBuilder<List<RestaurantWithScore>>(
          future: _nearbyRestaurantsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                ),
              );
            if (!snapshot.hasData || snapshot.data!.isEmpty)
              return Center(
                child: Text(
                  'No real spots found nearby',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              );
            final data = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: data.length > 5 ? 5 : data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                final r = item.restaurant;
                return _buildOpenNowItem(
                  context: context,
                  title: r.name,
                  location: r.address,
                  priceText: '৳' * r.priceTier,
                  category: r.categoryDisplay,
                  rating: r.rating.toStringAsFixed(1),
                  imageUrl: r.imageUrl,
                  scoreLabel: item.scoreLabel.toUpperCase(),
                  distance: item.distanceKm,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/restaurant-details',
                    arguments: r.id,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String emoji, String title, String subtitle) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8A7A50),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(String title, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Icon(
            icon,
            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildSeeMoreButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, color: Color(0xFFFFD700), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildTop10RestaurantRow({
    required String rank,
    required String name,
    required String category,
    required String rating,
    required String imageUrl,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    rank,
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: colors.surfaceContainerHighest,
                      child: const Icon(Icons.restaurant, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        category,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFD700), size: 13),
                    const SizedBox(width: 3),
                    Text(
                      rating,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            color: colors.outlineVariant,
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }

  Widget _buildTop10CriticRow({
    required String rank,
    required String name,
    required String tier,
    required String points,
    String? photoUrl,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    rank,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.surfaceContainerHighest,
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Icon(
                          Icons.person,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        tier,
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  points,
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            color: colors.outlineVariant,
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }

  Widget _buildOpenNowItem({
    required BuildContext context,
    required String title,
    required String location,
    required String priceText,
    required String category,
    required String rating,
    required String imageUrl,
    required String scoreLabel,
    double? distance,
    VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: colors.surfaceContainerHighest,
                  child: const Icon(Icons.restaurant, size: 30),
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
                          title,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        scoreLabel,
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
                    location,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        priceText,
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• $category',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      if (distance != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.near_me,
                          color: colors.onSurfaceVariant,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${distance.toStringAsFixed(1)} km',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
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
                        rating,
                        style: TextStyle(
                          color: colors.onSurface,
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

  Widget _buildDishItem({required BuildContext context, required Dish dish}) {
    final colors = Theme.of(context).colorScheme;
    final dishRating = dish.avgRating;
    final dishReviewCount = dish.reviewCount;

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/dish-details', arguments: dish),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
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
                  color: colors.surfaceContainerHighest,
                  child: Icon(
                    Icons.fastfood,
                    size: 30,
                    color: colors.onSurfaceVariant,
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
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text(
                        'DEVELOPING',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dish.restaurantName ?? ''} • ${dish.restaurantAddress ?? ''}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '৳${dish.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• ${dish.category ?? 'Main'}',
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                      ),
                      const Spacer(),
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
                        style: TextStyle(
                          color: colors.onSurface,
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
