import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_sudoku/sudoku.dart';

void main() {
  for (final level in SudokuLevel.values) {
    test('${level.label}: one solution and the clue count', () {
      final p = generateSudoku(level, Random(level.index + 7));
      expect(p.clues, greaterThanOrEqualTo(level.clues));
      expect(p.clues, lessThanOrEqualTo(level.clues + 3));
      final sol = <int>[];
      expect(countSolutions(p.puzzle, limit: 2, solutionOut: sol), 1);
      expect(sol, p.solution);
      for (var i = 0; i < 81; i++) {
        if (p.puzzle[i] != 0) expect(p.puzzle[i], p.solution[i]);
      }
    });
  }

  test('same seed gives the same puzzle', () {
    final a = generateSudoku(SudokuLevel.easy, Random(3));
    final b = generateSudoku(SudokuLevel.easy, Random(3));
    expect(a.puzzle, b.puzzle);
  });

  test(
    'solver rejects a clash and finds several solutions of an empty grid',
    () {
      final g = List<int>.filled(81, 0)
        ..[0] = 5
        ..[1] = 5;
      expect(countSolutions(g), 0);
      expect(countSolutions(List<int>.filled(81, 0), limit: 2), 2);
    },
  );

  SudokuGame game() => SudokuGame(generateSudoku(SudokuLevel.easy, Random(1)));
  int firstEmpty(SudokuGame g) => g.values.indexOf(0);

  test('right and wrong digits, mistakes, undo, erase and givens', () {
    final g = game();
    final i = firstEmpty(g);
    final right = g.puzzle.solution[i];
    final wrong = right == 9 ? 1 : right + 1;
    expect(g.enter(i, wrong), isTrue);
    expect(g.isWrong(i), isTrue);
    expect(g.mistakes, 1);
    expect(g.undo(), isTrue);
    expect(g.values[i], 0);
    g.enter(i, right);
    expect(g.isWrong(i), isFalse);
    expect(g.erase(i), isTrue);
    expect(g.values[i], 0);
    final given = g.puzzle.puzzle.indexWhere((v) => v != 0);
    expect(g.enter(given, 1), isFalse);
  });

  test('pencil notes toggle, and a right digit clears notes in its peers', () {
    final g = game();
    final i = firstEmpty(g);
    final d = g.puzzle.solution[i];
    g.enter(i, d, pencil: true);
    expect(g.hasNote(i, d), isTrue);
    g.enter(i, d, pencil: true);
    expect(g.hasNote(i, d), isFalse);
    final peer = List.generate(
      81,
      (k) => k,
    ).firstWhere((k) => k != i && g.values[k] == 0 && k ~/ 9 == i ~/ 9);
    g.enter(peer, d, pencil: true);
    g.enter(i, d);
    expect(g.hasNote(peer, d), isFalse);
  });

  test('hints are limited per puzzle and fill the right digit', () {
    final g = game();
    for (var n = 0; n < 3; n++) {
      final c = g.hint(null);
      expect(c, isNotNull);
      expect(g.values[c!], g.puzzle.solution[c]);
    }
    expect(g.hintsLeft, 0);
    expect(g.hint(null), isNull);
  });

  test('solving ends the game, and help lowers the score', () {
    final g = game();
    g.hint(null);
    for (var i = 0; i < 81; i++) {
      g.values[i] = g.puzzle.solution[i];
    }
    expect(g.solved, isTrue);
    expect(g.score, 200);
    expect(g.enter(0, 1), isFalse);
  });

  test('save and restore keeps the whole game', () {
    final g = game();
    g.enter(firstEmpty(g), 1, pencil: true);
    g.hint(null);
    final r = SudokuGame.fromJson(g.toJson())!;
    expect(r.values, g.values);
    expect(r.notes, g.notes);
    expect(r.hintsUsed, 1);
    expect(SudokuGame.fromJson({'level': 'nope'}), isNull);
    expect(SudokuGame.fromJson(null), isNull);
  });

  group('stepped hint', () {
    // A solved grid (a shifted pattern) used as the solution.
    final solution = [
      for (var r = 0; r < 9; r++)
        for (var c = 0; c < 9; c++) (r * 3 + r ~/ 3 + c) % 9 + 1,
    ];
    SudokuGame gameWith(List<int> puzzle) =>
        SudokuGame(SudokuPuzzle(SudokuLevel.easy, puzzle, solution));

    test('a naked single: only one digit fits the square', () {
      final puzzle = List<int>.of(solution)..[40] = 0;
      final step = findSudokuHint(gameWith(puzzle), null)!;
      expect(step.technique, SudokuTechnique.nakedSingle);
      expect(step.cell, 40);
      expect(step.digit, solution[40]);
      expect(step.area, [40]);
      expect(step.where, contains('row 5, column 5'));
    });

    test('a hidden single is explained in words', () {
      // Cells 0 and 1 are empty in row 0 with the same two candidates except that the digit
      // solution[0] cannot go into cell 1 because it is already in column 1 (an extra given).
      // Build it from a real puzzle: find any hidden single on a generated puzzle.
      var found = false;
      for (var seed = 1; seed < 40 && !found; seed++) {
        final g = SudokuGame(generateSudoku(SudokuLevel.expert, Random(seed)));
        final step = findSudokuHint(g, null)!;
        if (step.technique == SudokuTechnique.hiddenSingle) {
          found = true;
          expect(
            step.reason,
            matches(
              RegExp(r'^Only one place for \d in this (row|column|box)\.$'),
            ),
          );
          expect(step.digit, g.puzzle.solution[step.cell]);
        }
      }
      expect(found, isTrue);
    });

    test('falls back to the reveal when no single exists', () {
      final g = SudokuGame(
        SudokuPuzzle(SudokuLevel.easy, List<int>.filled(81, 0), solution),
      );
      final step = findSudokuHint(g, null)!;
      expect(step.technique, SudokuTechnique.reveal);
      expect(step.digit, solution[step.cell]);
    });

    test('wrong entries are ignored, a solved puzzle has no hint', () {
      final puzzle = List<int>.of(solution)..[40] = 0;
      final g = gameWith(puzzle)..enter(40, solution[40] % 9 + 1);
      expect(findSudokuHint(g, null)!.cell, 40);
      g.enter(40, solution[40]);
      expect(findSudokuHint(g, null), isNull);
    });

    test('the digit step costs one hint and 100 points', () {
      final puzzle = List<int>.of(solution)..[40] = 0;
      final g = gameWith(puzzle);
      expect(g.fillHint(40), isTrue);
      expect(g.hintsUsed, 1);
      expect(g.solved, isTrue);
      expect(g.score, 300 - 100);
    });
  });
}
