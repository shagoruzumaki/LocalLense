import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_lense/services/user_service.dart';
import 'package:local_lense/services/storage_service.dart';
import 'package:local_lense/services/auth_services.dart';

/// LocalLens — Profile Page
/// Responsive layout using CustomScrollView + SliverAppBar + SliverFillRemaining
/// No NestedScrollView/Column/Expanded chain — fixes RenderFlex overflow
/// Member 1 — Ismail Hossain Shagor

class ProfilePage extends StatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();

  late TabController _tabController;

  bool _loadingProfile = true;
  bool _loadingReviews = true;
  bool _loadingVisited = true;
  bool _loadingRewards = true;

  Map<String, dynamic>? _profile;
  List<dynamic> _reviews = [];
  List<dynamic> _visited = [];
  List<dynamic> _activeRewards = [];
  List<dynamic> _redeemedRewards = [];

  String? _error;
  bool _isOwnProfile = false;

  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _savingProfile = false;

  static const Map<String, _TierConfig> _tiers = {
    'explorer': _TierConfig(
      label: 'Explorer',
      color: Color(0xFFCD7F32),
      icon: Icons.explore,
      nextTier: 'Expert',
      votesRequired: 50,
    ),
    'expert': _TierConfig(
      label: 'Expert',
      color: Color(0xFFC0C0C0),
      icon: Icons.workspace_premium,
      nextTier: 'Diamond',
      votesRequired: 200,
    ),
    'diamond': _TierConfig(
      label: 'Diamond',
      color: Color(0xFF00BFFF),
      icon: Icons.diamond,
      nextTier: 'Platinum',
      votesRequired: 500,
    ),
    'platinum': _TierConfig(
      label: 'Platinum',
      color: Color(0xFFE5E4E2),
      icon: Icons.military_tech,
      nextTier: null,
      votesRequired: null,
    ),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final currentId = _authService.currentUser?.id;
    final targetId = widget.userId ?? currentId;
    _isOwnProfile = (widget.userId == null || widget.userId == currentId);
    if (targetId != null) {
      _loadProfile(targetId);
      _loadReviews(targetId);
      _loadVisited(targetId);
      if (_isOwnProfile) _loadRewards();
    } else {
      setState(() {
        _error = 'Not logged in.';
        _loadingProfile = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  String get _targetUserId => widget.userId ?? _authService.currentUser!.id;

  Future<void> _loadProfile(String userId) async {
    final result = await _userService.getUserProfile(userId);
    if (!mounted) return;
    if (result.isSuccess) {
      final profile = result.data!;
      _nameCtrl.text = profile['name'] ?? '';
      _bioCtrl.text = profile['bio'] ?? '';
      setState(() {
        _profile = profile;
        _loadingProfile = false;
      });
    } else {
      setState(() {
        _error = result.message;
        _loadingProfile = false;
      });
    }
  }

  Future<void> _loadReviews(String userId, {int page = 1}) async {
    setState(() => _loadingReviews = true);
    final result = await _userService.getUserReviews(userId, page: page);
    if (!mounted) return;
    setState(() {
      if (result.isSuccess) _reviews = result.data!['reviews'] as List;
      _loadingReviews = false;
    });
  }

  Future<void> _loadVisited(String userId) async {
    final result = await _userService.getVisitedPlaces(userId);
    if (!mounted) return;
    setState(() {
      if (result.isSuccess) _visited = result.data!['visited'] as List;
      _loadingVisited = false;
    });
  }

  Future<void> _loadRewards() async {
    final result = await _userService.getUserRewards();
    if (!mounted) return;
    setState(() {
      if (result.isSuccess) {
        _activeRewards = result.data!['active'] as List;
        _redeemedRewards = result.data!['redeemed'] as List;
      }
      _loadingRewards = false;
    });
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.path.split('.').last.toLowerCase();
    final result = await _storageService.uploadProfilePhoto(
      fileBytes: Uint8List.fromList(bytes),
      fileExtension: ext,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _profile = {...?_profile, 'profile_photo_url': result.url});
      _showSnack('Photo updated!');
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  Future<void> _saveProfileChanges() async {
    setState(() => _savingProfile = true);
    final result = await _userService.updateProfile(
      name: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _savingProfile = false);
    if (result.isSuccess) {
      setState(() => _profile = {
        ...?_profile,
        'name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
      });
      Navigator.pop(context);
      _showSnack('Profile updated!');
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[800] : const Color(0xFFFFD700),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditProfileSheet(
        nameCtrl: _nameCtrl,
        bioCtrl: _bioCtrl,
        saving: _savingProfile,
        onSave: _saveProfileChanges,
        onPickPhoto: _pickAndUploadPhoto,
        currentPhotoUrl: _profile?['profile_photo_url'],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Center(child: Text(_error!, style: const TextStyle(color: Colors.white54))),
      );
    }

    final tier = (_profile?['tier'] as String? ?? 'explorer').toLowerCase();
    final tierCfg = _tiers[tier] ?? _tiers['explorer']!;
    final helpfulVotes = (_profile?['helpful_votes'] as int?) ?? 0;
    final reviewCount = (_profile?['review_count'] as int?) ?? 0;
    final isVerified = (_profile?['verified'] as bool?) ?? false;
    final name = _profile?['name'] as String? ?? '—';
    final bio = _profile?['bio'] as String?;
    final photoUrl = _profile?['profile_photo_url'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      // ── Correct responsive pattern:
      // Scaffold → DefaultTabController (already provided via _tabController)
      // → NestedScrollView with SliverAppBar + TabBar pinned
      // → TabBarView inside body (handles its own scroll per tab)
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: const Color(0xFF0D0D0D),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'LocalLens',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                fontFamily: 'serif',
              ),
            ),
            actions: [
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  onPressed: _openEditSheet,
                ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          // Profile header as a sliver — no fixed expandedHeight, sizes to content
          SliverToBoxAdapter(
            child: _ProfileHeader(
              profile: _profile!,
              tier: tier,
              tierCfg: tierCfg,
              helpfulVotes: helpfulVotes,
              reviewCount: reviewCount,
              isVerified: isVerified,
              name: name,
              bio: bio,
              photoUrl: photoUrl,
              visitedCount: _visited.length,
              isOwnProfile: _isOwnProfile,
              storageService: _storageService,
              onEditTap: _openEditSheet,
              onCameraTap: _pickAndUploadPhoto,
            ),
          ),
          // TabBar pinned below header
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFFFFD700),
                unselectedLabelColor: Colors.white38,
                indicatorColor: const Color(0xFFFFD700),
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Reviews'),
                  Tab(text: 'Visited'),
                  Tab(text: 'Rewards'),
                ],
              ),
            ),
          ),
        ],
        // Each tab manages its own scroll — no Expanded/Column wrapping here
        body: TabBarView(
          controller: _tabController,
          children: [
            _ReviewsTab(
              reviews: _reviews,
              loading: _loadingReviews,
              onRefresh: () => _loadReviews(_targetUserId),
            ),
            _VisitedTab(visited: _visited, loading: _loadingVisited),
            _RewardsTab(
              active: _activeRewards,
              redeemed: _redeemedRewards,
              loading: _loadingRewards,
              isOwnProfile: _isOwnProfile,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Persistent header delegate for TabBar ────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0D0D0D),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ── Profile header — self-sizing, no fixed height ────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String tier;
  final _TierConfig tierCfg;
  final int helpfulVotes;
  final int reviewCount;
  final bool isVerified;
  final String name;
  final String? bio;
  final String? photoUrl;
  final int visitedCount;
  final bool isOwnProfile;
  final StorageService storageService;
  final VoidCallback onEditTap;
  final VoidCallback onCameraTap;

  const _ProfileHeader({
    required this.profile,
    required this.tier,
    required this.tierCfg,
    required this.helpfulVotes,
    required this.reviewCount,
    required this.isVerified,
    required this.name,
    required this.bio,
    required this.photoUrl,
    required this.visitedCount,
    required this.isOwnProfile,
    required this.storageService,
    required this.onEditTap,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min, // critical — sizes to content only
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tierCfg.color, width: 2.5),
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white12,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(storageService.getProfilePhotoUrl(photoUrl!))
                      : null,
                  child: photoUrl == null
                      ? const Icon(Icons.person, color: Colors.white54, size: 36)
                      : null,
                ),
              ),
              if (isOwnProfile)
                GestureDetector(
                  onTap: onCameraTap,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: tierCfg.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0D0D0D), width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.black, size: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 8),

          // Badges
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _TierBadge(config: tierCfg),
              if (isVerified) const _VerifiedBadge(),
            ],
          ),

          // Bio
          if (bio != null && bio!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bio!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
            ),
          ],
          const SizedBox(height: 18),

          // Stats
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(value: reviewCount.toString(), label: 'Reviews'),
                const VerticalDivider(color: Colors.white12, width: 1),
                _StatItem(value: helpfulVotes.toString(), label: 'Helpful\nVotes'),
                const VerticalDivider(color: Colors.white12, width: 1),
                _StatItem(
                  value: visitedCount == 0 ? '—' : visitedCount.toString(),
                  label: 'Visited',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tier progress bar
          if (tier != 'platinum')
            _TierProgressBar(
              tier: tier,
              tierCfg: tierCfg,
              helpfulVotes: helpfulVotes,
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// REVIEWS TAB
// ════════════════════════════════════════════════════════════════════════════════
class _ReviewsTab extends StatelessWidget {
  final List<dynamic> reviews;
  final bool loading;
  final VoidCallback onRefresh;

  const _ReviewsTab({
    required this.reviews,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (reviews.isEmpty) {
      return _EmptyState(
        icon: Icons.rate_review_outlined,
        message: 'No reviews yet',
        sub: 'Reviews you write will appear here',
      );
    }
    return RefreshIndicator(
      color: const Color(0xFFFFD700),
      backgroundColor: const Color(0xFF1A1A1A),
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: reviews.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _ReviewCard(review: reviews[i]),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final restaurant = review['restaurants'] as Map<String, dynamic>?;
    final restaurantName = restaurant?['name'] as String? ?? 'Unknown Place';
    final restaurantPhotos = restaurant?['photos'] as List? ?? [];
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final body = review['body'] as String? ?? '';
    final moodTag = review['mood_tag'] as String? ?? '';
    final helpfulVotes = review['helpful_votes'] as int? ?? 0;
    final photos = review['photos'] as List? ?? [];
    final dishMentions = review['dish_mentions'] as List? ?? [];
    final createdAt = review['created_at'] as String?;

    final moodColor = moodTag == 'loved_it'
        ? Colors.green
        : moodTag == 'good'
        ? const Color(0xFFFFD700)
        : Colors.orange;

    final moodLabel = moodTag == 'loved_it'
        ? '❤️ Loved it'
        : moodTag == 'good'
        ? '👍 Good'
        : '😐 Average';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Restaurant header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: restaurantPhotos.isNotEmpty
                      ? Image.network(
                    restaurantPhotos.first.toString(),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderThumb(),
                  )
                      : _placeholderThumb(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurantName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(createdAt),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFFD700), size: 12),
                      const SizedBox(width: 3),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: moodColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: moodColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    moodLabel,
                    style: TextStyle(
                      color: moodColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (dishMentions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: dishMentions
                        .take(4)
                        .map((d) => _DishChip(name: d.toString()))
                        .toList(),
                  ),
                ],
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, pi) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          photos[pi].toString(),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderThumb(size: 72),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                const Icon(Icons.thumb_up_outlined, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$helpfulVotes helpful',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderThumb({double size = 44}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white12,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.restaurant, color: Colors.white24, size: 20),
  );

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// VISITED TAB
// ════════════════════════════════════════════════════════════════════════════════
class _VisitedTab extends StatelessWidget {
  final List<dynamic> visited;
  final bool loading;
  const _VisitedTab({required this.visited, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (visited.isEmpty) {
      return _EmptyState(
        icon: Icons.place_outlined,
        message: 'No places visited yet',
        sub: 'Restaurants you review will appear here',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: visited.length,
      itemBuilder: (ctx, i) => _VisitedCard(restaurant: visited[i]),
    );
  }
}

class _VisitedCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  const _VisitedCard({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final name = restaurant['name'] as String? ?? '—';
    final photos = restaurant['photos'] as List? ?? [];
    final score = (restaurant['algorithm_score'] as num?)?.toDouble();
    final priceTier = restaurant['price_tier'] as int? ?? 1;
    final category = restaurant['category'] as String? ?? '';
    final priceStr = '৳' * priceTier;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: photos.isNotEmpty
                  ? Image.network(
                photos.first.toString(),
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
                  : _placeholder(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      priceStr,
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11),
                    ),
                  ],
                ),
                if (score != null) ...[
                  const SizedBox(height: 4),
                  _ScoreChip(score: score),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    color: Colors.white.withValues(alpha: 0.06),
    child: const Center(child: Icon(Icons.restaurant, color: Colors.white24)),
  );
}

// ════════════════════════════════════════════════════════════════════════════════
// REWARDS TAB
// ════════════════════════════════════════════════════════════════════════════════
class _RewardsTab extends StatelessWidget {
  final List<dynamic> active;
  final List<dynamic> redeemed;
  final bool loading;
  final bool isOwnProfile;

  const _RewardsTab({
    required this.active,
    required this.redeemed,
    required this.loading,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile) {
      return _EmptyState(
        icon: Icons.lock_outline,
        message: 'Private',
        sub: 'Rewards are only visible to the account owner',
      );
    }
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (active.isEmpty && redeemed.isEmpty) {
      return _EmptyState(
        icon: Icons.card_giftcard_outlined,
        message: 'No rewards yet',
        sub: 'Keep reviewing to unlock tier rewards',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (active.isNotEmpty) ...[
          _sectionLabel('Active Rewards (${active.length})'),
          const SizedBox(height: 10),
          ...active.map((r) => _RewardCard(item: r, isRedeemed: false)),
          const SizedBox(height: 20),
        ],
        if (redeemed.isNotEmpty) ...[
          _sectionLabel('Redeemed (${redeemed.length})'),
          const SizedBox(height: 10),
          ...redeemed.map((r) => _RewardCard(item: r, isRedeemed: true)),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    ),
  );
}

class _RewardCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isRedeemed;
  const _RewardCard({required this.item, required this.isRedeemed});

  @override
  Widget build(BuildContext context) {
    final reward = item['rewards'] as Map<String, dynamic>?;
    if (reward == null) return const SizedBox.shrink();

    final restaurant = reward['restaurants'] as Map<String, dynamic>?;
    final restaurantName = restaurant?['name'] as String? ?? 'Unknown Place';
    final type = reward['type'] as String? ?? '';
    final value = reward['value'] as String? ?? '';
    final description = reward['description'] as String? ?? '';
    final tierRequired = reward['tier_required'] as String? ?? '';
    final expiryDate = reward['expiry_date'] as String?;

    final typeIcon = type == 'discount'
        ? Icons.percent
        : type == 'free_item'
        ? Icons.card_giftcard
        : Icons.shopping_bag_outlined;

    final typeColor = isRedeemed ? Colors.white24 : const Color(0xFFFFD700);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRedeemed
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRedeemed
              ? Colors.white10
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: typeColor.withValues(alpha: 0.3)),
            ),
            child: Icon(typeIcon, color: typeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: isRedeemed ? Colors.white38 : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  restaurantName,
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                if (expiryDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    isRedeemed ? 'Redeemed' : 'Expires ${_formatDate(expiryDate)}',
                    style: TextStyle(
                      color: isRedeemed ? Colors.white24 : Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _TierPill(tier: tierRequired),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return iso;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// EDIT PROFILE BOTTOM SHEET
// ════════════════════════════════════════════════════════════════════════════════
class _EditProfileSheet extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController bioCtrl;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onPickPhoto;
  final String? currentPhotoUrl;

  const _EditProfileSheet({
    required this.nameCtrl,
    required this.bioCtrl,
    required this.saving,
    required this.onSave,
    required this.onPickPhoto,
    this.currentPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Pushes sheet up when keyboard appears
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Edit Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: onPickPhoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white12,
                      backgroundImage: currentPhotoUrl != null
                          ? NetworkImage(currentPhotoUrl!)
                          : null,
                      child: currentPhotoUrl == null
                          ? const Icon(Icons.person, color: Colors.white38, size: 36)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.black, size: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _inputLabel('Name'),
            const SizedBox(height: 6),
            _inputField(controller: nameCtrl, hint: 'Your display name'),
            const SizedBox(height: 16),
            _inputLabel('Bio'),
            const SizedBox(height: 6),
            _inputField(
              controller: bioCtrl,
              hint: 'A short description about yourself',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: saving ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor:
                  const Color(0xFFFFD700).withValues(alpha: 0.4),
                ),
                child: saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black),
                )
                    : const Text(
                  'Save Changes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputLabel(String text) =>
      Text(text, style: const TextStyle(color: Colors.white60, fontSize: 12));

  Widget _inputField({
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════════
// TIER PROGRESS BAR
// ════════════════════════════════════════════════════════════════════════════════
class _TierProgressBar extends StatelessWidget {
  final String tier;
  final _TierConfig tierCfg;
  final int helpfulVotes;

  const _TierProgressBar({
    required this.tier,
    required this.tierCfg,
    required this.helpfulVotes,
  });

  @override
  Widget build(BuildContext context) {
    if (tierCfg.votesRequired == null) return const SizedBox.shrink();

    const tierStarts = {'explorer': 0, 'expert': 50, 'diamond': 200};
    final start = tierStarts[tier] ?? 0;
    final end = tierCfg.votesRequired!;
    final progress = ((helpfulVotes - start) / (end - start)).clamp(0.0, 1.0);
    final remaining = (end - helpfulVotes).clamp(0, end);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next: ${tierCfg.nextTier}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              Text(
                '$helpfulVotes / $end votes',
                style: TextStyle(
                  color: tierCfg.color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(tierCfg.color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$remaining more helpful votes to reach ${tierCfg.nextTier}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// SMALL REUSABLE WIDGETS
// ════════════════════════════════════════════════════════════════════════════════
class _TierBadge extends StatelessWidget {
  final _TierConfig config;
  const _TierBadge({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: config.color, size: 12),
          const SizedBox(width: 4),
          Text(
            config.label.toUpperCase(),
            style: TextStyle(
              color: config.color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, color: Colors.green, size: 12),
          SizedBox(width: 4),
          Text(
            'VERIFIED',
            style: TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final double score;
  const _ScoreChip({required this.score});

  Color get _color {
    if (score >= 90) return const Color(0xFF00E676);
    if (score >= 75) return const Color(0xFFFFD700);
    if (score >= 60) return Colors.orange;
    return Colors.red[300]!;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.analytics_outlined, color: _color, size: 11),
        const SizedBox(width: 3),
        Text(
          score.toStringAsFixed(0),
          style: TextStyle(
            color: _color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _DishChip extends StatelessWidget {
  final String name;
  const _DishChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        name,
        style: const TextStyle(color: Colors.white60, fontSize: 11),
      ),
    );
  }
}

class _TierPill extends StatelessWidget {
  final String tier;
  const _TierPill({required this.tier});

  @override
  Widget build(BuildContext context) {
    const colors = {
      'explorer': Color(0xFFCD7F32),
      'expert': Color(0xFFC0C0C0),
      'diamond': Color(0xFF00BFFF),
      'platinum': Color(0xFFE5E4E2),
    };
    final color = colors[tier.toLowerCase()] ?? Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        tier.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white12, size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: const TextStyle(color: Colors.white24, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// TIER CONFIG
// ════════════════════════════════════════════════════════════════════════════════
class _TierConfig {
  final String label;
  final Color color;
  final IconData icon;
  final String? nextTier;
  final int? votesRequired;

  const _TierConfig({
    required this.label,
    required this.color,
    required this.icon,
    required this.nextTier,
    required this.votesRequired,
  });
}