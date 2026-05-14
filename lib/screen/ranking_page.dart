import 'package:flutter/material.dart';

class RankingPage extends StatelessWidget {
  const RankingPage({super.key});

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top 10 Restaurants', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif')),
            Text('Dhaka • Updated weekly', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Time Period Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildTimeChip('This Week', isSelected: true),
                _buildTimeChip('This Month'),
                _buildTimeChip('All Time'),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildRankOneCard(
                  name: "Sultan's Dine",
                  location: "Gulshan 2, Dhaka",
                  score: "9.8",
                  description: "The gold standard for slow-cooked mutton kacchi biryani...",
                  imageUrl: "https://images.unsplash.com/photo-1589302168068-964664d93dc0?q=80&w=500&auto=format&fit=crop",
                ),
                const SizedBox(height: 16),
                _buildRankItem("2", "Izakaya", "Banani, Dhaka", "Known for authentic robata-style grilling..."),
                const SizedBox(height: 12),
                _buildRankItem("3", "The Atrium", "Baridhara, Dhaka", "Elegant fusion dining set within a garden..."),
                const SizedBox(height: 12),
                _buildRankItem("4", "Kacchi Bhai", "Multiple Locations", "Consistently ranked for its aromatic spice..."),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'VIEW REMAINING',
                    style: TextStyle(color: const Color(0xFFFFD700).withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFFFD700),
        child: const Icon(Icons.tune, color: Colors.black),
      ),
    );
  }

  Widget _buildTimeChip(String label, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: isSelected ? const Color(0xFFFFD700) : Colors.white10),
      ),
      child: Text(
        label,
        style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRankOneCard({required String name, required String location, required String score, required String description, required String imageUrl}) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Colors.transparent]),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text('1', style: TextStyle(color: Color(0xFFFFD700), fontSize: 48, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: const Color(0xFF2A2A2A), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFD700), width: 1)),
                        child: const Icon(Icons.stars, color: Color(0xFFFFD700), size: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text(score, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(location, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(description, style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('View Details', style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
                Icon(Icons.chevron_right, color: Color(0xFFFFD700), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankItem(String rank, String name, String location, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(rank, style: const TextStyle(color: Colors.white54, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'serif')),
          ),
          const SizedBox(width: 16),
          Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(location, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
