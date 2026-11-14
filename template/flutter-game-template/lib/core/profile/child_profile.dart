import '../../engine/engine.dart';

/// Game or Study mode. A parent can lock a child to one of them.
enum LearnMode {
  game,
  study;

  static LearnMode? parse(Object? v) {
    for (final m in values) {
      if (m.name == v) return m;
    }
    return null;
  }
}

/// Built-in avatars (no photos). Names only; the UI maps each to an icon.
const List<String> avatarIds = [
  'fox',
  'owl',
  'bear',
  'cat',
  'frog',
  'panda',
  'rabbit',
  'penguin',
];

const int maxChildProfiles = 4;
const int maxNicknameLength = 12;

/// One child on this device: a made-up nickname and an avatar. Nothing leaves the device.
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.nickname,
    this.avatar = 'fox',
    this.year,
    this.colorTheme = 'default',
    this.goalPreset = GoalPreset.steady,
    this.mode = LearnMode.game,
    this.lockedMode,
    this.progress = const ChildProgress(),
    this.playTime = const PlayTimeLog(),
    this.activity = const ActivityLog(),
  });

  final String id;
  final String nickname;
  final String avatar;

  /// Year level (0 = Foundation); null until the child picks one at first launch.
  final int? year;

  /// The colour theme the child picked in the shop ('default' until then).
  final String colorTheme;

  /// The parent's goal size for this child (item counts only; coins do not change).
  final GoalPreset goalPreset;

  /// The mode the child last used (Game on first launch). A lock overrides it.
  final LearnMode mode;

  /// The mode shown now: the lock when set, else the last used one.
  LearnMode get effectiveMode => lockedMode ?? mode;

  /// Null: the child may switch. Otherwise only this mode is offered.
  final LearnMode? lockedMode;
  final ChildProgress progress;

  /// Time played per day (this device only), for the weekly total in the grown-ups' view.
  final PlayTimeLog playTime;

  /// Answers, passes and topics per day for the last 8 weeks (this device only), for the
  /// weekly report.
  final ActivityLog activity;

  ChildProfile copyWith({
    String? nickname,
    String? avatar,
    int? year,
    String? colorTheme,
    GoalPreset? goalPreset,
    LearnMode? mode,
    LearnMode? lockedMode,
    bool clearLock = false,
    ChildProgress? progress,
    PlayTimeLog? playTime,
    ActivityLog? activity,
  }) => ChildProfile(
    id: id,
    nickname: nickname ?? this.nickname,
    avatar: avatar ?? this.avatar,
    year: year ?? this.year,
    colorTheme: colorTheme ?? this.colorTheme,
    goalPreset: goalPreset ?? this.goalPreset,
    mode: mode ?? this.mode,
    lockedMode: clearLock ? null : (lockedMode ?? this.lockedMode),
    progress: progress ?? this.progress,
    playTime: playTime ?? this.playTime,
    activity: activity ?? this.activity,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'nickname': nickname,
    'avatar': avatar,
    'year': year,
    'colorTheme': colorTheme,
    'goalPreset': goalPreset.name,
    'mode': mode.name,
    'lockedMode': lockedMode?.name,
    'progress': progress.toJson(),
    'playTime': playTime.toJson(),
    'activity': activity.toJson(),
  };

  factory ChildProfile.fromJson(Map<String, Object?> j) => ChildProfile(
    id: j['id'] as String,
    nickname: j['nickname'] as String? ?? 'Player',
    avatar: j['avatar'] as String? ?? 'fox',
    year: (j['year'] as num?)?.toInt(),
    colorTheme: j['colorTheme'] as String? ?? 'default',
    goalPreset: GoalPreset.parse(j['goalPreset']),
    mode: LearnMode.parse(j['mode']) ?? LearnMode.game,
    lockedMode: LearnMode.parse(j['lockedMode']),
    progress: ChildProgress.fromJson(
      (j['progress'] as Map?)?.cast<String, Object?>(),
    ),
    playTime: PlayTimeLog.fromJson(j['playTime']),
    activity: ActivityLog.fromJson(j['activity']),
  );
}

/// Something a child can buy with coins in the shop: an avatar (a shape, never a person) or a
/// colour theme. [price] 0 means every child has it from the start.
class ShopItem {
  const ShopItem(this.id, this.kind, this.title, this.price);
  final String id;
  final ShopKind kind;
  final String title;
  final int price;
}

enum ShopKind { avatar, theme, sound }

const List<ShopItem> shopItems = [
  ShopItem('fox', ShopKind.avatar, 'Fox', 0),
  ShopItem('owl', ShopKind.avatar, 'Owl', 0),
  ShopItem('bear', ShopKind.avatar, 'Bear', 0),
  ShopItem('cat', ShopKind.avatar, 'Cat', 40),
  ShopItem('frog', ShopKind.avatar, 'Frog', 40),
  ShopItem('panda', ShopKind.avatar, 'Panda', 60),
  ShopItem('rabbit', ShopKind.avatar, 'Rabbit', 60),
  ShopItem('penguin', ShopKind.avatar, 'Penguin', 80),
  ShopItem('default', ShopKind.theme, 'Classic', 0),
  ShopItem('sunset', ShopKind.theme, 'Sunset', 60),
  ShopItem('forest', ShopKind.theme, 'Forest', 60),
  ShopItem('ocean', ShopKind.theme, 'Ocean', 60),
  // Extra themes and ambience packs: shown only when `shop.extra_themes` / `shop.sound_packs`
  // are on (the Mind hubs). A sound item id is the ambience track id.
  ShopItem('midnight', ShopKind.theme, 'Midnight', 60),
  ShopItem('lavender', ShopKind.theme, 'Lavender', 60),
  ShopItem('sand', ShopKind.theme, 'Sand', 60),
  ShopItem('slate', ShopKind.theme, 'Slate', 60),
  ShopItem('rain', ShopKind.sound, 'Rain', 80),
  ShopItem('waves', ShopKind.sound, 'Waves', 80),
  ShopItem('forest_wind', ShopKind.sound, 'Forest wind', 80),
  ShopItem('fireplace', ShopKind.sound, 'Fireplace', 80),
];

/// Theme ids that need `shop.extra_themes`.
const Set<String> extraThemeIds = {'midnight', 'lavender', 'sand', 'slate'};

/// The items the shop offers with the given flags (`shop.extra_themes`, `shop.sound_packs`).
List<ShopItem> shopItemsFor({
  required bool extraThemes,
  required bool soundPacks,
}) => [
  for (final i in shopItems)
    if (i.kind == ShopKind.sound
        ? soundPacks
        : (extraThemes || !extraThemeIds.contains(i.id)))
      i,
];
