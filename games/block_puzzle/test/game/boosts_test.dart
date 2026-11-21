import 'dart:math';

import 'package:game_block_puzzle/src/core/save/save_data.dart';
import 'package:game_block_puzzle/src/game/rules/board.dart';
import 'package:game_block_puzzle/src/game/rules/boosts.dart';
import 'package:game_block_puzzle/src/game/rules/game_state.dart';
import 'package:game_block_puzzle/src/game/rules/piece.dart';
import 'package:game_block_puzzle/src/game/rules/piece_generator.dart';
import 'package:game_block_puzzle/src/game/rules/start_board.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _full() => List.filled(8, '########');

GameState _game({Board? board, List<Piece>? tray, int seed = 1}) => GameState(
  generator: PieceGenerator(Random(seed), 0),
  board: board,
  tray: tray ?? [PieceCatalog.dot, PieceCatalog.dot, PieceCatalog.dot],
);

/// A board with a few scattered blocks so a dot always fits.
Board _scattered() => Board.fromRows([
  '#.......',
  '.#......',
  '........',
  '...#....',
  '........',
  '......#.',
  '.......#',
  '........',
]);

void main() {
  group('boost table', () {
    test('prices and per-game caps', () {
      expect(
        {for (final d in Boosts.all) d.key: (d.price, d.maxUses)},
        {
          'blast': (50, 2),
          'shuffle': (40, 2),
          'undo': (30, 3),
          'sweep': (60, 1),
          'hammer': (25, 3),
        },
      );
      expect(Boosts.maxAdRefillsPerGame, 3);
    });
  });

  group('board effects', () {
    test('Blast empties the filled cells of the 3x3, clipped at a corner', () {
      final r = Boosts.blast(Board.fromRows(_full()), 0, 0)!;
      expect(r.cells.toSet(), {(0, 0), (0, 1), (1, 0), (1, 1)});
      expect(r.board.filledCount, 64 - 4);
    });

    test('Blast clipped at an edge, only filled cells count', () {
      final rows = _full();
      rows[3] = '#.######'; // (3,1) already empty
      final r = Boosts.blast(Board.fromRows(rows), 3, 0)!;
      expect(r.cells.toSet(), {(2, 0), (2, 1), (3, 0), (4, 0), (4, 1)});
      expect(r.board.filledCount, 63 - 5);
    });

    test('Blast on an empty area does nothing', () {
      expect(Boosts.blast(Board.empty(), 4, 4), isNull);
    });

    test('Sweep takes the fullest line; ties: rows first, lowest index', () {
      final rows = List.filled(8, '........');
      rows[2] = '###.....';
      rows[5] = '###.....';
      // Columns 0..2 hold 2 each, rows 2 and 5 hold 3: the lowest row wins.
      final r = Boosts.sweep(Board.fromRows(rows))!;
      expect(r.cells.toSet(), {(2, 0), (2, 1), (2, 2)});
      // A column ties with a row: the row goes first.
      final rows2 = List.filled(8, '........');
      rows2[0] = '##......';
      rows2[1] = '#.......';
      final r2 = Boosts.sweep(Board.fromRows(rows2))!;
      expect(r2.cells.toSet(), {(0, 0), (0, 1)}); // row 0 (2) ties col 0 (2)
      // A column that is fuller than any row wins.
      final rows3 = List.filled(8, '........');
      rows3[0] = '#.......';
      rows3[1] = '#.......';
      rows3[2] = '#.......';
      final r3 = Boosts.sweep(Board.fromRows(rows3))!;
      expect(r3.cells.toSet(), {(0, 0), (1, 0), (2, 0)});
      expect(Boosts.sweep(Board.empty()), isNull);
    });

    test('Hammer empties one cell, special kinds vanish without effect', () {
      final board = Board.fromRows(
        ['#.......', ...List.filled(7, '........')],
        kinds: {(0, 0): CellKind.boom},
      );
      final r = Boosts.hammer(board, 0, 0)!;
      expect(r.board.filledCount, 0);
      expect(r.board.kindAt(0, 0), CellKind.normal);
      expect(Boosts.hammer(board, 3, 3), isNull);
    });
  });

  group('GameState boosts', () {
    test('no boost changes score, combo, stage, lines or rush', () {
      final g = _game(board: _scattered())
        ..score = 123
        ..comboStreak = 3
        ..linesClearedTotal = 11
        ..rushLeft = 4;
      // Something to undo.
      g.place(0, 7, 0);
      final before = (
        g.score,
        g.comboStreak,
        g.stage,
        g.linesClearedTotal,
        g.rushLeft,
      );
      expect(g.useBlast(0, 0), isNotNull);
      expect(g.useHammer(3, 3), isNotNull);
      expect(g.useSweep(), isNotNull);
      expect(g.useShuffle(), isTrue);
      expect((
        g.score,
        g.comboStreak,
        g.stage,
        g.linesClearedTotal,
        g.rushLeft,
      ), before);
    });

    test('Blast, Sweep and Hammer clear gems and gold without payout', () {
      final board = Board.fromRows(
        ['###.....', ...List.filled(7, '........')],
        kinds: {
          (0, 0): CellKind.gem,
          (0, 1): CellKind.gold,
          (0, 2): CellKind.boom,
        },
      );
      final g = _game(board: board);
      final score = g.score;
      final r = g.useBlast(0, 1)!;
      expect(r.cells.length, 3);
      expect(g.board.filledCount, 0);
      expect(g.score, score);
      expect(g.rushLeft, 0);
    });

    test(
      'Shuffle: every piece fits, deterministic for a seed, tray counter kept',
      () {
        List<Piece> run() {
          final gen = PieceGenerator(Random(5));
          final g = GameState.newGame(generator: gen);
          final traysBefore = gen.traysDealt;
          expect(g.useShuffle(), isTrue);
          expect(gen.traysDealt, traysBefore);
          expect(g.tray.whereType<Piece>().length, 3);
          for (final p in g.tray.whereType<Piece>()) {
            expect(g.board.canPlaceAnywhere(p), isTrue);
            expect(p.hasSpecial, isFalse);
          }
          return g.tray.whereType<Piece>().toList();
        }

        final a = run(), b = run();
        expect(
          [for (final p in a) (p.id, p.colorIndex)],
          [for (final p in b) (p.id, p.colorIndex)],
        );
      },
    );

    test('Shuffle takes away a special cell', () {
      final tray = [
        PieceCatalog.byId('bar2_0').withKind(0, CellKind.gem),
        PieceCatalog.dot,
        PieceCatalog.dot,
      ];
      final g = _game(board: _scattered(), tray: tray);
      expect(g.tray.any((p) => p!.hasSpecial), isTrue);
      g.useShuffle();
      expect(g.tray.any((p) => p!.hasSpecial), isFalse);
    });

    test('Undo restores everything, including the gem coins taken back', () {
      // One row of 7 with a gem; the dot completes the row (gem pays 1 coin).
      final rows = List.filled(8, '........');
      rows[0] = '.#######';
      final board = Board.fromRows(rows, kinds: {(0, 1): CellKind.gem});
      final g = _game(board: board)
        ..comboStreak = 2
        ..rushLeft = 3
        ..linesClearedTotal = 4;
      final before = (
        g.score,
        g.bestScore,
        g.comboStreak,
        g.linesClearedTotal,
        g.rushLeft,
        g.piecesPlaced,
        g.stage,
      );
      final cells = List<int>.of(g.board.cells);
      final out = g.place(0, 0, 0)!;
      expect(out.gems, 1);
      expect(g.canUndo, isTrue);
      final coins = g.useUndo();
      expect(coins, 1);
      expect(g.board.cells, cells);
      expect(g.board.kindAt(0, 1), CellKind.gem);
      expect(g.tray[0], isNotNull);
      expect((
        g.score,
        g.bestScore,
        g.comboStreak,
        g.linesClearedTotal,
        g.rushLeft,
        g.piecesPlaced,
        g.stage,
      ), before);
    });

    test(
      'Undo is disabled at the start, after Undo and after other boosts',
      () {
        final g = _game(board: _scattered());
        expect(g.canUseBoost(BoostId.undo), isFalse);
        expect(g.useUndo(), isNull);
        g.place(0, 7, 0);
        expect(g.canUseBoost(BoostId.undo), isTrue);
        g.useUndo();
        expect(g.canUseBoost(BoostId.undo), isFalse);
        g.place(0, 7, 0);
        g.useHammer(0, 0);
        expect(g.canUseBoost(BoostId.undo), isFalse);
        g.place(1, 7, 1);
        expect(g.canUseBoost(BoostId.undo), isTrue);
        g.useShuffle();
        expect(g.canUseBoost(BoostId.undo), isFalse);
      },
    );

    test('Undo is disabled after Continue', () {
      final rows = List.generate(8, (r) => r.isEven ? '.#.#.#.#' : '#.#.#.#.');
      final g = _game(
        board: Board.fromRows(rows),
        tray: [PieceCatalog.dot, PieceCatalog.dot, PieceCatalog.dot],
      );
      g.place(0, 0, 0);
      expect(g.canUndo, isTrue);
      while (!g.isGameOver) {
        final m = [
          for (var s = 0; s < 3; s++)
            for (var r = 0; r < 8; r++)
              for (var c = 0; c < 8; c++)
                if (g.canPlace(s, r, c)) (s, r, c),
        ];
        if (m.isEmpty) break;
        g.place(m.first.$1, m.first.$2, m.first.$3);
      }
      if (g.isGameOver) {
        expect(g.canUndo, isFalse);
        expect(g.revive(), isTrue);
        expect(g.canUndo, isFalse);
      }
    });

    test('per-game caps hold whatever the stock', () {
      final rows = _full();
      rows[7] = '#######.'; // one hole, so the game is not over
      final g = _game(board: Board.fromRows(rows));
      expect(g.useHammer(0, 0), isNotNull);
      expect(g.useHammer(0, 1), isNotNull);
      expect(g.useHammer(0, 2), isNotNull);
      expect(g.useHammer(0, 3), isNull);
      expect(g.canUseBoost(BoostId.hammer), isFalse);
      expect(g.useSweep(), isNotNull);
      expect(g.useSweep(), isNull);
      expect(g.useBlast(7, 7), isNotNull);
      expect(g.useBlast(0, 7), isNotNull);
      expect(g.useBlast(4, 4), isNull);
      expect(g.useShuffle(), isTrue);
      expect(g.useShuffle(), isTrue);
      expect(g.useShuffle(), isFalse);
      // A new game starts with fresh caps.
      expect(
        GameState.newGame(generator: PieceGenerator(Random(1)))
            .boostUsesLeft(BoostId.hammer),
        3,
      );
    });

    test('ad refills: at most 3 per game across all boosts', () {
      final g = _game();
      expect(g.takeAdRefill(), isTrue);
      expect(g.takeAdRefill(), isTrue);
      expect(g.takeAdRefill(), isTrue);
      expect(g.takeAdRefill(), isFalse);
      expect(g.adRefillsLeft, 0);
    });

    test('boosts are not usable once the game is over', () {
      final g = _game(
        board: Board.fromRows(_full()),
        tray: [PieceCatalog.dot, PieceCatalog.dot, PieceCatalog.dot],
      );
      expect(g.isGameOver, isTrue);
      expect(g.useHammer(0, 0), isNull);
      expect(g.useShuffle(), isFalse);
    });
  });

  group('stock in the save', () {
    test('new saves and migrated v2 saves start with 1 of each', () {
      for (final d in Boosts.all) {
        expect(const SaveData().itemCount(d.key), 1);
      }
      final migrated = SaveMigrator.migrate({'version': 2, 'coins': 9});
      expect(migrated['version'], SaveData.currentVersion);
      final back = SaveData.fromJson(migrated);
      expect(back.coins, 9);
      for (final d in Boosts.all) {
        expect(back.itemCount(d.key), 1);
      }
    });

    test('stock round trips and never goes below 0', () {
      final d = const SaveData().copyWith(
        items: {'blast': 4, 'shuffle': 0, 'undo': -3, 'sweep': 2, 'hammer': 7},
      );
      final back = SaveData.fromJson(
        SaveMigrator.migrate(d.toJson().cast<String, Object?>()),
      );
      expect(back.itemCount('blast'), 4);
      expect(back.itemCount('shuffle'), 0);
      expect(back.itemCount('undo'), 0);
      expect(back.itemCount('hammer'), 7);
    });
  });

  group('dealing with big pieces', () {
    test('the rectangle has two orientations of 6 cells, weight 3', () {
      final rects = PieceCatalog.weighted.where(
        (w) => w.piece.id.startsWith('rect23'),
      );
      expect(rects.length, 2);
      expect(
        {for (final w in rects) (w.piece.height, w.piece.width)},
        {(2, 3), (3, 2)},
      );
      expect(rects.every((w) => w.weight == 3 && w.piece.size == 6), isTrue);
      expect(
        PieceCatalog.weighted
            .firstWhere((w) => w.piece.id.startsWith('square3'))
            .weight,
        3,
      );
    });

    test('the start tray never has a 6+ cell piece', () {
      for (var seed = 0; seed < 200; seed++) {
        final s = StartBoard.generate(Random(seed));
        expect(s.tray.every((p) => p.size == 4), isTrue, reason: 'seed $seed');
        final g = GameState.newGame(generator: PieceGenerator(Random(seed)));
        expect(g.tray.whereType<Piece>().every((p) => p.size < 6), isTrue);
      }
    });

    test(
      'the rectangle and the 3x3 square appear in long seeded runs, all fit',
      () {
        final seen = <String>{};
        for (var seed = 0; seed < 30; seed++) {
          final gen = PieceGenerator(Random(seed));
          final g = GameState.newGame(generator: gen);
          for (var i = 0; i < 150 && !g.isGameOver; i++) {
            for (final p in g.tray.whereType<Piece>()) {
              seen.add(p.id.split('_').first);
            }
            final moves = [
              for (var s = 0; s < 3; s++)
                for (var r = 0; r < 8; r++)
                  for (var c = 0; c < 8; c++)
                    if (g.canPlace(s, r, c)) (s, r, c),
            ];
            if (moves.isEmpty) break;
            final m = moves[(i * 7) % moves.length];
            g.place(m.$1, m.$2, m.$3);
          }
        }
        expect(seen, containsAll(['rect23', 'square3']));
      },
    );
  });
}
