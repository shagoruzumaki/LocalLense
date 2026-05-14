import 'package:flutter/material.dart';

class ScoreBreakdownPage extends StatelessWidget {
  const ScoreBreakdownPage({super.key});

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
        title: const Text('LocalLens', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image
            Stack(
              children: [
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1559339352-11d035aa65de?q=80&w=1000&auto=format&fit=crop'),
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
                      colors: [Colors.black.withValues(alpha: 0.2), const Color(0xFF0D0D0D)],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Yugen Dining Hall',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'EXPERIMENTAL NEO-IZAKAYA • 1.2KM AWAY',
                        style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Algorithm Score Card
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
                      style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          '92',
                          style: TextStyle(color: Colors.black, fontSize: 64, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                        ),
                        Text(
                          ' / 100',
                          style: TextStyle(color: Colors.black.withValues(alpha: 0.5), fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildMetricRow('RATING', '98%', 0.98),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildMetricRow('PRICE', r'$$$', 0.6, labelOnly: true)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildMetricRow('TRUST', 'HIGH', 0.9, labelOnly: true)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildMetricRow('POPULARITY', '95%', 0.95, labelOnly: true)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildMetricRow('DISTANCE', 'CLOSE', 0.8, labelOnly: true)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Quick Info Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildQuickInfoCard(Icons.access_time, 'Open Now', 'UNTIL 2 AM'),
                  const SizedBox(width: 12),
                  _buildQuickInfoCard(Icons.restaurant_menu, 'Tasting', 'MENU ONLY'),
                  const SizedBox(width: 12),
                  _buildQuickInfoCard(Icons.confirmation_number_outlined, 'Waitlist', '15-20 MIN'),
                ],
              ),
            ),

            const SizedBox(height: 30),
            // Tabs
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _TabItem(label: 'Overview', isSelected: true),
                  SizedBox(width: 24),
                  _TabItem(label: 'Reviews'),
                  SizedBox(width: 24),
                  _TabItem(label: 'Photos'),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Vibe',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Yūgen brings the kinetic energy of a Shinjuku alleyway to the heart of the city. Expect dimly lit charcoal interiors, neon accents, and an uncompromising approach to seasonal fermentation and wood-fired grilling.',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),

            // Map Preview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        image: const DecorationImage(
                          image: NetworkImage('https://images.unsplash.com/photo-1524661135-423995f22d0b?q=80&w=500&auto=format&fit=crop'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle),
                          child: const Icon(Icons.location_on, color: Colors.black, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('420 Lantern Way, District 7', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text('DIRECTIONS • 5 MIN DRIVE', style: TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                        ),
                        Icon(Icons.near_me_outlined, color: Color(0xFFFFD700)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        color: const Color(0xFF0D0D0D),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.share_outlined, color: Color(0xFFFFD700), size: 18),
                  SizedBox(width: 8),
                  Text('Share', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rate_review_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Write a Review', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, double progress, {bool labelOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.black.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
            minHeight: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInfoCard(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFFD700), size: 24),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
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
        Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFFD700) : Colors.white38,
            fontSize: 16,
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
    );
  }
}
