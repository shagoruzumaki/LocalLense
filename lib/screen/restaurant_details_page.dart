import 'dart:io' show File;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../api/review_system.dart';
import '../api/ai_summary.dart';
import '../services/discovery_service.dart';
import '../model/restaurant.dart';
import 'map_page.dart';
import 'score_breakdown_page.dart';
import 'reviewer_profile_page.dart';
import '../model/dish.dart';
import 'dish_details_page.dart';

class RestaurantDetailsPage extends StatefulWidget {
  final String? restaurantId;
  const RestaurantDetailsPage({super.key, this.restaurantId});

  @override
  State<RestaurantDetailsPage> createState() => _RestaurantDetailsPageState();
}

class _RestaurantDetailsPageState extends State<RestaurantDetailsPage> {
  final DiscoveryService _discoveryService = DiscoveryService();
  final ReviewApi _reviewApi = ReviewApi();
  final AiSummaryApi _aiSummaryApi = AiSummaryApi();

  RestaurantWithScore? _data;
  AlgorithmScore? _scoreBreakdown;
  bool _isLoading = true;

  // AI Summary state
  String? _aiSummary;
  List<String> _aiTags = [];
  bool _loadingSummary = false;

  int _selectedTab = 0; // 0=Overview, 1=Menu, 2=Reviews, 3=Photos
  List<Map<String, dynamic>> _reviews = [];
  bool _loadingReviews = false;
  final Set<String> _votedReviewIds = {};

