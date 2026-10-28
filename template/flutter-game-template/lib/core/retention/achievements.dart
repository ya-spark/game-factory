/// Lifetime counters that achievements are derived from. Pure Dart.
class LifetimeStats {
  const LifetimeStats({
    this.gamesPlayed = 0,
    this.totalLines = 0,
    this.piecesPlaced = 0,
    this.bestScore = 0,
    this.maxCombo = 0,
    this.bestStreak = 0,
  });

  final int gamesPlayed;
  final int totalLines;
  final int piecesPlaced;
  final int bestScore;
  final int maxCombo;
  final int bestStreak;

  LifetimeStats copyWith({
    int? gamesPlayed,
    int? totalLines,
    int? piecesPlaced,
    int? bestScore,
    int? maxCombo,
    int? bestStreak,
  }) => LifetimeStats(
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    totalLines: totalLines ?? this.totalLines,
    piecesPlaced: piecesPlaced ?? this.piecesPlaced,
    bestScore: bestScore ?? this.bestScore,
    maxCombo: maxCombo ?? this.maxCombo,
    bestStreak: bestStreak ?? this.bestStreak,
  );

  Map<String, Object?> toJson() => {
    'gamesPlayed': gamesPlayed,
    'totalLines': totalLines,
    'piecesPlaced': piecesPlaced,
    'bestScore': bestScore,
    'maxCombo': maxCombo,
    'bestStreak': bestStreak,
  };

  factory LifetimeStats.fromJson(Map<String, Object?>? j) => j == null
      ? const LifetimeStats()
      : LifetimeStats(
          gamesPlayed: (j['gamesPlayed'] as num?)?.toInt() ?? 0,
          totalLines: (j['totalLines'] as num?)?.toInt() ?? 0,
          piecesPlaced: (j['piecesPlaced'] as num?)?.toInt() ?? 0,
          bestScore: (j['bestScore'] as num?)?.toInt() ?? 0,
          maxCombo: (j['maxCombo'] as num?)?.toInt() ?? 0,
          bestStreak: (j['bestStreak'] as num?)?.toInt() ?? 0,
        );
}

enum AchievementMetric {
  gamesPlayed,
  totalLines,
  piecesPlaced,
  bestScore,
  maxCombo,
  bestStreak,
}

class AchievementDef {
  const AchievementDef(
    this.id,
    this.title,
    this.description,
    this.metric,
    this.target,
    this.reward,
  );

  /// Stable ID; also the key for the Play Games achievement mapping.
  final String id;
  final String title;
  final String description;
  final AchievementMetric metric;
  final int target;
  final int reward;

  int valueIn(LifetimeStats s) => switch (metric) {
    AchievementMetric.gamesPlayed => s.gamesPlayed,
    AchievementMetric.totalLines => s.totalLines,
    AchievementMetric.piecesPlaced => s.piecesPlaced,
    AchievementMetric.bestScore => s.bestScore,
    AchievementMetric.maxCombo => s.maxCombo,
    AchievementMetric.bestStreak => s.bestStreak,
  };
}

abstract final class AchievementEngine {
  static const List<AchievementDef> all = [
    AchievementDef(
      'first_game',
      'First Steps',
      'Finish your first game',
      AchievementMetric.gamesPlayed,
      1,
      25,
    ),
    AchievementDef(
      'games_25',
      'Regular',
      'Play 25 games',
      AchievementMetric.gamesPlayed,
      25,
      100,
    ),
    AchievementDef(
      'lines_50',
      'Line Cleaner',
      'Clear 50 lines',
      AchievementMetric.totalLines,
      50,
      50,
    ),
    AchievementDef(
      'lines_500',
      'Line Master',
      'Clear 500 lines',
      AchievementMetric.totalLines,
      500,
      250,
    ),
    AchievementDef(
      'score_1000',
      'Four Digits',
      'Score 1,000 in one game',
      AchievementMetric.bestScore,
      1000,
      50,
    ),
    AchievementDef(
      'score_5000',
      'High Roller',
      'Score 5,000 in one game',
      AchievementMetric.bestScore,
      5000,
      250,
    ),
    AchievementDef(
      'combo_3',
      'Combo Starter',
      'Reach a x3 combo',
      AchievementMetric.maxCombo,
      3,
      50,
    ),
    AchievementDef(
      'pieces_500',
      'Builder',
      'Place 500 pieces',
      AchievementMetric.piecesPlaced,
      500,
      100,
    ),
    AchievementDef(
      'streak_7',
      'Week Warrior',
      'Reach a 7-day streak',
      AchievementMetric.bestStreak,
      7,
      150,
    ),
  ];

  /// Achievements newly reached by [stats] that are not yet in [unlocked].
  static List<AchievementDef> newlyUnlocked(
    LifetimeStats stats,
    Set<String> unlocked,
  ) => [
    for (final a in all)
      if (!unlocked.contains(a.id) && a.valueIn(stats) >= a.target) a,
  ];
}
