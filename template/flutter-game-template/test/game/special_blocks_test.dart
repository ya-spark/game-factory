import 'dart:math';

import 'package:flutter_game_template/game/rules/board.dart';
import 'package:flutter_game_template/game/rules/game_state.dart';
import 'package:flutter_game_template/game/rules/piece.dart';
import 'package:flutter_game_template/game/rules/piece_generator.dart';
import 'package:flutter_test/flutter_test.dart';

const dot = Piece('dot_0', [(0, 0)], 0);
Piece dotOf(CellKind k) => dot.withKind(0, k);

/// Row 3 full except column 7, and the special cell at (3, [col]); a dot at (3,7) clears it.
GameState rowState(CellKind kind, {int col = 0, List<String>? extra}) {
  final rows = [
    for (var r = 0; r < 8; r++)
      if (r == 3) '1111111.' else (extra?[r] ?? '........'),
  ];
  final board = Board.fromRows(rows, kinds: {(3, col): kind});
  return GameState(
    board: board,
    generator: PieceGenerator(Random(1), 0),
    tray: [dot, dot, dot],
  );
}

void main() {
  group('dealing', () {
    test('every 4th tray has exactly one special cell on a 2+ cell piece', () {
      final gen = PieceGenerator(Random(7));
      final board = Board.empty();
      for (var n = 1; n <= 12; n++) {
        final tray = gen.dealTray(board);
        final specials = [
          for (final p in tray)
            for (var i = 0; i < p.size; i++)
              if (p.kindAt(i) != CellKind.normal) p,
        ];
        if (n % 4 == 0) {
          expect(specials.length, 1, reason: 'tray $n');
          expect(specials.single.size, greaterThanOrEqualTo(2));
        } else {
          expect(specials, isEmpty, reason: 'tray $n');
        }
      }
    });

    test('is deterministic for a seed', () {
      List<String> run() {
        final gen = PieceGenerator(Random(11));
        return [
          for (var n = 0; n < 8; n++)
            for (final p in gen.dealTray(Board.empty())) '${p.id}${p.kinds}',
        ];
      }

      expect(run(), run());
    });

    test('the first tray of a game has no special cells', () {
      for (var seed = 0; seed < 20; seed++) {
        final g = GameState(generator: PieceGenerator(Random(seed)));
        for (var r = 0; r < 8; r++) {
          for (var c = 0; c < 8; c++) {
            expect(g.board.kindAt(r, c), CellKind.normal);
          }
        }
        expect(g.tray.whereType<Piece>().any((p) => p.hasSpecial), isFalse);
      }
    });

    test('a kind travels with the piece cell onto the board', () {
      final p = const Piece('bar2_0', [
        (0, 0),
        (0, 1),
      ], 0).withKind(1, CellKind.gem);
      final res = Board.empty().place(p, 2, 2);
      expect(res.board.kindAt(2, 3), CellKind.gem);
      expect(res.board.kindAt(2, 2), CellKind.normal);
    });
  });

  group('effects', () {
    test('blast block (boom) empties the 3x3 area around it', () {
      // Rows 2..4 and the whole board filled except (3,7): placing it clears row 3 and
      // every column that completes. Keep it simple: use a half-filled board.
      final rows = [
        '........',
        '.1111...',
        '.1111...',
        '1111111.',
        '.1111...',
        '.1111...',
        '........',
        '........',
      ];
      final board = Board.fromRows(rows, kinds: {(3, 3): CellKind.boom});
      final res = board.place(dot, 3, 7);
      expect(res.clearedRows, [3]);
      expect(res.booms, 1);
      // 3x3 around (3,3): rows 2..4, cols 2..4; row 3 is already cleared.
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          final inBlast = r >= 2 && r <= 4 && c >= 2 && c <= 4;
          final wasFilled = rows[r][c] == '1';
          if (r == 3) {
            expect(res.board.isFilled(r, c), isFalse);
          } else if (inBlast) {
            expect(res.board.isFilled(r, c), isFalse, reason: '$r,$c');
          } else {
            expect(res.board.isFilled(r, c), wasFilled, reason: '$r,$c');
          }
        }
      }
      // Extra emptied cells: 6 (3 above, 3 below row 3).
      expect(res.blastCells.length, 6);
    });

    test('blast block at the board edge is clipped, not an error', () {
      final rows = [
        '11......',
        '11......',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ];
      // Make row 0 complete by placing a dot: fill 0..6 and drop at (0,7).
      rows[0] = '1111111.';
      final board = Board.fromRows(rows, kinds: {(0, 0): CellKind.boom});
      final res = board.place(dot, 0, 7);
      expect(res.clearedRows, [0]);
      // Blast area (rows 0..1, cols 0..1): row 0 is cleared, row 1 cols 0,1 are extra.
      expect(res.blastCells.toSet(), {(1, 0), (1, 1)});
      expect(res.board.isFilled(1, 0), isFalse);
      expect(res.board.isFilled(1, 1), isFalse);
      expect(res.board.isFilled(1, 2), isFalse);
    });

    test('a blast block scores 5 per extra emptied cell', () {
      final rows = [
        '........',
        '........',
        '.1......',
        '1111111.',
        '........',
        '........',
        '........',
        '........',
      ];
      final plain = GameState(
        board: Board.fromRows(rows),
        generator: PieceGenerator(Random(1), 0),
        tray: [dot, dot, dot],
      );
      final boom = GameState(
        board: Board.fromRows(rows, kinds: {(3, 1): CellKind.boom}),
        generator: PieceGenerator(Random(1), 0),
        tray: [dot, dot, dot],
      );
      final a = plain.place(0, 3, 7)!;
      final b = boom.place(0, 3, 7)!;
      expect(b.scoreGained - a.scoreGained, 5); // (1,1) is the only extra cell
    });

    test('a gem pays 50 points (inside the line base) and 1 coin', () {
      final plain = rowState(CellKind.normal);
      final gem = rowState(CellKind.gem);
      final a = plain.place(0, 3, 7)!;
      final b = gem.place(0, 3, 7)!;
      // combo 1: +50 * 1
      expect(b.scoreGained - a.scoreGained, 50);
      expect(a.gems, 0);
      expect(b.gems, 1);
    });

    test('a gem inside a blast still pays', () {
      final rows = [
        '........',
        '........',
        '.1......',
        '1111111.',
        '........',
        '........',
        '........',
        '........',
      ];
      final g = GameState(
        board: Board.fromRows(
          rows,
          kinds: {(3, 1): CellKind.boom, (2, 1): CellKind.gem},
        ),
        generator: PieceGenerator(Random(1), 0),
        tray: [dot, dot, dot],
      );
      final o = g.place(0, 3, 7)!;
      expect(o.gems, 1);
    });
  });

  group('Gold Rush', () {
    test('a golden block starts a rush that lasts 5 placements', () {
      final g = rowState(CellKind.gold);
      final o = g.place(0, 3, 7)!;
      expect(o.startedRush, isTrue);
      expect(g.rushLeft, 5);
      expect(o.rushDoubled, isFalse);
      for (var i = 0; i < 5; i++) {
        // tray refills after 3 placements; just place dots wherever they fit.
        var placed = false;
        for (var r = 0; r < 8 && !placed; r++) {
          for (var c = 0; c < 8 && !placed; c++) {
            for (var s = 0; s < 3 && !placed; s++) {
              if (g.canPlace(s, r, c)) {
                final p = g.place(s, r, c)!;
                expect(p.rushDoubled, isTrue);
                placed = true;
              }
            }
          }
        }
        expect(placed, isTrue);
      }
      expect(g.rushLeft, 0);
    });

    test('a second golden block extends by 5, capped at 15', () {
      final g = rowState(CellKind.gold);
      g.rushLeft = 3;
      g.place(0, 3, 7);
      expect(g.rushLeft, 2 + 5); // one placement consumed, then +5
      final h = rowState(CellKind.gold)..rushLeft = 14;
      h.place(0, 3, 7);
      expect(h.rushLeft, GameState.rushCap);
    });

    test('a rush doubles placement points and the line bonus', () {
      final base = rowState(CellKind.normal);
      final rush = rowState(CellKind.normal)..rushLeft = 2;
      final a = base.place(0, 3, 7)!;
      final b = rush.place(0, 3, 7)!;
      expect(b.scoreGained, a.scoreGained * 2);
      expect(rush.rushLeft, 1);
    });
  });
}
