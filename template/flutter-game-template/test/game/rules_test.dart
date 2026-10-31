import 'dart:io';
import 'dart:math';

import 'package:flutter_game_template/game/layout.dart';
import 'package:flutter_game_template/game/rules/board.dart';
import 'package:flutter_game_template/game/rules/game_state.dart';
import 'package:flutter_game_template/game/rules/piece.dart';
import 'package:flutter_game_template/game/rules/piece_generator.dart';
import 'package:flutter_test/flutter_test.dart';

Piece p(String id) => PieceCatalog.byId(id);

void main() {
  group('Board', () {
    test('starts empty with 8x8', () {
      final b = Board.empty();
      expect(b.size, 8);
      expect(b.isEmpty, isTrue);
    });

    test('rejects out-of-bounds and overlapping placements', () {
      final b = Board.empty();
      final bar = p('bar5_0'); // horizontal 5
      expect(b.canPlace(bar, 0, 4), isFalse); // 4..8 overflows
      expect(b.canPlace(bar, 0, 3), isTrue);
      final placed = b.place(bar, 0, 0).board;
      expect(placed.canPlace(PieceCatalog.dot, 0, 2), isFalse);
      expect(() => placed.place(PieceCatalog.dot, 0, 2), throwsArgumentError);
    });

    test('a full row clears', () {
      var b = Board.empty();
      b = b.place(p('bar4_0'), 3, 0).board;
      final r = b.place(p('bar4_0'), 3, 4);
      expect(r.clearedRows, [3]);
      expect(r.clearedCols, isEmpty);
      expect(r.board.isEmpty, isTrue);
    });

    test('a full column clears', () {
      var b = Board.empty();
      b = b.place(p('bar4_1'), 0, 2).board; // vertical 4
      final r = b.place(p('bar4_1'), 4, 2);
      expect(r.clearedCols, [2]);
      expect(r.board.isEmpty, isTrue);
    });

    test('row and column crossing clear together', () {
      // Fill row 0 and col 0 except the corner cell (0,0), then drop a dot there.
      var b = Board.empty();
      b = b.place(p('bar5_0'), 0, 1).board;
      b = b.place(p('bar2_0'), 0, 6).board; // row 0: cols 1..7
      b = b.place(p('bar5_1'), 1, 0).board;
      b = b.place(p('bar2_1'), 6, 0).board; // col 0: rows 1..7
      final r = b.place(PieceCatalog.dot, 0, 0);
      expect(r.clearedRows, [0]);
      expect(r.clearedCols, [0]);
      expect(r.linesCleared, 2);
      expect(r.board.isEmpty, isTrue);
    });

    test('partial lines do not clear', () {
      final r = Board.empty().place(p('bar4_0'), 0, 0);
      expect(r.linesCleared, 0);
      expect(r.board.filledCount, 4);
    });

    test('canPlaceAnywhere false on a full board', () {
      final full = Board.fromRows(List.filled(8, '########'));
      expect(full.canPlaceAnywhere(PieceCatalog.dot), isFalse);
    });
  });

  group('PieceCatalog', () {
    test('ids are unique and cells normalized', () {
      final ids = PieceCatalog.all.map((x) => x.id);
      expect(ids.toSet().length, ids.length);
      for (final piece in PieceCatalog.all) {
        expect(piece.cells.map((c) => c.$1).reduce(min), 0);
        expect(piece.cells.map((c) => c.$2).reduce(min), 0);
        expect(piece.width, lessThanOrEqualTo(5));
        expect(piece.height, lessThanOrEqualTo(5));
      }
    });

    test('every piece fits on an empty board', () {
      for (final piece in PieceCatalog.all) {
        expect(Board.empty().canPlaceAnywhere(piece), isTrue, reason: piece.id);
      }
    });
  });

  group('PieceGenerator', () {
    test('deals three pieces and is deterministic for a seed', () {
      final a = PieceGenerator(Random(5)).dealTray(Board.empty());
      final b = PieceGenerator(Random(5)).dealTray(Board.empty());
      expect(a, hasLength(3));
      expect(a.map((x) => x.id).toList(), b.map((x) => x.id).toList());
    });

    test(
      'a dealt tray always has a playable piece when the board is not full',
      () {
        final rng = Random(1);
        final gen = PieceGenerator(rng);
        // Board with a single hole: only the dot fits.
        final rows = List.filled(8, '########');
        rows[4] = '###.####';
        final board = Board.fromRows(rows);
        for (var i = 0; i < 30; i++) {
          final tray = gen.dealTray(board);
          expect(tray.any(board.canPlaceAnywhere), isTrue);
        }
      },
    );
  });

  group('GameState', () {
    GameState game({List<Piece>? tray, Board? board}) => GameState(
      generator: PieceGenerator(Random(3)),
      tray: tray ?? [p('bar4_0'), p('bar4_0'), PieceCatalog.dot],
      board: board,
    );

    test('placing a piece scores its cell count and consumes the slot', () {
      final g = game();
      final o = g.place(0, 0, 0)!;
      expect(o.scoreGained, 4);
      expect(g.score, 4);
      expect(g.tray[0], isNull);
      expect(g.piecesPlaced, 1);
    });

    test('illegal placement returns null and changes nothing', () {
      final g = game();
      expect(g.place(0, 0, 6), isNull); // would overflow
      expect(g.score, 0);
      expect(g.tray[0], isNotNull);
    });

    test('clearing a row scores 10*lines^2 plus cells', () {
      final g = game();
      g.place(0, 0, 0);
      final o = g.place(1, 0, 4)!;
      expect(o.linesCleared, 1);
      expect(o.scoreGained, 4 + 10);
      expect(o.combo, 1);
      expect(g.linesClearedTotal, 1);
    });

    test('consecutive clearing moves build a combo multiplier', () {
      // Two near-full rows: clearing them back to back gives x1 then x2.
      final g2 = GameState(
        generator: PieceGenerator(Random(3)),
        tray: [p('bar4_0'), p('bar4_0'), p('bar4_0')],
        board: Board.fromRows(
          List.generate(8, (r) => r < 2 ? '....####' : '........'),
        ),
      );
      expect(g2.place(0, 0, 0)!.combo, 1);
      final o2 = g2.place(1, 1, 0)!;
      expect(o2.combo, 2);
      expect(o2.scoreGained, 4 + 10 * 1 * 1 * 2);
      expect(g2.maxComboReached, 2);
    });

    test('a non-clearing move resets the combo', () {
      final g = GameState(
        generator: PieceGenerator(Random(3)),
        tray: [p('bar4_0'), PieceCatalog.dot, PieceCatalog.dot],
        board: Board.fromRows(
          List.generate(8, (r) => r == 0 ? '....####' : '........'),
        ),
      );
      g.place(0, 0, 0); // clears
      expect(g.comboStreak, 1);
      g.place(1, 5, 5);
      expect(g.comboStreak, 0);
    });

    test('tray refills after all three pieces are used', () {
      final g = game(
        tray: [PieceCatalog.dot, PieceCatalog.dot, PieceCatalog.dot],
      );
      g.place(0, 0, 0);
      g.place(1, 0, 1);
      expect(g.tray.whereType<Piece>().length, 1);
      g.place(2, 0, 2);
      expect(g.tray.whereType<Piece>().length, 3);
    });

    test('game over when no remaining piece fits', () {
      final rows = List.filled(8, '########');
      rows[0] = '.#######'; // a single hole
      final g = GameState(
        generator: PieceGenerator(Random(3)),
        tray: [p('bar2_0'), p('square2_0'), p('bar3_1')],
        board: Board.fromRows(rows),
      );
      expect(g.isGameOver, isTrue);
      expect(g.place(0, 0, 0), isNull); // input ignored when over
    });

    test('game over is reported by the placement that causes it', () {
      // Checkerboard: every empty cell is isolated, so only single dots fit.
      final rows = List.generate(8, (r) => r.isEven ? '.#.#.#.#' : '#.#.#.#.');
      final g = GameState(
        generator: PieceGenerator(Random(3)),
        tray: [PieceCatalog.dot, p('bar2_0'), p('square2_0')],
        board: Board.fromRows(rows),
      );
      expect(g.isGameOver, isFalse);
      final o = g.place(0, 0, 0)!;
      expect(
        o.gameOver,
        isTrue,
      ); // one single hole left, only larger pieces remain
      expect(g.isGameOver, isTrue);
    });

    test('up to three revives per run, then none; new run resets', () {
      final rows = List.filled(8, '########');
      rows[0] = '.#######';
      final g = GameState(
        generator: PieceGenerator(Random(3)),
        tray: [p('bar2_0'), p('square2_0'), p('bar3_1')],
        board: Board.fromRows(rows),
      );
      expect(g.revivesRemaining, 3);
      expect(g.canRevive, isTrue);
      expect(g.revive(), isTrue);
      expect(g.isGameOver, isFalse);
      expect(g.board.filledCount, lessThan(64 - 1));
      expect(g.revivesRemaining, 2);
      for (var i = 0; i < 2; i++) {
        g.isGameOver = true; // simulate running out of moves again
        expect(g.canRevive, isTrue);
        expect(g.revive(), isTrue);
      }
      expect(g.revivesRemaining, 0);
      g.isGameOver = true;
      expect(g.canRevive, isFalse);
      expect(g.revive(), isFalse);
      expect(GameState().revivesRemaining, 3);
    });

    test('best score follows the score', () {
      final g = GameState(
        generator: PieceGenerator(Random(3)),
        bestScore: 3,
        tray: [p('bar4_0'), PieceCatalog.dot, PieceCatalog.dot],
      );
      g.place(0, 0, 0);
      expect(g.bestScore, 4);
    });

    test('full random playthrough terminates and never throws', () {
      final rng = Random(42);
      for (var run = 0; run < 20; run++) {
        final g = GameState(generator: PieceGenerator(Random(run)));
        var moves = 0;
        while (!g.isGameOver && moves < 2000) {
          final options = <(int, int, int)>[];
          for (var s = 0; s < 3; s++) {
            final piece = g.tray[s];
            if (piece == null) continue;
            for (var r = 0; r < 8; r++) {
              for (var c = 0; c < 8; c++) {
                if (g.canPlace(s, r, c)) options.add((s, r, c));
              }
            }
          }
          expect(options, isNotEmpty);
          final (s, r, c) = options[rng.nextInt(options.length)];
          g.place(s, r, c);
          moves++;
        }
        expect(g.isGameOver, isTrue);
      }
    });
  });

  group('PuzzleLayout', () {
    final l = PuzzleLayout(400, 800);

    test('maps cells to centers and back', () {
      final (x, y) = l.cellCenter(3, 5);
      expect(l.cellAt(x, y), (3, 5));
      expect(l.cellAt(-5, -5), isNull);
    });

    test('tray slots are below the board and distinct', () {
      expect(l.trayTop, greaterThan(l.boardTop + l.boardSizePx));
      for (var i = 0; i < 3; i++) {
        final (x, y) = l.trayCenter(i);
        expect(l.traySlotAt(x, y), i);
      }
    });

    test('fingerFor snaps the piece to the requested cell', () {
      final (fx, fy) = l.fingerFor(2, 3, 4, 1);
      // Reconstruct the piece top-left the way the view does.
      final tlX = fx - 3 * l.cellSize / 2;
      final tlY = fy - l.dragLift - 2 * l.cellSize / 2;
      expect(l.snapTopLeft(tlX, tlY), (4, 1));
    });
  });

  group('purity', () {
    test('lib/game/rules has no Flutter, Flame or Android imports', () {
      final files = [
        ...Directory('lib/game/rules').listSync().whereType<File>(),
        File('lib/game/layout.dart'),
      ];
      expect(files, isNotEmpty);
      for (final f in files) {
        final src = f.readAsStringSync();
        expect(
          RegExp(r"import 'package:(flutter|flame)|import 'dart:(ui|io)'")
              .hasMatch(src),
          isFalse,
          reason: f.path,
        );
      }
    });
  });
}
