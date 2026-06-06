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
      final results = await Future.wait([
        _userService.getUserProfile(userId),
        _tierUpgradeApi.getTierInfo(userId),
        _reviewApi.getUserReviews(userId),
      ]);

      final userResult = results[0] as UserResult;

      if (mounted) {
        setState(() {
          _userData = userResult.data;
          _tierInfo = results[1] as Map<String, dynamic>;
          _reviews = results[2] as List<Map<String, dynamic>>;
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
    final nameController = TextEditingController(text: _userData?['name']);
    final bioController = TextEditingController(text: _userData?['bio'] ?? '');
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontFamily: 'serif')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD700))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD700))),
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
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD700))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD700))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
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
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully!')),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      );
    }

    if (_userData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: Text('User not found', style: TextStyle(color: Colors.white))),
      );
    }

    final String name = _userData?['name'] ?? 'Anonymous';
    final String? profilePhotoUrl = _userData?['profile_photo_url'];
    final String tier = (_tierInfo?['current_tier'] as String? ?? 'explorer').toUpperCase();
    final bool verified = _userData?['verified'] ?? false;
    final int helpfulVotes = _tierInfo?['helpful_votes'] ?? 0;
    final int votesNeeded = _tierInfo?['votes_needed'] ?? 0;
    final int threshold = _tierInfo?['threshold'] ?? 100;
    final double progress = threshold > 0 ? (helpfulVotes / threshold).clamp(0.0, 1.0) : 0.0;
    final String nextTier = (_tierInfo?['next_tier'] as String? ?? 'None').replaceAll('_', ' ');

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('LocalLens', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
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
              // Profile Header
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD700), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        backgroundImage: (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
                            ? NetworkImage(profilePhotoUrl)
                            : null,
                        child: (profilePhotoUrl == null || profilePhotoUrl.isEmpty)
                            ? const Icon(Icons.person, size: 50, color: Colors.white54)
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
                        child: const Icon(Icons.edit, color: Colors.black, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'serif'),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBadge(tier, _getTierColor(tier)),
                  if (verified) ...[
                    const SizedBox(width: 8),
                    _buildBadge('Verified • NID', Colors.green),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(_reviews.length.toString(), 'Reviews'),
                  _buildStatItem(helpfulVotes.toString(), 'Helpful'),
                  _buildStatItem(_userData?['points']?.toString() ?? '0', 'Points'),
                ],
              ),
              const SizedBox(height: 32),
              // Account Settings
              _buildSectionHeader('Account Settings'),
              const SizedBox(height: 16),
              _buildSettingsItem(Icons.verified_user_outlined, 'Verification',
                  onTap: () => Navigator.pushNamed(context, '/verification'),
                  trailing: verified ? _buildVerifiedBadge() : const Icon(Icons.chevron_right, color: Colors.white38)),
              _buildSettingsItem(Icons.person_outline, 'Personal Information', onTap: _showEditProfileDialog),
              _buildSettingsItem(Icons.payment_outlined, 'Payment Methods'),
              const SizedBox(height: 32),
              // Recent Reviews
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('Recent Reviews'),
                  TextButton(
                    onPressed: () {},
                    child: const Text('View All', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_reviews.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No reviews yet', style: TextStyle(color: Colors.white54)),
                )
              else
                ..._reviews.take(3).map((review) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildRecentReview(
                        review['restaurants']?['name'] ?? 'Unknown Restaurant',
                        review['body'] ?? '',
                        (review['rating'] ?? 0.0).toString(),
                        review['photos'] != null && (review['photos'] as List).isNotEmpty
                            ? (review['photos'] as List)[0]
                            : null,
                      ),
                    )),
              const SizedBox(height: 24),
              // Milestone
              if (nextTier != 'None')
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
                          const Text('Next Milestone', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('$helpfulVotes / $threshold Votes',
                              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                          children: [
                            TextSpan(text: 'Get $votesNeeded more helpful votes to unlock '),
                            TextSpan(
                                text: '$nextTier',
                                style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
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

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return Colors.blueGrey.shade200;
      case 'diamond':
        return Colors.cyan;
      case 'expert':
        return Colors.deepPurpleAccent;
      case 'explorer':
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
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'serif'),
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, {VoidCallback? onTap, Widget? trailing}) {
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
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const Spacer(),
            trailing ?? const Icon(Icons.chevron_right, color: Colors.white38),
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
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 12),
          SizedBox(width: 4),
          Text('VERIFIED', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRecentReview(String restaurantName, String content, String rating, String? photoUrl) {
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
          Row(
            children: [
              Expanded(
                child: Text(restaurantName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
              const SizedBox(width: 4),
              Text(rating, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(content,
              style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          if (photoUrl != null) ...[
            const SizedBox(height: 12),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white10,
                image: DecorationImage(
                  image: NetworkImage(photoUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
