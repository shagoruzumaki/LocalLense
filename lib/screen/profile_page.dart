import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../api/review_system.dart';
import '../api/tier_upgrade_api.dart';
import 'package:local_lense/admin/admin_dishes_screen.dart';
import 'package:local_lense/admin/admin_restaurants_screen.dart';
import 'package:local_lense/admin/admin_reviews_screen.dart';
import 'package:local_lense/theme/theme_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserService _userService = UserService();
  final ReviewApi _reviewApi = ReviewApi();
  final TierUpgradeApi _tierUpgradeApi = TierUpgradeApi();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _tierInfo;
  List<Map<String, dynamic>> _reviews = [];

  // Admin check — derived from _userData['role'], no extra network call needed.
  bool get _isAdmin => (_userData?['role'] as String?) == 'admin';

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
      final userResult = await _userService.getUserProfile(userId);
      final results = await Future.wait([
        _tierUpgradeApi.getTierInfo(userId),
        _reviewApi.getUserReviews(userId),
      ]);
      if (mounted) {
        setState(() {
          _userData = userResult.isSuccess ? userResult.data : null;
          _tierInfo = results[0] as Map<String, dynamic>;
          _reviews = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null) return;

      setState(() => _isUploadingPhoto = true);

      final bytes = await picked.readAsBytes();
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final ext = picked.name.split('.').last.toLowerCase();

      // bucket name matches your actual Supabase bucket 'profiile-photos'
      // (note the typo — double i — to match what you created)
      // To fix permanently: rename bucket in Supabase to 'profile-photos'
      const bucketName = 'profiile-photos';
      final filePath = 'avatars/$userId/avatar.$ext';

      await Supabase.instance.client.storage
          .from(bucketName)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'),
          );

      final publicUrl = Supabase.instance.client.storage
          .from(bucketName)
          .getPublicUrl(filePath);

      await Supabase.instance.client
          .from('users')
          .update({'profile_photo_url': publicUrl})
          .eq('id', userId);

      if (mounted) {
        setState(() {
          _userData = {..._userData ?? {}, 'profile_photo_url': publicUrl};
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: Color(0xFFFFD700),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    if (_userData == null) return;
    final nameController = TextEditingController(
      text: _userData?['name'] ?? '',
    );
    final bioController = TextEditingController(text: _userData?['bio'] ?? '');
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontFamily: 'serif'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bioController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newBio = bioController.text.trim();
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final result = await _userService.updateProfile(
                name: newName.isNotEmpty ? newName : null,
                bio: newBio.isNotEmpty ? newBio : null,
              );
              if (result.isSuccess) {
                await _fetchData();
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated!')),
                  );
              } else {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result.message)));
                }
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_userData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Failed to load profile'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final String name = _userData?['name'] ?? 'Anonymous';
    final String? profilePhotoUrl = _userData?['profile_photo_url'];
    final String? bio = _userData?['bio'];
    final bool verified = _userData?['verified'] ?? false;
    final String? idType = _userData?['id_type'];
    final int reviewCount = _userData?['review_count'] ?? _reviews.length;
    final String tier = (_tierInfo?['current_tier'] as String? ?? 'explorer')
        .toUpperCase();
    final int helpfulVotes = _tierInfo?['helpful_votes'] ?? 0;
    final int votesNeeded = _tierInfo?['votes_needed'] ?? 0;
    final int threshold = _tierInfo?['threshold'] ?? 50;
    final String nextTier = (_tierInfo?['next_tier'] as String? ?? 'none')
        .replaceAll('_', ' ');
    final tierStarts = {
      'explorer': 0,
      'expert': 50,
      'diamond': 200,
      'platinum': 500,
    };
    final String currentTierKey =
        (_tierInfo?['current_tier'] as String? ?? 'explorer');
    final int tierStart = tierStarts[currentTierKey] ?? 0;
    final double progress = currentTierKey == 'platinum'
        ? 1.0
        : (threshold - tierStart) > 0
        ? ((helpfulVotes - tierStart) / (threshold - tierStart)).clamp(0.0, 1.0)
        : 0.0;
    final String verifiedLabel = idType == 'student_id'
        ? 'Verified • Student ID'
        : 'Verified • NID';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'LocalLens',
          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
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
                          color: const Color(0xFFFFD700),
                          width: 2,
                        ),
                      ),
                      child: _isUploadingPhoto
                          ? const SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                color: Color(0xFFFFD700),
                                strokeWidth: 3,
                              ),
                            )
                          : CircleAvatar(
                              radius: 50,
                              backgroundColor: colors.surfaceContainerHighest,
                              backgroundImage:
                                  (profilePhotoUrl != null &&
                                      profilePhotoUrl.isNotEmpty)
                                  ? NetworkImage(profilePhotoUrl)
                                  : null,
                              child:
                                  (profilePhotoUrl == null ||
                                      profilePhotoUrl.isEmpty)
                                  ? Icon(
                                      Icons.person,
                                      size: 50,
                                      color: colors.onSurfaceVariant,
                                    )
                                  : null,
                            ),
                    ),
                    GestureDetector(
                      onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD700),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.black,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'serif',
                ),
              ),
              if (bio != null && bio.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _buildBadge(tier, _getTierColor(tier)),
                  if (verified) _buildBadge(verifiedLabel, Colors.green),
                  if (_isAdmin) _buildBadge('ADMIN', Colors.redAccent),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(reviewCount.toString(), 'Reviews'),
                  _buildStatItem(helpfulVotes.toString(), 'Helpful'),
                  _buildStatItem(
                    _calcPoints(helpfulVotes, tier).toString(),
                    'Points',
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Admin Panel (only visible to role == 'admin') ──────
              if (_isAdmin) ...[
                _buildSectionHeader('Admin Panel'),
                const SizedBox(height: 16),

                _buildSettingsItem(
                  Icons.storefront_outlined,
                  'Manage Restaurants',
                  subtitle: 'Add, edit, or deactivate restaurants',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminRestaurantsScreen(),
                    ),
                  ),
                ),

                _buildSettingsItem(
                  Icons.restaurant_menu_outlined,
                  'Manage Dishes',
                  subtitle: 'Pick a restaurant to manage its menu',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminDishesScreen(),
                    ),
                  ),
                ),

                _buildSettingsItem(
                  Icons.rate_review_outlined,
                  'Manage Reviews',
                  subtitle: 'Moderate, approve, or remove reviews',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminReviewsScreen(),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],

              _buildSectionHeader('Account Settings'),
              const SizedBox(height: 16),

              _buildSettingsItem(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                'Appearance',
                subtitle: Theme.of(context).brightness == Brightness.dark
                    ? 'Dark theme'
                    : 'Light theme',
                onTap: () => themeController.setMode(
                  Theme.of(context).brightness == Brightness.dark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                ),
                trailing: Switch.adaptive(
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (dark) => themeController.setMode(
                    dark ? ThemeMode.dark : ThemeMode.light,
                  ),
                ),
              ),

              _buildSettingsItem(
                Icons.verified_user_outlined,
                'Verification',
                subtitle: verified ? 'Verified' : 'Not verified',
                onTap: () => Navigator.pushNamed(context, '/verification'),
                trailing: verified
                    ? _buildVerifiedBadge()
                    : const Icon(Icons.chevron_right),
              ),

              _buildSettingsItem(
                Icons.person_outline,
                'Personal Information',
                subtitle: 'Edit name and bio',
                onTap: _showEditProfileDialog,
              ),

              _buildSettingsItem(
                Icons.photo_camera_outlined,
                'Change Profile Photo',
                subtitle: 'Upload from gallery',
                onTap: _pickAndUploadPhoto,
              ),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('Recent Reviews'),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'View All',
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_reviews.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: const Column(
                    children: [
                      Icon(Icons.rate_review_outlined, size: 48),
                      SizedBox(height: 12),
                      Text('No reviews yet', style: TextStyle(fontSize: 14)),
                      SizedBox(height: 4),
                      Text(
                        'Your reviews will appear here',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ..._reviews
                    .take(3)
                    .map(
                      (review) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildRecentReview(review),
                      ),
                    ),

              const SizedBox(height: 24),

              if (nextTier != 'none')
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Next Milestone',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '$helpfulVotes / $threshold Votes',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: colors.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFD700),
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  'Get $votesNeeded more helpful votes to unlock ',
                            ),
                            TextSpan(
                              text: nextTier,
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.bold,
                              ),
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

  int _calcPoints(int helpfulVotes, String tier) {
    final multipliers = {
      'PLATINUM': 4,
      'DIAMOND': 3,
      'EXPERT': 2,
      'EXPLORER': 1,
    };
    return helpfulVotes * (multipliers[tier] ?? 1);
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return Colors.blueGrey.shade200;
      case 'diamond':
        return Colors.cyan;
      case 'expert':
        return Colors.deepPurpleAccent;
      default:
        return Colors.amber;
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
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'serif',
        ),
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
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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

  Widget _buildRecentReview(Map<String, dynamic> review) {
    final restaurant = review['restaurants'] as Map<String, dynamic>? ?? {};
    final restaurantName = restaurant['name'] ?? 'Unknown Restaurant';
    final body = review['body'] ?? '';
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final helpfulVotes = review['helpful_votes'] ?? 0;
    final moodTag = review['mood_tag'] ?? 'good';
    final reviewPhotos = (review['photos'] as List<dynamic>?) ?? [];
    final restPhotos = (restaurant['photos'] as List<dynamic>?) ?? [];
    final photoUrl = reviewPhotos.isNotEmpty
        ? reviewPhotos[0].toString()
        : null;
    final restPhotoUrl = restPhotos.isNotEmpty
        ? restPhotos[0].toString()
        : null;
    final moodEmoji = moodTag == 'loved_it'
        ? '😍'
        : moodTag == 'good'
        ? '😊'
        : '😐';
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  restaurantName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(moodEmoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
              const SizedBox(width: 3),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeAgo,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
              fontSize: 13,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (photoUrl != null || restPhotoUrl != null || helpfulVotes > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
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
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.image_not_supported,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                if (helpfulVotes > 0)
                  Row(
                    children: [
                      Icon(
                        Icons.thumb_up_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$helpfulVotes helpful',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
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
