import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context), // Fixed: Now returns to previous screen
        ),
        title: const Text('LocalLens', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    child: const CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200&auto=format&fit=crop'),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.black, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Arif Rahman',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'serif'),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBadge('DIAMOND', Colors.amber),
                const SizedBox(width: 8),
                _buildBadge('Verified • NID', Colors.green),
              ],
            ),
            const SizedBox(height: 24),
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('128', 'Reviews'),
                _buildStatItem('42', 'Photos'),
                _buildStatItem('1.2k', 'Points'),
              ],
            ),
            const SizedBox(height: 32),
            // Account Settings
            _buildSectionHeader('Account Settings'),
            const SizedBox(height: 16),
            _buildSettingsItem(Icons.verified_user_outlined, 'Verification', trailing: _buildVerifiedBadge()),
            _buildSettingsItem(Icons.person_outline, 'Personal Information'),
            _buildSettingsItem(Icons.payment_outlined, 'Payment Methods'),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
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

  Widget _buildSettingsItem(IconData icon, String title, {Widget? trailing}) {
    return Container(
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
}
