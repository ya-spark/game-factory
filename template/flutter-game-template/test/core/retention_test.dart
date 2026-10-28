import 'package:flutter_game_template/core/clock.dart';
import 'package:flutter_game_template/core/retention/achievements.dart';
import 'package:flutter_game_template/core/retention/daily_challenges.dart';
import 'package:flutter_game_template/core/retention/daily_reward.dart';
import 'package:flutter_game_template/core/retention/streaks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyRewardEngine (7-day cycle)', () {
    test('first claim is day 1', () {
      const s = DailyRewardState();
      final c = DailyRewardEngine.claim(s, 100)!;
      expect(c.day, 0);
      expect(c.coins, DailyRewardEngine.coinsByDay[0]);
    });

    test('cannot claim twice on the same day', () {
      final c = DailyRewardEngine.claim(const DailyRewardState(), 100)!;
      expect(DailyRewardEngine.canClaim(c.state, 100), isFalse);
      expect(DailyRewardEngine.claim(c.state, 100), isNull);
    });

    test('consecutive days walk the cycle and wrap after day 7', () {
      var s = const DailyRewardState();
      final days = <int>[];
      for (var d = 100; d < 109; d++) {
        final c = DailyRewardEngine.claim(s, d)!;
        days.add(c.day);
        s = c.state;
      }
      expect(days, [0, 1, 2, 3, 4, 5, 6, 0, 1]);
    });

    test('missing a day restarts the cycle', () {
      var s = DailyRewardEngine.claim(const DailyRewardState(), 100)!.state;
      s = DailyRewardEngine.claim(s, 101)!.state;
      final c = DailyRewardEngine.claim(s, 103)!; // skipped 102
      expect(c.day, 0);
    });

    test('json round trip', () {
      const s = DailyRewardState(nextDay: 3, lastClaimDay: 42);
      final r = DailyRewardState.fromJson(s.toJson());
      expect(r.nextDay, 3);
      expect(r.lastClaimDay, 42);
    });
  });

  group('StreakEngine', () {
    test('increments on consecutive days, same day is a no-op', () {
      var s = const StreakState();
      s = StreakEngine.recordActivity(s, 10).state;
      expect(s.current, 1);
      expect(StreakEngine.recordActivity(s, 10).changed, isFalse);
      s = StreakEngine.recordActivity(s, 11).state;
      s = StreakEngine.recordActivity(s, 12).state;
      expect(s.current, 3);
      expect(s.best, 3);
    });

    test('a missed day resets the streak without a freeze', () {
      var s = const StreakState(current: 5, best: 5, lastActiveDay: 10);
      final u = StreakEngine.recordActivity(s, 12);
      expect(u.state.current, 1);
      expect(u.state.best, 5);
      expect(u.broken, isTrue);
    });

    test('a freeze covers one missed day', () {
      const s = StreakState(current: 5, best: 5, lastActiveDay: 10, freezes: 1);
      final u = StreakEngine.recordActivity(s, 12);
      expect(u.state.current, 6);
      expect(u.state.freezes, 0);
      expect(u.freezesUsed, 1);
    });

    test('freezes are optional: disabled means the streak breaks', () {
      const s = StreakState(current: 5, best: 5, lastActiveDay: 10, freezes: 1);
      final u = StreakEngine.recordActivity(s, 12, useFreezes: false);
      expect(u.state.current, 1);
      expect(u.state.freezes, 1);
    });

    test('not enough freezes for a long gap breaks the streak', () {
      const s = StreakState(current: 5, best: 5, lastActiveDay: 10, freezes: 1);
      expect(StreakEngine.recordActivity(s, 14).state.current, 1);
    });

    test('a freeze is earned every 7 days, capped', () {
      var s = const StreakState();
      for (var d = 0; d < 7; d++) {
        s = StreakEngine.recordActivity(s, d).state;
      }
      expect(s.current, 7);
      expect(s.freezes, 1);
      for (var d = 7; d < 30; d++) {
        s = StreakEngine.recordActivity(s, d).state;
      }
      expect(s.freezes, StreakEngine.maxFreezes);
    });

    test('displayStreak reads 0 once the streak lapsed', () {
      const s = StreakState(current: 4, best: 4, lastActiveDay: 10);
      expect(StreakEngine.displayStreak(s, 11), 4);
      expect(StreakEngine.displayStreak(s, 13), 0);
    });
  });

  group('DailyChallengeEngine', () {
    test(
      'creates exactly three distinct challenges, deterministic per day',
      () {
        final a = DailyChallengeEngine.ensureToday(
          const DailyChallengesState(),
          200,
        );
        final b = DailyChallengeEngine.ensureToday(
          const DailyChallengesState(),
          200,
        );
        expect(a.challenges, hasLength(3));
        expect(a.challenges.map((c) => c.kind).toSet(), hasLength(3));
        expect(
          a.challenges.map((c) => c.id).toList(),
          b.challenges.map((c) => c.id).toList(),
        );
      },
    );

    test('keeps progress within a day, regenerates on a new day', () {
      var s = DailyChallengeEngine.ensureToday(const DailyChallengesState(), 5);
      final kind = s.challenges.first.kind;
      s = DailyChallengeEngine.record(s, kind, 1);
      expect(DailyChallengeEngine.ensureToday(s, 5), same(s));
      final next = DailyChallengeEngine.ensureToday(s, 6);
      expect(next.day, 6);
      expect(next.challenges.every((c) => c.progress == 0), isTrue);
    });

    test('progress completes and can be claimed exactly once', () {
      var s = DailyChallengeEngine.ensureToday(const DailyChallengesState(), 9);
      final c = s.challenges.first;
      s = DailyChallengeEngine.record(s, c.kind, c.target);
      final r = DailyChallengeEngine.claim(s, c.id)!;
      expect(r.coins, c.reward);
      expect(DailyChallengeEngine.claim(r.state, c.id), isNull);
    });

    test('cannot claim an incomplete challenge', () {
      final s = DailyChallengeEngine.ensureToday(
        const DailyChallengesState(),
        9,
      );
      expect(DailyChallengeEngine.claim(s, s.challenges.first.id), isNull);
    });

    test('max-type challenges keep the best value, others accumulate', () {
      var s = DailyChallengesState(
        day: 1,
        challenges: const [
          Challenge(
            id: 'a',
            kind: ChallengeKind.scorePoints,
            description: '',
            target: 500,
            reward: 1,
          ),
          Challenge(
            id: 'b',
            kind: ChallengeKind.clearLines,
            description: '',
            target: 10,
            reward: 1,
          ),
        ],
      );
      s = DailyChallengeEngine.record(s, ChallengeKind.scorePoints, 200);
      s = DailyChallengeEngine.record(s, ChallengeKind.scorePoints, 150);
      s = DailyChallengeEngine.record(s, ChallengeKind.clearLines, 3);
      s = DailyChallengeEngine.record(s, ChallengeKind.clearLines, 4);
      expect(s.challenges[0].progress, 200);
      expect(s.challenges[1].progress, 7);
    });

    test('json round trip', () {
      final s = DailyChallengeEngine.ensureToday(
        const DailyChallengesState(),
        77,
      );
      final r = DailyChallengesState.fromJson(s.toJson());
      expect(r.day, 77);
      expect(r.challenges.length, 3);
      expect(r.challenges.first.description, s.challenges.first.description);
    });
  });

  group('AchievementEngine', () {
    test('unlocks when thresholds are reached, once', () {
      const stats = LifetimeStats(gamesPlayed: 1, bestScore: 1200);
      final first = AchievementEngine.newlyUnlocked(stats, {});
      expect(first.map((a) => a.id), containsAll(['first_game', 'score_1000']));
      final again = AchievementEngine.newlyUnlocked(
        stats,
        first.map((a) => a.id).toSet(),
      );
      expect(again, isEmpty);
    });

    test('nothing unlocked for zero stats', () {
      expect(
        AchievementEngine.newlyUnlocked(const LifetimeStats(), {}),
        isEmpty,
      );
    });

    test('achievement ids are unique', () {
      final ids = AchievementEngine.all.map((a) => a.id);
      expect(ids.toSet().length, ids.length);
    });
  });

  group('dayIndexOf', () {
    test('uses the local calendar date', () {
      expect(
        dayIndexOf(DateTime(2026, 1, 2, 23, 59)) -
            dayIndexOf(DateTime(2026, 1, 1, 0, 1)),
        1,
      );
    });
  });
}
