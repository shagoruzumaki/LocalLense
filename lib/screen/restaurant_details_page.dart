import 'package:flutter/material.dart';
import '../services/discovery_service.dart';
import '../model/restaurant.dart';
import 'map_page.dart';

class RestaurantDetailsPage extends StatefulWidget {
  final String? restaurantId;
  const RestaurantDetailsPage({super.key, this.restaurantId});

  @override
  State<RestaurantDetailsPage> createState() => _RestaurantDetailsPageState();
}

class _RestaurantDetailsPageState extends State<RestaurantDetailsPage> {
  final DiscoveryService _discoveryService = DiscoveryService();
  RestaurantWithScore? _data;
  AlgorithmScore? _scoreBreakdown;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final id = widget.restaurantId ?? (args is String ? args : null);
      if (id != null) {
        _fetchDetails(id);
      }
    }
  }

  Future<void> _fetchDetails(String id) async {
    setState(() => _isLoading = true);
    try {
      final detail = await _discoveryService.getRestaurantDetail(id);
      final score = await _discoveryService.getScoreBreakdown(id);

      if (mounted) {
        setState(() {
          _data = detail;
          _scoreBreakdown = score;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      );
    }

    if (_data == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: Text('Restaurant not found', style: TextStyle(color: Colors.white))),
      );
    }

    final r = _data!.restaurant;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0D0D0D),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    r.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(color: Colors.white10),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          const Color(0xFF0D0D0D),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildBadge(r.category.toUpperCase(), const Color(0xFFFFD700)),
                            const SizedBox(width: 8),
                            if (r.active) _buildBadge('VERIFIED', Colors.green),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          r.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif',
                          ),
                        ),
                        Text(
                          r.address,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildScoreCircle((r.algorithmScore ?? 0).toInt()),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _data!.scoreLabel,
                                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Lens Algorithm Score based on ${(_scoreBreakdown?.reviewCount ?? 0)} reviews',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_scoreBreakdown != null) ...[
                          const SizedBox(height: 20),
                          _buildScoreStat('Quality', _scoreBreakdown!.qualityScore ?? 0),
                          _buildScoreStat('Trust', _scoreBreakdown!.trustScore ?? 0),
                          _buildScoreStat('Popularity', _scoreBreakdown!.popularityScore ?? 0),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildSectionHeader('AI Summary'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
                    ),
                    child: Text(
                      r.aiSummary ?? 'No AI summary available yet for this spot.',
                      style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 25),
                  if (r.aiTags != null && r.aiTags!.isNotEmpty) ...[
                    _buildSectionHeader('Highlights'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: r.aiTags!.map((tag) => _buildBadge(tag, Colors.white24)).toList(),
                    ),
                    const SizedBox(height: 25),
                  ],
                  _buildSectionHeader('Location & Hours'),
                  const SizedBox(height: 15),
                  
                  // DIRECTIONS BUTTON
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapPage(targetRestaurant: r),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Color(0xFFFFD700), size: 20),
                          const SizedBox(width: 10),
                          const Text(
                            'Google Maps Directions', 
                            style: TextStyle(
                              color: Color(0xFFFFD700), 
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            )
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right, color: Color(0xFFFFD700), size: 18),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.white54, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _data!.isOpenNow ? 'Open Now' : 'Closed',
                        style: TextStyle(color: _data!.isOpenNow ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color.opacity == 1.0 ? Colors.white : color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildScoreCircle(int score) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 4,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
          ),
        ),
        Text(
          score.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildScoreStat(String label, double score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Expanded(
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
              minHeight: 4,
            ),
          ),
          const SizedBox(width: 10),
          Text(score.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'serif'),
    );
  }
}
