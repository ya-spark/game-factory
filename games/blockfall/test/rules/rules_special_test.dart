import 'dart:math';

import 'package:game_blockfall/src/game/rules/active_piece.dart';
import 'package:game_blockfall/src/game/rules/blockfall_game.dart';
import 'package:game_blockfall/src/game/rules/piece_type.dart';
import 'package:game_blockfall/src/game/rules/scoring.dart';
import 'package:game_blockfall/src/game/rules/well.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

BlockfallGame _game(
  int seed, {
  int prism = prismEveryNthPiece,
  int boom = boomEveryNthPiece,
  int gold = goldEveryNthPiece,
}) => BlockfallGame(
  random: Random(seed),
  prismRandom: Random(seed ^ 0x5eed),
  specialRandom: Random(seed ^ 0xb00),
  fitRandom: Random(seed ^ 0xf17),
  prismInterval: prism,
  boomInterval: boom,
  goldInterval: gold,
);

/// The first [n] pieces the game deals (the well is emptied after every drop).
List<PieceSpec> _deal(BlockfallGame g, int n) {
  final out = <PieceSpec>[];
  for (var i = 0; i < n; i++) {
    out.add(g.currentPiece!.spec!);
    g.hardDrop();
    g.well.clearRowRange(0, Well.totalRows);
  }
  return out;
}

