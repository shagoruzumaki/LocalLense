// LocalLens — App Constants
// Store all API keys and config values here
//⚠️ Add this file to .gitignore before pushing to GitHub

class AppConstants {
  // Gemini API Key (Google AI Studio — free tier)
  // Get yours at: aistudio.google.com
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  // Supabase config (get from Member 1 — Ismail)
  static const String supabaseUrl = 'https://bevgjdxwozuezcunizho.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJldmdqZHh3b3p1ZXpjdW5pemhvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4MzMzODIsImV4cCI6MjA5NDQwOTM4Mn0.28rsGqn_8s0ealKroQz04tRFk8MCFvARWiOR9xDN44c';
}
