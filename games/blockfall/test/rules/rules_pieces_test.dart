import 'dart:math';

import 'package:game_blockfall/src/game/rules/active_piece.dart';
import 'package:game_blockfall/src/game/rules/bag.dart';
import 'package:game_blockfall/src/game/rules/blockfall_game.dart';
import 'package:game_blockfall/src/game/rules/events.dart';
import 'package:game_blockfall/src/game/rules/fit.dart';
import 'package:game_blockfall/src/game/rules/gravity.dart';
import 'package:game_blockfall/src/game/rules/piece_type.dart';
import 'package:game_blockfall/src/game/rules/well.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('pieces and spawn', () {
    test('every piece has 4 distinct cells in each of its 4 states', () {
      for (final t in PieceType.values) {
        expect(t.states, hasLength(4));
        for (final s in t.states) {
          expect(s.toSet(), hasLength(4), reason: t.name);
          for (final (c, r) in s) {
            expect(c, inInclusiveRange(0, 3));
            expect(r, inInclusiveRange(0, 3));
          }
        }
      }
      expect(PieceType.values.map((t) => t.colorId), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('four clockwise turns return to the start shape', () {
      for (final t in PieceType.values) {
        var p = ActivePiece(spec: PieceSpec(t), rotation: 0, col: 3, row: 5);
        final start = p.cells.map((c) => (c.row, c.col)).toSet();
        for (var i = 0; i < 4; i++) {
          p = p.rotatedClockwise();
        }
        expect(p.cells.map((c) => (c.row, c.col)).toSet(), start);
      }
    });

    test('Bar spawns at columns 3-6, Cube at 4-5, others at 3-5', () {
      List<int> cols(PieceType t) {
        final g = mk(seq: [t]);
        return (g.currentPiece!.cells.map((c) => c.col).toSet().toList()
          ..sort());
      }

      expect(cols(PieceType.bar), [3, 4, 5, 6]);
      expect(cols(PieceType.cube), [4, 5]);
      for (final t in [
        PieceType.prong,
        PieceType.zig,
        PieceType.zag,
        PieceType.hook,
        PieceType.boot,
      ]) {
        expect(cols(t), [3, 4, 5], reason: t.name);
      }
    });

    test('every piece spawns inside the two hidden rows', () {
      for (final t in PieceType.values) {
        final g = mk(seq: [t]);
        expect(g.currentPiece!.cells.every((c) => c.row < 2), isTrue);
        expect(g.currentPiece!.rotation, 0);
      }
    });

    test('moves are blocked by walls and filled cells', () {
      final g = mk();
      while (g.moveLeft()) {}
      expect(g.currentPiece!.cells.map((c) => c.col).reduce(min), 0);
      expect(g.moveLeft(), isFalse);
      while (g.moveRight()) {}
      expect(g.currentPiece!.cells.map((c) => c.col).reduce(max), 9);
      final h = mk(rows: ['..........', '.........1'.replaceAll('1', '1')]);
      h.hardDrop();
      expect(h.piecesPlaced, 1);
    });
  });

  // The first [n] piece types a game deals; the well is emptied between drops.
  List<PieceType> pieceStream(BlockfallGame g, int n) {
    final out = <PieceType>[];
    while (out.length < n) {
      out.add(g.currentPiece!.type!);
      g.well.clearRowRange(0, Well.totalRows);
      g.hardDrop();
    }
    return out;
  }

  group('bag and next queue (criteria 9-10)', () {
    test('seeded: every bag of 7 holds each type exactly once', () {
      for (final seed in [1, 2, 3, 42, 999]) {
        final types = pieceStream(BlockfallGame.seeded(seed), 14);
        for (final bag in [types.sublist(0, 7), types.sublist(7)]) {
          expect(bag.toSet(), hasLength(7), reason: 'seed $seed');
        }
      }
    });

    test('level 1 picks the Bar for a one-wide four-deep gap', () {
      for (final seed in [1, 2, 3, 42, 999]) {
        final g = BlockfallGame.seeded(
          seed,
          well: Well.fromRows(List.filled(4, '1111.11111')),
        );
        expect(g.currentPiece!.type, PieceType.bar, reason: 'seed $seed');
      }
    });

    test('level 9 and up equals the plain bag order for the same seed', () {
      for (final seed in [1, 2, 3, 42, 999]) {
        for (final lines in [80, 150]) {
          final g = BlockfallGame.seeded(
            seed,
            startLines: lines,
            well: Well.fromRows(List.filled(4, '1111.11111')),
          );
          final bag = PieceBag(Random(seed));
          expect(pieceStream(g, 14), [...bag.nextBag(), ...bag.nextBag()]);
        }
      }
    });

    test('never more than 12 pieces between two copies of a type', () {
      for (var seed = 0; seed < 20; seed++) {
        for (final lines in [0, 30, 60, 80]) {
          final types = pieceStream(
            BlockfallGame.seeded(seed, startLines: lines),
            140,
          );
          for (final t in PieceType.values) {
            final idx = [
              for (var i = 0; i < types.length; i++)
                if (types[i] == t) i,
            ];
            for (var i = 1; i < idx.length; i++) {
              expect(idx[i] - idx[i - 1] - 1, lessThanOrEqualTo(12));
            }
          }
        }
      }
    });

    test('fit probability fades from 1 at level 1 to 0 at level 9', () {
      expect(fitProbability(1), 1);
      expect(fitProbability(5), 0.5);
      expect(fitProbability(9), 0);
      expect(fitProbability(20), 0);
    });

    test('same type never more than 12 pieces apart', () {
      final bag = PieceBag(Random(5));
      final seq = [for (var i = 0; i < 50; i++) ...bag.nextBag()];
      for (final t in PieceType.values) {
        final idx = [
          for (var i = 0; i < seq.length; i++)
            if (seq[i] == t) i,
        ];
        for (var i = 1; i < idx.length; i++) {
          expect(idx[i] - idx[i - 1], lessThanOrEqualTo(13));
        }
      }
    });

    test('next queue always has 3 pieces', () {
      final g = BlockfallGame.seeded(11);
      for (var i = 0; i < 30 && !g.isGameOver; i++) {
        expect(g.next, hasLength(3));
        g.hardDrop();
        if (i % 3 == 0) g.moveLeft();
      }
    });

    test('same seed gives the same sequence incl. prism placement', () {
      String dump(BlockfallGame g) =>
          [g.currentPiece!.spec, ...g.upcoming].join('|');
      expect(dump(BlockfallGame.seeded(8)), dump(BlockfallGame.seeded(8)));
      expect(
        dump(BlockfallGame.seeded(8)) == dump(BlockfallGame.seeded(9)),
        isFalse,
      );
    });
  });

  group('hold (criterion 8)', () {
    test('first hold stores the piece and spawns the next', () {
      final g = mk(seq: [PieceType.bar, PieceType.cube, PieceType.zig]);
      final nextType = g.next.first.type;
      expect(g.holdPiece, isNull);
      expect(g.hold(), isTrue);
      expect(g.holdPiece!.type, PieceType.bar);
      expect(g.currentPiece!.type, nextType);
      expect(g.holdsUsed, 1);
    });

    test('second hold before locking is ignored; works again after a lock', () {
      final g = mk(seq: [PieceType.bar, PieceType.cube, PieceType.zig]);
      g.hold();
      final cur = g.currentPiece!.type;
      expect(g.hold(), isFalse);
      expect(g.currentPiece!.type, cur);
      expect(g.holdPiece!.type, PieceType.bar);
      g.hardDrop();
      expect(g.canHold, isTrue);
      final falling = g.currentPiece!.type;
      expect(g.hold(), isTrue);
      expect(g.currentPiece!.type, PieceType.bar);
      expect(g.currentPiece!.rotation, 0);
      expect(g.holdPiece!.type, falling);
    });

    test('the swapped-in piece respawns at the top in rotation 0', () {
      final g = mk(seq: [PieceType.prong, PieceType.zig]);
      g.hold(); // prong held, zig falls
      g.hardDrop();
      g.rotate();
      expect(g.currentPiece!.rotation, 1);
      // locked once, so hold is available again
      g.hardDrop();
      expect(g.hold(), isTrue);
      expect(g.currentPiece!.type, PieceType.prong);
      expect(g.currentPiece!.rotation, 0);
      expect(g.currentPiece!.row, 0);
      expect(g.currentPiece!.col, 3);
    });

    test('the flag resets on lock only, not on swap', () {
      final g = mk(seq: [PieceType.bar, PieceType.cube]);
      g.hold();
      expect(g.canHold, isFalse);
      g.moveLeft();
      expect(g.canHold, isFalse);
      g.tick(0.1);
      expect(g.canHold, isFalse);
    });
  });

  group('gravity (criterion 11)', () {
    test('table values and caps', () {
      expect(secondsPerRowForLevel(1), 1.0);
      expect(secondsPerRowForLevel(2), 0.80);
      expect(secondsPerRowForLevel(10), 0.12);
      expect(secondsPerRowForLevel(15), 0.04);
      expect(secondsPerRowForLevel(20), 0.04);
      expect(secondsPerRowForLevel(99), 0.04);
      expect(gravityTable, hasLength(15));
      for (var i = 1; i < gravityTable.length; i++) {
        expect(gravityTable[i], lessThan(gravityTable[i - 1]));
      }
    });

    test('soft drop is 20x gravity with a 0.03 s minimum', () {
      expect(softDropStep(1.0), 0.05);
      expect(softDropStep(0.04), 0.03);
      expect(softDropStep(0.8), closeTo(0.04, 1e-12));
    });

    test('the piece falls one row per step and speeds up on level up', () {
      final g = mk();
      g.tick(0.99);
      expect(g.currentPiece!.row, 0);
      g.tick(0.02);
      expect(g.currentPiece!.row, 1);
      for (var i = 0; i < 10; i++) {
        for (var c = 0; c < 10; c++) {
          if (c < 3 || c > 6) g.well.set(21, c, 1);
        }
        g.hardDrop();
      }
      expect(g.level, 2);
      final row = g.currentPiece!.row;
      g.tick(0.79);
      expect(g.currentPiece!.row, row);
      g.tick(0.02);
      expect(g.currentPiece!.row, row + 1);
    });

    test('a long tick processes many rows and the lock', () {
      final g = mk();
      g.tick(100);
      expect(g.piecesPlaced, greaterThanOrEqualTo(1));
    });

    test('pause stops gravity and the lock timer', () {
      final g = mk();
      g.isPaused = true;
      g.tick(50);
      expect(g.currentPiece!.row, 0);
      expect(g.moveLeft(), isFalse);
      g.isPaused = false;
      g.tick(1.0);
      expect(g.currentPiece!.row, 1);
    });
  });

  group('lock delay (criterion 12)', () {
    test('a resting piece locks after 0.5 s', () {
      final g = mk(rows: ['1111111111', '1111111111']);
      // Spawn row 0-1, floor far below: ground it with soft drop.
      g.softDrop(true);
      g.tick(
        0.05 * 18,
      ); // bar from row 0 to the row above the floor (rows 20-21)
      g.softDrop(false);
      expect(g.piecesPlaced, 0);
      expect(g.lockTimeLeft, closeTo(0.5, 1e-6));
      g.tick(0.49);
      expect(g.piecesPlaced, 0);
      g.tick(0.02);
      expect(g.piecesPlaced, 1);
    });

    test(
      'moves restart the timer up to 10 times, then it stops restarting',
      () {
        final g = mk(rows: ['1111111111', '1111111111']);
        g.softDrop(true);
        g.tick(0.05 * 18);
        g.softDrop(false);
        for (var i = 0; i < 10; i++) {
          g.tick(0.4);
          expect(g.piecesPlaced, 0, reason: 'restart $i');
          expect(i.isEven ? g.moveLeft() : g.moveRight(), isTrue);
          expect(g.lockRestartsUsed, i + 1);
        }
        g.tick(0.4);
        expect(g.moveLeft(), isTrue); // still moves, but no restart
        expect(g.lockRestartsUsed, 10);
        g.tick(0.11);
        expect(g.piecesPlaced, 1);
      },
    );

    test('falling to a lower row resets the restart count', () {
      // A ledge on the right: the bar rests on it, slides off and falls to the floor.
      final g = mk(
        rows: [
          '......1111',
          for (var i = 0; i < 8; i++) '..........',
          '111111111.',
        ],
      );
      g.softDrop(true);
      g.tick(0.05 * 10); // row 0 -> row 10, resting on the ledge (row 12)
      g.softDrop(false);
      expect(g.lockTimeLeft, closeTo(0.5, 1e-6));
      for (var i = 0; i < 3; i++) {
        mustSucceed(g.moveRight());
      }
      expect(g.lockRestartsUsed, 3);
      for (var i = 0; i < 4; i++) {
        mustSucceed(g.moveLeft());
      }
      expect(g.lockRestartsUsed, 6);
      g.tick(9.0); // falls from the ledge to the floor
      expect(g.piecesPlaced, 0);
      expect(g.lockRestartsUsed, 0);
    });

    test('hard drop locks instantly', () {
      final g = mk();
      g.hardDrop();
      expect(g.piecesPlaced, 1);
    });
  });

  group('rotation (criterion 13)', () {
    test('each kick offset is tried in order', () {
      const kicks = [(0, 0), (-1, 0), (1, 0), (0, -1), (-2, 0), (2, 0)];
      for (var k = 0; k < kicks.length; k++) {
        final g = mk(seq: [PieceType.prong]);
        g.tick(3.0); // origin row 3 so the "up" kick is possible
        final p = g.currentPiece!;
        final turned = p.rotatedClockwise();
        Set<(int, int)> cellsOf(ActivePiece a) =>
            a.cells.map((c) => (c.row, c.col)).toSet();
        final target = cellsOf(turned.shifted(kicks[k].$1, kicks[k].$2));
        final own = cellsOf(p);
        for (var i = 0; i < k; i++) {
          final cand = cellsOf(turned.shifted(kicks[i].$1, kicks[i].$2));
          final blocker = cand.firstWhere(
            (c) => !target.contains(c) && !own.contains(c),
          );
          g.well.set(blocker.$1, blocker.$2, 7);
        }
        expect(g.rotate(), isTrue, reason: 'kick $k');
        expect(g.currentPiece!.rotation, 1);
        expect(g.currentPiece!.col, p.col + kicks[k].$1, reason: 'kick $k');
        expect(g.currentPiece!.row, p.row + kicks[k].$2, reason: 'kick $k');
      }
    });

    test(
      'the bar at the left wall rotates with a kick and stays in bounds',
      () {
        final g = mk();
        g.tick(2.0);
        mustSucceed(g.rotate()); // vertical
        while (g.moveLeft()) {}
        expect(g.currentPiece!.cells.map((c) => c.col).toSet(), {0});
        expect(g.currentPiece!.col, lessThan(0)); // box sticks out of the well
        expect(g.rotate(), isTrue); // horizontal needs a +2 kick
        expect(g.currentPiece!.rotation, 2);
        final cols = g.currentPiece!.cells.map((c) => c.col).toList()..sort();
        expect(cols, [0, 1, 2, 3]);
      },
    );

    test('the bar at the right wall also kicks', () {
      final g = mk();
      g.tick(2.0);
      mustSucceed(g.rotate());
      while (g.moveRight()) {}
      expect(g.rotate(), isTrue);
      final cols = g.currentPiece!.cells.map((c) => c.col).toList()..sort();
      expect(cols.last, lessThanOrEqualTo(9));
      expect(cols.first, greaterThanOrEqualTo(0));
    });

    test('if no offset fits the state is unchanged', () {
      final g = mk(seq: [PieceType.prong], rows: ['1111111111']);
      // Row 2 (just below the spawn) is full-width: nothing fits below.
      final w = Well();
      for (var c = 0; c < 10; c++) {
        w.set(2, c, 1);
      }
      final h = mk(seq: [PieceType.prong], well: w);
      final before = h.currentPiece!;
      expect(h.rotate(), isFalse);
      expect(h.currentPiece!.rotation, before.rotation);
      expect(h.currentPiece!.col, before.col);
      expect(h.currentPiece!.row, before.row);
      expect(g.currentPiece, isNotNull);
    });

    test('the cube never changes', () {
      final g = mk(seq: [PieceType.cube]);
      final before = g.currentPiece!.cells;
      expect(g.rotate(), isFalse);
      expect(g.currentPiece!.cells, before);
      expect(g.currentPiece!.rotation, 0);
    });

    test('rotation is clockwise only and cycles through 4 states', () {
      final g = mk(seq: [PieceType.hook]);
      g.tick(3.0);
      for (var i = 1; i <= 4; i++) {
        mustSucceed(g.rotate());
        expect(g.currentPiece!.rotation, i % 4);
      }
    });
  });

  group('ghost', () {
    test('the ghost is where a hard drop lands', () {
      final g = mk(rows: ['111111111.']);
      final ghost = g.ghostPiece!;
      expect(ghost.cells.map((c) => c.row).toSet(), {20});
      g.hardDrop();
      expect(g.well.isFilled(20, 3), isTrue);
    });
  });

  group('game over (criterion 14)', () {
    test('block out: a filled spawn cell ends the game at spawn', () {
      final w = Well()..set(1, 4, 3);
      final g = mk(seq: [PieceType.prong], well: w);
      expect(g.isGameOver, isTrue);
      expect(g.gameOverReason, GameOverReason.blockOut);
      expect(g.currentPiece, isNull);
      expect(g.drainEvents().whereType<GameOver>(), hasLength(1));
      expect(g.moveLeft(), isFalse);
      expect(g.hardDrop(), 0);
    });

    test('block out on the next spawn after a lock', () {
      final w = Well();
      for (var r = 3; r < 22; r++) {
        for (var c = 4; c <= 5; c++) {
          w.set(r, c, 2);
        }
      }
      final g = mk(seq: [PieceType.cube], well: w);
      expect(g.isGameOver, isFalse);
      g.hardDrop(); // cube locks in rows 1-2
      expect(g.isGameOver, isTrue);
      expect(g.gameOverReason, GameOverReason.blockOut);
    });

    test('lock out: a piece locked fully in the hidden rows ends the game', () {
      final w = Well();
      for (var r = 2; r < 22; r++) {
        for (var c = 3; c <= 6; c++) {
          w.set(r, c, 2);
        }
      }
      final g = mk(well: w);
      expect(g.isGameOver, isFalse);
      g.hardDrop();
      expect(g.isGameOver, isTrue);
      expect(g.gameOverReason, GameOverReason.lockOut);
    });

    test('a resting piece also locks out via the lock timer', () {
      final w = Well();
      for (var r = 2; r < 22; r++) {
        for (var c = 3; c <= 6; c++) {
          w.set(r, c, 2);
        }
      }
      final g = mk(well: w);
      g.tick(0.6);
      expect(g.isGameOver, isTrue);
      g.tick(5);
      expect(g.piecesPlaced, 1);
    });

    test('the well fits the spec dimensions', () {
      expect(Well.cols, 10);
      expect(Well.visibleRows, 20);
      expect(Well.hiddenRows, 2);
      expect(Well.totalRows, 22);
    });
  });

  group('soft drop latch', () {
    test('soft drop stays on the current piece until released', () {
      final g = mk();
      g.softDrop(true);
      expect(g.isSoftDropping, isTrue);
      g.hardDrop(); // current piece locks, next spawns
      expect(g.isSoftDropping, isFalse);
      g.softDrop(true); // finger still down: move events keep re-asserting
      expect(g.isSoftDropping, isFalse);
      final row = g.currentPiece!.row;
      g.tick(0.5);
      expect(g.currentPiece!.row - row, lessThanOrEqualTo(1));
      g.softDrop(false); // finger lifted
      g.softDrop(true); // new gesture
      expect(g.isSoftDropping, isTrue);
    });
  });
}
