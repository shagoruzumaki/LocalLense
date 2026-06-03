// import 'dart:async';
// import 'package:flutter/material.dart';
//
// // --- MAIN APP ENTRY ---
// // You can use this in your main.dart:
// // home: const SplashScreen(),
//
// // --- SPLASH SCREEN ---
// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});
//
//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//     Timer(const Duration(seconds: 3), () {
//       if (mounted) {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => const LandingPage()),
//         );
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Container(
//         width: double.infinity,
//         height: double.infinity,
//         decoration: const BoxDecoration(
//           gradient: RadialGradient(
//             colors: [
//               Color(0xFF423401),
//               Colors.black,
//             ],
//             center: Alignment.center,
//             radius: 0.8,
//           ),
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Stack(
//               alignment: Alignment.center,
//               children: [
//                 Container(
//                   width: 140,
//                   height: 140,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     border: Border.all(color: const Color(0xFFFFD700), width: 2.0),
//                     boxShadow: [
//                       BoxShadow(
//                         color: const Color(0xFFFFD700).withValues(alpha: 0.3),
//                         blurRadius: 30,
//                         spreadRadius: 5,
//                       ),
//                     ],
//                   ),
//                   child: const Center(
//                     child: Icon(Icons.restaurant, color: Color(0xFFFFD700), size: 65),
//                   ),
//                 ),
//                 Positioned(
//                   top: 10,
//                   right: 10,
//                   child: Container(
//                     padding: const EdgeInsets.all(4),
//                     decoration: const BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle),
//                     child: const Icon(Icons.location_on, color: Colors.black, size: 14),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 50),
//             const Text(
//               'LocalLens',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 48,
//                 fontWeight: FontWeight.bold,
//                 fontFamily: 'serif',
//                 letterSpacing: 1.2,
//               ),
//             ),
//             const SizedBox(height: 10),
//             RichText(
//               text: const TextSpan(
//                 style: TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 0.5),
//                 children: [
//                   TextSpan(text: "Your city's best. "),
//                   TextSpan(
//                     text: 'Ranked.',
//                     style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // --- LANDING PAGE ---
// class LandingPage extends StatelessWidget {
//   const LandingPage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           Container(
//             decoration: const BoxDecoration(
//               image: DecorationImage(
//                 image: NetworkImage('https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?q=80&w=2070&auto=format&fit=crop'),
//                 fit: BoxFit.cover,
//               ),
//             ),
//           ),
//           Container(
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//                 colors: [
//                   Colors.black.withValues(alpha: 0.8),
//                   Colors.black.withValues(alpha: 0.9),
//                   Colors.black,
//                 ],
//               ),
//             ),
//           ),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 24.0),
//               child: Column(
//                 children: [
//                   const SizedBox(height: 60),
//                   const Text(
//                     'LocalLens',
//                     style: TextStyle(
//                       color: Color(0xFFFFD700),
//                       fontSize: 42,
//                       fontWeight: FontWeight.bold,
//                       fontStyle: FontStyle.italic,
//                       fontFamily: 'serif',
//                       shadows: [Shadow(color: Color(0xFFFFD700), blurRadius: 15)],
//                     ),
//                   ),
//                   const Spacer(),
//                   _buildFeatureCard(
//                     icon: Icons.trending_up,
//                     title: 'Algorithm-ranked results',
//                     subtitle: 'Beyond just basic crowdsourced reviews',
//                   ),
//                   const SizedBox(height: 16),
//                   _buildFeatureCard(
//                     icon: Icons.near_me_outlined,
//                     title: 'Closest best spots, instantly',
//                     subtitle: 'Proximity meets premium quality filters',
//                   ),
//                   const SizedBox(height: 16),
//                   _buildFeatureCard(
//                     icon: Icons.verified_user_outlined,
//                     title: 'Trusted scores from real locals',
//                     subtitle: 'Validated by the city\'s expert diner network',
//                   ),
//                   const SizedBox(height: 60),
//                   SizedBox(
//                     width: double.infinity,
//                     height: 56,
//                     child: Container(
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(28),
//                         gradient: const LinearGradient(colors: [Color(0xFFFDB03D), Color(0xFFF48C06)]),
//                       ),
//                       child: ElevatedButton(
//                         onPressed: () {
//                           Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupPage()));
//                         },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.transparent,
//                           shadowColor: Colors.transparent,
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
//                         ),
//                         child: const Text('EXPLORE NOW', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   SizedBox(
//                     width: double.infinity,
//                     height: 56,
//                     child: OutlinedButton(
//                       onPressed: () {
//                         Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
//                       },
//                       style: OutlinedButton.styleFrom(
//                         side: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
//                       ),
//                       child: const Text('SIGN IN', style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
//                     ),
//                   ),
//                   const SizedBox(height: 40),
//                   Text(
//                     'v2.4.0 • LocalLens Scout Network',
//                     style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, letterSpacing: 0.5),
//                   ),
//                   const SizedBox(height: 20),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFeatureCard({required IconData icon, required String title, required String subtitle}) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white.withValues(alpha: 0.08),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: Colors.black.withValues(alpha: 0.5),
//               border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
//             ),
//             child: Icon(icon, color: const Color(0xFFFFD700), size: 24),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'serif')),
//                 const SizedBox(height: 4),
//                 Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // --- LOGIN PAGE ---
// class LoginPage extends StatelessWidget {
//   const LoginPage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         width: double.infinity,
//         height: double.infinity,
//         decoration: const BoxDecoration(
//           gradient: RadialGradient(
//             colors: [Color(0xFF332601), Colors.black],
//             center: Alignment.topCenter,
//             radius: 1.0,
//           ),
//         ),
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 30),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const SizedBox(height: 80),
//               IconButton(
//                 onPressed: () => Navigator.pop(context),
//                 icon: const Icon(Icons.arrow_back, color: Color(0xFFFFD700)),
//               ),
//               const SizedBox(height: 20),
//               const Text('Welcome Back', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'serif')),
//               const SizedBox(height: 10),
//               const Text('Sign in to continue exploring your city.', style: TextStyle(color: Colors.white70, fontSize: 16)),
//               const SizedBox(height: 50),
//               _buildTextField(label: 'Email', icon: Icons.email_outlined),
//               const SizedBox(height: 20),
//               _buildTextField(label: 'Password', icon: Icons.lock_outline, isPassword: true),
//               const SizedBox(height: 15),
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: TextButton(onPressed: () {}, child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFFFFD700)))),
//               ),
//               const SizedBox(height: 30),
//               SizedBox(
//                 width: double.infinity,
//                 height: 55,
//                 child: ElevatedButton(
//                   onPressed: () {},
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFFFFD700),
//                     foregroundColor: Colors.black,
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//                     elevation: 5,
//                   ),
//                   child: const Text('SIGN IN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                 ),
//               ),
//               const SizedBox(height: 30),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Text("Don't have an account? ", style: TextStyle(color: Colors.white70)),
//                   GestureDetector(
//                     onTap: () {
//                       Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupPage()));
//                     },
//                     child: const Text('Sign Up', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTextField({required String label, required IconData icon, bool isPassword = false}) {
//     return TextField(
//       obscureText: isPassword,
//       style: const TextStyle(color: Colors.white),
//       decoration: InputDecoration(
//         labelText: label,
//         labelStyle: const TextStyle(color: Colors.white60),
//         prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
//         enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white24)),
//         focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFFFD700))),
//         filled: true,
//         fillColor: Colors.white.withValues(alpha: 0.05),
//       ),
//     );
//   }
// }
//
// // --- SIGNUP PAGE ---
// class SignupPage extends StatelessWidget {
//   const SignupPage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         width: double.infinity,
//         height: double.infinity,
//         decoration: const BoxDecoration(
//           gradient: RadialGradient(
//             colors: [Color(0xFF332601), Colors.black],
//             center: Alignment.topCenter,
//             radius: 1.0,
//           ),
//         ),
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 30),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const SizedBox(height: 80),
//               IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
//               const SizedBox(height: 20),
//               const Text('Create Account', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'serif')),
//               const SizedBox(height: 10),
//               const Text('Join LocalLens and discover the best spots.', style: TextStyle(color: Colors.white70, fontSize: 16)),
//               const SizedBox(height: 40),
//               _buildTextField(label: 'Full Name', icon: Icons.person_outline),
//               const SizedBox(height: 20),
//               _buildTextField(label: 'Email', icon: Icons.email_outlined),
//               const SizedBox(height: 20),
//               _buildTextField(label: 'Password', icon: Icons.lock_outline, isPassword: true),
//               const SizedBox(height: 40),
//               SizedBox(
//                 width: double.infinity,
//                 height: 55,
//                 child: ElevatedButton(
//                   onPressed: () {},
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFFFFD700),
//                     foregroundColor: Colors.black,
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//                     elevation: 5,
//                   ),
//                   child: const Text('SIGN UP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                 ),
//               ),
//               const SizedBox(height: 30),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Text("Already have an account? ", style: TextStyle(color: Colors.white70)),
//                   GestureDetector(
//                     onTap: () => Navigator.pop(context),
//                     child: const Text('Sign In', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTextField({required String label, required IconData icon, bool isPassword = false}) {
//     return TextField(
//       obscureText: isPassword,
//       style: const TextStyle(color: Colors.white),
//       decoration: InputDecoration(
//         labelText: label,
//         labelStyle: const TextStyle(color: Colors.white60),
//         prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
//         enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white24)),
//         focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFFFD700))),
//         filled: true,
//         fillColor: Colors.white.withValues(alpha: 0.05),
//       ),
//     );
//   }
// }
