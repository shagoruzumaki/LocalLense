import 'package:flutter/material.dart';
import 'package:local_lense/screen/ForgotPassword_page.dart';
import 'package:local_lense/screen/ResetPassword_page.dart';
import 'package:local_lense/screen/discover_page.dart';
import 'package:local_lense/screen/home_page.dart';
import 'package:local_lense/screen/login_page.dart';
import 'package:local_lense/screen/profile_page.dart';
import 'package:local_lense/screen/map_page.dart';
import 'package:local_lense/screen/splash_screen.dart';
import 'package:local_lense/screen/landing_page.dart';
import 'package:local_lense/screen/search_page.dart';
import 'package:local_lense/view/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_lense/screen/signup_page.dart';
import 'package:local_lense/screen/ranking_page.dart';
import 'package:local_lense/screen/restaurant_details_page.dart';
import 'package:local_lense/screen/verification_page.dart';
import 'package:local_lense/screen/dish_details_page.dart';
import 'package:local_lense/screen/notifications_page.dart';
import 'package:local_lense/model/dish.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://bevgjdxwozuezcunizho.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJldmdqZHh3b3p1ZXpjdW5pemhvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4MzMzODIsImV4cCI6MjA5NDQwOTM4Mn0.28rsGqn_8s0ealKroQz04tRFk8MCFvARWiOR9xDN44c',
  );

  runApp(const MyApp());
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
        fontFamilyFallback: const ['ArialUnicode', 'SegoeUiEmoji'],
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700),
          brightness: Brightness.dark,
        ),
      ),
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/restaurant-details') {
          final restaurantId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) =>
                RestaurantDetailsPage(restaurantId: restaurantId),
          );
        }
        if (settings.name == '/dish-details') {
          final dish = settings.arguments as Dish;
          return MaterialPageRoute(
            builder: (context) => DishDetailsPage(dish: dish),
          );
        }
        if (settings.name == '/search') {
          final query = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (context) => SearchPage(initialQuery: query),
          );
        }
        return null; // Let 'routes' handle other routes
      },
      routes: {
        '/landing': (_) => const LandingPage(),
        '/auth': (_) => AuthGate(
          homeScreen: const HomePage(),
          loginScreen: const LoginPage(),
          resetPasswordScreen: const ResetPasswordPage(),
        ),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const SignupPage(),
        '/forgot-password': (_) => const ForgotPasswordPage(),
        '/reset-password': (_) => const ResetPasswordPage(),
        '/discover': (_) => const DiscoverPage(),
        // '/search' is now handled in onGenerateRoute
        '/profile': (_) => const ProfilePage(),
        '/ranking': (_) => const RankingPage(),
        '/map': (_) => const MapPage(),
        '/home': (_) => const HomePage(),
        '/verification': (_) => const VerificationPage(),
        '/notifications': (_) => const NotificationsPage(),
      },
    );
  }
}
