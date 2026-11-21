import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_ball_sort/ball_sort.dart';

BallSortState st(List<List<int>> t) => BallSortState(t);

void main() {
  test('colours grow with the level up to ten', () {
    expect(coloursForLevel(1), 3);
    expect(coloursForLevel(2), 3);
    expect(coloursForLevel(3), 4);
    expect(coloursForLevel(14), 9);
    expect(coloursForLevel(15), 10);
    expect(coloursForLevel(99), 10);
    expect(seedForLevel(1), isNot(seedForLevel(2)));
  });

  test('a move carries the top run onto the same colour or an empty tube', () {
    final s = st([
      [0, 1, 1],
      [2, 1],
      [],
      [0, 0, 0, 0],
    ]);
    expect(s.movable(0, 1), 2); // the run of two 1s fits on a 1
    expect(s.movable(1, 0), 1); // one 1 on a 1
    expect(s.movable(0, 3), 0); // full tube
    expect(s.movable(0, 0), 0);
    expect(s.move(0, 1), 2);
    expect(s.tubes[1], [2, 1, 1, 1]);
    expect(s.tubes[0], [0]);
    expect(s.moves, 1);
    expect(s.move(1, 0), 0); // 1 on 0: wrong colour
    expect(s.move(0, 2), 1); // into the empty tube
  });

  test('the run is cut to the room left in the target', () {
    final s = st([
      [5, 1, 1, 1],
      [2, 1],
      [],
    ]);
    expect(s.movable(0, 1), 2);
    expect(s.move(0, 1), 2);
    expect(s.tubes[0], [5, 1]);
  });

  test('solved: every tube empty or full of one colour', () {
    expect(
      st([
        [0, 0, 0, 0],
        [1, 1, 1, 1],
        [],
      ]).solved,
      isTrue,
    );
    expect(
      st([
        [0, 0, 0],
        [1, 1, 1, 1],
        [0],
      ]).solved,
      isFalse,
    );
  });

  test('add-a-tube works once per level', () {
    final g = BallSortGame(
      st([
        [0, 1, 0, 1],
        [1, 0, 1, 0],
        [],
      ]),
    );
    expect(g.addTube(), isTrue);
    expect(g.state.tubes.length, 4);
    expect(g.addTube(), isFalse);
    expect(g.undo(), isTrue);
    expect(g.state.tubes.length, 3);
    expect(g.state.added, isFalse);
  });

  test('undo restores the tubes; the move counter keeps counting', () {
    final g = BallSortGame(
      st([
        [0, 1],
        [1, 0],
        [],
      ]),
    );
    expect(g.move(0, 2), 1);
    expect(g.move(2, 1), 0);
    expect(g.undo(), isTrue);
    expect(g.state.tubes[0], [0, 1]);
    expect(g.state.moves, 1);
    expect(g.helped, isTrue);
    expect(g.undo(), isFalse);
  });

  test('score: clean play earns the bonus, help does not', () {
    final clean = BallSortGame(
      st([
        [0, 0, 0, 0],
        [1, 1, 1, 1],
        [],
      ]),
    );
    expect(clean.score, 200 + 100 + 100);
    clean.helped = true;
    expect(clean.score, 300);
  });

  test('the solver proves a solvable position and rejects a stuck one', () {
    expect(
      solveBallSort(
        st([
          [0, 1, 0, 1],
          [1, 0, 1, 0],
          [],
          [],
        ]),
      ),
      isTrue,
    );
    // Full tubes and no empty tube: nothing can move.
    expect(
      solveBallSort(
        st([
          [0, 1, 0, 1],
          [1, 0, 1, 0],
        ]),
      ),
      isFalse,
    );
  });

  test('levels: right size, solvable, repeatable, and not already sorted', () {
    for (final level in [1, 3, 8, 15, 20]) {
      final a = generateBallSort(level, Random(seedForLevel(level)));
      final b = generateBallSort(level, Random(seedForLevel(level)));
      final colours = coloursForLevel(level);
      expect(a.proven, isTrue, reason: 'level $level');
      expect(a.state.tubes.length, colours + 2);
      expect(a.state.solved, isFalse);
      expect(a.state.key, b.state.key);
      final counts = <int, int>{};
      for (final t in a.state.tubes) {
        for (final ball in t) {
          counts[ball] = (counts[ball] ?? 0) + 1;
        }
      }
      expect(counts.length, colours);
      expect(counts.values.every((n) => n == tubeCapacity), isTrue);
      expect(solveBallSort(a.state), isTrue);
    }
  });
}
