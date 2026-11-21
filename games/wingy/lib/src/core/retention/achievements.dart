/// Lifetime counters that achievements are derived from. Pure Dart.
class LifetimeStats {
  const LifetimeStats({
    this.gamesPlayed = 0,
    this.totalPairs = 0,
    this.totalOrbs = 0,
    this.totalShattered = 0,
    this.totalDashUses = 0,
    this.bestScore = 0,
    this.maxPerfectStreak = 0,
    this.bestStreak = 0,
  });

  final int gamesPlayed;
  final int totalPairs;
  final int totalOrbs;
  final int totalShattered;
  final int totalDashUses;
  final int bestScore;
  final int maxPerfectStreak;
  final int bestStreak;

  LifetimeStats copyWith({
    int? gamesPlayed,
    int? totalPairs,
    int? totalOrbs,
    int? totalShattered,
    int? totalDashUses,
    int? bestScore,
    int? maxPerfectStreak,
    int? bestStreak,
  }) => LifetimeStats(
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    totalPairs: totalPairs ?? this.totalPairs,
    totalOrbs: totalOrbs ?? this.totalOrbs,
    totalShattered: totalShattered ?? this.totalShattered,
    totalDashUses: totalDashUses ?? this.totalDashUses,
    bestScore: bestScore ?? this.bestScore,
    maxPerfectStreak: maxPerfectStreak ?? this.maxPerfectStreak,
    bestStreak: bestStreak ?? this.bestStreak,
  );

  Map<String, Object?> toJson() => {
    'gamesPlayed': gamesPlayed,
    'totalPairs': totalPairs,
    'totalOrbs': totalOrbs,
    'totalShattered': totalShattered,
    'totalDashUses': totalDashUses,
    'bestScore': bestScore,
    'maxPerfectStreak': maxPerfectStreak,
    'bestStreak': bestStreak,
  };

  factory LifetimeStats.fromJson(Map<String, Object?>? j) => j == null
      ? const LifetimeStats()
      : LifetimeStats(
          gamesPlayed: (j['gamesPlayed'] as num?)?.toInt() ?? 0,
          totalPairs: (j['totalPairs'] as num?)?.toInt() ?? 0,
          totalOrbs: (j['totalOrbs'] as num?)?.toInt() ?? 0,
          totalShattered: (j['totalShattered'] as num?)?.toInt() ?? 0,
          totalDashUses: (j['totalDashUses'] as num?)?.toInt() ?? 0,
          bestScore: (j['bestScore'] as num?)?.toInt() ?? 0,
          maxPerfectStreak: (j['maxPerfectStreak'] as num?)?.toInt() ?? 0,
          bestStreak: (j['bestStreak'] as num?)?.toInt() ?? 0,
        );
}

enum AchievementMetric {
  gamesPlayed,
  totalPairs,
  totalOrbs,
  totalShattered,
  totalDashUses,
  bestScore,
  maxPerfectStreak,
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
    AchievementMetric.totalPairs => s.totalPairs,
    AchievementMetric.totalOrbs => s.totalOrbs,
    AchievementMetric.totalShattered => s.totalShattered,
    AchievementMetric.totalDashUses => s.totalDashUses,
    AchievementMetric.bestScore => s.bestScore,
    AchievementMetric.maxPerfectStreak => s.maxPerfectStreak,
    AchievementMetric.bestStreak => s.bestStreak,
  };
}

abstract final class AchievementEngine {
  static const List<AchievementDef> all = [
    AchievementDef(
      'ach_first_flight',
      'First Flight',
      'Score a point',
      AchievementMetric.bestScore,
      1,
      25,
    ),
    AchievementDef(
      'ach_ten_gaps',
      'Ten Gaps',
      'Score 10 in one run',
      AchievementMetric.bestScore,
      10,
      25,
    ),
    AchievementDef(
      'ach_gold_wings',
      'Gold Wings',
      'Score 50 in one run',
      AchievementMetric.bestScore,
      50,
      100,
    ),
    AchievementDef(
      'ach_prism_wings',
      'Prism Wings',
      'Score 100 in one run',
      AchievementMetric.bestScore,
      100,
      250,
    ),
    AchievementDef(
      'ach_perfectionist',
      'Perfectionist',
      '7 Perfect passes in a row',
      AchievementMetric.maxPerfectStreak,
      7,
      100,
    ),
    AchievementDef(
      'ach_orb_collector',
      'Orb Collector',
      'Collect 50 glow orbs',
      AchievementMetric.totalOrbs,
      50,
      75,
    ),
    AchievementDef(
      'ach_dash_master',
      'Dash Master',
      'Shatter 20 spire pairs with Glow Dash',
      AchievementMetric.totalShattered,
      20,
      100,
    ),
    AchievementDef(
      'ach_night_owl',
      'Night Owl',
      'Score 60 in a run',
      AchievementMetric.bestScore,
      60,
      100,
    ),
    AchievementDef(
      'ach_regular',
      'Regular',
      'Play 50 runs',
      AchievementMetric.gamesPlayed,
      50,
      100,
    ),
    AchievementDef(
      'ach_daily_devotee',
      'Daily Devotee',
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
