import 'package:flutter_game_template/core/retention/daily_challenges.dart';
import 'package:flutter_game_template/game/rules/game_challenges.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _of(DailyChallengesState s, ChallengeKind k) =>
    s.challenges.firstWhere((c) => c.kind == k);

void main() {
  final fresh = GameChallengeEngine.ensureToday(
    const DailyChallengesState(),
    100,
    1,
  );

  test('three game-based challenges, same for the same day', () {
    expect(fresh.challenges.map((c) => c.kind), [
      ChallengeKind.scorePoints,
      ChallengeKind.playDifferentGames,
      ChallengeKind.streakDays,
    ]);
    final again = GameChallengeEngine.ensureToday(
      const DailyChallengesState(),
      100,
      1,
    );
    expect(again.toJson(), fresh.toJson());
  });

  test('a score counts in any game, best single game wins', () {
    var s = GameChallengeEngine.recordPlay(fresh, 'sudoku', 150);
    s = GameChallengeEngine.recordPlay(s, 'merge', 90);
    expect(_of(s, ChallengeKind.scorePoints).progress, 150);
    s = GameChallengeEngine.recordPlay(s, 'blockfall', 5000);
    expect(_of(s, ChallengeKind.scorePoints).completed, isTrue);
  });

  test('different games count once each', () {
    var s = GameChallengeEngine.recordPlay(fresh, 'sudoku', 1);
    s = GameChallengeEngine.recordPlay(s, 'sudoku', 1);
    expect(_of(s, ChallengeKind.playDifferentGames).progress, 1);
    s = GameChallengeEngine.recordPlay(s, 'merge', 1);
    s = GameChallengeEngine.recordPlay(s, 'snake', 1);
    s = GameChallengeEngine.recordPlay(s, 'stack', 1);
    final c = _of(s, ChallengeKind.playDifferentGames);
    expect(c.progress, 4);
    expect(c.completed, isTrue);
  });

  test('streak goal is the next milestone and follows the streak', () {
    expect(_of(fresh, ChallengeKind.streakDays).target, 3);
    expect(_of(fresh, ChallengeKind.streakDays).progress, 1);
    final s = GameChallengeEngine.ensureToday(fresh, 100, 3);
    expect(_of(s, ChallengeKind.streakDays).progress, 3);
    expect(_of(s, ChallengeKind.streakDays).claimable, isTrue);
    final far = GameChallengeEngine.ensureToday(
      const DailyChallengesState(),
      7,
      7,
    );
    expect(_of(far, ChallengeKind.streakDays).target, 14);
    final beyond = GameChallengeEngine.ensureToday(
      const DailyChallengesState(),
      7,
      40,
    );
    expect(_of(beyond, ChallengeKind.streakDays).target, greaterThan(40));
  });

  test('a new day makes a new set; claimed challenges stay claimed', () {
    final done = DailyChallengeEngine.claim(
      GameChallengeEngine.recordPlay(fresh, 'sudoku', 5000),
      _of(fresh, ChallengeKind.scorePoints).id,
    )!;
    final same = GameChallengeEngine.ensureToday(done.state, 100, 1);
    expect(_of(same, ChallengeKind.scorePoints).claimed, isTrue);
    final next = GameChallengeEngine.ensureToday(done.state, 101, 1);
    expect(_of(next, ChallengeKind.scorePoints).claimed, isFalse);
  });

  test('state survives a JSON round trip, including the seen games', () {
    final s = GameChallengeEngine.recordPlay(fresh, 'sudoku', 10);
    final back = DailyChallengesState.fromJson(s.toJson());
    expect(_of(back, ChallengeKind.playDifferentGames).seen, ['sudoku']);
  });
}
