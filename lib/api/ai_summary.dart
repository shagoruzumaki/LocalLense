import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../constant.dart'; // Updated to use your main constant file
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

  // API key loaded from AppConstants
  String get _geminiApiKey => AppConstants.geminiApiKey;

  // ─────────────────────────────────────────────
  // MAIN: Check if summary should be generated
  // Called from review_api.dart after every submitReview()
  // ─────────────────────────────────────────────
  Future<void> checkAndGenerateSummary(String restaurantId) async {
    try {
      // Count total reviews for this restaurant
      final countResponse = await _supabase
          .from('reviews')
          .select('id')
          .eq('restaurant_id', restaurantId)
          .eq('flagged', false);

      final reviewCount = (countResponse as List<dynamic>).length;
      debugPrint('[AiSummaryApi] Review count for $restaurantId: $reviewCount');

      // Check if a summary already exists
      final restaurant = await _supabase
          .from('restaurants')
          .select('ai_summary')
          .eq('id', restaurantId)
          .single();
      
      final bool hasNoSummary = restaurant['ai_summary'] == null;

      // Trigger logic:
      // 1. If 5+ reviews exist and there is NO summary yet
      // 2. Milestone triggers: 15, 25, 35, 45...
      final bool shouldGenerate = (hasNoSummary && reviewCount >= 5) || 
                                  (reviewCount > 5 && (reviewCount - 5) % 10 == 0);

      if (shouldGenerate) {
        debugPrint('[AiSummaryApi] Triggering summary generation (Count: $reviewCount, Initial: $hasNoSummary)');
        await generateAndSaveSummary(restaurantId);
      } else {
        debugPrint('[AiSummaryApi] Conditions not met for generation.');
      }
    } catch (e) {
      debugPrint('[AiSummaryApi] Error in checkAndGenerateSummary: $e');
    }
  }

  // ─────────────────────────────────────────────
  // CORE: Generate summary and save to Supabase
  // ─────────────────────────────────────────────
  Future<void> generateAndSaveSummary(String restaurantId) async {
    final reviews = await _fetchLatestReviews(restaurantId);

    if (reviews.length < 5) {
      debugPrint('[AiSummaryApi] Aborting: Need at least 5 reviews (current: ${reviews.length})');
      return; 
    }

    final geminiResponse = await _callGemini(reviews);

    if (geminiResponse == null) {
      debugPrint('[AiSummaryApi] Gemini returned null or failed.');
      return; 
    }

    final parsed = _parseGeminiResponse(geminiResponse);

    if (parsed == null) {
      debugPrint('[AiSummaryApi] Failed to parse Gemini response.');
      return;
    }

    await _saveSummary(
      restaurantId: restaurantId,
      summary: parsed['summary']!,
      tags: parsed['tags'] as List<String>,
    );
    debugPrint('[AiSummaryApi] Summary successfully updated for $restaurantId');
  }

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

  Future<String?> _callGemini(List<String> reviewBodies) async {
    if (_geminiApiKey.isEmpty || _geminiApiKey == 'YOUR_GEMINI_API_KEY') {
      debugPrint('[AiSummaryApi] ERROR: Gemini API key is not configured in AppConstants.');
      return null;
    }

    final reviewText = reviewBodies
        .asMap()
        .entries
        .map((e) => 'Review ${e.key + 1}: ${e.value}')
        .join('\n');

    final prompt = '''
Summarize these restaurant reviews in 2-3 sentences.
Then provide exactly 3 short keyword tags.

Reviews:
$reviewText

Format:
SUMMARY: [text]
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
        'temperature': 0.4,
        'maxOutputTokens': 300,
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
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      } else {
        debugPrint('[AiSummaryApi] Gemini API Error (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[AiSummaryApi] Network Error: $e');
      return null;
    }
  }

  Map<String, dynamic>? _parseGeminiResponse(String rawResponse) {
    try {
      debugPrint('[AiSummaryApi] Raw Response: $rawResponse');
      
      final clean = rawResponse.replaceAll('**', '').trim();
      final lines = clean.split('\n');

      String summary = '';
      List<String> tags = [];

      for (var line in lines) {
        final trimmedLine = line.trim();
        final upperLine = trimmedLine.toUpperCase();
        
        if (upperLine.startsWith('SUMMARY:')) {
          summary = trimmedLine.substring(trimmedLine.indexOf(':') + 1).trim();
        } else if (upperLine.startsWith('TAGS:')) {
          final tagsPart = trimmedLine.substring(trimmedLine.indexOf(':') + 1).trim();
          final cleanTags = tagsPart.replaceAll('[', '').replaceAll(']', '');
          tags = cleanTags
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();
        }
      }

      if (summary.isEmpty || tags.isEmpty) return null;

      return {
        'summary': summary,
        'tags': tags.take(3).toList(),
      };
    } catch (e) {
      debugPrint('[AiSummaryApi] Parse Error: $e');
      return null;
    }
  }

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

  Future<Map<String, dynamic>?> getSummary(String restaurantId) async {
    final response = await _supabase
        .from('restaurants')
        .select('ai_summary, ai_tags')
        .eq('id', restaurantId)
        .single();

    if (response['ai_summary'] == null) return null;

    return {
      'ai_summary': response['ai_summary'] as String,
      'ai_tags': List<String>.from(response['ai_tags'] ?? []),
    };
  }
}
