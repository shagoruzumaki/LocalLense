import 'package:flutter/material.dart';
import '../services/restaurant_service.dart';
import '../services/top10_service.dart';
import '../services/location_service.dart';
import '../services/discovery_service.dart';
import '../model/restaurant.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RestaurantService _restaurantService = RestaurantService();
  final Top10Service _top10Service = Top10Service();
  final LocationService _locationService = LocationService();
  final DiscoveryService _discoveryService = DiscoveryService();
  
  late Future<List<RestaurantWithScore>> _nearbyRestaurantsFuture;
  late Future<List<Restaurant>> _top10RestaurantsFuture;
  late Future<List<Map<String, dynamic>>> _top10CriticsFuture;
  
  String _neighbourhood = 'Nearby';

  @override
  void initState() {
    super.initState();
    // Initialize futures immediately to avoid LateInitializationError during first build
    _top10RestaurantsFuture = _top10Service.getTop10Restaurants(filter: 'week');
    _top10CriticsFuture = _top10Service.getTop10Critics(filter: 'week');
    _nearbyRestaurantsFuture = _discoveryService.getNearby(lat: 23.8103, lng: 90.4125, radiusKm: 10);
    _loadData();
  }

  Future<void> _loadData() async {
    double lat = 23.8103; 
    double lng = 90.4125;

    try {
      final hasPermission = await _locationService.checkPermission();
      if (hasPermission) {
        final pos = await _locationService.getCurrentLocation();
        lat = pos.latitude;
        lng = pos.longitude;
        final name = await _restaurantService.getNeighbourhoodName(lat, lng);
        if (mounted) setState(() => _neighbourhood = name);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _nearbyRestaurantsFuture = _discoveryService.getNearby(lat: lat, lng: lng, radiusKm: 10);
        _top10RestaurantsFuture = _top10Service.getTop10Restaurants(filter: 'week');
        _top10CriticsFuture = _top10Service.getTop10Critics(filter: 'week');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadData(),
          color: const Color(0xFFFFD700),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Dynamic Top Bar ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFFFD700), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _neighbourhood,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                      const SizedBox(width: 15),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                        child: const CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(
                            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=100&auto=format&fit=crop',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Search ───────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'What are you craving?',
                    style: TextStyle(
                      color: Colors.white,
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
                    readOnly: true,
                    onTap: () => Navigator.pushNamed(context, '/discover'),
                    decoration: InputDecoration(
                      hintText: 'Search for dishes or places...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // ══════════════════════════════════════════
                // TOP 10 RESTAURANTS SECTION
                // ══════════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Top Ranked',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                            ),
                            Text(
                              "Weekly Leaders in $_neighbourhood",
                              style: const TextStyle(color: Color(0xFF8A7A50), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: FutureBuilder<List<Restaurant>>(
                      future: _top10RestaurantsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))));
                        }
                        
                        final topList = snapshot.data ?? [];
                        // Showing all 10 as requested, instead of just 3
                        final displayList = topList.take(10).toList();

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                              child: Row(
                                children: [
                                  const Text('Top 10 Restaurants', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Icon(Icons.auto_awesome, color: const Color(0xFFFFD700).withValues(alpha: 0.5), size: 16),
                                ],
                              ),
                            ),
                            const Divider(color: Colors.white10, height: 1),
                            if (displayList.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No rankings available', style: TextStyle(color: Colors.white38)),
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
                                  onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
                                );
                              }),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/ranking'),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Text('See Full List', style: TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w600)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward, color: Color(0xFFFFD700), size: 14),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ══════════════════════════════════════════
                // TOP 10 CRITICS SECTION
                // ══════════════════════════════════════════
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _top10CriticsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))));
                        }
                        
                        final critics = snapshot.data ?? [];
                        final displayCritics = critics.take(5).toList(); // Show a few more critics too

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                              child: Row(
                                children: [
                                  const Text('Top 10 Critics', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  const Icon(Icons.verified_user_outlined, color: Colors.white38, size: 16),
                                ],
                              ),
                            ),
                            const Divider(color: Colors.white10, height: 1),
                            if (displayCritics.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No critics ranked this week', style: TextStyle(color: Colors.white38)),
                              )
                            else
                              ...displayCritics.asMap().entries.map((entry) {
                                int idx = entry.key;
                                var c = entry.value;
                                return _buildTop10CriticRow(
                                  rank: '#${idx + 1}',
                                  name: c['name'] ?? 'Critic',
                                  tier: (c['tier'] ?? 'EXPLORER').toString().toUpperCase(),
                                  points: '${c['rank_score'] ?? 0} Pts',
                                  photoUrl: c['profile_photo_url'],
                                  isLast: idx == displayCritics.length - 1,
                                );
                              }),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/ranking'),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Text('View Leaderboard', style: TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w600)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward, color: Color(0xFFFFD700), size: 14),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // ── Found Near You (Requirement 3.1) ───────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.circle, color: Colors.green, size: 10),
                          SizedBox(width: 6),
                          Text(
                            'Found Near You',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif'),
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFFFFD700))));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No real spots found nearby', style: TextStyle(color: Colors.white38)));
                    }

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
                          onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Theme(
        data: ThemeData(canvasColor: const Color(0xFF0D0D0D)),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF0D0D0D),
          selectedItemColor: const Color(0xFFFFD700),
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          currentIndex: 0,
          onTap: (index) {
            if (index == 1) Navigator.pushNamed(context, '/discover');
            if (index == 2) Navigator.pushNamed(context, '/map');
            if (index == 3) Navigator.pushNamed(context, '/profile');
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'HOME'),
            BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'DISCOVER'),
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'MAP'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'PROFILE'),
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
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(width: 28, child: Text(rank, style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13))),
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(imageUrl, width: 44, height: 44, fit: BoxFit.cover, 
                    errorBuilder: (_, __, ___) => Container(color: Colors.white10, child: const Icon(Icons.restaurant, size: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(category, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFD700), size: 13),
                    const SizedBox(width: 3),
                    Text(rating, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isLast) Divider(color: Colors.white.withValues(alpha: 0.06), height: 1, indent: 16, endIndent: 16),
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
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(width: 28, child: Text(rank, style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 13))),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white10,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null ? const Icon(Icons.person, size: 16, color: Colors.white38) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(tier, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Text(points, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
        if (!isLast) Divider(color: Colors.white.withValues(alpha: 0.06), height: 1, indent: 16, endIndent: 16),
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
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
              child: Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.white10, child: const Icon(Icons.restaurant, size: 30))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'serif'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(scoreLabel, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(location, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(priceText, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('• $category', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                      const Spacer(),
                      const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 4),
                      Text(rating, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
