/// Lifetime counters that achievements are derived from. Pure Dart.
class LifetimeStats {
  const LifetimeStats({
    this.gamesPlayed = 0,
    this.totalLines = 0,
    this.piecesPlaced = 0,
    this.bestScore = 0,
    this.maxCombo = 0,
    this.bestStreak = 0,
    this.quads = 0,
    this.prismRows = 0,
    this.holdsUsed = 0,
    this.perfectClears = 0,
    this.maxLevel = 0,
  });

  final int gamesPlayed;
  final int totalLines;
  final int piecesPlaced;
  final int bestScore;
  final int maxCombo;
  final int bestStreak;

  /// Quads (4 rows at once), total.
  final int quads;

  /// Rows that contained a prism and were cleared, total.
  final int prismRows;
  final int holdsUsed;
  final int perfectClears;

  /// Highest level reached in any game.
  final int maxLevel;

  LifetimeStats copyWith({
    int? gamesPlayed,
    int? totalLines,
    int? piecesPlaced,
    int? bestScore,
    int? maxCombo,
    int? bestStreak,
    int? quads,
    int? prismRows,
    int? holdsUsed,
    int? perfectClears,
    int? maxLevel,
  }) => LifetimeStats(
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    totalLines: totalLines ?? this.totalLines,
    piecesPlaced: piecesPlaced ?? this.piecesPlaced,
    bestScore: bestScore ?? this.bestScore,
    maxCombo: maxCombo ?? this.maxCombo,
    bestStreak: bestStreak ?? this.bestStreak,
    quads: quads ?? this.quads,
    prismRows: prismRows ?? this.prismRows,
    holdsUsed: holdsUsed ?? this.holdsUsed,
    perfectClears: perfectClears ?? this.perfectClears,
    maxLevel: maxLevel ?? this.maxLevel,
  );

  Map<String, Object?> toJson() => {
    'gamesPlayed': gamesPlayed,
    'totalLines': totalLines,
    'piecesPlaced': piecesPlaced,
    'bestScore': bestScore,
    'maxCombo': maxCombo,
    'bestStreak': bestStreak,
    'quads': quads,
    'prismRows': prismRows,
    'holdsUsed': holdsUsed,
    'perfectClears': perfectClears,
    'maxLevel': maxLevel,
  };

  factory LifetimeStats.fromJson(Map<String, Object?>? j) {
    int n(String k) => (j?[k] as num?)?.toInt() ?? 0;
    return LifetimeStats(
      gamesPlayed: n('gamesPlayed'),
      totalLines: n('totalLines'),
      piecesPlaced: n('piecesPlaced'),
      bestScore: n('bestScore'),
      maxCombo: n('maxCombo'),
      bestStreak: n('bestStreak'),
      quads: n('quads'),
      prismRows: n('prismRows'),
      holdsUsed: n('holdsUsed'),
      perfectClears: n('perfectClears'),
      maxLevel: n('maxLevel'),
    );
  }
}

enum AchievementMetric {
  gamesPlayed,
  totalLines,
  piecesPlaced,
  bestScore,
  maxCombo,
  bestStreak,
  quads,
  prismRows,
  holdsUsed,
  perfectClears,
  maxLevel,
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
    AchievementMetric.quads => s.quads,
    AchievementMetric.prismRows => s.prismRows,
    AchievementMetric.holdsUsed => s.holdsUsed,
    AchievementMetric.perfectClears => s.perfectClears,
    AchievementMetric.maxLevel => s.maxLevel,
  };
}

abstract final class AchievementEngine {
  /// The ten Blockfall achievements; ids double as the Play Games achievement keys.
  static const List<AchievementDef> all = [
    AchievementDef(
      'ach_first_row',
      'First Row',
      'Clear your first line',
      AchievementMetric.totalLines,
      1,
      25,
    ),
    AchievementDef(
      'ach_century',
      'Century',
      'Clear 100 lines in total',
      AchievementMetric.totalLines,
      100,
      100,
    ),
    AchievementDef(
      'ach_quad_squad',
      'Quad Squad',
      'Clear 4 rows at once, 4 times',
      AchievementMetric.quads,
      4,
      100,
    ),
    AchievementDef(
      'ach_prism_collector',
      'Prism Collector',
      'Clear 50 rows that hold a prism',
      AchievementMetric.prismRows,
      50,
      150,
    ),
    AchievementDef(
      'ach_combo_master',
      'Combo Master',
      'Reach a x5 combo',
      AchievementMetric.maxCombo,
      5,
      100,
    ),
    AchievementDef(
      'ach_speed_demon',
      'Speed Demon',
      'Reach level 10',
      AchievementMetric.maxLevel,
      10,
      150,
    ),
    AchievementDef(
      'ach_perfect',
      'Perfect',
      'Clear the whole well',
      AchievementMetric.perfectClears,
      1,
      200,
    ),
    AchievementDef(
      'ach_hold_tactician',
      'Hold Tactician',
      'Use Hold 100 times',
      AchievementMetric.holdsUsed,
      100,
      75,
    ),
    AchievementDef(
      'ach_marathoner',
      'Marathoner',
      'Score 20,000 in one game',
      AchievementMetric.bestScore,
      20000,
      250,
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
