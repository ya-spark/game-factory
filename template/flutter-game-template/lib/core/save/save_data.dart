import '../../engine/content/progress.dart' show ItemResult, mistakeClearStreak;
import '../profile/child_profile.dart';
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
    this.ambience = 'morning_birds',
    this.voiceOn = true,
    this.leftHanded = false,
    this.tipsOff = false,
    this.spacedReview = true,
    this.tipHomeDay = -1,
    this.vibrationOn = true,
    this.remindersOn = false,
    this.reminderHour = 19,
    this.reminderMinute = 0,
    this.reminderDays = const {1, 2, 3, 4, 5, 6, 7},
    this.lastOpenedDay = -1,
    this.textSize = 'normal',
    this.reduceMotion = false,
    this.lastSeenMs = 0,
    this.savedAtMs = 0,
    this.dailyReward = const DailyRewardState(),
    this.streak = const StreakState(),
    this.challenges = const DailyChallengesState(),
    this.stats = const LifetimeStats(),
    this.unlockedAchievements = const {},
    this.processedPurchases = const {},
    this.profiles = const [],
    this.fullUnlock = false,
    this.ownedPacks = const {},
    this.unlockedGames = const {},
    this.ownedItems = const {},
    this.downloadWifiOnly = false,
  });

  /// Bump when the JSON shape changes and add a step to [SaveMigrator].
  static const int currentVersion = 9;

  final int coins;
  final int bestScore;
  final bool adsRemoved;
  final bool soundOn;

  /// Master volume 0..1, ambience track id ('off', 'morning_birds', ...), voice switch.
  final double masterVolume;
  final String ambience;
  final bool voiceOn;

  /// Left-handed layout: controls mirrored to the other side.
  final bool leftHanded;

  /// Tips are turned off ("Don't show tips again" ticked, or the settings switch is off).
  final bool tipsOff;

  /// Parent switch "Spaced review": due items join "Today's review". Off keeps the mistakes round.
  final bool spacedReview;

  /// Day index on which the home tip of the day was closed.
  final int tipHomeDay;
  final bool vibrationOn;
  final bool remindersOn;

  /// Local time of the daily reminder.
  final int reminderHour;
  final int reminderMinute;

  /// Weekdays (1 Monday .. 7 Sunday) that get a reminder. Default: every day.
  final Set<int> reminderDays;

  /// Day index the app was last opened (-1: unknown); drives the 3-day silent stop.
  final int lastOpenedDay;

  /// `small`, `normal` or `large` ([TextSizeChoice]); multiplies the system text size.
  final String textSize;

  /// Fewer and shorter animations.
  final bool reduceMotion;

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

  /// Child profiles on this device (up to [maxChildProfiles]). The coin balance, Remove Ads,
  /// Full Unlock and extra packs above are shared by all of them.
  final List<ChildProfile> profiles;

  /// Full Unlock bought: all built-in content is open.
  final bool fullUnlock;

  /// Product ids (`pack_<id>`) of extra packs bought on this device.
  final Set<String> ownedPacks;

  /// Coin-locked minigames unlocked on this device (permanent, shared by all children).
  final Set<String> unlockedGames;

  /// Shop items bought with coins (avatars, colour themes), shared by every child.
  final Set<String> ownedItems;

  /// Parent setting: full packs never download on mobile data.
  final bool downloadWifiOnly;

  SaveData copyWith({
    int? coins,
    int? bestScore,
    bool? adsRemoved,
    bool? soundOn,
    double? masterVolume,
    String? ambience,
    bool? voiceOn,
    bool? leftHanded,
    bool? tipsOff,
    bool? spacedReview,
    int? tipHomeDay,
    bool? vibrationOn,
    bool? remindersOn,
    int? reminderHour,
    int? reminderMinute,
    Set<int>? reminderDays,
    int? lastOpenedDay,
    String? textSize,
    bool? reduceMotion,
    int? lastSeenMs,
    int? savedAtMs,
    DailyRewardState? dailyReward,
    StreakState? streak,
    DailyChallengesState? challenges,
    LifetimeStats? stats,
    Set<String>? unlockedAchievements,
    Set<String>? processedPurchases,
    List<ChildProfile>? profiles,
    bool? fullUnlock,
    Set<String>? ownedPacks,
    Set<String>? unlockedGames,
    Set<String>? ownedItems,
    bool? downloadWifiOnly,
  }) => SaveData(
    profiles: profiles ?? this.profiles,
    fullUnlock: fullUnlock ?? this.fullUnlock,
    ownedPacks: ownedPacks ?? this.ownedPacks,
    unlockedGames: unlockedGames ?? this.unlockedGames,
    ownedItems: ownedItems ?? this.ownedItems,
    downloadWifiOnly: downloadWifiOnly ?? this.downloadWifiOnly,
    coins: coins ?? this.coins,
    bestScore: bestScore ?? this.bestScore,
    adsRemoved: adsRemoved ?? this.adsRemoved,
    soundOn: soundOn ?? this.soundOn,
    masterVolume: masterVolume ?? this.masterVolume,
    ambience: ambience ?? this.ambience,
    voiceOn: voiceOn ?? this.voiceOn,
    leftHanded: leftHanded ?? this.leftHanded,
    tipsOff: tipsOff ?? this.tipsOff,
    spacedReview: spacedReview ?? this.spacedReview,
    tipHomeDay: tipHomeDay ?? this.tipHomeDay,
    vibrationOn: vibrationOn ?? this.vibrationOn,
    remindersOn: remindersOn ?? this.remindersOn,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    reminderDays: reminderDays ?? this.reminderDays,
    lastOpenedDay: lastOpenedDay ?? this.lastOpenedDay,
    textSize: textSize ?? this.textSize,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    lastSeenMs: lastSeenMs ?? this.lastSeenMs,
    savedAtMs: savedAtMs ?? this.savedAtMs,
    dailyReward: dailyReward ?? this.dailyReward,
    streak: streak ?? this.streak,
    challenges: challenges ?? this.challenges,
    stats: stats ?? this.stats,
    unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    processedPurchases: processedPurchases ?? this.processedPurchases,
  );

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'coins': coins,
    'bestScore': bestScore,
    'adsRemoved': adsRemoved,
    'soundOn': soundOn,
    'masterVolume': masterVolume,
    'ambience': ambience,
    'voiceOn': voiceOn,
    'leftHanded': leftHanded,
    'tipsOff': tipsOff,
    'spacedReview': spacedReview,
    'tipHomeDay': tipHomeDay,
    'vibrationOn': vibrationOn,
    'remindersOn': remindersOn,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'reminderDays': (reminderDays.toList()..sort()),
    'lastOpenedDay': lastOpenedDay,
    'textSize': textSize,
    'reduceMotion': reduceMotion,
    'lastSeenMs': lastSeenMs,
    'savedAtMs': savedAtMs,
    'dailyReward': dailyReward.toJson(),
    'streak': streak.toJson(),
    'challenges': challenges.toJson(),
    'stats': stats.toJson(),
    'unlockedAchievements': unlockedAchievements.toList()..sort(),
    'processedPurchases': processedPurchases.toList()..sort(),
    'profiles': [for (final p in profiles) p.toJson()],
    'fullUnlock': fullUnlock,
    'ownedPacks': ownedPacks.toList()..sort(),
    'unlockedGames': unlockedGames.toList()..sort(),
    'ownedItems': ownedItems.toList()..sort(),
    'downloadWifiOnly': downloadWifiOnly,
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
    ambience: j['ambience'] as String? ?? 'morning_birds',
    voiceOn: j['voiceOn'] as bool? ?? true,
    leftHanded: j['leftHanded'] as bool? ?? false,
    tipsOff: j['tipsOff'] as bool? ?? false,
    spacedReview: j['spacedReview'] as bool? ?? true,
    tipHomeDay: (j['tipHomeDay'] as num?)?.toInt() ?? -1,
    vibrationOn: j['vibrationOn'] as bool? ?? true,
    remindersOn: j['remindersOn'] as bool? ?? false,
    reminderHour: ((j['reminderHour'] as num?)?.toInt() ?? 19).clamp(0, 23),
    reminderMinute: ((j['reminderMinute'] as num?)?.toInt() ?? 0).clamp(0, 59),
    reminderDays: _days(j['reminderDays']),
    lastOpenedDay: (j['lastOpenedDay'] as num?)?.toInt() ?? -1,
    textSize: j['textSize'] as String? ?? 'normal',
    reduceMotion: j['reduceMotion'] as bool? ?? false,
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
    profiles: [
      for (final p in (j['profiles'] as List?) ?? const [])
        if (p is Map) ChildProfile.fromJson(p.cast<String, Object?>()),
    ],
    fullUnlock: j['fullUnlock'] as bool? ?? false,
    ownedPacks: {...?(j['ownedPacks'] as List?)?.cast<String>()},
    unlockedGames: {...?(j['unlockedGames'] as List?)?.cast<String>()},
    ownedItems: {...?(j['ownedItems'] as List?)?.cast<String>()},
    downloadWifiOnly: j['downloadWifiOnly'] as bool? ?? false,
  );

  static Set<int> _days(Object? o) {
    final s = {
      for (final v in (o is List ? o : const []))
        if (v is num && v >= 1 && v <= 7) v.toInt(),
    };
    return o is List ? s : {1, 2, 3, 4, 5, 6, 7};
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
        3 => _v3ToV4(j),
        4 => _v4ToV5(j),
        5 => _v5ToV6(j),
        6 => _v6ToV7(j),
        7 => _v7ToV8(j),
        8 => _v8ToV9(j),
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

  /// v5 added the correct-in-a-row streak (`cs`) and the last-seen day (`ls`) to every item
  /// result. An item last answered right counts as cleared (`cs` 2) so nothing reappears in the
  /// mistakes notebook because of the migration; one last answered wrong starts at 0; `ls` stays
  /// unset.
  static Map<String, Object?> _v4ToV5(Map<String, Object?> j) {
    final profiles = j['profiles'];
    return {
      ...j,
      'version': 5,
      if (profiles is List)
        'profiles': [
          for (final p in profiles)
            if (p is Map) _profileV5(p.cast<String, Object?>()) else p,
        ],
    };
  }

  static Map<String, Object?> _profileV5(Map<String, Object?> p) {
    final progress = p['progress'];
    if (progress is! Map) return p;
    final items = progress['items'];
    if (items is! Map) return p;
    return {
      ...p,
      'progress': {
        ...progress.cast<String, Object?>(),
        'items': {
          for (final e in items.entries)
            e.key: e.value is Map
                ? {
                    ...(e.value as Map).cast<String, Object?>(),
                    'cs':
                        (e.value as Map)['cs'] ??
                        (((e.value as Map)['ok'] as bool? ?? false)
                            ? mistakeClearStreak
                            : 0),
                  }
                : e.value,
        },
      },
    };
  }

  /// v9 added the per-child exam history (`exams`, the last 10) and the parent's extra-time
  /// choice (`extraTime`, default none). Old saves start with no exams; nothing else changes.
  static Map<String, Object?> _v8ToV9(Map<String, Object?> j) => {
    ...j,
    'version': 9,
  };

  /// v8 added the per-child goal preset (`goalPreset`, default Steady), the reminder weekdays
  /// (default every day) and the last-opened day. Old saves keep their reminder switch and time.
  static Map<String, Object?> _v7ToV8(Map<String, Object?> j) => {
    ...j,
    'version': 8,
  };

  /// v7 added the per-child activity log (`activity`, 8 weeks). Old saves start with an empty
  /// log; nothing else changes.
  static Map<String, Object?> _v6ToV7(Map<String, Object?> j) => {
    ...j,
    'version': 7,
  };

  /// v6 added the spaced-review box (`bx`) to every item result: last answer wrong 0, passed 1,
  /// otherwise 0. Items with no `ls` (answered before version 5) are not due until answered
  /// again, so nothing becomes due all at once.
  static Map<String, Object?> _v5ToV6(Map<String, Object?> j) {
    final profiles = j['profiles'];
    return {
      ...j,
      'version': 6,
      if (profiles is List)
        'profiles': [
          for (final p in profiles)
            if (p is Map) _profileV6(p.cast<String, Object?>()) else p,
        ],
    };
  }

  static Map<String, Object?> _profileV6(Map<String, Object?> p) {
    final progress = p['progress'];
    if (progress is! Map) return p;
    final items = progress['items'];
    if (items is! Map) return p;
    return {
      ...p,
      'progress': {
        ...progress.cast<String, Object?>(),
        'items': {
          for (final e in items.entries)
            e.key: e.value is Map
                ? {
                    ...(e.value as Map).cast<String, Object?>(),
                    'bx': ItemResult.legacyBox(
                      (e.value as Map).cast<String, Object?>(),
                    ),
                  }
                : e.value,
        },
      },
    };
  }

  /// v4 added the text size, reduce motion and the reminder time (all have defaults), and the
  /// per-child play time (read as empty when missing).
  static Map<String, Object?> _v3ToV4(Map<String, Object?> j) => {
    ...j,
    'version': 4,
    'reminderHour': j['reminderHour'] ?? 19,
    'reminderMinute': j['reminderMinute'] ?? 0,
    'textSize': j['textSize'] ?? 'normal',
    'reduceMotion': j['reduceMotion'] ?? false,
  };

  /// v3 added child profiles. The existing single-player save becomes the first profile
  /// (year still to be picked); the coins and purchases stay shared by the device.
  static Map<String, Object?> _v2ToV3(Map<String, Object?> j) => {
    ...j,
    'version': 3,
    'profiles':
        j['profiles'] ??
        [const ChildProfile(id: 'p1', nickname: 'Player 1').toJson()],
    'fullUnlock': j['fullUnlock'] ?? false,
    'ownedPacks': j['ownedPacks'] ?? const <String>[],
    'downloadWifiOnly': j['downloadWifiOnly'] ?? false,
  };

  /// v2 added `processedPurchases` and `savedAtMs`.
  static Map<String, Object?> _v1ToV2(Map<String, Object?> j) => {
    ...j,
    'version': 2,
    'processedPurchases': j['processedPurchases'] ?? const <String>[],
    'savedAtMs': j['savedAtMs'] ?? 0,
  };
}
