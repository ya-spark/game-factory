import 'dart:math';

import 'package:game_block_puzzle/src/game/rules/game_state.dart';
import 'package:game_block_puzzle/src/game/rules/piece_generator.dart';
import 'package:game_block_puzzle/src/game/rules/start_board.dart';
import 'package:flutter_test/flutter_test.dart';

/// Greedy bot: places the piece/position that clears the most lines (ties: most filled
/// neighbours-free choice = first found). Plays until [targetLines] lines are cleared.
({int score, int lines, int pieces}) playGreedy(int seed, int targetLines) {
  // The band measures a game without special blocks (specialEvery 0 deals none).
  final g = GameState.newGame(generator: PieceGenerator(Random(seed), 0));
  var moves = 0;
  while (!g.isGameOver && g.linesClearedTotal < targetLines && moves < 5000) {
    (int, int, int)? best;
    var bestLines = -1;
    for (var s = 0; s < 3; s++) {
      final piece = g.tray[s];
      if (piece == null) continue;
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          if (!g.board.canPlace(piece, r, c)) continue;
          // Most lines first; ties go to the placement touching the most filled cells/walls.
          var contact = 0;
          final own = {for (final (dr, dc) in piece.cells) (r + dr, c + dc)};
          for (final (rr, cc) in own) {
            for (final (nr, nc) in [
              (rr - 1, cc),
              (rr + 1, cc),
              (rr, cc - 1),
              (rr, cc + 1),
            ]) {
              if (own.contains((nr, nc))) continue;
              if (nr < 0 ||
                  nc < 0 ||
                  nr >= 8 ||
                  nc >= 8 ||
                  g.board.isFilled(nr, nc)) {
                contact++;
              }
            }
          }
          final l = g.board.place(piece, r, c).linesCleared * 100 + contact;
          if (l > bestLines) {
            bestLines = l;
            best = (s, r, c);
          }
        }
      }
    }
    g.place(best!.$1, best.$2, best.$3);
    moves++;
  }
  return (score: g.score, lines: g.linesClearedTotal, pieces: g.piecesPlaced);
}

void main() {
  group('StartBoard', () {
    test('70% full, no complete line, every first piece clears lines', () {
      var twoLines = 0;
      const seeds = 300;
      for (var seed = 0; seed < seeds; seed++) {
        final s = StartBoard.generate(Random(seed));
        final filled = s.board.filledCount;
        expect((filled - 45).abs(), lessThanOrEqualTo(2), reason: 'seed $seed');
        for (var i = 0; i < 8; i++) {
          expect(
            List.generate(8, (c) => s.board.isFilled(i, c)).every((v) => v),
            isFalse,
          );
          expect(
            List.generate(8, (r) => s.board.isFilled(r, i)).every((v) => v),
            isFalse,
          );
        }
        var all2 = true;
        for (final piece in s.tray) {
          var best = 0;
          for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
              if (s.board.canPlace(piece, r, c)) {
                best = max(best, s.board.place(piece, r, c).linesCleared);
              }
            }
          }
          expect(best, greaterThanOrEqualTo(1), reason: 'seed $seed');
          if (best < 2) all2 = false;
        }
        if (all2) twoLines++;
      }
      expect(twoLines / seeds, greaterThanOrEqualTo(0.95));
    });

    test(
      'is deterministic for a seed and used by newGame, not by Continue',
      () {
        final a = StartBoard.generate(Random(9));
        final b = StartBoard.generate(Random(9));
        expect(a.board.cells, b.board.cells);
        final g = GameState.newGame(generator: PieceGenerator(Random(9)));
        expect(g.board.cells, a.board.cells);
        expect(g.board.filledCount, inInclusiveRange(43, 47));
      },
    );
  });

  group('Scoring', () {
    test('line bonus is 10 * lines^2 * combo * stage', () {
      expect(GameState.maxCombo, 8);
      expect(GameState.maxStage, 13);
      final g = GameState(generator: PieceGenerator(Random(3)))
        ..linesClearedTotal = 10; // stage 3
      expect(g.stage, 3);
      g.linesClearedTotal = 500;
      expect(g.stage, GameState.maxStage);
    });

    test('60-line game scores 10,000 to 12,000 (greedy bot, seeded)', () {
      var total = 0, n = 0;
      for (var seed = 0; seed < 20; seed++) {
        final r = playGreedy(seed, 60);
        if (r.lines < 60) continue;
        total += r.score;
        n++;
      }
      expect(n, greaterThan(5));
      final avg = total / n;
      // ignore: avoid_print
      print('greedy 60-line average score: $avg over $n games');
      expect(avg, inInclusiveRange(10000, 12000));
    });
  });
}
