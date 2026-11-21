import 'package:flutter_test/flutter_test.dart';
import 'package:game_blockfall/src/game/rules/bag.dart';
import 'package:game_blockfall/src/game/rules/blockfall_game.dart';
import 'package:game_blockfall/src/game/rules/blockfall_versus.dart';
import 'package:game_blockfall/src/game/rules/piece_type.dart';
import 'package:game_blockfall/src/game/rules/powerups.dart';
import 'package:game_blockfall/src/game/rules/well.dart';

/// Hard-drops [p]'s pieces [n] times at the spawn column.
void drop(BlockfallVersus v, int p, int n) {
  for (var i = 0; i < n; i++) {
    v.hardDrop(p);
  }
}

void main() {
  group('garbage amounts', () {
    test('single none, double 1, triple 2, quad 4, back-to-back quad 5', () {
      expect(garbageForLines(1), 0);
      expect(garbageForLines(2), 1);
      expect(garbageForLines(3), 2);
      expect(garbageForLines(4), 4);
      expect(garbageForLines(4, backToBack: true), 5);
      expect(garbageForLines(0), 0);
    });
  });

  group('two fair wells', () {
    test('both wells get the same pieces in the same order', () {
      final v = BlockfallVersus(seed: 11);
      final a = v.game(1), b = v.game(2);
      for (var i = 0; i < 12; i++) {
        expect(a.currentPiece!.type, b.currentPiece!.type, reason: 'piece $i');
        expect(
          [for (final s in a.next) s.type],
          [for (final s in b.next) s.type],
        );
        a.hardDrop();
        b.hardDrop();
        a.drainEvents();
        b.drainEvents();
        if (a.isGameOver || b.isGameOver) break;
      }
    });

    test('power-ups, prisms, boom and gold are off', () {
      final v = BlockfallVersus(seed: 3);
      for (final p in [1, 2]) {
        final g = v.game(p);
        for (final t in PowerUpType.values) {
          expect(g.stock(t), 0);
        }
        expect(g.prismInterval, 0);
        expect(g.boomInterval, 0);
        expect(g.goldInterval, 0);
        for (final s in [...g.next]) {
          expect(s.prismCell ?? s.boomCell ?? s.goldCell, isNull);
        }
      }
    });

    test('each player\'s commands move only their well', () {
      final v = BlockfallVersus(seed: 5);
      final c1 = v.game(1).currentPiece!.col, c2 = v.game(2).currentPiece!.col;
      v.moveLeft(1);
      expect(v.game(1).currentPiece!.col, c1 - 1);
      expect(v.game(2).currentPiece!.col, c2);
      v.moveRight(2);
      expect(v.game(2).currentPiece!.col, c2 + 1);
      expect(v.game(1).currentPiece!.col, c1 - 1);
    });

    test('hold works once per piece in each well', () {
      final v = BlockfallVersus(seed: 5);
      expect(v.hold(1), isTrue);
      expect(v.hold(1), isFalse);
      expect(v.hold(2), isTrue);
    });
  });

  group('the clock', () {
    test('the level rises every 45 seconds of play in both wells', () {
      final v = BlockfallVersus(seed: 1);
      expect(v.level, 1);
      v.tick(44);
      expect(v.level, 1);
      v.tick(2);
      expect(v.level, 2);
      expect(v.game(1).level, 2);
      expect(v.game(2).level, 2);
      v.tick(90);
      expect(v.level, 4);
    });

    test('a paused game does not move or age', () {
      final v = BlockfallVersus(seed: 1);
      v.pause();
      final row = v.game(1).currentPiece!.row;
      v.tick(10);
      expect(v.elapsed, 0);
      expect(v.game(1).currentPiece!.row, row);
      expect(v.moveLeft(1), isFalse);
      expect(v.hardDrop(1), 0);
      v.resume();
      v.tick(1);
      expect(v.elapsed, 1);
    });
  });

  group('garbage in the well', () {
    test('rows rise from the bottom, full except one hole', () {
      final g = BlockfallGame(
        bag: PieceBag.sequence([PieceType.cube]),
        stock: {for (final t in PowerUpType.values) t: 0},
      );
      expect(g.well.isEmpty, isTrue);
      expect(g.receiveGarbage(2, 4), isFalse);
      for (final r in [Well.totalRows - 1, Well.totalRows - 2]) {
        for (var c = 0; c < Well.cols; c++) {
          expect(g.well.isFilled(r, c), c != 4, reason: 'row $r col $c');
        }
      }
      expect(g.well.isFilled(Well.totalRows - 3, 0), isFalse);
    });

    test('an existing stack is pushed up', () {
      final g = BlockfallGame(
        bag: PieceBag.sequence([PieceType.cube]),
        well: Well.fromRows(['1.........']),
      );
      final top = Well.totalRows - 1;
      expect(g.well.isFilled(top, 0), isTrue);
      g.receiveGarbage(1, 9);
      expect(g.well.colorAt(top - 1, 0), 1); // the old row moved up one
      expect(g.well.isFilled(top, 0), isTrue); // garbage below it
      expect(g.well.isFilled(top, 9), isFalse); // the hole
    });

    test('pushing the stack over the top ends the game', () {
      final rows = List.filled(Well.totalRows, '111111111.');
      final g = BlockfallGame(
        bag: PieceBag.sequence([PieceType.cube]),
        well: Well.fromRows(rows.sublist(4)),
      );
      expect(g.isGameOver, isFalse);
      expect(g.receiveGarbage(3, 0), isTrue);
      expect(g.isGameOver, isTrue);
    });

    test('the falling piece is lifted clear of the new rows', () {
      final g = BlockfallGame(bag: PieceBag.sequence([PieceType.cube]));
      for (var i = 0; i < 40; i++) {
        g.tick(0.5); // let it fall to the bottom
        if (g.currentPiece == null) break;
        if (g.currentPiece!.row >= Well.totalRows - 3) break;
      }
      g.receiveGarbage(2, 0);
      final p = g.currentPiece;
      if (p != null) {
        for (final c in p.cells) {
          expect(g.well.isFilled(c.row, c.col), isFalse);
        }
      }
    });

    test('a normal game is untouched: no forced level', () {
      final g = BlockfallGame.seeded(1);
      expect(g.forcedLevel, 0);
      expect(g.level, 1);
    });
  });

  group('sending and receiving', () {
    /// Two wells that both get cubes (2 x 2), so a drop at the spawn column can clear two rows.
    BlockfallVersus cubes() => BlockfallVersus(
      seed: 21,
      bagFor: () => PieceBag.sequence([PieceType.cube]),
    );

    /// Fills the bottom [rows] rows of [p]'s well except the columns of its falling piece, so
    /// dropping it straight down clears them.
    void setUp(BlockfallVersus v, int p, int rows) {
      final g = v.game(p);
      final gap = {for (final c in g.currentPiece!.cells) c.col};
      for (var r = Well.totalRows - rows; r < Well.totalRows; r++) {
        for (var c = 0; c < Well.cols; c++) {
          g.well.set(r, c, gap.contains(c) ? 0 : 1);
        }
      }
    }

    test('a double sends one garbage row to the other player', () {
      final v = cubes();
      setUp(v, 1, 2);
      v.hardDrop(1);
      expect(v.pendingFor(2), 1);
      expect(v.pendingFor(1), 0);
    });

    test('a single sends nothing', () {
      final v = cubes();
      setUp(v, 1, 1);
      v.hardDrop(
        1,
      ); // the cube fills one row's gap and half of the next: one line
      expect(v.pendingFor(2), 0);
    });

    test('garbage rises after the receiver\'s next lock, not before', () {
      final v = cubes();
      setUp(v, 1, 2);
      v.hardDrop(1);
      expect(v.pendingFor(2), 1);
      expect(v.game(2).well.isEmpty, isTrue); // not yet
      v.hardDrop(2); // a lock with no clear
      expect(v.pendingFor(2), 0);
      // the receiver's cube is on the floor over one garbage row: five cells high is not possible;
      // the bottom row is garbage with a single hole
      final bottom = Well.totalRows - 1;
      var holes = 0;
      for (var c = 0; c < Well.cols; c++) {
        if (!v.game(2).well.isFilled(bottom, c)) holes++;
      }
      expect(holes, 1);
    });

    test('a clear first cancels the garbage waiting for the clearer', () {
      final v = cubes();
      setUp(v, 1, 2);
      v.hardDrop(1); // player 2 now has 1 waiting
      setUp(v, 2, 2);
      v.hardDrop(
        2,
      ); // player 2 clears a double: sends 1, cancelling the 1 waiting for them
      expect(v.pendingFor(2), 0);
      expect(v.pendingFor(1), 0);
    });
  });

  group('winning', () {
    test('a player who tops out loses, the other wins', () {
      final v = BlockfallVersus(seed: 2);
      expect(v.winner, isNull);
      var guard = 0;
      while (v.winner == null && guard++ < 80) {
        v.hardDrop(1);
      }
      expect(v.winner, 2);
      expect(v.isOver, isTrue);
    });

    test('after the game is decided nothing moves', () {
      final v = BlockfallVersus(seed: 2);
      var guard = 0;
      while (v.winner == null && guard++ < 80) {
        v.hardDrop(1);
      }
      final row = v.game(2).currentPiece?.row;
      v.tick(5);
      expect(v.moveLeft(2), isFalse);
      expect(v.game(2).currentPiece?.row, row);
    });

    test('both wells over at once is a draw', () {
      final v = BlockfallVersus(seed: 2);
      v.game(1).receiveGarbage(Well.totalRows, 0);
      expect(v.winner, 2);
      // a second well over makes it a draw only if it happens before the verdict is read
      final w = BlockfallVersus(seed: 2);
      w.game(1).receiveGarbage(Well.totalRows, 0);
      w.game(2).receiveGarbage(Well.totalRows, 0);
      expect(w.winner, 0);
    });
  });

  group('level floor', () {
    test('forcedLevel raises gravity, lines still can too', () {
      final g = BlockfallGame.seeded(1)..forcedLevel = 5;
      expect(g.level, 5);
      expect(g.secondsPerRow, lessThan(BlockfallGame.seeded(1).secondsPerRow));
    });
  });
}
