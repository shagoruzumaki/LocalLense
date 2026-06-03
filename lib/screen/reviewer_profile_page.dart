import 'package:flutter/material.dart';

class ReviewerProfilePage extends StatelessWidget {
  const ReviewerProfilePage({super.key});

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
        title: const Text('Reviewer Profile', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontFamily: 'serif')),
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=200&auto=format&fit=crop'),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                    child: const Icon(Icons.diamond, color: Color(0xFF00E5FF), size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Arif Rahman', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'serif')),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 4),
                const Text('Dhaka', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('DIAMOND REVIEWER', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 24),
            // Stats Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat('47', 'REVIEWS'),
                _buildStat('612', 'HELPFUL'),
                _buildStat('38', 'VISITED'),
              ],
            ),
            const SizedBox(height: 24),
            // Progress Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.military_tech, color: Color(0xFFFFD700)),
                          SizedBox(width: 8),
                          Text('Progress to Platinum', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(text: '612 ', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                            TextSpan(text: '/ 1000 votes', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      value: 0.612,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Tabs
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TabItem(label: 'Reviews', isSelected: true),
                _TabItem(label: 'Stats'),
                _TabItem(label: 'Visited'),
              ],
            ),
            const SizedBox(height: 20),
            // Filter Chips
            Row(
              children: [
                _buildChip('Recent', isSelected: true),
                _buildChip('Highest Rated'),
                _buildChip('Critical'),
              ],
            ),
            const SizedBox(height: 24),
            // Review List
            _buildReviewCard(
                'Salt & Fire Grill',
                'RESTAURANT',
                'The smoked hilsa here is a revelation. Arif Rahman\'s recommendation was spot on. The balance of traditional...',
                '124', '12', '2 days ago'
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          child: const Text('FOLLOW ARIF RAHMAN', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildStat(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.0)),
      ],
    );
  }

  Widget _buildChip(String label, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildReviewCard(String title, String type, String body, String likes, String comments, String date) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Color(0xFFFFD700), size: 16),
              const SizedBox(width: 8),
              const Text('COMMUNITY FAVOURITE REVIEW', style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(type, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    const Row(children: [Icon(Icons.star, color: Color(0xFFFFD700), size: 10), Icon(Icons.star, color: Color(0xFFFFD700), size: 10), Icon(Icons.star, color: Color(0xFFFFD700), size: 10), Icon(Icons.star, color: Color(0xFFFFD700), size: 10), Icon(Icons.star, color: Color(0xFFFFD700), size: 10)]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.thumb_up_outlined, color: Color(0xFFFFD700), size: 16),
              const SizedBox(width: 4),
              Text(likes, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
              const SizedBox(width: 16),
              const Icon(Icons.chat_bubble_outline, color: Colors.white38, size: 16),
              const SizedBox(width: 4),
              Text(comments, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const Spacer(),
              Text(date, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  const _TabItem({required this.label, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: isSelected ? const Color(0xFFFFD700) : Colors.white38, fontWeight: FontWeight.bold)),
        if (isSelected) Container(margin: const EdgeInsets.only(top: 4), height: 2, width: 60, color: const Color(0xFFFFD700)),
      ],
    );
  }
}
