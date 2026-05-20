import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Bar ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFFFFD700), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Dhaka',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                      ),
                    ),
                    const Spacer(),
                    Stack(
                      children: [
                        const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFD700),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
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

              const SizedBox(height: 25),

              // ── Categories ───────────────────────────
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20),
                  children: [
                    _buildCategoryChip('All', isSelected: true),
                    _buildCategoryChip('Restaurants'),
                    _buildCategoryChip('Cafes'),
                    _buildCategoryChip('Street Food'),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ══════════════════════════════════════════
              // TOP 10 SECTION
              // ══════════════════════════════════════════
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      '🏆',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top 10',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'serif',
                            ),
                          ),
                          Text(
                            "This week's best in Dhaka",
                            style: TextStyle(
                              color: Color(0xFF8A7A50),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Top 10 Restaurants Container ─────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                        child: Row(
                          children: [
                            const Text(
                              'Top 10 Restaurants',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.settings_outlined,
                                  color: Colors.white54, size: 16),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1),

                      // Restaurant rows
                      _buildTop10RestaurantRow(
                        rank: '#1',
                        name: 'The Spice Trail',
                        category: 'Fine Indian',
                        rating: '4.9',
                        imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?q=80&w=100&auto=format&fit=crop',
                      ),
                      _buildTop10RestaurantRow(
                        rank: '#2',
                        name: 'Neon Street Grill',
                        category: 'BBQ & Grill',
                        rating: '4.7',
                        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?q=80&w=100&auto=format&fit=crop',
                      ),
                      _buildTop10RestaurantRow(
                        rank: '#3',
                        name: 'Velvet Lounge',
                        category: 'Continental',
                        rating: '4.8',
                        imageUrl: 'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?q=80&w=100&auto=format&fit=crop',
                        isLast: true,
                      ),

                      // See full list
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/ranking'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Text(
                                'See Full List',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward,
                                  color: Color(0xFFFFD700), size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Top 10 Critics Container ──────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                        child: Row(
                          children: [
                            const Text(
                              'Top 10 Critics',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shield_outlined,
                                  color: Colors.white54, size: 16),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1),

                      // Critics rows
                      _buildTop10CriticRow(
                        name: 'Arif Rahman',
                        reviews: '1.2k Reviews',
                        points: '45k Points',
                        tier: 'platinum',
                        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=100&auto=format&fit=crop',
                      ),
                      _buildTop10CriticRow(
                        name: 'Nadia Hossain',
                        reviews: '886 Reviews',
                        points: '28k Points',
                        tier: 'diamond',
                        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=100&auto=format&fit=crop',
                      ),
                      _buildTop10CriticRow(
                        name: 'Reza Khan',
                        reviews: '2k Reviews',
                        points: '60k Points',
                        tier: 'platinum',
                        avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=100&auto=format&fit=crop',
                        isLast: true,
                      ),

                      // See full list
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/ranking'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Text(
                                'See Full List',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward,
                                  color: Color(0xFFFFD700), size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ── Top Ranked Near You ───────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Top Ranked Near You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif',
                      ),
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
              SizedBox(
                height: 280,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20),
                  children: [
                    _buildRankedCard(
                      context: context,
                      rank: '#1',
                      points: '94pts',
                      title: 'The Spice Trail',
                      subtitle: 'AUTHENTIC BENGALI',
                      imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?q=80&w=500&auto=format&fit=crop',
                    ),
                    _buildRankedCard(
                      context: context,
                      rank: '#2',
                      points: '89pts',
                      title: 'Urban Kitchen',
                      subtitle: 'FUSION CUISINE',
                      imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?q=80&w=500&auto=format&fit=crop',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ── Open Right Now ────────────────────────
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
                          'Open Right Now',
                          style: TextStyle(
                            color: Colors.white,
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
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildOpenNowItem(
                    context: context,
                    title: 'The Caffeine Hub',
                    location: '0.4 km away • Banani',
                    priceText: r'$$',
                    category: 'Coffee & Snacks',
                    rating: '4.8',
                    imageUrl: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?q=80&w=200&auto=format&fit=crop',
                  ),
                  _buildOpenNowItem(
                    context: context,
                    title: 'Neon Street Grill',
                    location: '1.2 km away • Dhanmondi',
                    priceText: r'$',
                    category: 'Kebab & Rolls',
                    rating: '4.5',
                    imageUrl: 'https://images.unsplash.com/photo-1561651823-34feb02250e4?q=80&w=200&auto=format&fit=crop',
                  ),
                  _buildOpenNowItem(
                    context: context,
                    title: 'Velvet Lounge',
                    location: '2.8 km away • Gulshan 2',
                    priceText: r'$$$',
                    category: 'Fine Dining',
                    rating: '4.9',
                    imageUrl: 'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?q=80&w=200&auto=format&fit=crop',
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),

      // ── FAB ──────────────────────────────────────
      floatingActionButton: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, color: Colors.black, size: 20),
            SizedBox(width: 10),
            Text(
              'Quick Filters',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // ── Bottom Nav ───────────────────────────────
      bottomNavigationBar: Theme(
        data: ThemeData(canvasColor: const Color(0xFF0D0D0D)),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF0D0D0D),
          selectedItemColor: const Color(0xFFFFD700),
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          currentIndex: 0,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          onTap: (index) {
            switch (index) {
              case 0:
              // already on home — do nothing
                break;
              case 1:
                Navigator.pushNamed(context, '/discover');
                break;
              case 2:
                Navigator.pushNamed(context, '/map');
                break;
              case 3:
                Navigator.pushNamed(context, '/profile');
                break;
            }
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

  // ── CATEGORY CHIP ─────────────────────────────
  Widget _buildCategoryChip(String label, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFFFFD700) : Colors.white10,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // ── TOP 10 RESTAURANT ROW ─────────────────────
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
              // Rank
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
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              // Name + category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Rating
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFD700), size: 13),
                  const SizedBox(width: 3),
                  Text(
                    rating,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            color: Colors.white.withValues(alpha: 0.06),
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }

  // ── TOP 10 CRITIC ROW ─────────────────────────
  Widget _buildTop10CriticRow({
    required String name,
    required String reviews,
    required String points,
    required String tier,
    required String avatarUrl,
    bool isLast = false,
  }) {
    final tierColors = {
      'platinum': const Color(0xFF9C27B0),
      'diamond': const Color(0xFF2196F3),
      'expert': const Color(0xFF4CAF50),
      'explorer': const Color(0xFF8A7A50),
    };
    final tierColor = tierColors[tier] ?? const Color(0xFF8A7A50);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Avatar with tier badge
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: NetworkImage(avatarUrl),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: tierColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0D0D0D), width: 1.5),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 9),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Name + stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.verified, color: tierColor, size: 14),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$reviews • $points',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Tier badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  tier[0].toUpperCase() + tier.substring(1),
                  style: TextStyle(
                    color: tierColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            color: Colors.white.withValues(alpha: 0.06),
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }

  // ── RANKED CARD ───────────────────────────────
  Widget _buildRankedCard({
    required BuildContext context,
    required String rank,
    required String points,
    required String title,
    required String subtitle,
    required String imageUrl,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/restaurant-details'),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      rank,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      points,
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'serif',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── OPEN NOW ITEM ─────────────────────────────
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
              child: Image.network(
                imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
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
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'serif',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'OPEN',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        priceText,
                        style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• $category',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star_outline, color: Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        rating,
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