import 'package:flutter/material.dart';
import 'package:local_lense/screen/profile_page.dart';
import 'screen/screens.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: 'https://bevgjdxwozuezcunizho.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJldmdqZHh3b3p1ZXpjdW5pemhvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4MzMzODIsImV4cCI6MjA5NDQwOTM4Mn0.28rsGqn_8s0ealKroQz04tRFk8MCFvARWiOR9xDN44c',
  );
  runApp(const MyApp());
  final supabase = Supabase.instance.client;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LocalLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700),
          brightness: Brightness.dark,
        ),
      ),
      home: const ProfilePage(),
    );
  }
}