void main() {
  group('dealing special cells', () {
    test('every 9th piece a Boom block, every 13th a golden block', () {
      final specs = _deal(_game(3), 60);
      for (var i = 0; i < specs.length; i++) {
        final s = specs[i];
        final gold = i % 13 == 12;
        final boom = i % 9 == 8 && !gold;
        final prism = i % 4 == 3 && !gold && !boom;
        expect(s.goldCell != null, gold, reason: 'gold $i');
        expect(s.boomCell != null, boom, reason: 'boom $i');
        expect(s.prismCell != null, prism, reason: 'prism $i');
        for (final cell in [s.goldCell, s.boomCell, s.prismCell]) {
          if (cell != null) expect(cell, inInclusiveRange(0, 3));
        }
      }
    });

    test('deterministic for a seed', () {
      String show(List<PieceSpec> l) => l.join('|');
      expect(show(_deal(_game(11), 40)), show(_deal(_game(11), 40)));
      expect(show(_deal(_game(11), 40)), isNot(show(_deal(_game(12), 40))));
    });

    test('priority gold, then boom, then prism; at most one per piece', () {
      final g = _game(5, prism: 1, boom: 2, gold: 4);
      final s = _deal(g, 8);
      expect(s[0].prismCell, isNotNull); // only prism due
      expect(s[1].boomCell, isNotNull); // boom beats prism
      expect(s[1].prismCell, isNull);
      expect(s[3].goldCell, isNotNull); // gold beats boom and prism
      expect(s[3].boomCell, isNull);
      expect(s[3].prismCell, isNull);
      expect(s[7].goldCell, isNotNull);
    });

    test('the bag order never changes', () {
      List<PieceType> types(BlockfallGame g) => [
        for (final s in _deal(g, 50)) s.type,
      ];
      expect(types(_game(9)), types(_game(9, prism: 0, boom: 0, gold: 0)));
    });

    test('the kinds land on the well cells', () {
      final g = mk(seq: [PieceType.cube], boomInterval: 1);
      final spec = g.currentPiece!.spec!;
      final cell = g.ghostPiece!.cells[spec.boomCell!];
      g.hardDrop();
      expect(g.well.kindAt(cell.row, cell.col), CellKind.boom);
      expect(Well.fromRows(['Ab.......H']).toRows().last, 'Ab.......H');
    });
  });

  group('Boom block', () {
    test('removes the 3x3 area, nothing falls, 5 x level per extra cell', () {
      // Bar fills the gap (cols 3-6) in row 21; the Boom block sits at (21, 7).
      final g = mk(rows: ['1......11.', '111....A11'], seq: [PieceType.bar]);
      g.well.set(10, 0, 2); // not a perfect clear
      g.well.set(19, 8, 3); // above the blast area: only the clear moves it
      final before = g.score;
      final d = g.hardDrop();
      final ev = clears(g).single;
      expect(ev.rows, [21]);
      // 2 extra cells (20,7) (20,8); the cleared row itself is not counted.
      expect(ev.blastCells, hasLength(2));
      expect(g.score - before, 100 + 2 * blastCellPoints + 2 * d);
      // Row 20 lost cols 7-8, then dropped one row; (19,8) dropped one row (the clear only).
      expect(g.well.toRows()[21], '1.........');
      expect(g.well.colorAt(20, 8), 3);
      expect(g.well.colorAt(11, 0), 2);
    });

    test(
      'rows the blast fills are not cleared; blasted effects do nothing',
      () {
        final g = mk(rows: ['1......H1.', '111....A11'], seq: [PieceType.bar]);
        g.well.set(10, 0, 2);
        g.hardDrop();
        final ev = clears(g).single;
        expect(ev.rows, [21]);
        expect(ev.goldBlocks, 0);
        expect(
          g.rushActive,
          isFalse,
        ); // the blasted golden block starts nothing
      },
    );

    test('blasted prisms still pay their coin', () {
      final g = mk(rows: ['1......a1.', '111....A11'], seq: [PieceType.bar]);
      g.well.set(10, 0, 2);
      g.hardDrop();
      final ev = clears(g).single;
      expect(ev.prismCoins, 1);
      expect(g.coinsFromPrisms, 1);
      expect(ev.prismRows, 0); // no doubling: its row was not cleared
    });
  });

  group('Gold Rush', () {
    BlockfallGame rushGame() {
      final g = mk(rows: ['11H....111'], seq: [PieceType.bar]);
      g.well.set(10, 0, 2);
      return g;
    }

    test(
      'a golden block starts a 10 s rush; the clear itself is not doubled',
      () {
        final g = rushGame();
        final before = g.score;
        final d = g.hardDrop();
        expect(clears(g).single.goldBlocks, 1);
        expect(g.score - before, 100 + 2 * d);
        expect(g.rushRemaining, rushSeconds);
      },
    );

    test('doubles line, combo scores while it runs; time is play time', () {
      final g = rushGame();
      g.hardDrop();
      g.drainEvents();
      g.well.set(21, 0, 1); // a second clear (combo 2) from a fresh row
      for (var c = 0; c < Well.cols; c++) {
        if (c < 3 || c > 6) g.well.set(21, c, 1);
      }
      // Paused time does not count.
      g.isPaused = true;
      g.tick(5);
      g.isPaused = false;
      expect(g.rushRemaining, rushSeconds);
      g.tick(0.5);
      expect(g.rushRemaining, closeTo(9.5, 1e-6));
      final before = g.score;
      final d = g.hardDrop();
      final ev = clears(g).single;
      expect(ev.rushDoubled, isTrue);
      expect(g.score - before, (100 + 50) * 2 + 2 * d);
    });

    test('ends after 10 s of play time and then scores normally', () {
      final g = rushGame();
      g.hardDrop();
      g.drainEvents();
      // Lift the stack out of the way so only time passes (no lock out).
      g.tick(9.99);
      expect(g.rushActive, isTrue);
      g.tick(0.02);
      expect(g.rushActive, isFalse);
      expect(g.rushRemaining, 0);
    });

    test('another golden block adds 10 s, capped at 30 s', () {
      final g = rushGame();
      final seen = <double>[];
      for (var i = 0; i < 5; i++) {
        g.hardDrop();
        seen.add(g.rushRemaining);
        g.drainEvents();
        for (var c = 0; c < Well.cols; c++) {
          if (c < 3 || c > 6) g.well.set(21, c, c == 2 ? 1 : 1);
        }
        g.well.set(21, 2, 1, kind: CellKind.gold);
      }
      expect(seen, [10, 20, 30, 30, 30]);
    });
  });
}
