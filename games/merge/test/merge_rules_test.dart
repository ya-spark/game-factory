import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_merge/merge.dart';

List<int> board(List<List<int>> rows) => [for (final r in rows) ...r];

void main() {
  test('a new game has two plants of stage 1 or 2', () {
    final g = MergeGame(Random(1));
    final plants = g.cells.where((v) => v > 0).toList();
    expect(plants.length, 2);
    expect(plants.every((v) => v == 1 || v == 2), isTrue);
  });

  test('slide and merge once per move: 1 1 1 1 left gives 2 2', () {
    final g = MergeGame(
      Random(1),
      cells: board([
        [1, 1, 1, 1],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
    );
    expect(g.swipe(MergeDir.left), isTrue);
    expect(g.cells.sublist(0, 2), [2, 2]);
    expect(g.score, 8); // two merges into stage 2: 4 + 4
  });

  test('a plant merges only once: 2 1 1 0 left gives 2 2', () {
    final g = MergeGame(
      Random(1),
      cells: board([
        [2, 1, 1, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
    );
    g.swipe(MergeDir.left);
    expect(g.cells.sublist(0, 2), [2, 2]);
  });

  test('all four directions', () {
    List<int> start() => board([
      [0, 0, 0, 0],
      [0, 1, 1, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    var g = MergeGame(Random(2), cells: start());
    g.swipe(MergeDir.right);
    expect(g.cells[7], 2);
    g = MergeGame(Random(2), cells: start());
    g.swipe(MergeDir.left);
    expect(g.cells[4], 2);
    g = MergeGame(
      Random(2),
      cells: board([
        [0, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 0, 0],
      ]),
    );
    g.swipe(MergeDir.up);
    expect(g.cells[1], 2);
    g = MergeGame(
      Random(2),
      cells: board([
        [0, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 0, 0],
      ]),
    );
    g.swipe(MergeDir.down);
    expect(g.cells[13], 2);
  });

  test('a swipe that moves nothing is refused and spawns nothing', () {
    final g = MergeGame(
      Random(3),
      cells: board([
        [1, 2, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
    );
    expect(g.swipe(MergeDir.left), isFalse);
    expect(g.moves, 0);
    expect(g.cells.where((v) => v > 0).length, 2);
    expect(g.canUndo, isFalse);
  });

  test('undo goes back one move, once', () {
    final g = MergeGame(Random(4));
    final start = List.of(g.cells);
    final dir = [
      for (final d in MergeDir.values)
        if (MergeGame(Random(4)).swipe(d)) d,
    ].first;
    expect(g.swipe(dir), isTrue);
    expect(g.canUndo, isTrue);
    expect(g.undo(), isTrue);
    expect(g.cells, start);
    expect(g.score, 0);
    expect(g.moves, 0);
    expect(g.canUndo, isFalse);
    expect(g.undo(), isFalse);
  });

  // Stages 3 and 4 in a checker: a spawn (stage 1 or 2) can never match a neighbour.
  List<int> nearlyFull() => board([
    [3, 4, 3, 4],
    [4, 3, 4, 3],
    [3, 4, 3, 4],
    [4, 0, 3, 4],
  ]);

  test('classic: game over when no move is left', () {
    final h = MergeGame(Random(5), cells: nearlyFull());
    expect(h.swipe(MergeDir.left), isTrue);
    expect(h.full, isTrue);
    expect(h.hasMove, isFalse);
    expect(h.over, isTrue);
    expect(h.swipe(MergeDir.up), isFalse);
    expect(h.undo(), isTrue); // the last move can still be taken back
    expect(h.over, isFalse);
  });

  test('relaxed: no game over; the smallest plants are cleared', () {
    final h = MergeGame(Random(5), relaxed: true, cells: nearlyFull());
    expect(h.swipe(MergeDir.left), isTrue);
    expect(h.over, isFalse);
    expect(h.clears, 1);
    expect(h.cells.every((v) => v == 0 || v >= 3), isTrue);
    expect(h.hasMove, isTrue);
    expect(MergeDir.values.any(h.swipe), isTrue);
  });

  test('the top stage does not merge further', () {
    final g = MergeGame(
      Random(6),
      cells: board([
        [maxStage, maxStage, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
    );
    expect(g.swipe(MergeDir.left), isFalse);
  });

  test('points double with each stage and there is a name for each', () {
    expect(pointsForStage(1), 2);
    expect(pointsForStage(3), 8);
    expect(stageNames.length, maxStage);
  });

  test('the same seed plays the same game', () {
    List<int> run() {
      final g = MergeGame(Random(7));
      for (var i = 0; i < 30; i++) {
        for (final d in MergeDir.values) {
          if (g.swipe(d)) break;
        }
      }
      return [...g.cells, g.score];
    }

    expect(run(), run());
  });
}
