import 'dart:io';
import 'dart:math';

import 'package:game_block_puzzle/src/game/layout.dart';
import 'package:game_block_puzzle/src/game/rules/board.dart';
import 'package:game_block_puzzle/src/game/rules/game_state.dart';
import 'package:game_block_puzzle/src/game/rules/piece.dart';
import 'package:game_block_puzzle/src/game/rules/piece_generator.dart';
import 'package:game_block_puzzle/src/game/rules/snap.dart';
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

    test('no two pieces are the same shape; new shapes exist', () {
      final keys = PieceCatalog.all
          .map((x) => x.cells.map((c) => '${c.$1},${c.$2}').join(';'))
          .toList();
      expect(keys.toSet().length, keys.length);
      for (final id in ['z4_0', 'z4_1', 'j4_0', 'j4_3', 'plus5_0']) {
        expect(PieceCatalog.byId(id).id, id);
      }
      expect(PieceCatalog.byId('plus5_0').size, 5);
      expect(PieceCatalog.byId('diag2_1').size, 2);
      expect(PieceCatalog.byId('diag3_1').size, 3);
      expect(
        PieceCatalog.all.where((x) => x.id.startsWith('plus5')),
        hasLength(1),
      );
    });

    test('dealt pieces always fit, diagonals included', () {
      final gen = PieceGenerator(Random(9), 0);
      var diagonals = 0;
      final rows = List.filled(8, '########');
      rows[0] = '#.#.####';
      rows[1] = '.#.#####';
      final board = Board.fromRows(rows);
      for (var i = 0; i < 300; i++) {
        for (final piece in gen.dealTray(board)) {
          expect(board.canPlaceAnywhere(piece), isTrue, reason: piece.id);
          if (piece.id.startsWith('diag')) diagonals++;
        }
      }
      expect(diagonals, greaterThan(0));
    });

    test('snap works for a diagonal piece and special cells are allowed', () {
      final d = p('diag2_0');
      expect(snapToLegalCell(Board.empty(), d, 2.2, 3.1), (2, 3));
      final b = Board.empty()
          .place(PieceCatalog.dot, 3, 3)
          .board; // blocks (3,3)
      // top-left (2,2) would need (3,3): not legal; nearest legal cell is used.
      expect(snapToLegalCell(b, d, 2, 2), isNot((2, 2)));
      final g = PieceGenerator(Random(1)).addSpecial([d.withColor(0)]);
      expect(g.single.hasSpecial, isTrue);
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

  group('PieceGenerator difficulty by lines cleared', () {
    // A crowded board: two 1x1 holes and a 2x2 hole, so many pieces do not fit.
    Board crowded() {
      final rows = List.filled(8, '########');
      rows[0] = '##.#####';
      rows[3] = '#.######';
      rows[6] = '######..';
      rows[7] = '######..';
      return Board.fromRows(rows);
    }

    test('every dealt piece fits on its own, at any number of lines', () {
      final board = crowded();
      for (final lines in [0, 10, 30, 59, 60, 200]) {
        for (var seed = 0; seed < 40; seed++) {
          final gen = PieceGenerator(Random(seed));
          final tray = gen.dealTray(board, linesCleared: lines);
          expect(tray.every(board.canPlaceAnywhere), isTrue);
        }
      }
    });

    test('share of 4-cell pieces is about the same early and late', () {
      // More than half full, so small pieces are not filtered out as on a roomy board.
      final board = Board.fromRows([
        for (var i = 0; i < 5; i++) '#######.',
        ...List.filled(3, '........'),
      ]);
      double share(int lines) {
        var four = 0, total = 0;
        for (var seed = 0; seed < 300; seed++) {
          final gen = PieceGenerator(Random(seed));
          for (final p in gen.dealTray(board, linesCleared: lines)) {
            total++;
            if (p.size == 4) four++;
          }
        }
        return four / total;
      }

      final early = share(0), late = share(100);
      expect((early - late).abs(), lessThan(0.05));
      expect(late, greaterThan(0.5)); // 4-cell pieces are preferred
    });

    test('trays below 20 lines can be played out one after another', () {
      final board = Board.fromRows([
        for (var i = 0; i < 5; i++) '#######.',
        ...List.filled(3, '........'),
      ]);
      bool playable(Board b, List<Piece> ps) {
        if (ps.isEmpty) return true;
        for (var i = 0; i < ps.length; i++) {
          final rest = [...ps.sublist(0, i), ...ps.sublist(i + 1)];
          for (var r = 0; r < 8; r++) {
            for (var c = 0; c < 8; c++) {
              if (b.canPlace(ps[i], r, c) &&
                  playable(b.place(ps[i], r, c).board, rest)) {
                return true;
              }
            }
          }
        }
        return false;
      }

      for (var seed = 0; seed < 60; seed++) {
        final tray = PieceGenerator(Random(seed))
            .dealTray(board, linesCleared: 5);
        expect(playable(board, tray), isTrue, reason: 'seed $seed');
      }
    });

    test('a roomy board is never dealt pieces under three cells', () {
      final gen = PieceGenerator(Random(21));
      for (var i = 0; i < 200; i++) {
        for (final p in gen.dealTray(Board.empty())) {
          expect(p.size, greaterThanOrEqualTo(PieceGenerator.minRoomySize));
        }
      }
    });

    test('dealing on a mostly empty board is fast', () {
      final gen = PieceGenerator(Random(14));
      final sw = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        gen.dealTray(Board.empty());
      }
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
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
        // A press well below the piece still picks it, down to the screen bottom.
        expect(l.traySlotAt(x, l.height - 1), i);
      }
      expect(l.traySlotAt(l.boardLeft, l.boardTop), isNull);
    });

    test('fingerFor snaps the piece to the requested cell', () {
      final (fx, fy) = l.fingerFor(2, 3, 4, 1);
      // Reconstruct the piece top-left the way the view does.
      final tlX = fx - 3 * l.cellSize / 2;
      final tlY = fy - l.dragLift - 2 * l.cellSize;
      final (cy, cx) = l.topLeftInCells(tlX, tlY);
      expect(cy, closeTo(4, 1e-9));
      expect(cx, closeTo(1, 1e-9));
      expect(snapToLegalCell(Board.empty(), p('bar3_0'), cy, cx), (4, 1));
    });
  });

  group('snapToLegalCell', () {
    final dot = PieceCatalog.dot;

    test('exact drop is unchanged', () {
      expect(snapToLegalCell(Board.empty(), dot, 3, 4), (3, 4));
    });

    test('occupied nearest cell lands on a free neighbour within 1.0', () {
      final b = Board.empty().place(dot, 3, 4).board;
      // Nearest cell (3,4) is taken; (3,5) is 0.7 away horizontally.
      expect(snapToLegalCell(b, dot, 3.0, 4.3), (3, 5));
    });

    test('only legal cell farther than 1.0 rejects the drop', () {
      final one = Board.fromRows([
        'XXXXXXXX',
        'XXXXXXXX',
        'XXXXXXXX',
        'XXXXXXXX',
        'XXXXXXXX',
        'XXXXXXXX',
        'XXXXXXXX',
        'XXXXXXX.',
      ]);
      expect(snapToLegalCell(one, dot, 7, 5.9), isNull); // 1.1 away
      expect(snapToLegalCell(one, dot, 7, 6.1), (7, 7)); // 0.9 away
    });

    test('tie goes to the line-clearing cell', () {
      final b = Board.fromRows([
        '........',
        'XX.XXXXX',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      // (0,2) and (1,2) are equally close; only (1,2) clears row 1.
      expect(snapToLegalCell(b, dot, 0.5, 2), (1, 2));
    });

    test('tie without line clears prefers the smaller row, then column', () {
      expect(snapToLegalCell(Board.empty(), dot, 0.5, 0.5), (0, 0));
    });
  });

  group('purity', () {
    test('lib/src/game/rules has no Flutter, Flame or Android imports', () {
      final files = [
        ...Directory('lib/src/game/rules').listSync().whereType<File>(),
        File('lib/src/game/layout.dart'),
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
