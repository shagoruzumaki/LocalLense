import 'package:flutter/material.dart';
import 'verification_submitted_page.dart';

class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key});

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
        title: const Text('Upload Your NID',
            style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontFamily: 'serif')),
        actions: [
          const Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Text('Step 2 of 3', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(true, true),
                _buildLine(),
                _buildDot(true, false, isCurrent: true),
                _buildLine(),
                _buildDot(false, false),
              ],
            ),
            const SizedBox(height: 32),
            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFFFD700), size: 20),
                      SizedBox(width: 12),
                      Text('Please upload a clear photo',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 12),
                  _BulletPoint('Avoid reflections and glares'),
                  _BulletPoint('Ensure all 4 corners are visible'),
                  _BulletPoint('Text must be easily readable'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Upload Grid
            Row(
              children: [
                Expanded(child: _buildUploadBox(Icons.cloud_upload_outlined, 'Front Side', 'Tap to upload')),
                const SizedBox(width: 16),
                Expanded(child: _buildUploadBox(Icons.cloud_upload_outlined, 'Back Side', 'Tap to upload')),
              ],
            ),
            const SizedBox(height: 24),
            // Selfie Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05), style: BorderStyle.none), // dashed border not easily possible in standard Flutter, using thin border
              ),
              // Simulating dashed border with a CustomPainter would be overkill here, using container with border
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(15),
                      image: const DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1531123897727-8f129e16fd3c?q=80&w=200&auto=format&fit=crop'), // Example selfie with ID
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Selfie with ID',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Hold your ID card next to your face and take a clear photo of both.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Open Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(200, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const VerificationSubmittedPage()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                foregroundColor: Colors.white38,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white38, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your data is encrypted and used only for identity verification purposes. We never share your sensitive information with third parties without your explicit consent.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(bool isFilled, bool isDone, {bool isCurrent = false}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? const Color(0xFFFFD700) : Colors.transparent,
        border: Border.all(
          color: isFilled ? const Color(0xFFFFD700) : Colors.white24,
          width: 2,
        ),
      ),
      child: isDone
          ? const Icon(Icons.check, color: Colors.black, size: 14)
          : isCurrent
          ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle)))
          : null,
    );
  }

  Widget _buildLine() {
    return Container(height: 2, width: 40, color: Colors.white24);
  }

  Widget _buildUploadBox(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFFFFD700), fontSize: 16)),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }
}
