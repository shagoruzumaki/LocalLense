import 'package:flutter/material.dart';
import '../../api/admin_api.dart';

/// Admin screen for Review moderation (CRUD: Read all + Approve + Delete).
/// Reviews aren't admin-created, so there's no "Add" here — moderation only.
class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  final AdminApi _adminApi = AdminApi();

  bool _isLoading = true;
  bool _showFlaggedOnly = true;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);
    try {
      final data = _showFlaggedOnly
          ? await _adminApi.getFlaggedReviews()
          : await _adminApi.getAllReviews();
      if (mounted) setState(() => _reviews = data);
    } catch (e) {
      _showSnack('Failed to load reviews: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFFFFD700),
    ));
  }

  Future<void> _approve(Map<String, dynamic> review) async {
    try {
      await _adminApi.approveReview(review['id'] as String);
      _showSnack('Review approved — flag cleared');
      _fetchReviews();
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    }
  }

  Future<void> _confirmRemove(Map<String, dynamic> review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Remove Review?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This permanently deletes the review and recalculates the restaurant\'s score. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminApi.removeReview(review['id'] as String);
        _showSnack('Review removed, scores updated');
        _fetchReviews();
      } catch (e) {
        _showSnack('Failed: $e', isError: true);
      }
    }
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
        title: const Text('Manage Reviews', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                _filterChip('Flagged', _showFlaggedOnly),
                const SizedBox(width: 10),
                _filterChip('All Reviews', !_showFlaggedOnly),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() => _showFlaggedOnly = label == 'Flagged');
        _fetchReviews();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (_reviews.isEmpty) {
      return Center(
        child: Text(
          _showFlaggedOnly ? 'No flagged reviews. All clear!' : 'No reviews found.',
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReviews,
      color: const Color(0xFFFFD700),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: _reviews.length,
        itemBuilder: (context, index) {
          final review = _reviews[index];
          final user = review['users'] as Map<String, dynamic>? ?? {};
          final restaurant = review['restaurants'] as Map<String, dynamic>? ?? {};
          final isFlagged = review['flagged'] == true;
          final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
          final helpfulVotes = review['helpful_votes'] ?? 0;
          final body = review['body'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isFlagged ? Colors.redAccent.withValues(alpha: 0.4) : Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        restaurant['name'] ?? 'Unknown Restaurant',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFlagged)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('FLAGGED', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('by ${user['name'] ?? 'Unknown'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 8),
                    const Icon(Icons.star, color: Color(0xFFFFD700), size: 13),
                    const SizedBox(width: 2),
                    Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('• $helpfulVotes helpful', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (isFlagged) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _approve(review),
                          icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.greenAccent),
                          label: const Text('Approve', style: TextStyle(color: Colors.greenAccent)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.greenAccent)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmRemove(review),
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        label: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
