import 'package:flutter/material.dart';
import '../services/restaurant_service.dart';
import '../model/restaurant.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RestaurantService _restaurantService = RestaurantService();
  late Future<List<Restaurant>> _nearbyRestaurantsFuture;
  String _neighbourhood = 'Nearby';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _nearbyRestaurantsFuture = _restaurantService.fetchNearbyRestaurants();
    });
    // Dynamically detect neighbourhood name
    _restaurantService.fetchNearbyRestaurants().then((list) async {
      if (list.isNotEmpty && list.first.lat != null) {
        final name = await _restaurantService.getNeighbourhoodName(list.first.lat!, list.first.lng!);
        if (mounted) setState(() => _neighbourhood = name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadData(),
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
                    onSubmitted: (val) => Navigator.pushNamed(context, '/discover'),
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
                // DYNAMIC TOP 10 SECTION (Requirement 3.1 / 3.3)
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
                              "Best in $_neighbourhood based on Algorithm",
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
                      future: _nearbyRestaurantsFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                        
                        // Sort by Algorithm Score (lensScore)
                        final topList = List<Restaurant>.from(snapshot.data!);
                        topList.sort((a, b) => b.lensScore.compareTo(a.lensScore));
                        final top3 = topList.take(3).toList();

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
                            ...top3.asMap().entries.map((entry) {
                              int idx = entry.key;
                              Restaurant r = entry.value;
                              return _buildTop10RestaurantRow(
                                rank: '#${idx + 1}',
                                name: r.name,
                                category: r.category,
                                rating: r.rating.toString(),
                                imageUrl: r.imageUrl,
                                isLast: idx == top3.length - 1,
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
                FutureBuilder<List<Restaurant>>(
                  future: _nearbyRestaurantsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFFFFD700))));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No real spots found nearby', style: TextStyle(color: Colors.white38)));
                    }

                    final restaurants = snapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: restaurants.length > 5 ? 5 : restaurants.length,
                      itemBuilder: (context, index) {
                        final r = restaurants[index];
                        return _buildOpenNowItem(
                          context: context,
                          title: r.name,
                          location: r.address,
                          priceText: r'$$',
                          category: r.category,
                          rating: r.rating.toString(),
                          imageUrl: r.imageUrl,
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
  }) {
    return Column(
      children: [
        Padding(
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
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/restaurant-details'),
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
                      const Icon(Icons.verified, color: Colors.green, size: 16),
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
