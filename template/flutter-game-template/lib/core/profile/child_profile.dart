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
    this.mode = LearnMode.game,
    this.lockedMode,
    this.progress = const ChildProgress(),
  });

  final String id;
  final String nickname;
  final String avatar;

  /// Year level (0 = Foundation); null until the child picks one at first launch.
  final int? year;

  /// The mode the child last used (Game on first launch). A lock overrides it.
  final LearnMode mode;

  /// The mode shown now: the lock when set, else the last used one.
  LearnMode get effectiveMode => lockedMode ?? mode;

  /// Null: the child may switch. Otherwise only this mode is offered.
  final LearnMode? lockedMode;
  final ChildProgress progress;

  ChildProfile copyWith({
    String? nickname,
    String? avatar,
    int? year,
    LearnMode? mode,
    LearnMode? lockedMode,
    bool clearLock = false,
    ChildProgress? progress,
  }) => ChildProfile(
    id: id,
    nickname: nickname ?? this.nickname,
    avatar: avatar ?? this.avatar,
    year: year ?? this.year,
    mode: mode ?? this.mode,
    lockedMode: clearLock ? null : (lockedMode ?? this.lockedMode),
    progress: progress ?? this.progress,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'nickname': nickname,
    'avatar': avatar,
    'year': year,
    'mode': mode.name,
    'lockedMode': lockedMode?.name,
    'progress': progress.toJson(),
  };

  factory ChildProfile.fromJson(Map<String, Object?> j) => ChildProfile(
    id: j['id'] as String,
    nickname: j['nickname'] as String? ?? 'Player',
    avatar: j['avatar'] as String? ?? 'fox',
    year: (j['year'] as num?)?.toInt(),
    mode: LearnMode.parse(j['mode']) ?? LearnMode.game,
    lockedMode: LearnMode.parse(j['lockedMode']),
    progress: ChildProgress.fromJson(
      (j['progress'] as Map?)?.cast<String, Object?>(),
    ),
  );
}
