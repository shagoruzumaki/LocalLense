
class ReviewInput {
  final String tier; // explorer / expert / diamond / platinum
  final double rating; // 1.0 - 5.0

  ReviewInput({required this.tier, required this.rating});
}

class ScoreInput {
  final double quality;
  final double trust;
  final double popularity;
  final double proximity;

  ScoreInput({
    required this.quality,
    required this.trust,
    required this.popularity,

    required this.proximity,
  });
}

class ScoreResult {
  final double finalScore;
  final String label;
  final double qualityScore;
  final double trustScore;

  ScoreResult({
    required this.finalScore,
    required this.label,
    required this.qualityScore,
    required this.trustScore,
  });
}

class RestaurantScoreCalculator {

  // --- Tier Multiplier ---
  static int getTierMultiplier(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum': return 4;
      case 'diamond':  return 3;
      case 'expert':   return 2;
      case 'explorer': return 1;
      default:         return 1;
    }
  }

  // --- Score Label ---
  static String getScoreLabel(double score) {
    if (score >= 90) return 'Elite';
    if (score >= 75) return 'Excellent';
    if (score >= 60) return 'Good';
    return 'Developing';
  }

  // --- Quality Score (40%) ---
  // Weighted average of ratings by tier. Normalized to 0-100.
  static double calculateQualityScore(List<ReviewInput> reviews) {
    if (reviews.isEmpty) return 0.0;

    double weightedSum = 0;
    double totalWeight = 0;

    for (final review in reviews) {
      final weight = getTierMultiplier(review.tier);
      weightedSum += review.rating * weight;
      totalWeight += weight;
    }

    final avg = weightedSum / totalWeight;
    return double.parse(((avg / 5.0) * 100).toStringAsFixed(2));
  }

  // --- Trust Score (25%) ---
  // How trustworthy are the reviewers based on their tiers.
  static double calculateTrustScore(List<ReviewInput> reviews) {
    if (reviews.isEmpty) return 0.0;

    final totalWeight = reviews.fold<double>(
      0, (sum, r) => sum + getTierMultiplier(r.tier),
    );
    final maxPossible = reviews.length * 4.0; // platinum = 4 is max

    return double.parse(((totalWeight / maxPossible) * 100).toStringAsFixed(2));
  }

  // --- Final Score Formula ---
  // Score = (Quality x 0.40) + (Trust x 0.25) + (Popularity x 0.20) + (Proximity x 0.15)
  static double calculateFinalScore(ScoreInput input) {
    final score =
        (input.quality   * 0.40) +
            (input.trust     * 0.25) +
            (input.popularity * 0.20) +
            (input.proximity  * 0.15);

    return double.parse(score.toStringAsFixed(2));
  }

  // --- Full calculation: reviews in, ScoreResult out ---
  static ScoreResult calculate({
    required List<ReviewInput> reviews,
    required double popularity,
    required double proximity,
  }) {
    final quality = calculateQualityScore(reviews);
    final trust   = calculateTrustScore(reviews);

    final finalScore = calculateFinalScore(ScoreInput(
      quality:    quality,
      trust:      trust,
      popularity: popularity,
      proximity:  proximity,
    ));

    return ScoreResult(
      finalScore:   finalScore,
      label:        getScoreLabel(finalScore),
      qualityScore: quality,
      trustScore:   trust,
    );
  }
}