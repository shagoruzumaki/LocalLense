import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../api/review_system.dart';
import '../api/tier_upgrade_api.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserService _userService = UserService();
  final ReviewApi _reviewApi = ReviewApi();
  final TierUpgradeApi _tierUpgradeApi = TierUpgradeApi();

  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _tierInfo;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      // Fetch user profile
      final userResult = await _userService.getUserProfile(userId);

      // Fetch tier info and reviews in parallel
      final results = await Future.wait([
        _tierUpgradeApi.getTierInfo(userId),
        _reviewApi.getUserReviews(userId),
      ]);

      if (mounted) {
        setState(() {
          // ── user data ──
          // getUserProfile returns UserResult with a 'data' map
          // that includes: id, name, tier, verified, helpful_votes,
          // profile_photo_url, bio, review_count
          _userData = userResult.isSuccess ? userResult.data : null;

          _tierInfo = results[0] as Map<String, dynamic>;
          _reviews  = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    if (_userData == null) return;
    final nameController = TextEditingController(text: _userData?['name'] ?? '');
    final bioController  = TextEditingController(text: _userData?['bio']  ?? '');

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontFamily: 'serif'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFFD700))),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFFD700))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bioController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Bio',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFFD700))),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFFD700))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newBio  = bioController.text.trim();
              Navigator.pop(context);
              setState(() => _isLoading = true);

              final result = await _userService.updateProfile(
                name: newName.isNotEmpty ? newName : null,
                bio:  newBio.isNotEmpty  ? newBio  : null,
              );

              if (result.isSuccess) {
                await _fetchData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Profile updated successfully!')),
                  );
                }
              } else {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700)),
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      );
    }

    if (_userData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Failed to load profile',
                  style: TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchData,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700)),
                child: const Text('Retry',
                    style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      );
    }

    // ── Pull data from Supabase response ──
    final String  name            = _userData?['name']              ?? 'Anonymous';
    final String? profilePhotoUrl = _userData?['profile_photo_url'];
    final String? bio             = _userData?['bio'];
    final bool    verified        = _userData?['verified']          ?? false;
    final String? idType          = _userData?['id_type'];          // 'nid' or 'student_id'
    final int     reviewCount     = _userData?['review_count']      ?? _reviews.length;

    // ── Tier info ──
    final String tier         = (_tierInfo?['current_tier'] as String? ?? 'explorer').toUpperCase();
    final int    helpfulVotes = _tierInfo?['helpful_votes'] ?? 0;
    final int    votesNeeded  = _tierInfo?['votes_needed']  ?? 0;
    final int    threshold    = _tierInfo?['threshold']     ?? 50;
    final String nextTier = (_tierInfo?['next_tier'] as String? ?? 'none')
        .replaceAll('_', ' ');

    // Progress within current tier range
    final tierStarts = {
      'explorer': 0,
      'expert':   50,
      'diamond':  200,
      'platinum': 500,
    };
    final String currentTierKey = (_tierInfo?['current_tier'] as String? ?? 'explorer');
    final int tierStart    = tierStarts[currentTierKey] ?? 0;
    final double progress = currentTierKey == 'platinum'
        ? 1.0
        : (threshold - tierStart) > 0
        ? ((helpfulVotes - tierStart) / (threshold - tierStart)).clamp(0.0, 1.0)
        : 0.0;

    // Verified badge label
    final String verifiedLabel = idType == 'student_id'
        ? 'Verified • Student ID'
        : 'Verified • NID';

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
            icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: const Color(0xFFFFD700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── Profile Photo ──────────────────────
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFFFD700), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor:
                        Colors.white.withValues(alpha: 0.1),
                        backgroundImage: (profilePhotoUrl != null &&
                            profilePhotoUrl.isNotEmpty)
                            ? NetworkImage(profilePhotoUrl)
                            : null,
                        child: (profilePhotoUrl == null ||
                            profilePhotoUrl.isEmpty)
                            ? const Icon(Icons.person,
                            size: 50, color: Colors.white54)
                            : null,
                      ),
                    ),
                    GestureDetector(
                      onTap: _showEditProfileDialog,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD700),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit,
                            color: Colors.black, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Name ──────────────────────────────
              Text(
                name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif'),
              ),

              // ── Bio ───────────────────────────────
              if (bio != null && bio.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13, height: 1.4),
                ),
              ],

              const SizedBox(height: 10),

              // ── Badges ────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _buildBadge(tier, _getTierColor(tier)),
                  if (verified)
                    _buildBadge(verifiedLabel, Colors.green),
                ],
              ),

              const SizedBox(height: 24),

              // ── Stats ─────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(reviewCount.toString(), 'Reviews'),
                  _buildStatItem(helpfulVotes.toString(), 'Helpful'),
                  // Points = helpful_votes × tier multiplier
                  _buildStatItem(
                    _calcPoints(helpfulVotes, tier).toString(),
                    'Points',
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Account Settings ──────────────────
              _buildSectionHeader('Account Settings'),
              const SizedBox(height: 16),

              _buildSettingsItem(
                Icons.verified_user_outlined,
                'Verification',
                subtitle: verified ? 'Verified' : 'Not verified',
                onTap: () => Navigator.pushNamed(context, '/verification'),
                trailing: verified
                    ? _buildVerifiedBadge()
                    : const Icon(Icons.chevron_right,
                    color: Colors.white38),
              ),

              _buildSettingsItem(
                Icons.person_outline,
                'Personal Information',
                subtitle: 'Edit name and bio',
                onTap: _showEditProfileDialog,
              ),

              _buildSettingsItem(
                Icons.payment_outlined,
                'Payment Methods',
                subtitle: 'Coming soon',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Payment methods coming soon.')),
                ),
              ),

              const SizedBox(height: 32),

              // ── Recent Reviews ────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('Recent Reviews'),
                  TextButton(
                    onPressed: () {
                      // TODO: navigate to full reviews list
                    },
                    child: const Text('View All',
                        style: TextStyle(
                            color: Color(0xFFFFD700), fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_reviews.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.rate_review_outlined,
                          color: Colors.white24, size: 48),
                      const SizedBox(height: 12),
                      const Text('No reviews yet',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14)),
                      const SizedBox(height: 4),
                      const Text('Your reviews will appear here',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 12)),
                    ],
                  ),
                )
              else
                ..._reviews.take(3).map((review) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildRecentReview(review),
                )),

              const SizedBox(height: 24),

              // ── Next Milestone ────────────────────
              if (nextTier != 'none')
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Next Milestone',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text('$helpfulVotes / $threshold Votes',
                              style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFFD700)),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                          children: [
                            TextSpan(
                                text:
                                'Get $votesNeeded more helpful votes to unlock '),
                            TextSpan(
                              text: nextTier,
                              style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' status.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ── Points calc: helpful_votes × tier multiplier ──
  int _calcPoints(int helpfulVotes, String tier) {
    final multipliers = {
      'PLATINUM': 4,
      'DIAMOND':  3,
      'EXPERT':   2,
      'EXPLORER': 1,
    };
    return helpfulVotes * (multipliers[tier] ?? 1);
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum': return Colors.blueGrey.shade200;
      case 'diamond':  return Colors.cyan;
      case 'expert':   return Colors.deepPurpleAccent;
      default:         return Colors.amber;
    }
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'serif'),
      ),
    );
  }

  Widget _buildSettingsItem(
      IconData icon,
      String title, {
        String? subtitle,
        VoidCallback? onTap,
        Widget? trailing,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 12),
          SizedBox(width: 4),
          Text('VERIFIED',
              style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Review card ───────────────────────────────
  Widget _buildRecentReview(Map<String, dynamic> review) {
    final restaurant = review['restaurants'] as Map<String, dynamic>? ?? {};
    final String restaurantName = restaurant['name'] ?? 'Unknown Restaurant';
    final String body           = review['body']    ?? '';
    final double rating         = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final int    helpfulVotes   = review['helpful_votes'] ?? 0;
    final String moodTag        = review['mood_tag'] ?? 'good';

    // Get first review photo if exists
    final reviewPhotos = (review['photos'] as List<dynamic>?) ?? [];
    final String? photoUrl =
    reviewPhotos.isNotEmpty ? reviewPhotos[0].toString() : null;

    // Get first restaurant photo as fallback
    final restPhotos =
        (restaurant['photos'] as List<dynamic>?) ?? [];
    final String? restPhotoUrl =
    restPhotos.isNotEmpty ? restPhotos[0].toString() : null;

    // Mood emoji
    final moodEmoji = moodTag == 'loved_it'
        ? '😍'
        : moodTag == 'good'
        ? '😊'
        : '😐';

    // Time ago
    final createdAt =
        DateTime.tryParse(review['created_at'] ?? '') ?? DateTime.now();
    final diff = DateTime.now().difference(createdAt);
    final timeAgo = diff.inDays > 30
        ? '${(diff.inDays / 30).floor()}mo ago'
        : diff.inDays > 0
        ? '${diff.inDays}d ago'
        : diff.inHours > 0
        ? '${diff.inHours}h ago'
        : 'Just now';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant name + rating + time
          Row(
            children: [
              Expanded(
                child: Text(
                  restaurantName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(moodEmoji,
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              const Icon(Icons.star,
                  color: Color(0xFFFFD700), size: 14),
              const SizedBox(width: 3),
              Text(rating.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(timeAgo,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),

          // Review body
          Text(
            body,
            style: const TextStyle(
                color: Colors.white70, height: 1.5, fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          // Photo + helpful votes row
          if (photoUrl != null || restPhotoUrl != null || helpfulVotes > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Photo thumbnail
                if (photoUrl != null || restPhotoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photoUrl ?? restPhotoUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.white24, size: 20),
                      ),
                    ),
                  ),
                const Spacer(),
                // Helpful votes
                if (helpfulVotes > 0)
                  Row(
                    children: [
                      const Icon(Icons.thumb_up_outlined,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 4),
                      Text('$helpfulVotes helpful',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}