import 'package:flutter/material.dart';
import '../services/top10_service.dart';
import '../services/location_service.dart';
import '../services/restaurant_service.dart';
import '../model/restaurant.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> with SingleTickerProviderStateMixin {
  final Top10Service _top10Service = Top10Service();
  final LocationService _locationService = LocationService();
  final RestaurantService _restaurantService = RestaurantService();
  late TabController _tabController;
  
  String _timeFilter = 'alltime'; 
  List<Restaurant> _restaurants = [];
  List<Map<String, dynamic>> _critics = [];
  bool _isLoading = true;
  String _locationName = 'Nearby';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final hasPermission = await _locationService.checkPermission();
      if (hasPermission) {
        final pos = await _locationService.getCurrentLocation();
        _locationName = await _restaurantService.getNeighbourhoodName(pos.latitude, pos.longitude);
      }

      if (_timeFilter != 'alltime') {
        final res = await _top10Service.getTop10Restaurants(filter: _timeFilter);
        final critics = await _top10Service.getTop10Critics(filter: _timeFilter);
        if (mounted) {
          setState(() {
            _restaurants = res;
            _critics = critics;
            _isLoading = false;
          });
        }
      } else {
        final critics = await _top10Service.getTop10Critics(filter: 'alltime');
        if (mounted) {
          setState(() {
            _critics = critics;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setTimeFilter(String filter) {
    if (_timeFilter == filter) return;
    setState(() {
      _timeFilter = filter;
      _isLoading = true;
      _restaurants = []; // Reset list to show loading state
    });
    _fetchData();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leaderboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif')),
            Text(
              '$_locationName • Updated ${_timeFilter == 'alltime' ? 'Real-time' : _timeFilter == 'week' ? 'Weekly' : 'Monthly'}', 
              style: const TextStyle(color: Colors.white38, fontSize: 12)
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD700),
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Restaurants'),
            Tab(text: 'Critics'),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildTimeChip('This Week', isSelected: _timeFilter == 'week', onTap: () => _setTimeFilter('week')),
                _buildTimeChip('This Month', isSelected: _timeFilter == 'month', onTap: () => _setTimeFilter('month')),
                _buildTimeChip('All Time', isSelected: _timeFilter == 'alltime', onTap: () => _setTimeFilter('alltime')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRestaurantTabContent(),
                _buildCriticTabContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantTabContent() {
    if (_timeFilter == 'alltime') {
      return StreamBuilder<List<Restaurant>>(
        stream: _top10Service.getTop10RestaurantsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
          }
          final list = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _fetchData,
            color: const Color(0xFFFFD700),
            child: _buildRestaurantList(list),
          );
        },
      );
    }

    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFFFFD700),
      child: _buildRestaurantList(_restaurants),
    );
  }

  Widget _buildCriticTabContent() {
    if (_timeFilter == 'alltime') {
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: _top10Service.getTop10CriticsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
          }
          final list = snapshot.data ?? _critics;
          return RefreshIndicator(
            onRefresh: _fetchData,
            color: const Color(0xFFFFD700),
            child: _buildCriticList(list),
          );
        },
      );
    }

    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFFFFD700),
      child: _buildCriticList(_critics),
    );
  }

  Widget _buildRestaurantList(List<Restaurant> list) {
    if (list.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text('No rankings found', style: TextStyle(color: Colors.white54))),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final r = list[index];
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildRankOneCard(
              name: r.name,
              location: r.address,
              score: r.rating.toStringAsFixed(1),
              description: r.aiSummary ?? "Highly rated culinary experience...",
              imageUrl: r.imageUrl,
              onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRankItem(
            (index + 1).toString(), 
            r.name, 
            r.address, 
            r.aiSummary ?? "Outstanding service and taste.", 
            imageUrl: r.imageUrl, 
            score: r.rating.toStringAsFixed(1),
            onTap: () => Navigator.pushNamed(context, '/restaurant-details', arguments: r.id),
          ),
        );
      },
    );
  }

  Widget _buildCriticList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text('No critics found', style: TextStyle(color: Colors.white54))),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final c = list[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCriticItem(
            (index + 1).toString(),
            c['name'] ?? 'Anonymous',
            '${c['helpful_votes'] ?? 0} Votes • ${c['rank_score'] ?? 0} Points',
            (c['tier'] ?? 'EXPLORER').toString().toUpperCase(),
            photoUrl: c['profile_photo_url'],
          ),
        );
      },
    );
  }

  Widget _buildTimeChip(String label, {bool isSelected = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD700) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: isSelected ? const Color(0xFFFFD700) : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildRankOneCard({
    required String name, 
    required String location, 
    required String score, 
    required String description, 
    required String imageUrl,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [Color(0xFFFFD700), Colors.transparent]),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text('1', style: TextStyle(color: Color(0xFFFFD700), fontSize: 48, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: const Color(0xFF2A2A2A), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFD700), width: 1)),
                          child: const Icon(Icons.stars, color: Color(0xFFFFD700), size: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.white10, width: 80, height: 80)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(name, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text(score, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(location, style: const TextStyle(color: Colors.white54, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Text(description, style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('View Details', style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
                  Icon(Icons.chevron_right, color: Color(0xFFFFD700), size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankItem(String rank, String name, String location, String description, {String? imageUrl, String? score, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(rank, style: const TextStyle(color: Colors.white54, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'serif')),
            ),
            const SizedBox(width: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null 
                ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.white10, width: 60, height: 60))
                : Container(width: 60, height: 60, color: Colors.white10),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (score != null) Text(score, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(location, style: const TextStyle(color: Colors.white54, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticItem(String rank, String name, String stats, String tier, {String? photoUrl}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(rank, style: const TextStyle(color: Colors.white54, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'serif')),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white10,
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: Colors.blue, size: 14),
                  ],
                ),
                Text(stats, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
            ),
            child: Text(tier, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
