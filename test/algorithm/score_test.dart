// test/algorithm/score_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:local_lense/algorithm/score.dart';

void main() {

  // ─────────────────────────────────────────
  // getTierMultiplier
  // ─────────────────────────────────────────
  group('getTierMultiplier', () {
    test('platinum returns 4', () {
      expect(RestaurantScoreCalculator.getTierMultiplier('platinum'), equals(4));
    });

    test('diamond returns 3', () {
      expect(RestaurantScoreCalculator.getTierMultiplier('diamond'), equals(3));
    });

    test('expert returns 2', () {
      expect(RestaurantScoreCalculator.getTierMultiplier('expert'), equals(2));
    });

    test('explorer returns 1', () {
      expect(RestaurantScoreCalculator.getTierMultiplier('explorer'), equals(1));
    });

    test('unknown tier defaults to 1', () {
      expect(RestaurantScoreCalculator.getTierMultiplier('unknown'), equals(1));
    });
  });

  // ─────────────────────────────────────────
  // getScoreLabel
  // ─────────────────────────────────────────
  group('getScoreLabel', () {
    test('90 and above is Elite', () {
      expect(RestaurantScoreCalculator.getScoreLabel(95.0), equals('Elite'));
      expect(RestaurantScoreCalculator.getScoreLabel(90.0), equals('Elite'));
    });

    test('75 to 89 is Excellent', () {
      expect(RestaurantScoreCalculator.getScoreLabel(80.0), equals('Excellent'));
      expect(RestaurantScoreCalculator.getScoreLabel(75.0), equals('Excellent'));
    });

    test('60 to 74 is Good', () {
      expect(RestaurantScoreCalculator.getScoreLabel(65.0), equals('Good'));
      expect(RestaurantScoreCalculator.getScoreLabel(60.0), equals('Good'));
    });

    test('below 60 is Developing', () {
      expect(RestaurantScoreCalculator.getScoreLabel(59.0), equals('Developing'));
      expect(RestaurantScoreCalculator.getScoreLabel(0.0),  equals('Developing'));
    });
  });

  // ─────────────────────────────────────────
  // calculateQualityScore
  // ─────────────────────────────────────────
  group('calculateQualityScore', () {
    test('empty reviews returns 0', () {
      expect(RestaurantScoreCalculator.calculateQualityScore([]), equals(0.0));
    });

    test('all explorer reviewers with rating 5 returns 100', () {
      final reviews = [
        ReviewInput(tier: 'explorer', rating: 5.0),
        ReviewInput(tier: 'explorer', rating: 5.0),
      ];
      expect(RestaurantScoreCalculator.calculateQualityScore(reviews), equals(100.0));
    });

    test('all platinum reviewers with rating 5 returns 100', () {
      final reviews = [
        ReviewInput(tier: 'platinum', rating: 5.0),
        ReviewInput(tier: 'platinum', rating: 5.0),
      ];
      expect(RestaurantScoreCalculator.calculateQualityScore(reviews), equals(100.0));
    });

    test('single review with rating 4 returns 80', () {
      final reviews = [
        ReviewInput(tier: 'explorer', rating: 4.0),
      ];
      expect(RestaurantScoreCalculator.calculateQualityScore(reviews), equals(80.0));
    });

    test('mixed tiers platinum 5 and explorer 1 calculates correctly', () {
      // platinum weight=4: 5.0*4=20
      // explorer weight=1: 1.0*1=1
      // weightedSum=21, totalWeight=5
      // avg = 21/5 = 4.2 → (4.2/5)*100 = 84.0
      final reviews = [
        ReviewInput(tier: 'platinum', rating: 5.0),
        ReviewInput(tier: 'explorer', rating: 1.0),
      ];
      expect(RestaurantScoreCalculator.calculateQualityScore(reviews), equals(84.0));
    });
  });

  // ─────────────────────────────────────────
  // calculateTrustScore
  // ─────────────────────────────────────────
  group('calculateTrustScore', () {
    test('empty reviews returns 0', () {
      expect(RestaurantScoreCalculator.calculateTrustScore([]), equals(0.0));
    });

    test('all platinum returns 100', () {
      final reviews = [
        ReviewInput(tier: 'platinum', rating: 5.0),
        ReviewInput(tier: 'platinum', rating: 5.0),
      ];
      expect(RestaurantScoreCalculator.calculateTrustScore(reviews), equals(100.0));
    });

    test('all explorer returns 25', () {
      // totalWeight=2, maxPossible=8 → (2/8)*100 = 25
      final reviews = [
        ReviewInput(tier: 'explorer', rating: 3.0),
        ReviewInput(tier: 'explorer', rating: 3.0),
      ];
      expect(RestaurantScoreCalculator.calculateTrustScore(reviews), equals(25.0));
    });

    test('single platinum reviewer returns 100', () {
      final reviews = [ReviewInput(tier: 'platinum', rating: 4.0)];
      expect(RestaurantScoreCalculator.calculateTrustScore(reviews), equals(100.0));
    });
  });

  // ─────────────────────────────────────────
  // calculateFinalScore
  // ─────────────────────────────────────────
  group('calculateFinalScore', () {
    test('all 100s returns 100', () {
      final input = ScoreInput(
        quality: 100, trust: 100, popularity: 100, proximity: 100,
      );
      expect(RestaurantScoreCalculator.calculateFinalScore(input), equals(100.0));
    });

    test('all zeros returns 0', () {
      final input = ScoreInput(
        quality: 0, trust: 0, popularity: 0, proximity: 0,
      );
      expect(RestaurantScoreCalculator.calculateFinalScore(input), equals(0.0));
    });

    test('weights calculate correctly', () {
      // 80*0.40 + 60*0.25 + 70*0.20 + 50*0.15
      // = 32 + 15 + 14 + 7.5 = 68.5
      final input = ScoreInput(
        quality: 80, trust: 60, popularity: 70, proximity: 50,
      );
      expect(RestaurantScoreCalculator.calculateFinalScore(input), equals(68.5));
    });
  });

  // ─────────────────────────────────────────
  // Full calculate() — edge cases from PDF
  // ─────────────────────────────────────────
  group('calculate - edge cases from PDF', () {
    test('0 reviews returns Developing label', () {
      final result = RestaurantScoreCalculator.calculate(
        reviews: [],
        popularity: 50.0,
        proximity: 60.0,
      );
      expect(result.label, equals('Developing'));
    });

    test('single review restaurant works correctly', () {
      final result = RestaurantScoreCalculator.calculate(
        reviews: [ReviewInput(tier: 'expert', rating: 4.0)],
        popularity: 60.0,
        proximity: 70.0,
      );
      expect(result.finalScore, isNonZero);
      expect(result.label, isNotEmpty);
    });

    test('all explorer reviewers gives lower score than all platinum', () {
      final explorerResult = RestaurantScoreCalculator.calculate(
        reviews: [
          ReviewInput(tier: 'explorer', rating: 4.0),
          ReviewInput(tier: 'explorer', rating: 4.0),
        ],
        popularity: 70.0,
        proximity: 70.0,
      );

      final platinumResult = RestaurantScoreCalculator.calculate(
        reviews: [
          ReviewInput(tier: 'platinum', rating: 4.0),
          ReviewInput(tier: 'platinum', rating: 4.0),
        ],
        popularity: 70.0,
        proximity: 70.0,
      );

      expect(platinumResult.finalScore, greaterThan(explorerResult.finalScore));
    });

    test('all platinum with perfect ratings returns Elite', () {
      final result = RestaurantScoreCalculator.calculate(
        reviews: [
          ReviewInput(tier: 'platinum', rating: 5.0),
          ReviewInput(tier: 'platinum', rating: 5.0),
        ],
        popularity: 100.0,
        proximity: 100.0,
      );
      expect(result.finalScore, equals(100.0));
      expect(result.label, equals('Elite'));
    });
  });
}