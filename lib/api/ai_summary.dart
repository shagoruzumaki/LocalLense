import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../constants.dart'; // API keys
import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

/// 2.3 AI Summary Engine
/// Owner: Kamonashish Dutta Hemel
/// Auto-generates a 2-3 sentence summary + 3 keyword tags
/// from the latest 50 reviews using Gemini 1.5 Flash (free tier)
/// Saves to restaurants.ai_summary and restaurants.ai_tags

class AiSummaryApi {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Gemini 1.5 Flash endpoint
  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  // API key loaded from .env file
  String get _geminiApiKey => AppConstants.geminiApiKey;

  // ─────────────────────────────────────────────
  // MAIN: Check if summary should be generated
  // Called from review_api.dart after every submitReview()
  // Triggers at 5 reviews (first time) and every 10 after
  // ─────────────────────────────────────────────
  Future<void> checkAndGenerateSummary(String restaurantId) async {
    // Count total reviews for this restaurant
    final countResponse = await _supabase
        .from('reviews')
        .select('id')
        .eq('restaurant_id', restaurantId)
        .eq('flagged', false);

    final reviewCount = (countResponse as List<dynamic>).length;

    // Trigger logic:
    // First time: exactly 5 reviews
    // After that: every 10 new reviews (15, 25, 35, 45...)
    final bool shouldGenerate =
        reviewCount == 5 || (reviewCount > 5 && (reviewCount - 5) % 10 == 0);

    if (shouldGenerate) {
      await generateAndSaveSummary(restaurantId);
    }
  }

  // ─────────────────────────────────────────────
  // CORE: Generate summary and save to Supabase
  // Also callable directly for admin override:
  // POST /admin/restaurants/:id/regenerate-summary
  // ─────────────────────────────────────────────
  Future<void> generateAndSaveSummary(String restaurantId) async {
    // Step 1: Fetch latest 50 non-flagged review bodies
    final reviews = await _fetchLatestReviews(restaurantId);

    // Need at least 5 reviews to generate a meaningful summary
    if (reviews.length < 5) {
      return; // Do nothing — frontend shows null
    }

    // Step 2: Call Gemini 1.5 Flash
    final geminiResponse = await _callGemini(reviews);

    if (geminiResponse == null) {
      return; // Gemini call failed — keep existing summary
    }

    // Step 3: Parse Gemini response into summary + tags
    final parsed = _parseGeminiResponse(geminiResponse);

    if (parsed == null) {
      return; // Parsing failed — keep existing summary
    }

    // Step 4: Save to Supabase restaurants table
    await _saveSummary(
      restaurantId: restaurantId,
      summary: parsed['summary']!,
      tags: parsed['tags'] as List<String>,
    );
  }

  // ─────────────────────────────────────────────
  // STEP 1: Fetch latest 50 review bodies
  // ─────────────────────────────────────────────
  Future<List<String>> _fetchLatestReviews(String restaurantId) async {
    final response = await _supabase
        .from('reviews')
        .select('body')
        .eq('restaurant_id', restaurantId)
        .eq('flagged', false)
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List<dynamic>)
        .map((r) => r['body'] as String)
        .where((body) => body.trim().isNotEmpty)
        .toList();
  }

  // ─────────────────────────────────────────────
  // STEP 2: Call Gemini 1.5 Flash API
  // ─────────────────────────────────────────────
  Future<String?> _callGemini(List<String> reviewBodies) async {
    if (_geminiApiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }

    // Build the prompt — same structure as the backend doc specifies
    final reviewText = reviewBodies
        .asMap()
        .entries
        .map((e) => 'Review ${e.key + 1}: ${e.value}')
        .join('\n');

    final prompt = '''
You are summarising customer reviews for a restaurant discovery app.

Here are the reviews:
$reviewText

Task: Summarise what reviewers most commonly say about this restaurant in 2-3 sentences. Then list exactly 3 keyword tags separated by commas.

Rules:
- Summary must be 2-3 sentences only
- Tags must be exactly 3, separated by commas
- No extra text, no bullet points, no numbering
- Format your response EXACTLY like this:
SUMMARY: [your 2-3 sentence summary here]
TAGS: [tag1, tag2, tag3]
''';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3, // low temp = consistent, factual output
        'maxOutputTokens': 200,
      }
    };

    try {
      final response = await http.post(
        Uri.parse('$_geminiEndpoint?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Extract text from Gemini response structure
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      } else if (response.statusCode == 429) {
        // Rate limit hit — Gemini free tier allows 15 requests/min
        throw Exception('Gemini rate limit reached. Try again in a minute.');
      } else {
        throw Exception('Gemini API error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      // Log error but don't crash the app — summary generation is non-critical
      debugPrint('[AiSummaryApi] Gemini call failed: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // STEP 3: Parse Gemini response
  // Extracts summary text and tags array
  // ─────────────────────────────────────────────
  Map<String, dynamic>? _parseGeminiResponse(String rawResponse) {
    try {
      // Expected format:
      // SUMMARY: Reviewers love the smoked hilsa here...
      // TAGS: Smoked Fish, Intimate Ambience, Weekend Special

      final lines = rawResponse.trim().split('\n');

      String summary = '';
      List<String> tags = [];

      for (final line in lines) {
        if (line.startsWith('SUMMARY:')) {
          summary = line.replaceFirst('SUMMARY:', '').trim();
        } else if (line.startsWith('TAGS:')) {
          final tagsRaw = line.replaceFirst('TAGS:', '').trim();
          tags = tagsRaw
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .take(3) // ensure max 3 tags
              .toList();
        }
      }

      // Validate we got both parts
      if (summary.isEmpty || tags.length < 3) {
        debugPrint('[AiSummaryApi] Parsing failed — unexpected format: $rawResponse');
        return null;
      }

      return {
        'summary': summary,
        'tags': tags,
      };
    } catch (e) {
      debugPrint('[AiSummaryApi] Parse error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // STEP 4: Save summary and tags to Supabase
  // Updates restaurants.ai_summary and restaurants.ai_tags
  // ─────────────────────────────────────────────
  Future<void> _saveSummary({
    required String restaurantId,
    required String summary,
    required List<String> tags,
  }) async {
    await _supabase.from('restaurants').update({
      'ai_summary': summary,
      'ai_tags': tags,
    }).eq('id', restaurantId);
  }

  // ─────────────────────────────────────────────
  // READ: Get existing summary for a restaurant
  // Returns null if fewer than 5 reviews exist
  // This is the same as review_api.dart getRestaurantAiSummary()
  // but kept here for direct access if needed
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>?> getSummary(String restaurantId) async {
    final response = await _supabase
        .from('restaurants')
        .select('ai_summary, ai_tags')
        .eq('id', restaurantId)
        .single();

    if (response['ai_summary'] == null) {
      return null; // fewer than 5 reviews — show nothing on frontend
    }

    return {
      'ai_summary': response['ai_summary'] as String,
      'ai_tags': List<String>.from(response['ai_tags'] ?? []),
    };
  }
}
