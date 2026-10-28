import 'dart:math';

/// What a challenge measures. Events are fed in by the profile store.
enum ChallengeKind {
  scorePoints,
  clearLines,
  placePieces,
  playGames,
  makeCombo,
}

class ChallengeTemplate {
  const ChallengeTemplate(
    this.kind,
    this.description,
    this.targets,
    this.rewards, {
    this.isMax = false,
  });

  final ChallengeKind kind;

  /// Uses `{n}` for the target.
  final String description;

  /// Easy / medium / hard targets.
  final List<int> targets;
  final List<int> rewards;

  /// Progress is the maximum seen (single-game score) rather than a running total.
  final bool isMax;
}

class Challenge {
  const Challenge({
    required this.id,
    required this.kind,
    required this.description,
    required this.target,
    required this.reward,
    this.progress = 0,
    this.claimed = false,
  });

  final String id;
  final ChallengeKind kind;
  final String description;
  final int target;
  final int reward;
  final int progress;
  final bool claimed;

  bool get completed => progress >= target;
  bool get claimable => completed && !claimed;

  Challenge copyWith({int? progress, bool? claimed}) => Challenge(
    id: id,
    kind: kind,
    description: description,
    target: target,
    reward: reward,
    progress: progress ?? this.progress,
    claimed: claimed ?? this.claimed,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'description': description,
    'target': target,
    'reward': reward,
    'progress': progress,
    'claimed': claimed,
  };

  factory Challenge.fromJson(Map<String, Object?> j) => Challenge(
    id: j['id'] as String,
    kind: ChallengeKind.values.byName(j['kind'] as String),
    description: j['description'] as String,
    target: (j['target'] as num).toInt(),
    reward: (j['reward'] as num).toInt(),
    progress: (j['progress'] as num?)?.toInt() ?? 0,
    claimed: j['claimed'] as bool? ?? false,
  );
}

class DailyChallengesState {
  const DailyChallengesState({this.day = -1, this.challenges = const []});

  final int day;
  final List<Challenge> challenges;

  Map<String, Object?> toJson() => {
    'day': day,
    'challenges': [for (final c in challenges) c.toJson()],
  };

  factory DailyChallengesState.fromJson(Map<String, Object?>? j) => j == null
      ? const DailyChallengesState()
      : DailyChallengesState(
          day: (j['day'] as num?)?.toInt() ?? -1,
          challenges: [
            for (final c in (j['challenges'] as List? ?? const []))
              Challenge.fromJson((c as Map).cast<String, Object?>()),
          ],
        );
}

abstract final class DailyChallengeEngine {
  static const int perDay = 3;

  static const List<ChallengeTemplate> templates = [
    ChallengeTemplate(
      ChallengeKind.scorePoints,
      'Score {n} points in one game',
      [300, 600, 1000],
      [20, 40, 80],
      isMax: true,
    ),
    ChallengeTemplate(
      ChallengeKind.clearLines,
      'Clear {n} lines',
      [8, 15, 25],
      [20, 40, 80],
    ),
    ChallengeTemplate(
      ChallengeKind.placePieces,
      'Place {n} pieces',
      [30, 60, 100],
      [20, 40, 80],
    ),
    ChallengeTemplate(
      ChallengeKind.playGames,
      'Play {n} games',
      [2, 4, 6],
      [20, 40, 80],
    ),
    ChallengeTemplate(
      ChallengeKind.makeCombo,
      'Reach a x{n} combo',
      [2, 3, 4],
      [20, 40, 80],
      isMax: true,
    ),
  ];

  /// Makes sure the state holds today's three challenges. Deterministic per day
  /// (seeded by the day index) so it is identical across reinstalls on the same day.
  static DailyChallengesState ensureToday(DailyChallengesState s, int today) {
    if (s.day == today && s.challenges.length == perDay) return s;
    final rng = Random(today);
    final pool = [...templates]..shuffle(rng);
    final picks = pool.take(perDay).toList();
    return DailyChallengesState(
      day: today,
      challenges: [
        for (var i = 0; i < picks.length; i++)
          Challenge(
            id: 'c${today}_$i',
            kind: picks[i].kind,
            description: picks[i].description.replaceAll(
              '{n}',
              '${picks[i].targets[i]}',
            ),
            target: picks[i].targets[i],
            reward: picks[i].rewards[i],
          ),
      ],
    );
  }

  static ChallengeTemplate _template(ChallengeKind k) =>
      templates.firstWhere((t) => t.kind == k);

  /// Feeds an event. For "max" kinds [amount] replaces progress if larger; otherwise it adds.
  static DailyChallengesState record(
    DailyChallengesState s,
    ChallengeKind kind,
    int amount,
  ) {
    if (amount <= 0) return s;
    final isMax = _template(kind).isMax;
    return DailyChallengesState(
      day: s.day,
      challenges: [
        for (final c in s.challenges)
          if (c.kind != kind || c.claimed)
            c
          else
            c.copyWith(
              progress: isMax ? max(c.progress, amount) : c.progress + amount,
            ),
      ],
    );
  }

  /// Claims a completed challenge; null if not claimable.
  static ({DailyChallengesState state, int coins})? claim(
    DailyChallengesState s,
    String id,
  ) {
    final c = s.challenges.where((c) => c.id == id).firstOrNull;
    if (c == null || !c.claimable) return null;
    return (
      state: DailyChallengesState(
        day: s.day,
        challenges: [
          for (final x in s.challenges)
            x.id == id ? x.copyWith(claimed: true) : x,
        ],
      ),
      coins: c.reward,
    );
  }
}
