import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const older = MiniGameLevel.older();
  const younger = MiniGameLevel.younger();

  test('turns alternate and a right answer pulls toward the player', () {
    final run = FamilyTugRun(older);
    expect(run.turn, 0);
    run.answer(correct: true);
    expect(run.position, 1);
    expect(run.turn, 1);
    run.answer(correct: true);
    expect(run.position, 0);
    expect(run.turn, 0);
  });

  test('older rules: a wrong answer pulls one step back', () {
    final run = FamilyTugRun(older);
    run.answer(correct: false); // player 0 wrong: toward player 1
    expect(run.position, -1);
    run.answer(correct: false); // player 1 wrong: toward player 0
    expect(run.position, 0);
  });

  test('gentler rules: a wrong answer never pulls the rope back', () {
    final run = FamilyTugRun(younger);
    run.answer(correct: false);
    expect(run.position, 0);
  });

  test('round ends at the rope end; first to two rounds takes the game', () {
    final run = FamilyTugRun(younger); // reach 3
    // Player 0 right, player 1 wrong (no pull back): only player 0 moves.
    FamilyTugEnd end = FamilyTugEnd.none;
    for (var i = 0; i < 5; i++) {
      end = run.answer(correct: true); // p0
      if (end != FamilyTugEnd.none) break;
      run.answer(correct: false); // p1
    }
    expect(end, FamilyTugEnd.round);
    expect(run.lastRoundWinner, 0);
    expect(run.roundsOf(0), 1);
    expect(run.position, 0);
    expect(run.isOver, isFalse);
    expect(run.turn, 1);
    // Next round: player 1 pulls three times, player 0 misses.
    for (var i = 0; i < 3; i++) {
      end = run.answer(correct: true); // p1
      if (end == FamilyTugEnd.round) break;
      run.answer(correct: false);
    }
    expect(run.lastRoundWinner, 1);
    expect(run.roundsOf(1), 1);
    expect(run.winner, isNull);
    // Third round: player 0 again.
    while (!run.isOver) {
      run.answer(correct: run.turn == 0);
    }
    expect(run.winner, 0);
    expect(run.roundsOf(0), 2);
    expect(() => run.answer(correct: true), throwsStateError);
  });

  test(
    'fair settings: if either would be younger, both get the gentler rules',
    () {
      expect(familyTugLevel([younger, older]).older, isFalse);
      expect(familyTugLevel([older, older]).older, isTrue);
      expect(familyTugLevel([older, older]).harder, isFalse);
      expect(familyTugLevel([older, older], harder: true).harder, isTrue);
      final run = FamilyTugRun(familyTugLevel([older, younger]));
      expect(run.settings.pullsBack, isFalse);
      expect(run.settings.secondsPerQuestion, 0);
    },
  );

  test('eligibility: fewer than two eligible profiles hides the button', () {
    expect(familyTugAvailable([3, 4], minYear: 3), isTrue);
    expect(familyTugAvailable([3, 2], minYear: 3), isFalse);
    expect(familyTugAvailable([3, null], minYear: 3), isFalse);
    expect(familyTugAvailable([3], minYear: 3), isFalse);
    expect(familyTugEligibleYear(12, minYear: 3, maxYear: 12), isTrue);
  });
}
