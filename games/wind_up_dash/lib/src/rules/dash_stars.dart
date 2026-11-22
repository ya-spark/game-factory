/// Scoring, stars and coins of Wind-up dash. Pure Dart.
library;

import 'dart:math';

/// Best-score thresholds for 1, 2 and 3 stars on the Games tab tile (owner, 2026-11-22: raised from 100 / 250 / 500
/// because every star picked up adds 5 points).
const List<int> dashStarScores = [150, 350, 700];

/// Points for each star picked up.
const int pointsPerStar = 5;

/// 1 point per 10 units of the furthest distance, plus [pointsPerStar] for every star picked up.
int dashScore(double distance, int stars) =>
    (distance / 10).floor() + pointsPerStar * stars;

/// Coins for a score: 1 per 25 points, at most 20 a round.
int dashCoins(int score) => min(score ~/ 25, 20);

/// Course stars (0 to 3) for a finished course: 1 for the flag, 2 with at least 70 percent of the stars picked up,
/// 3 with at least 90 percent. 0 when not finished.
int dashCourseStars({
  required bool finished,
  required int picked,
  required int total,
}) {
  if (!finished) return 0;
  final share = total == 0 ? 1.0 : picked / total;
  return share >= 0.9
      ? 3
      : share >= 0.7
      ? 2
      : 1;
}