  // Dishes/Menu state
  List<Map<String, dynamic>> _dishes = [];
  bool _loadingDishes = false;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  // Real-time subscriptions
  StreamSubscription? _reviewSubscription;
  StreamSubscription? _restaurantSubscription;
  StreamSubscription? _dishSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final id = widget.restaurantId ?? (args is String ? args : null);
      if (id != null) {
        _initData(id);
      }
    }
  }

  @override
  void dispose() {
    _reviewSubscription?.cancel();
    _restaurantSubscription?.cancel();
    _dishSubscription?.cancel();
    super.dispose();
  }

  void _initData(String id) {
    _fetchDetails(id);
    _loadReviews(id);
    _loadDishes(id);
    _setupRealtime(id);
  }

  // ─────────────────────────────────────────────
  // Real-time updates: Automatically refresh data
  // when anything related to this restaurant changes
  // ─────────────────────────────────────────────
  void _setupRealtime(String restaurantId) {
    final supabase = Supabase.instance.client;

    // Listen for new or updated reviews for this restaurant
    _reviewSubscription = supabase
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', restaurantId)
        .listen((_) => _loadReviews(restaurantId, silent: true));

    // Listen for restaurant changes (score, address, etc.)
    _restaurantSubscription = supabase
        .from('restaurants')
        .stream(primaryKey: ['id'])
        .eq('id', restaurantId)
        .listen((_) => _fetchDetails(restaurantId, silent: true));

    // Listen for menu changes
    _dishSubscription = supabase
        .from('dishes')
        .stream(primaryKey: ['id'])
        .eq('restaurant_id', restaurantId)
        .listen((_) => _loadDishes(restaurantId, silent: true));
  }

  Future<void> _fetchDetails(String id, {bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final detail = await _discoveryService.getRestaurantDetail(id);
      final score = await _discoveryService.getScoreBreakdown(id);

      if (mounted) {
        setState(() {
          _data = detail;
          _scoreBreakdown = score;
          _isLoading = false;
        });
        // Load AI summary after restaurant data is ready
        await _loadAiSummary(id);
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAiSummary(String restaurantId) async {
    if (!mounted) return;
    setState(() => _loadingSummary = true);
    try {
      final result = await _aiSummaryApi.getSummary(restaurantId);
      if (mounted) {
        setState(() {
          _aiSummary = result?['ai_summary'] as String?;
          _aiTags = result != null
              ? List<String>.from(result['ai_tags'] ?? [])
              : [];
        });
      }
    } catch (e) {
      debugPrint('[RestaurantDetails] Failed to load AI summary: $e');
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _loadReviews(String id, {bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _loadingReviews = true);
    try {
      final reviews = await _reviewApi.getRestaurantReviews(id);
      if (mounted) {
        setState(() => _reviews = reviews);
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load reviews: $e')));
      }
    } finally {
      if (mounted && !silent) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _loadDishes(String restaurantId, {bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _loadingDishes = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('dishes')
          .select('id, name, description, price, photo_url, is_available, avg_rating, review_count')
          .eq('restaurant_id', restaurantId)
          .eq('is_available', true)
          .order('name', ascending: true);

      if (mounted) {
        setState(() => _dishes = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      debugPrint('[RestaurantDetails] Failed to load dishes: $e');
    } finally {
      if (mounted && !silent) setState(() => _loadingDishes = false);
    }
  }

  Future<void> _handleVote(String reviewId) async {
    final alreadyVoted = _votedReviewIds.contains(reviewId);
    try {
      if (alreadyVoted) {
        await _reviewApi.unvoteReview(reviewId);
        setState(() {
          _votedReviewIds.remove(reviewId);
          final idx = _reviews.indexWhere((r) => r['id'] == reviewId);
          if (idx != -1) {
            _reviews[idx]['helpful_votes'] =
                ((_reviews[idx]['helpful_votes'] as int?) ?? 1) - 1;
          }
        });
      } else {
        await _reviewApi.voteReview(reviewId);
        setState(() {
          _votedReviewIds.add(reviewId);
          final idx = _reviews.indexWhere((r) => r['id'] == reviewId);
          if (idx != -1) {
            _reviews[idx]['helpful_votes'] =
                ((_reviews[idx]['helpful_votes'] as int?) ?? 0) + 1;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _openReviewForm({Map<String, dynamic>? editReview}) {
    if (_data == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReviewFormSheet(
        restaurantId: _data!.restaurant.id,
        reviewApi: _reviewApi,
        availableDishes: _dishes,
        editReview: editReview,
        onSubmitted: () {
          final id = _data!.restaurant.id;
          _fetchDetails(id, silent: true);
          _loadReviews(id);
          _loadDishes(id, silent: true);
          setState(() => _selectedTab = 2);
        },
      ),
    );
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Review',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this review?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _reviewApi.deleteReview(reviewId);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Review deleted')));

      if (_data != null) {
        final id = _data!.restaurant.id;
        _fetchDetails(id, silent: true);
        _loadReviews(id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete review: $e')));
    }
  }

  void _navigateToDirections() {
    if (_data == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPage(targetRestaurant: _data!.restaurant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        ),
      );
    }

    if (_data == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: Text(
            'Restaurant not found',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final r = _data!.restaurant;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          CustomScrollView(
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
                        errorBuilder: (c, e, s) =>
                            Container(color: Colors.white10),
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
                                _buildBadge(
                                  r.categoryDisplay.toUpperCase(),
                                  const Color(0xFFFFD700),
                                ),
                                const SizedBox(width: 8),
                                if (r.active)
                                  _buildBadge('VERIFIED', Colors.green),
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
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
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
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.bookmark_border,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Score Card
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ScoreBreakdownPage(restaurantId: r.id),
                          ),
                        ),
                        child: Container(
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
                                  _buildScoreCircle(
                                    (r.algorithmScore ?? 0).toInt(),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Algorithm Score',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _data!.scoreLabel,
                                          style: const TextStyle(
                                            color: Color(0xFFFFD700),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFFD700,
                                        ),
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                        ),
                                      ),
                                      child: const Text(
                                        'BOOK TABLE',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {},
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Colors.white24,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                        ),
                                      ),
                                      child: const Icon(Icons.share_outlined),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      // Tabs Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _TabItem(
                            label: 'OVERVIEW',
                            isSelected: _selectedTab == 0,
                            onTap: () => setState(() => _selectedTab = 0),
                          ),
                          _TabItem(
                            label: 'MENU',
                            isSelected: _selectedTab == 1,
                            onTap: () => setState(() => _selectedTab = 1),
                          ),
                          _TabItem(
                            label: 'REVIEWS',
                            isSelected: _selectedTab == 2,
                            onTap: () => setState(() => _selectedTab = 2),
                          ),
                          _TabItem(
                            label: 'PHOTOS',
                            isSelected: _selectedTab == 3,
                            onTap: () => setState(() => _selectedTab = 3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      // Tab Content
                      if (_selectedTab == 0) _buildOverviewTab(),
                      if (_selectedTab == 1) _buildMenuTab(),
                      if (_selectedTab == 2) _buildReviewsTab(),
                      if (_selectedTab == 3) _buildPhotosTab(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Write Review Bottom Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: _openReviewForm,
                icon: const Icon(Icons.edit_outlined),
                label: const Text(
                  'Write a Review',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // OVERVIEW TAB
  // ─────────────────────────────────────────────
  Widget _buildOverviewTab() {
    final r = _data!.restaurant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Community Summary'),
        const SizedBox(height: 10),
        _buildAiSummaryBox(),
        const SizedBox(height: 25),
        _buildSectionHeader('The Vibe'),
        const SizedBox(height: 10),
        const Text(
          'Stepping into this spot is akin to discovering a secret garden hidden within the city\'s concrete heart. The lighting is deliberate—low-slung amber bulbs that cast long, artistic shadows.',
          style: TextStyle(color: Colors.white60, height: 1.5),
        ),
        const SizedBox(height: 25),
        _buildSectionHeader('Location'),
        const SizedBox(height: 15),
        InkWell(
          onTap: _navigateToDirections,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white10,
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1526778548025-fa2f459cd5c1?q=80&w=500&auto=format&fit=crop',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFFFFD700),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.address,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFFFFD700), size: 20),
            const SizedBox(width: 10),
            Text(
              _data!.isOpenNow ? 'Open Now' : 'Closed',
              style: TextStyle(
                color: _data!.isOpenNow ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // AI SUMMARY BOX
  // 3 states: loading / no summary yet / real summary
  // ─────────────────────────────────────────────
  Widget _buildAiSummaryBox() {
    // State 1: Loading
    if (_loadingSummary) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFFD700),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Generating community summary...',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // State 2: No summary yet — fewer than 7 reviews
    if (_aiSummary == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white24, size: 16),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Community summary appears after 7 reviews.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    // State 3: Real AI summary from Gemini via Supabase
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 12),
                SizedBox(width: 4),
                Text(
                  'AI Summary',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Summary text — real from Gemini
          Text(
            '"$_aiSummary"',
            style: const TextStyle(
              color: Colors.white70,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          // Keyword tags
          if (_aiTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _aiTags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MENU TAB
  // ─────────────────────────────────────────────
  Widget _buildMenuTab() {
    if (_loadingDishes) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        ),
      );
    }

    if (_dishes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: const [
              Icon(Icons.restaurant_menu, color: Colors.white24, size: 48),
              SizedBox(height: 16),
              Text(
                'No menu available yet.',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_dishes.length} Items Available',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _dishes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final dish = _dishes[index];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DishDetailsPage(
                    dish: Dish(
                      id: dish['id'] as String,
                      restaurantId: _data!.restaurant.id,
                      name: dish['name'] as String? ?? '',
                      description: dish['description'] as String?,
                      price: (dish['price'] as num?)?.toDouble() ?? 0.0,
                      photoUrl: dish['photo_url'] as String?,
                      isAvailable: dish['is_available'] as bool? ?? true,
                      restaurantName: _data!.restaurant.name,
                      restaurantAddress: _data!.restaurant.address,
                      restaurantRating: _data!.restaurant.algorithmScore != null
                          ? _data!.restaurant.algorithmScore! / 20.0
                          : null,
                    ),
                  ),
                ),
              ),
              child: _buildDishCard(dish),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDishCard(Map<String, dynamic> dish) {
    final name = dish['name'] as String? ?? '';
    final description = dish['description'] as String? ?? '';
    final price = (dish['price'] as num?)?.toDouble() ?? 0.0;
    final photoUrl = dish['photo_url'] as String?;
    final avgRating = (dish['avg_rating'] as num?)?.toDouble();
    final reviewCount = dish['review_count'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dish photo
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: photoUrl != null && photoUrl.isNotEmpty
                ? Image.network(
                    photoUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildDishPlaceholder(),
                  )
                : _buildDishPlaceholder(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Price tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '৳ ${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Rating — only show if dish has been reviewed
                    if (avgRating != null && reviewCount > 0)
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Color(0xFFFFD700),
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '($reviewCount)',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'No ratings yet',
                        style: TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.restaurant, color: Colors.white24, size: 28),
    );
  }

  // ─────────────────────────────────────────────
  // REVIEWS TAB
  // ─────────────────────────────────────────────
  Widget _buildReviewsTab() {
    if (_loadingReviews) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        ),
      );
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: const [
              Icon(Icons.rate_review_outlined, color: Colors.white24, size: 48),
              SizedBox(height: 16),
              Text(
                'No reviews yet.',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Be the first to review this place!',
                style: TextStyle(color: Colors.white24, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_reviews.length} Reviews',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                if (_data != null) _loadReviews(_data!.restaurant.id);
              },
              child: const Text(
                'Refresh',
                style: TextStyle(color: Color(0xFFFFD700), fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _reviews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _buildReviewCard(_reviews[index]),
        ),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final user = review['users'] as Map<String, dynamic>? ?? {};
    final reviewId = review['id'] as String;
    final helpfulVotes = review['helpful_votes'] as int? ?? 0;
    final isVoted = _votedReviewIds.contains(reviewId);
    final moodTag = review['mood_tag'] as String? ?? '';
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final body = review['body'] as String? ?? '';
    final photos = List<String>.from(review['photos'] ?? []);
    final dishMentions = List<String>.from(review['dish_mentions'] ?? []);
    final tier = user['tier'] as String? ?? 'explorer';
    final name = user['name'] as String? ?? 'Anonymous';
    final verified = user['verified'] as bool? ?? false;
    final isOwner = review['user_id'] == _currentUserId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFFFD700).withOpacity(0.2),
                backgroundImage: user['profile_photo_url'] != null
                    ? NetworkImage(user['profile_photo_url'] as String)
                    : null,
                child: user['profile_photo_url'] == null
                    ? Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final userId = user['id'] as String?;
                            if (userId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReviewerProfilePage(userId: userId),
                                ),
                              );
                            }
                          },
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white38,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        _buildTierBadge(tier),
                        const SizedBox(width: 8),
                        _buildStars(rating, size: 12),
                      ],
                    ),
                  ],
                ),
              ),
              _buildMoodTagBadge(moodTag),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          if (dishMentions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: dishMentions
                  .map(
                    (dish) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.restaurant_menu,
                            size: 10,
                            color: Color(0xFFFFD700),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dish,
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    photos[i],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => _handleVote(reviewId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isVoted
                        ? const Color(0xFFFFD700).withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isVoted
                          ? const Color(0xFFFFD700).withOpacity(0.5)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                        color: isVoted ? const Color(0xFFFFD700) : Colors.white38,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$helpfulVotes Helpful',
                        style: TextStyle(
                          color: isVoted ? const Color(0xFFFFD700) : Colors.white38,
                          fontSize: 13,
                          fontWeight: isVoted ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (isOwner) ...[
                IconButton(
                  tooltip: 'Edit review',
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFFFFD700),
                    size: 18,
                  ),
                  onPressed: () => _openReviewForm(editReview: review),
                ),
                IconButton(
                  tooltip: 'Delete review',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  onPressed: () => _deleteReview(reviewId),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PHOTOS TAB — from File 2: real community photos grid
  // ─────────────────────────────────────────────
  Widget _buildPhotosTab() {
    final List<String> allPhotos =
        _reviews.expand((r) => List<String>.from(r['photos'] ?? [])).toList();

    if (_loadingReviews) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        ),
      );
    }

    if (allPhotos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Text(
            'No community photos yet.',
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allPhotos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          allPhotos[i],
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(color: Colors.white10),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SHARED HELPER WIDGETS
  // ─────────────────────────────────────────────
  Widget _buildTierBadge(String tier) {
    final colors = {
      'platinum': Colors.cyanAccent,
      'diamond': Colors.lightBlueAccent,
      'expert': Colors.purpleAccent,
      'explorer': Colors.white38,
    };
    final color = colors[tier.toLowerCase()] ?? Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
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

  Widget _buildMoodTagBadge(String moodTag) {
    final map = {
      'loved_it': ('❤️ Loved it', Colors.redAccent),
      'good': ('👍 Good', Colors.greenAccent),
      'average': ('😐 Average', Colors.orangeAccent),
    };
    final data = map[moodTag] ?? ('', Colors.white38);
    if (data.$1.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: data.$2.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: data.$2.withOpacity(0.3)),
      ),
      child: Text(data.$1, style: TextStyle(color: data.$2, fontSize: 11)),
    );
  }

  Widget _buildStars(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return Icon(Icons.star, color: const Color(0xFFFFD700), size: size);
        } else if (i < rating) {
          return Icon(
            Icons.star_half,
            color: const Color(0xFFFFD700),
            size: size,
          );
        } else {
          return Icon(Icons.star_border, color: Colors.white24, size: size);
        }
      }),
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
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'serif',
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// TAB ITEM
// ═══════════════════════════════════════════════
class _TabItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _TabItem({
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFFFD700) : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 40,
              color: const Color(0xFFFFD700),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// REVIEW FORM SHEET
// ═══════════════════════════════════════════════
class _ReviewFormSheet extends StatefulWidget {
  final String restaurantId;
  final ReviewApi reviewApi;
  final List<Map<String, dynamic>> availableDishes;
  final VoidCallback onSubmitted;
  final Map<String, dynamic>? editReview;

  const _ReviewFormSheet({
    required this.restaurantId,
    required this.reviewApi,
    required this.availableDishes,
    required this.onSubmitted,
    this.editReview,
  });

  @override
  State<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<_ReviewFormSheet> {
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _dishController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedMood = '';
  double _selectedRating = 0;
  List<XFile> _selectedPhotos = [];
  List<String> _existingPhotos = [];
  final Set<String> _selectedDishes = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    final review = widget.editReview;
    if (review == null) return;

    _bodyController.text = review['body'] as String? ?? '';
    _selectedMood = review['mood_tag'] as String? ?? '';
    _selectedRating = (review['rating'] as num?)?.toDouble() ?? 0;
    _existingPhotos = List<String>.from(review['photos'] ?? []);

    final dishMentions = List<String>.from(review['dish_mentions'] ?? []);
    _selectedDishes.addAll(dishMentions);
    final knownDishNames = widget.availableDishes
        .map((dish) => dish['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
    final manualDishes =
        dishMentions.where((dish) => !knownDishNames.contains(dish)).toList();
    _dishController.text = manualDishes.join(', ');
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() => _selectedPhotos = picked.take(10).toList());
    }
  }

  Future<List<String>> _uploadPhotos() async {
    final supabase = Supabase.instance.client;
    final List<String> urls = [];
    for (final photo in _selectedPhotos) {
      final bytes = await photo.readAsBytes();
      final fileName =
          'review_${DateTime.now().millisecondsSinceEpoch}_${photo.name}';
      await supabase.storage
          .from('review-photos')
          .uploadBinary(fileName, bytes);
      final url = supabase.storage.from('review-photos').getPublicUrl(fileName);
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submitReview() async {
    if (_selectedMood.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mood tag.')),
      );
      return;
    }
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating.')),
      );
      return;
    }
    if (_selectedPhotos.isEmpty && _existingPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 1 photo is required.')),
      );
      return;
    }
    if (_bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your review.')),
      );
      return;
    }
    if (_dishController.text.trim().isEmpty && _selectedDishes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please mention at least one dish you tried.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final photoUrls = await _uploadPhotos();
      final allPhotoUrls = [..._existingPhotos, ...photoUrls];

      final Set<String> allDishes = Set.from(_selectedDishes);
      if (_dishController.text.trim().isNotEmpty) {
        allDishes.addAll(
          _dishController.text
              .split(',')
              .map((d) => d.trim())
              .where((d) => d.isNotEmpty),
        );
      }

      await widget.reviewApi.submitReview(
        restaurantId: widget.restaurantId,
        moodTag: _selectedMood,
        rating: _selectedRating,
        photoUrls: allPhotoUrls,
        body: _bodyController.text.trim(),
        dishMentions: allDishes.toList(),
      );

      if (widget.editReview != null) {
        await widget.reviewApi.deleteReview(widget.editReview!['id'] as String);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.editReview != null
                  ? 'Review updated!'
                  : 'Review submitted successfully!',
            ),
            backgroundColor: const Color(0xFFFFD700),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.editReview != null ? 'Edit Review' : 'Write a Review',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'How was it?',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MoodButton(
                  emoji: '❤️',
                  label: 'Loved it',
                  value: 'loved_it',
                  selected: _selectedMood == 'loved_it',
                  onTap: () => setState(() => _selectedMood = 'loved_it'),
                ),
                const SizedBox(width: 10),
                _MoodButton(
                  emoji: '👍',
                  label: 'Good',
                  value: 'good',
                  selected: _selectedMood == 'good',
                  onTap: () => setState(() => _selectedMood = 'good'),
                ),
                const SizedBox(width: 10),
                _MoodButton(
                  emoji: '😐',
                  label: 'Average',
                  value: 'average',
                  selected: _selectedMood == 'average',
                  onTap: () => setState(() => _selectedMood = 'average'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Star Rating',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (i) {
                final starValue = (i + 1).toDouble();
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = starValue),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      i < _selectedRating ? Icons.star : Icons.star_border,
                      color: i < _selectedRating
                          ? const Color(0xFFFFD700)
                          : Colors.white24,
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Photos (min 1)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
              ),
            ),
                TextButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Color(0xFFFFD700),
                    size: 18,
                  ),
                  label: const Text(
                    'Add Photos',
                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 13),
                  ),
                ),
              ],
            ),
            if (_existingPhotos.isNotEmpty || _selectedPhotos.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._existingPhotos.asMap().entries.map((entry) {
                      final i = entry.key;
                      final url = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _existingPhotos.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    ..._selectedPhotos.asMap().entries.map((entry) {
                      final i = entry.key;
                      final photo = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.network(
                                      photo.path,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(photo.path),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedPhotos.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Your Review',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bodyController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'What did you think? Mention dishes, atmosphere...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFFD700)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Dishes Mentioned (required)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.availableDishes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.availableDishes.map((dish) {
                  final name = dish['name'] as String;
                  final isSelected = _selectedDishes.contains(name);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedDishes.remove(name);
                        } else {
                          _selectedDishes.add(name);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFFD700).withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFFD700)
                              : Colors.white12,
                        ),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          color:
                              isSelected ? const Color(0xFFFFD700) : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _dishController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add other dishes manually...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFFD700)),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor:
                      const Color(0xFFFFD700).withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        widget.editReview != null
                            ? 'Update Review'
                            : 'Submit Review',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _dishController.dispose();
    super.dispose();
  }
}

class _MoodButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _MoodButton({
    required this.emoji,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFD700).withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFFFFD700) : Colors.white12,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFFFFD700) : Colors.white38,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
