import 'dart:math';

import 'daily_challenges.dart';

/// Game-based daily challenges for the hubs (`retention.game_challenges: true`). They work on any
/// game of the hub: one score goal, one "play N different games" goal and one streak goal.
/// Pure Dart: no Flutter, no storage. The profile store feeds the events and persists the state.
abstract final class GameChallengeEngine {
  static const String scoreId = 'score';
  static const String gamesId = 'games';
  static const String streakId = 'streak';

  /// Easy / medium / hard targets; the day picks one tier for each challenge.
  static const List<int> scoreTargets = [200, 500, 1000];
  static const List<int> gamesTargets = [2, 3, 4];
  static const List<int> streakMilestones = [3, 7, 14, 30];
  static const List<int> rewards = [20, 40, 80];

  /// Today's three challenges, seeded by the day so they are the same after a reinstall.
  /// [streak] is the current play-day streak; the streak goal is the next milestone above it.
  static DailyChallengesState ensureToday(
    DailyChallengesState s,
    int today,
    int streak,
  ) {
    if (s.day == today && _isGameSet(s)) return syncStreak(s, streak);
    final rng = Random(today);
    final scoreTier = rng.nextInt(3);
    final gamesTier = rng.nextInt(3);
    final milestone = streakMilestones.firstWhere(
      (m) => m > streak,
      orElse: () => streakMilestones.last + 7 * ((streak - 30) ~/ 7 + 1),
    );
    return syncStreak(
      DailyChallengesState(
        day: today,
        challenges: [
          Challenge(
            id: '${scoreId}_$today',
            kind: ChallengeKind.scorePoints,
            description: 'Score ${scoreTargets[scoreTier]} points in any game',
            target: scoreTargets[scoreTier],
            reward: rewards[scoreTier],
          ),
          Challenge(
            id: '${gamesId}_$today',
            kind: ChallengeKind.playDifferentGames,
            description: 'Play ${gamesTargets[gamesTier]} different games',
            target: gamesTargets[gamesTier],
            reward: rewards[gamesTier],
          ),
          Challenge(
            id: '${streakId}_$today',
            kind: ChallengeKind.streakDays,
            description: 'Reach a $milestone-day streak',
            target: milestone,
            reward: rewards[milestoneTier(milestone)],
          ),
        ],
      ),
      streak,
    );
  }

  static int milestoneTier(int milestone) => milestone <= 3
      ? 0
      : milestone <= 7
      ? 1
      : 2;

  static bool _isGameSet(DailyChallengesState s) =>
      s.challenges.length == 3 &&
      s.challenges.map((c) => c.kind).toSet().containsAll(const {
        ChallengeKind.scorePoints,
        ChallengeKind.playDifferentGames,
        ChallengeKind.streakDays,
      });

  /// Streak goal progress follows the current streak (it never goes down once the goal is met).
  static DailyChallengesState syncStreak(DailyChallengesState s, int streak) =>
      _map(
        s,
        (c) => c.kind == ChallengeKind.streakDays && !c.claimed
            ? c.copyWith(progress: max(c.progress, streak))
            : c,
      );

  /// A game was played: [score] counts for the score goal (best single game wins), [gameId]
  /// counts once for the different-games goal.
  static DailyChallengesState recordPlay(
    DailyChallengesState s,
    String gameId,
    int score,
  ) => _map(s, (c) {
    if (c.claimed) return c;
    switch (c.kind) {
      case ChallengeKind.scorePoints:
        return score > c.progress ? c.copyWith(progress: score) : c;
      case ChallengeKind.playDifferentGames:
        if (c.seen.contains(gameId)) return c;
        final seen = [...c.seen, gameId];
        return c.copyWith(seen: seen, progress: seen.length);
      default:
        return c;
    }
  });

  static DailyChallengesState _map(
    DailyChallengesState s,
    Challenge Function(Challenge) f,
  ) => DailyChallengesState(
    day: s.day,
    challenges: [for (final c in s.challenges) f(c)],
  );
}
