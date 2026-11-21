import '../../game/rules/boosts.dart';
import '../retention/achievements.dart';
import '../retention/daily_challenges.dart';
import '../retention/daily_reward.dart';
import '../retention/streaks.dart';

/// Everything persisted for the player. Plain JSON, versioned.
class SaveData {
  const SaveData({
    this.coins = 0,
    this.bestScore = 0,
    this.adsRemoved = false,
    this.soundOn = true,
    this.vibrationOn = true,
    this.remindersOn = false,
    this.lastSeenMs = 0,
    this.savedAtMs = 0,
    this.dailyReward = const DailyRewardState(),
    this.streak = const StreakState(),
    this.challenges = const DailyChallengesState(),
    this.stats = const LifetimeStats(),
    this.unlockedAchievements = const {},
    this.processedPurchases = const {},
    this.masterVolume = 1.0,
    this.ambience = 'morning_birds',
    this.voiceOn = true,
    this.leftHanded = false,
    this.themeIndex = 0,
    this.tipsOff = false,
    this.tipHomeDay = -1,
    this.game,
    this.items = const {
      'blast': Boosts.startingStock,
      'shuffle': Boosts.startingStock,
      'undo': Boosts.startingStock,
      'sweep': Boosts.startingStock,
      'hammer': Boosts.startingStock,
    },
  });

  /// Bump when the JSON shape changes and add a step to [SaveMigrator].
  static const int currentVersion = 3;

  /// Boost stock by boost key (`blast`, `shuffle`, `undo`, `sweep`, `hammer`); never below 0.
  final Map<String, int> items;

  /// Stock of boost [key] (0 when unknown).
  int itemCount(String key) => items[key] ?? 0;

  final int coins;
  final int bestScore;
  final bool adsRemoved;
  final bool soundOn;
  final bool vibrationOn;
  final bool remindersOn;

  /// Latest time ever seen (UTC ms), for the backwards-clock guard.
  final int lastSeenMs;

  /// When this save was written (UTC ms); used to pick a winner when merging with cloud saves.
  final int savedAtMs;
  final DailyRewardState dailyReward;
  final StreakState streak;
  final DailyChallengesState challenges;
  final LifetimeStats stats;
  final Set<String> unlockedAchievements;

  /// Purchase IDs already delivered, so a replayed purchase is not granted twice.
  final Set<String> processedPurchases;

  /// Master volume 0..1, ambience track id ('off', 'morning_birds', ...), voice switch.
  final double masterVolume;
  final String ambience;
  final bool voiceOn;

  /// Left-handed layout: pause and back mirrored to the other side.
  final bool leftHanded;

  /// Position in the theme rotation (`ThemeRotation`); a new game continues from it.
  final int themeIndex;

  /// Tips are turned off ("Don't show tips again" ticked, or the settings switch is off).
  final bool tipsOff;

  /// Day index on which the home tip of the day was closed.
  final int tipHomeDay;

  /// The unfinished game (autosave), or null when none is running. See `GameState.toJson`.
  final Map<String, Object?>? game;

