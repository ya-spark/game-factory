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
    this.masterVolume = 1.0,
    this.ambience = 'night',
    this.voiceOn = true,
    this.sfxOn = true,
    this.leftHanded = false,
    this.vibrationOn = true,
    this.remindersOn = false,
    this.reduceMotion = false,
    this.paletteStart = 0,
    this.tipsOff = false,
    this.tipHomeDay = -1,
    this.dashRefills = 0,
    this.adRefillDay = -1,
    this.adRefillsToday = 0,
    this.lastSeenMs = 0,
    this.savedAtMs = 0,
    this.dailyReward = const DailyRewardState(),
    this.streak = const StreakState(),
    this.challenges = const DailyChallengesState(),
    this.stats = const LifetimeStats(),
    this.unlockedAchievements = const {},
    this.processedPurchases = const {},
    this.ownedSkins = const {'moth'},
    this.equippedSkin = 'moth',
    this.game,
  });

  /// The unfinished run (autosave), or null when none is running. See `WingyRun.toJson`.
  final Map<String, Object?>? game;

  /// Bump when the JSON shape changes and add a step to [SaveMigrator].
  static const int currentVersion = 4;

  final int coins;
  final int bestScore;
  final bool adsRemoved;
  final bool soundOn;

  /// Master volume 0..1, ambience track id ('off', 'night', ...), voice and effects switches.
  final double masterVolume;
  final String ambience;
  final bool voiceOn;
  final bool sfxOn;

  /// Left-handed layout: in-game buttons mirrored.
  final bool leftHanded;
  final bool vibrationOn;
  final bool remindersOn;
  final bool reduceMotion;

  /// Index of the palette the next run starts with (0..5).
  final int paletteStart;

  /// Tips are turned off ("Don't show tips again" ticked, or the settings switch is off).
  final bool tipsOff;

  /// Day index on which the home tip of the day was closed.
  final int tipHomeDay;

  /// Dash Refill stock: each one starts a run with a full Glow Dash meter.
  final int dashRefills;

  /// Day index and count of rewarded-ad refills taken (daily cap).
  final int adRefillDay;
  final int adRefillsToday;

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

  /// Flyer skins owned (the free Moth always) and the one in use.
  final Set<String> ownedSkins;
  final String equippedSkin;

  SaveData copyWith({
    int? coins,
    int? bestScore,
    bool? adsRemoved,
    bool? soundOn,
    double? masterVolume,
    String? ambience,
    bool? voiceOn,
    bool? sfxOn,
    bool? leftHanded,
    bool? vibrationOn,
    bool? remindersOn,
    bool? reduceMotion,
    int? paletteStart,
    bool? tipsOff,
    int? tipHomeDay,
    int? dashRefills,
    int? adRefillDay,
    int? adRefillsToday,
    int? lastSeenMs,
    int? savedAtMs,
    DailyRewardState? dailyReward,
    StreakState? streak,
    DailyChallengesState? challenges,
    LifetimeStats? stats,
    Set<String>? unlockedAchievements,
    Set<String>? processedPurchases,
    Set<String>? ownedSkins,
    String? equippedSkin,
    Map<String, Object?>? game,
    bool clearGame = false,
  }) => SaveData(
    game: clearGame ? null : (game ?? this.game),
    coins: coins ?? this.coins,
    bestScore: bestScore ?? this.bestScore,
    adsRemoved: adsRemoved ?? this.adsRemoved,
    soundOn: soundOn ?? this.soundOn,
    masterVolume: masterVolume ?? this.masterVolume,
    ambience: ambience ?? this.ambience,
    voiceOn: voiceOn ?? this.voiceOn,
    sfxOn: sfxOn ?? this.sfxOn,
    leftHanded: leftHanded ?? this.leftHanded,
    vibrationOn: vibrationOn ?? this.vibrationOn,
    remindersOn: remindersOn ?? this.remindersOn,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    paletteStart: paletteStart ?? this.paletteStart,
    tipsOff: tipsOff ?? this.tipsOff,
    tipHomeDay: tipHomeDay ?? this.tipHomeDay,
    dashRefills: dashRefills ?? this.dashRefills,
    adRefillDay: adRefillDay ?? this.adRefillDay,
    adRefillsToday: adRefillsToday ?? this.adRefillsToday,
    lastSeenMs: lastSeenMs ?? this.lastSeenMs,
    savedAtMs: savedAtMs ?? this.savedAtMs,
    dailyReward: dailyReward ?? this.dailyReward,
    streak: streak ?? this.streak,
    challenges: challenges ?? this.challenges,
    stats: stats ?? this.stats,
    unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    processedPurchases: processedPurchases ?? this.processedPurchases,
    ownedSkins: ownedSkins ?? this.ownedSkins,
    equippedSkin: equippedSkin ?? this.equippedSkin,
  );

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'coins': coins,
    'bestScore': bestScore,
    'adsRemoved': adsRemoved,
    'soundOn': soundOn,
    'masterVolume': masterVolume,
    'ambience': ambience,
    if (game != null) 'game': game,
    'voiceOn': voiceOn,
    'sfxOn': sfxOn,
    'leftHanded': leftHanded,
    'vibrationOn': vibrationOn,
    'remindersOn': remindersOn,
    'reduceMotion': reduceMotion,
    'paletteStart': paletteStart,
    'tipsOff': tipsOff,
    'tipHomeDay': tipHomeDay,
    'dashRefills': dashRefills,
    'adRefillDay': adRefillDay,
    'adRefillsToday': adRefillsToday,
    'lastSeenMs': lastSeenMs,
    'savedAtMs': savedAtMs,
    'dailyReward': dailyReward.toJson(),
    'streak': streak.toJson(),
    'challenges': challenges.toJson(),
    'stats': stats.toJson(),
    'unlockedAchievements': unlockedAchievements.toList()..sort(),
    'processedPurchases': processedPurchases.toList()..sort(),
    'ownedSkins': ownedSkins.toList()..sort(),
    'equippedSkin': equippedSkin,
  };

  /// Expects JSON already migrated to [currentVersion].
  factory SaveData.fromJson(Map<String, Object?> j) => SaveData(
    coins: (j['coins'] as num?)?.toInt() ?? 0,
    bestScore: (j['bestScore'] as num?)?.toInt() ?? 0,
    adsRemoved: j['adsRemoved'] as bool? ?? false,
    soundOn: j['soundOn'] as bool? ?? true,
    masterVolume: ((j['masterVolume'] as num?)?.toDouble() ?? 1.0).clamp(
      0.0,
      1.0,
    ),
    ambience: _migrateAmbience(j['ambience'] as String?),
    voiceOn: j['voiceOn'] as bool? ?? true,
    sfxOn: j['sfxOn'] as bool? ?? true,
    leftHanded: j['leftHanded'] as bool? ?? false,
    vibrationOn: j['vibrationOn'] as bool? ?? true,
    remindersOn: j['remindersOn'] as bool? ?? false,
    reduceMotion: j['reduceMotion'] as bool? ?? false,
    paletteStart: ((j['paletteStart'] as num?)?.toInt() ?? 0).clamp(0, 5),
    tipsOff: j['tipsOff'] as bool? ?? false,
    tipHomeDay: (j['tipHomeDay'] as num?)?.toInt() ?? -1,
    dashRefills: (j['dashRefills'] as num?)?.toInt() ?? 0,
    adRefillDay: (j['adRefillDay'] as num?)?.toInt() ?? -1,
    adRefillsToday: (j['adRefillsToday'] as num?)?.toInt() ?? 0,
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
    ownedSkins: {'moth', ...?(j['ownedSkins'] as List?)?.cast<String>()},
    equippedSkin: j['equippedSkin'] as String? ?? 'moth',
    game: _map(j['game']),
  );

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
        3 => _v3ToV4(j),
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

  /// v2 added `processedPurchases` and `savedAtMs`.
  static Map<String, Object?> _v1ToV2(Map<String, Object?> j) => {
    ...j,
    'version': 2,
    'processedPurchases': j['processedPurchases'] ?? const <String>[],
    'savedAtMs': j['savedAtMs'] ?? 0,
  };

  /// v3 added Dash Refill stock, ad-refill counters and `reduceMotion`; all default safely.
  static Map<String, Object?> _v2ToV3(Map<String, Object?> j) => {
    ...j,
    'version': 3,
  };

  /// v4 added flyer skins (`ownedSkins`, `equippedSkin`); both default to the Moth.
  static Map<String, Object?> _v3ToV4(Map<String, Object?> j) => {
    ...j,
    'version': 4,
  };
}

/// The retired "Before sunrise" track falls back to the default (owner, 2026-11-09).
String _migrateAmbience(String? id) =>
    id == null || id == 'before_sunrise' ? 'night' : id;
