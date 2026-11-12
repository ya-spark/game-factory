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
    this.mode = LearnMode.game,
    this.lockedMode,
    this.progress = const ChildProgress(),
    this.playTime = const PlayTimeLog(),
  });

  final String id;
  final String nickname;
  final String avatar;

  /// Year level (0 = Foundation); null until the child picks one at first launch.
  final int? year;

  /// The colour theme the child picked in the shop ('default' until then).
  final String colorTheme;

  /// The mode the child last used (Game on first launch). A lock overrides it.
  final LearnMode mode;

  /// The mode shown now: the lock when set, else the last used one.
  LearnMode get effectiveMode => lockedMode ?? mode;

  /// Null: the child may switch. Otherwise only this mode is offered.
  final LearnMode? lockedMode;
  final ChildProgress progress;

  /// Time played per day (this device only), for the weekly total in the grown-ups' view.
  final PlayTimeLog playTime;

  ChildProfile copyWith({
    String? nickname,
    String? avatar,
    int? year,
    String? colorTheme,
    LearnMode? mode,
    LearnMode? lockedMode,
    bool clearLock = false,
    ChildProgress? progress,
    PlayTimeLog? playTime,
  }) => ChildProfile(
    id: id,
    nickname: nickname ?? this.nickname,
    avatar: avatar ?? this.avatar,
    year: year ?? this.year,
    colorTheme: colorTheme ?? this.colorTheme,
    mode: mode ?? this.mode,
    lockedMode: clearLock ? null : (lockedMode ?? this.lockedMode),
    progress: progress ?? this.progress,
    playTime: playTime ?? this.playTime,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'nickname': nickname,
    'avatar': avatar,
    'year': year,
    'colorTheme': colorTheme,
    'mode': mode.name,
    'lockedMode': lockedMode?.name,
    'progress': progress.toJson(),
    'playTime': playTime.toJson(),
  };

  factory ChildProfile.fromJson(Map<String, Object?> j) => ChildProfile(
    id: j['id'] as String,
    nickname: j['nickname'] as String? ?? 'Player',
    avatar: j['avatar'] as String? ?? 'fox',
    year: (j['year'] as num?)?.toInt(),
    colorTheme: j['colorTheme'] as String? ?? 'default',
    mode: LearnMode.parse(j['mode']) ?? LearnMode.game,
    lockedMode: LearnMode.parse(j['lockedMode']),
    progress: ChildProgress.fromJson(
      (j['progress'] as Map?)?.cast<String, Object?>(),
    ),
    playTime: PlayTimeLog.fromJson(j['playTime']),
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

enum ShopKind { avatar, theme }

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
  ShopItem('sunset', ShopKind.theme, 'Sunset', 50),
  ShopItem('forest', ShopKind.theme, 'Forest', 50),
  ShopItem('ocean', ShopKind.theme, 'Ocean', 50),
];
