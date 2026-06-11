import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScoreBreakdownPage extends StatefulWidget {
  final String restaurantId;
  const ScoreBreakdownPage({super.key, required this.restaurantId});

  @override
  State<ScoreBreakdownPage> createState() => _ScoreBreakdownPageState();
}

class _ScoreBreakdownPageState extends State<ScoreBreakdownPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // Score data from algorithm_scores table
  double _finalScore = 0;
  double _qualityScore = 0;
  double _trustScore = 0;
  double _popularityScore = 0;
  int _reviewCount = 0;
  String _scoreLabel = '';

  // Restaurant basic info from restaurants table
  String _restaurantName = '';
  String _category = '';
  String _address = '';

  StreamSubscription? _scoreSubscription;
  StreamSubscription? _restaurantSubscription;

  @override
  void initState() {
    super.initState();
    _fetchScoreData();
    _setupRealtime();
  }

  @override
  void dispose() {
    _scoreSubscription?.cancel();
    _restaurantSubscription?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Real-time updates: Automatically refresh when
  // scores or restaurant data change
  // ─────────────────────────────────────────────
  void _setupRealtime() {
    _scoreSubscription = _supabase
        .from('algorithm_scores')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', widget.restaurantId)
        .listen((_) => _fetchScoreData(silent: true));

    _restaurantSubscription = _supabase
        .from('restaurants')
        .stream(primaryKey: ['id'])
        .eq('id', widget.restaurantId)
        .listen((_) => _fetchScoreData(silent: true));
  }

  // ─────────────────────────────────────────────
  // Fetch score breakdown + restaurant info
  // ─────────────────────────────────────────────
  Future<void> _fetchScoreData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Fetch both in parallel
      final results = await Future.wait([
        // algorithm_scores table
        _supabase
            .from('algorithm_scores')
            .select('quality_score, trust_score, popularity_score, review_count')
            .eq('restaurant_id', widget.restaurantId)
            .maybeSingle(),

        // restaurants table for name, category, address, final score
        _supabase
            .from('restaurants')
            .select('name, category, address, algorithm_score')
            .eq('id', widget.restaurantId)
            .maybeSingle(),
      ]);

      final scores = results[0] as Map<String, dynamic>?;
      final restaurant = results[1] as Map<String, dynamic>?;

      if (restaurant == null) {
        if (mounted) {
          setState(() {
            _error = 'Restaurant not found.';
            _loading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          // Score components
          if (scores != null) {
            _qualityScore = (scores['quality_score'] as num?)?.toDouble() ?? 0;
            _trustScore = (scores['trust_score'] as num?)?.toDouble() ?? 0;
            _popularityScore = (scores['popularity_score'] as num?)?.toDouble() ?? 0;
            _reviewCount = (scores['review_count'] as int?) ?? 0;
          }

          // Final composite score from restaurants table
          _finalScore = (restaurant['algorithm_score'] as num?)?.toDouble() ?? 0;
          _scoreLabel = _getScoreLabel(_finalScore);

          // Restaurant info
          _restaurantName = restaurant['name'] as String? ?? '';
          _category = (restaurant['category'] as String? ?? '').toUpperCase();
          _address = restaurant['address'] as String? ?? '';

          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = 'Failed to load score data.';
          _loading = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  // Score label — matches 2.1 score.dart thresholds
  // ─────────────────────────────────────────────
  String _getScoreLabel(double score) {
    if (score >= 90) return 'Elite';
    if (score >= 75) return 'Excellent';
    if (score >= 60) return 'Good';
    return 'Developing';
  }

  // ─────────────────────────────────────────────
  // Convert 0-100 score to 0.0-1.0 for progress bar
  // ─────────────────────────────────────────────
  double _toProgress(double score) => (score / 100).clamp(0.0, 1.0);

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
        title: const Text('LocalLens',
            style: TextStyle(
                color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD700)),
      )
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(color: Colors.white38)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _fetchScoreData(),
              child: const Text('Retry',
                  style: TextStyle(color: Color(0xFFFFD700))),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Image ──────────────────────────────
            Stack(
              children: [
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(
                          'https://images.unsplash.com/photo-1559339352-11d035aa65de?q=80&w=1000&auto=format&fit=crop'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        const Color(0xFF0D0D0D)
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _restaurantName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'serif'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_category • $_address',
                        style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Algorithm Score Card ────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      'LOCALLENS ALGORITHM SCORE',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 16),

                    // ── Final Score ───────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _finalScore.toStringAsFixed(0),
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'serif'),
                        ),
                        Text(
                          ' / 100',
                          style: TextStyle(
                              color: Colors.black.withOpacity(0.5),
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    // ── Score Label ───────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _scoreLabel.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
                    ),

                    // ── Review Count ──────────────────────
                    Text(
                      'Based on $_reviewCount reviews',
                      style: TextStyle(
                          color: Colors.black.withOpacity(0.5),
                          fontSize: 12),
                    ),
                    const SizedBox(height: 24),

                    // ── Score Components ──────────────────
                    // Quality Score (40%)
                    _buildMetricRow(
                      'QUALITY',
                      '${_qualityScore.toStringAsFixed(0)}%',
                      _toProgress(_qualityScore),
                      subtitle: '40% weight',
                    ),
                    const SizedBox(height: 16),

                    // Trust + Popularity side by side
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricRow(
                            'TRUST',
                            '${_trustScore.toStringAsFixed(0)}%',
                            _toProgress(_trustScore),
                            subtitle: '25% weight',
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildMetricRow(
                            'POPULARITY',
                            '${_popularityScore.toStringAsFixed(0)}%',
                            _toProgress(_popularityScore),
                            subtitle: '20% weight',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Proximity note (per-user, not stored)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.black54, size: 14),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Proximity (15%) is calculated per user based on your current location.',
                              style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 11,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Score Breakdown Detail Cards ────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Score Breakdown',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'serif'),
                  ),
                  const SizedBox(height: 16),
                  _buildBreakdownCard(
                    icon: Icons.star_outline,
                    title: 'Quality Score',
                    score: _qualityScore,
                    weight: '40%',
                    description:
                    'Weighted average of dish ratings. Platinum reviewer ratings count 4× more than Explorer ratings.',
                    color: const Color(0xFFFFD700),
                  ),
                  const SizedBox(height: 12),
                  _buildBreakdownCard(
                    icon: Icons.verified_user_outlined,
                    title: 'Trust Score',
                    score: _trustScore,
                    weight: '25%',
                    description:
                    'Measures how credible the reviewer pool is. More Diamond and Platinum reviewers = higher trust.',
                    color: Colors.lightBlueAccent,
                  ),
                  const SizedBox(height: 12),
                  _buildBreakdownCard(
                    icon: Icons.trending_up,
                    title: 'Popularity Score',
                    score: _popularityScore,
                    weight: '20%',
                    description:
                    'Based on check-ins and visit frequency. Benchmarked per category.',
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(height: 12),
                  _buildBreakdownCard(
                    icon: Icons.near_me_outlined,
                    title: 'Proximity Score',
                    score: null,
                    weight: '15%',
                    description:
                    'Calculated in real-time based on your GPS location. Closed restaurants lose 30% of this score.',
                    color: Colors.purpleAccent,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),

      // ── Bottom Bar ────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        color: const Color(0xFF0D0D0D),
        child: Row(
          children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.share_outlined,
                      color: Color(0xFFFFD700), size: 18),
                  SizedBox(width: 8),
                  Text('Share',
                      style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rate_review_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Write a Review',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // METRIC ROW — inside gold score card
  // ─────────────────────────────────────────────
  Widget _buildMetricRow(
      String label,
      String value,
      double progress, {
        String subtitle = '',
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.black.withOpacity(0.4),
                          fontSize: 9)),
              ],
            ),
            Text(value,
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.black.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
            minHeight: 3,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // BREAKDOWN CARD — below the score card
  // ─────────────────────────────────────────────
  Widget _buildBreakdownCard({
    required IconData icon,
    required String title,
    required double? score,
    required String weight,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    // Weight badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(weight,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Score value or per-user note
                score != null
                    ? Row(
                  children: [
                    Text(
                      '${score.toStringAsFixed(1)} / 100',
                      style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _toProgress(score),
                          backgroundColor:
                          Colors.white.withOpacity(0.08),
                          valueColor:
                          AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                )
                    : Text(
                  'Calculated per user',
                  style: TextStyle(
                      color: color.withOpacity(0.7),
                      fontSize: 13,
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
                Text(description,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
