import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_tug_of_war/src/rules/tug_head_to_head_rules.dart';

HeadToHeadRun older({bool harder = false}) =>
    HeadToHeadRun(MiniGameLevel.older(harder: harder));
HeadToHeadRun younger() => HeadToHeadRun(const MiniGameLevel.younger());

void main() {
  test(
    'the first right answer pulls toward that player and ends the question',
    () {
      final r = older();
      expect(r.press(1, correct: true), HeadPress.pulled);
      expect(r.position, 1);
      expect(r.questionWinner, 1);
      expect(r.questionOver, isTrue);
      r.nextQuestion();
      expect(r.press(2, correct: true), HeadPress.pulled);
      expect(r.position, 0);
      expect(r.questionWinner, 2);
    },
  );

  test('after the question ended no press counts', () {
    final r = older();
    r.press(1, correct: true);
    expect(r.press(2, correct: true), HeadPress.ignored);
    expect(r.position, 1);
  });

  test('a wrong press locks only that player, the other may still answer', () {
    final r = older();
    expect(r.press(1, correct: false), HeadPress.locked);
    expect(r.isLocked(1), isTrue);
    expect(r.isLocked(2), isFalse);
    expect(r.questionOver, isFalse);
    expect(r.press(1, correct: true), HeadPress.ignored); // locked out
    expect(r.press(2, correct: true), HeadPress.pulled);
    expect(r.questionWinner, 2);
  });

  test('older: a wrong press pulls one step toward the opponent', () {
    final r = older();
    r.press(1, correct: false);
    expect(r.position, -1);
    r.nextQuestion();
    r.press(2, correct: false);
    expect(r.position, 0);
  });

  test(
    'younger: a wrong press never pulls back, it only locks the player out',
    () {
      final r = younger();
      r.press(1, correct: false);
      expect(r.position, 0);
      expect(r.isLocked(1), isTrue);
    },
  );

  test('both locked out ends the question with no winner', () {
    final r = younger();
    r.press(1, correct: false);
    expect(r.questionOver, isFalse);
    r.press(2, correct: false);
    expect(r.questionOver, isTrue);
    expect(r.questionWinner, isNull);
  });

  test('time up ends the question with no pull', () {
    final r = older();
    r.timeUp();
    expect(r.questionOver, isTrue);
    expect(r.position, 0);
    expect(r.press(1, correct: true), HeadPress.ignored);
  });

  test('the next question lifts the lock-outs', () {
    final r = older();
    r.press(1, correct: false);
    r.nextQuestion();
    expect(r.isLocked(1), isFalse);
    expect(r.questionOver, isFalse);
    expect(r.press(1, correct: true), HeadPress.pulled);
  });

  test('reaching the end of the rope wins the round and the rope returns to the middle', () {
    final r = older(); // reach 4
    for (var i = 0; i < 4; i++) {
      r.press(1, correct: true);
      if (i < 3) {
        expect(r.roundWinner, isNull);
        r.nextQuestion();
      }
    }
    expect(r.roundWinner, 1);
    expect(r.roundsOf(1), 1);
    expect(r.roundsOf(2), 0);
    expect(r.position, 0);
    expect(r.winner, isNull);
  });

  test('two rounds win the game and nothing counts after that', () {
    final r = younger(); // reach 3
    void round(int p) {
      for (var i = 0; i < 3; i++) {
        r.press(p, correct: true);
        r.nextQuestion();
      }
    }

    round(2);
    expect(r.winner, isNull);
    round(2);
    expect(r.winner, 2);
    expect(r.isOver, isTrue);
    expect(r.press(1, correct: true), HeadPress.ignored);
  });

  test('a wrong press can hand the opponent a round (older)', () {
    final r = older();
    for (var i = 0; i < 4; i++) {
      r.nextQuestion();
      r.press(1, correct: false); // pulls toward player 2
    }
    expect(r.roundsOf(2), 1);
    expect(r.roundWinner, 2);
  });

  test('the harder level has a longer rope and 4 options', () {
    expect(older(harder: true).settings.reach, 5);
    expect(older(harder: true).settings.options, 4);
    expect(older().settings.options, 3);
    expect(younger().settings.options, 2);
  });

  test('when the questions run out: rounds, then the rope, then a draw', () {
    final a = older();
    expect(a.decideWhenOut(), 0);
    a.press(2, correct: true);
    expect(a.decideWhenOut(), 2); // the rope leans to player 2
    final b = younger();
    for (var i = 0; i < 3; i++) {
      b.press(1, correct: true);
      b.nextQuestion();
    }
    b.press(2, correct: true);
    b.nextQuestion();
    b.press(2, correct: true);
    b.nextQuestion();
    expect(b.roundsOf(1), 1);
    expect(b.decideWhenOut(), 1); // a round more beats the rope
  });
}
