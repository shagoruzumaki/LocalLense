import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../constant.dart';
import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

/// 2.3 AI Summary Engine
/// Owner: Kamonashish Dutta Hemel
/// Auto-generates a 2-3 sentence summary + 3 keyword tags
/// from the latest 50 reviews using Gemini 1.5 Flash (free tier)
/// Saves to restaurants.ai_summary and restaurants.ai_tags

class AiSummaryApi {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const int _minimumReviewCount = 7;
  static const int _refreshEveryReviewCount = 10;

  // Gemini Flash endpoint
  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';

  // API key loaded from AppConstants
  String get _geminiApiKey => AppConstants.geminiApiKey;

  // ─────────────────────────────────────────────
  // MAIN: Check if summary should be generated
  // Called from review_api.dart after every submitReview()
  // Triggers at 7 reviews (first time) and every 10 after
  // ─────────────────────────────────────────────
  Future<void> checkAndGenerateSummary(String restaurantId) async {
    final reviewCount = await _countUsableReviews(restaurantId);
    if (reviewCount < _minimumReviewCount) return;

    final existingSummary = await _fetchSavedSummary(restaurantId);
    final hasSummary =
        (existingSummary['ai_summary'] as String?)?.trim().isNotEmpty ?? false;

    final bool shouldGenerate =
        !hasSummary ||
        reviewCount == _minimumReviewCount ||
        (reviewCount > _minimumReviewCount &&
            (reviewCount - _minimumReviewCount) % _refreshEveryReviewCount ==
                0);

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

    // Need enough reviews to generate a meaningful summary
    if (reviews.length < _minimumReviewCount) {
      return; // Do nothing — frontend shows null
    }

    // Step 2: Call Gemini Flash
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
  // STEP 2: Call Gemini Flash API
  // ─────────────────────────────────────────────
  Future<String?> _callGemini(List<String> reviewBodies) async {
    if (_geminiApiKey.isEmpty || _geminiApiKey == 'YOUR_GEMINI_API_KEY') {
      debugPrint('[AiSummaryApi] Gemini API key not configured.');
      return null;
    }

    // Build the prompt — same structure as the backend doc specifies
    final reviewText = reviewBodies
        .asMap()
        .entries
        .map((e) => 'Review ${e.key + 1}: ${e.value}')
        .join('\n');

    final prompt =
        '''
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
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.3, // low temp = consistent, factual output
        'maxOutputTokens': 200,
      },
    };

    try {
      var response = await _postGemini(requestBody, useHeaderKey: true);
      if (response.statusCode == 401) {
        response = await _postGemini(requestBody, useHeaderKey: false);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Extract text from Gemini response structure
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      } else if (response.statusCode == 429) {
        // Rate limit hit — Gemini free tier allows 15 requests/min
        throw Exception('Gemini rate limit reached. Try again in a minute.');
      } else {
        throw Exception(
          'Gemini API error: ${response.statusCode} ${response.body}',
        );
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
  Future<http.Response> _postGemini(
    Map<String, dynamic> requestBody, {
    required bool useHeaderKey,
  }) {
    final uri = useHeaderKey
        ? Uri.parse(_geminiEndpoint)
        : Uri.parse(
            _geminiEndpoint,
          ).replace(queryParameters: {'key': _geminiApiKey});

    return http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (useHeaderKey) 'X-goog-api-key': _geminiApiKey,
      },
      body: jsonEncode(requestBody),
    );
  }

  Map<String, dynamic>? _parseGeminiResponse(String rawResponse) {
    try {
      // Expected format:
      // SUMMARY: Reviewers love the smoked hilsa here...
      // TAGS: Smoked Fish, Intimate Ambience, Weekend Special

      final normalized = rawResponse.trim();
      final summaryMatch = RegExp(
        r'summary:\s*(.*?)(?:\n\s*tags\s*:|$)',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(normalized);
      final tagsMatch = RegExp(
        r'(?:^|\n)\s*tags\s*:\s*(.*)$',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(normalized);

      final summary = (summaryMatch?.group(1) ?? normalized)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final tagsRaw = tagsMatch?.group(1) ?? '';
      final tags = tagsRaw
          .split(',')
          .map((t) => t.replaceAll(RegExp(r'^[\-\*\d\.\s]+'), '').trim())
          .where((t) => t.isNotEmpty)
          .take(3)
          .toList();

      // Tags are nice-to-have; do not block a valid summary from displaying.
      if (summary.isEmpty) {
        debugPrint(
          '[AiSummaryApi] Parsing failed — unexpected format: $rawResponse',
        );
        return null;
      }

      return {'summary': summary, 'tags': tags};
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
    await _supabase
        .from('restaurants')
        .update({'ai_summary': summary, 'ai_tags': tags})
        .eq('id', restaurantId);
  }

  // ─────────────────────────────────────────────
  // READ: Get existing summary for a restaurant
  // Returns null if fewer than 7 reviews exist or Gemini generation fails
  // This is the same as review_api.dart getRestaurantAiSummary()
  // but kept here for direct access if needed
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>?> getSummary(String restaurantId) async {
    var response = await _fetchSavedSummary(restaurantId);

    final savedSummary = response['ai_summary'] as String?;
    if (savedSummary == null ||
        savedSummary.trim().isEmpty ||
        _looksTruncated(savedSummary)) {
      final reviewCount = await _countUsableReviews(restaurantId);
      if (reviewCount >= _minimumReviewCount) {
        await generateAndSaveSummary(restaurantId);
        response = await _fetchSavedSummary(restaurantId);
      }
    }

    final summary = response['ai_summary'] as String?;
    if (summary == null || summary.trim().isEmpty) {
      return null; // fewer than 7 reviews or Gemini failed
    }

    return {
      'ai_summary': summary,
      'ai_tags': List<String>.from(response['ai_tags'] ?? []),
    };
  }

  Future<int> _countUsableReviews(String restaurantId) async {
    final response = await _supabase
        .from('reviews')
        .select('id')
        .eq('restaurant_id', restaurantId)
        .eq('flagged', false);

    return (response as List<dynamic>).length;
  }

  Future<Map<String, dynamic>> _fetchSavedSummary(String restaurantId) async {
    return await _supabase
        .from('restaurants')
        .select('ai_summary, ai_tags')
        .eq('id', restaurantId)
        .single();
  }

  bool _looksTruncated(String summary) {
    final trimmed = summary.trim();
    if (trimmed.length < 40) return true;
    return !RegExp(r'[.!?]$').hasMatch(trimmed);
  }
}
