import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewerProfilePage extends StatefulWidget {
  final String userId;
  const ReviewerProfilePage({super.key, required this.userId});

  @override
  State<ReviewerProfilePage> createState() => _ReviewerProfilePageState();
}

class _ReviewerProfilePageState extends State<ReviewerProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ─────────────────────────────────────────────
  // Load user profile + their reviews
  // ─────────────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        // User profile
        _supabase
            .from('users')
            .select('id, name, tier, verified, helpful_votes, bio, profile_photo_url')
            .eq('id', widget.userId)
            .single(),

        // Their reviews with restaurant info
        _supabase
            .from('reviews')
            .select('''
              id, rating, body, helpful_votes, mood_tag, created_at,
              restaurants (id, name, category)
            ''')
            .eq('user_id', widget.userId)
            .eq('flagged', false)
            .order('created_at', ascending: false),
      ]);

      if (mounted) {
        setState(() {
          _user = results[0] as Map<String, dynamic>;
          _reviews = List<Map<String, dynamic>>.from(results[1] as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────
  // Tier config — color and label per tier
  // ─────────────────────────────────────────────
  Map<String, dynamic> _getTierConfig(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return {'color': Colors.cyanAccent, 'icon': Icons.workspace_premium, 'label': 'PLATINUM REVIEWER'};
      case 'diamond':
        return {'color': const Color(0xFF00E5FF), 'icon': Icons.diamond, 'label': 'DIAMOND REVIEWER'};
      case 'expert':
        return {'color': Colors.purpleAccent, 'icon': Icons.military_tech, 'label': 'EXPERT REVIEWER'};
      default:
        return {'color': Colors.white38, 'icon': Icons.explore, 'label': 'EXPLORER REVIEWER'};
    }
  }

  // ─────────────────────────────────────────────
  // Next tier threshold for progress bar
  // ─────────────────────────────────────────────
  Map<String, dynamic> _getTierProgress(String tier, int helpfulVotes) {
    switch (tier.toLowerCase()) {
      case 'explorer':
        return {'next': 'Expert', 'threshold': 50, 'progress': helpfulVotes / 50};
      case 'expert':
        return {'next': 'Diamond', 'threshold': 200, 'progress': helpfulVotes / 200};
      case 'diamond':
        return {'next': 'Platinum', 'threshold': 500, 'progress': helpfulVotes / 500};
      default:
        return {'next': null, 'threshold': 500, 'progress': 1.0}; // Platinum — maxed
    }
  }

  // ─────────────────────────────────────────────
  // Format relative time
  // ─────────────────────────────────────────────
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} months ago';
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      );
    }

    if (_user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: Text('User not found', style: TextStyle(color: Colors.white))),
      );
    }

    final name = _user!['name'] as String? ?? 'Anonymous';
    final tier = _user!['tier'] as String? ?? 'explorer';
    final verified = _user!['verified'] as bool? ?? false;
    final helpfulVotes = _user!['helpful_votes'] as int? ?? 0;
    final bio = _user!['bio'] as String?;
    final photoUrl = _user!['profile_photo_url'] as String?;
    final tierConfig = _getTierConfig(tier);
    final tierColor = tierConfig['color'] as Color;
    final tierIcon = tierConfig['icon'] as IconData;
    final tierLabel = tierConfig['label'] as String;
    final progress = _getTierProgress(tier, helpfulVotes);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reviewer Profile',
          style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontFamily: 'serif'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ── Avatar ───────────────────────────────
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: tierColor, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: tierColor.withOpacity(0.2),
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null
                          ? Text(
                        name[0].toUpperCase(),
                        style: TextStyle(color: tierColor, fontSize: 32, fontWeight: FontWeight.bold),
                      )
                          : null,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                    child: Icon(tierIcon, color: tierColor, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Name + Verified ──────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                if (verified) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.verified, color: Colors.green, size: 20),
                ],
              ],
            ),
            const SizedBox(height: 4),

            // ── Tier label ───────────────────────────
            Text(tierLabel, style: TextStyle(color: tierColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 8),

            // ── Bio ──────────────────────────────────
            if (bio != null && bio.isNotEmpty) ...[
              Text(bio, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],

            // ── Stats ────────────────────────────────
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat(_reviews.length.toString(), 'REVIEWS'),
                _buildStat(helpfulVotes.toString(), 'HELPFUL'),
                _buildStat(_reviews.map((r) => r['restaurants']?['id']).toSet().length.toString(), 'VISITED'),
              ],
            ),
            const SizedBox(height: 24),

            // ── Progress Bar ─────────────────────────
            if (tier.toLowerCase() != 'platinum')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.military_tech, color: Color(0xFFFFD700)),
                            const SizedBox(width: 8),
                            Text(
                              'Progress to ${progress['next']}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$helpfulVotes ',
                                style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: '/ ${progress['threshold']} votes',
                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (progress['progress'] as double).clamp(0.0, 1.0),
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Platinum badge if maxed ───────────────
            if (tier.toLowerCase() == 'platinum')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.cyanAccent),
                    SizedBox(width: 8),
                    Text('Platinum — Highest Tier Reached', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // ── Reviews header ───────────────────────
            const Row(
              children: [
                Text('Reviews', style: TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif')),
              ],
            ),
            const SizedBox(height: 16),

            // ── Reviews list ─────────────────────────
            if (_reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('No reviews yet.', style: TextStyle(color: Colors.white38)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reviews.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildReviewCard(_reviews[i]),
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        color: const Color(0xFF0D0D0D),
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          child: Text(
            'FOLLOW ${name.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STAT WIDGET
  // ─────────────────────────────────────────────
  Widget _buildStat(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.0)),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // REVIEW CARD
  // ─────────────────────────────────────────────
  Widget _buildReviewCard(Map<String, dynamic> review) {
    final restaurant = review['restaurants'] as Map<String, dynamic>? ?? {};
    final restaurantName = restaurant['name'] as String? ?? 'Unknown';
    final category = (restaurant['category'] as String? ?? '').toUpperCase();
    final body = review['body'] as String? ?? '';
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final helpfulVotes = review['helpful_votes'] as int? ?? 0;
    final createdAt = review['created_at'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant info row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant, color: Color(0xFFFFD700), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurantName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(category, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < rating.floor() ? Icons.star : (i < rating ? Icons.star_half : Icons.star_border),
                        color: const Color(0xFFFFD700),
                        size: 12,
                      )),
                    ),
                  ],
                ),
              ),
              Text(_formatDate(createdAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),

          // Review body
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),

          // Helpful votes
          Row(
            children: [
              const Icon(Icons.thumb_up_outlined, color: Color(0xFFFFD700), size: 14),
              const SizedBox(width: 4),
              Text('$helpfulVotes Helpful', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