  SaveData copyWith({
    int? coins,
    int? bestScore,
    bool? adsRemoved,
    bool? soundOn,
    bool? vibrationOn,
    bool? remindersOn,
    int? lastSeenMs,
    int? savedAtMs,
    DailyRewardState? dailyReward,
    StreakState? streak,
    DailyChallengesState? challenges,
    LifetimeStats? stats,
    Set<String>? unlockedAchievements,
    Set<String>? processedPurchases,
    double? masterVolume,
    String? ambience,
    bool? voiceOn,
    bool? leftHanded,
    int? themeIndex,
    bool? tipsOff,
    int? tipHomeDay,
    Map<String, int>? items,
    Map<String, Object?>? game,
    bool clearGame = false,
  }) => SaveData(
    game: clearGame ? null : (game ?? this.game),
    items: items ?? this.items,
    coins: coins ?? this.coins,
    bestScore: bestScore ?? this.bestScore,
    adsRemoved: adsRemoved ?? this.adsRemoved,
    soundOn: soundOn ?? this.soundOn,
    vibrationOn: vibrationOn ?? this.vibrationOn,
    remindersOn: remindersOn ?? this.remindersOn,
    lastSeenMs: lastSeenMs ?? this.lastSeenMs,
    savedAtMs: savedAtMs ?? this.savedAtMs,
    dailyReward: dailyReward ?? this.dailyReward,
    streak: streak ?? this.streak,
    challenges: challenges ?? this.challenges,
    stats: stats ?? this.stats,
    unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    processedPurchases: processedPurchases ?? this.processedPurchases,
    masterVolume: masterVolume ?? this.masterVolume,
    ambience: ambience ?? this.ambience,
    voiceOn: voiceOn ?? this.voiceOn,
    leftHanded: leftHanded ?? this.leftHanded,
    themeIndex: themeIndex ?? this.themeIndex,
    tipsOff: tipsOff ?? this.tipsOff,
    tipHomeDay: tipHomeDay ?? this.tipHomeDay,
  );

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'coins': coins,
    'bestScore': bestScore,
    'adsRemoved': adsRemoved,
    'soundOn': soundOn,
    'vibrationOn': vibrationOn,
    'remindersOn': remindersOn,
    'lastSeenMs': lastSeenMs,
    'savedAtMs': savedAtMs,
    'dailyReward': dailyReward.toJson(),
    'streak': streak.toJson(),
    'challenges': challenges.toJson(),
    'stats': stats.toJson(),
    'unlockedAchievements': unlockedAchievements.toList()..sort(),
    'processedPurchases': processedPurchases.toList()..sort(),
    'masterVolume': masterVolume,
    'ambience': ambience,
    'voiceOn': voiceOn,
    'leftHanded': leftHanded,
    'themeIndex': themeIndex,
    'tipsOff': tipsOff,
    'tipHomeDay': tipHomeDay,
    'items': {for (final e in items.entries) e.key: e.value},
    if (game != null) 'game': game,
  };

  /// Expects JSON already migrated to [currentVersion].
  factory SaveData.fromJson(Map<String, Object?> j) => SaveData(
    coins: (j['coins'] as num?)?.toInt() ?? 0,
    bestScore: (j['bestScore'] as num?)?.toInt() ?? 0,
    adsRemoved: j['adsRemoved'] as bool? ?? false,
    soundOn: j['soundOn'] as bool? ?? true,
    vibrationOn: j['vibrationOn'] as bool? ?? true,
    remindersOn: j['remindersOn'] as bool? ?? false,
    lastSeenMs: (j['lastSeenMs'] as num?)?.toInt() ?? 0,
    savedAtMs: (j['savedAtMs'] as num?)?.toInt() ?? 0,
    dailyReward: DailyRewardState.fromJson(_map(j['dailyReward'])),
    streak: StreakState.fromJson(_map(j['streak'])),
    challenges: DailyChallengesState.fromJson(_map(j['challenges'])),
    stats: LifetimeStats.fromJson(_map(j['stats'])),
    unlockedAchievements: {
      ...?(j['unlockedAchievements'] as List?)?.cast<String>(),
    },
    processedPurchases: {
      ...?(j['processedPurchases'] as List?)?.cast<String>(),
    },
    masterVolume: ((j['masterVolume'] as num?)?.toDouble() ?? 1.0).clamp(
      0.0,
      1.0,
    ),
    ambience: _migrateAmbience(j['ambience'] as String?),
    voiceOn: j['voiceOn'] as bool? ?? true,
    leftHanded: j['leftHanded'] as bool? ?? false,
    themeIndex: ((j['themeIndex'] as num?)?.toInt() ?? 0).abs(),
    tipsOff: j['tipsOff'] as bool? ?? false,
    tipHomeDay: (j['tipHomeDay'] as num?)?.toInt() ?? -1,
    items: _items(j['items']),
    game: _map(j['game']),
  );

  /// Missing `items` (should not happen after migration) means the starting stock.
  static Map<String, int> _items(Object? o) {
    if (o is! Map) return Boosts.startingItems();
    return {
      for (final d in Boosts.all)
        d.key: ((o[d.key] as num?)?.toInt() ?? 0).clamp(0, 1 << 30),
    };
  }

  static Map<String, Object?>? _map(Object? o) =>
      o is Map ? o.cast<String, Object?>() : null;
}

/// Upgrades old save JSON step by step to [SaveData.currentVersion].
abstract final class SaveMigrator {
  static Map<String, Object?> migrate(Map<String, Object?> json) {
    var v = (json['version'] as num?)?.toInt() ?? 0;
    if (v > SaveData.currentVersion) {
      throw FormatException(
        'Save version $v is newer than supported ${SaveData.currentVersion}',
      );
    }
    var j = Map<String, Object?>.of(json);
    while (v < SaveData.currentVersion) {
      j = switch (v) {
        0 => _v0ToV1(j),
        1 => _v1ToV2(j),
        2 => _v2ToV3(j),
        _ => throw StateError('No migration from $v'),
      };
      v = (j['version'] as num).toInt();
    }
    return j;
  }

  /// v0 (pre-release prototype) stored `highScore` and `coinBalance`.
  static Map<String, Object?> _v0ToV1(Map<String, Object?> j) => {
    ...j,
    'version': 1,
    'bestScore': j['bestScore'] ?? j['highScore'] ?? 0,
    'coins': j['coins'] ?? j['coinBalance'] ?? 0,
  };

  /// v3 added boost stock `items`: every existing save gets 1 of each boost.
  static Map<String, Object?> _v2ToV3(Map<String, Object?> j) => {
    ...j,
    'version': 3,
    'items': j['items'] ?? Boosts.startingItems(),
  };

  /// v2 added `processedPurchases` and `savedAtMs`.
  static Map<String, Object?> _v1ToV2(Map<String, Object?> j) => {
    ...j,
    'version': 2,
    'processedPurchases': j['processedPurchases'] ?? const <String>[],
    'savedAtMs': j['savedAtMs'] ?? 0,
  };
}

/// The retired "Before sunrise" track falls back to the default (owner, 2026-11-09).
String _migrateAmbience(String? id) =>
    id == null || id == 'before_sunrise' ? 'morning_birds' : id;
