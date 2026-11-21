import 'dart:io';
import 'dart:math';

import 'package:game_blockfall/src/game/rules/blockfall_game.dart';
import 'package:game_blockfall/src/game/rules/events.dart';
import 'package:game_blockfall/src/game/rules/piece_type.dart';
import 'package:game_blockfall/src/game/rules/powerups.dart';
import 'package:game_blockfall/src/game/rules/well.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('Sweep (criterion 15)', () {
    test('removes the bottom 3 rows, +3 lines, no score, no coins', () {
      final g = mk(
        rows: [
          '1.........',
          '2.........',
          '33a.......',
          '4444444444',
          '.5'.padRight(10, '.'),
        ],
      );
      // Rows (bottom-aligned): 17 '1', 18 '2', 19 prism row, 20 full, 21 '.5'
      expect(g.usePowerUp(PowerUpType.sweep), PowerUpResult.ok);
      expect(g.lines, 3);
      expect(g.score, 0);
      expect(g.coinsFromPrisms, 0);
      expect(g.combo, 0);
      expect(g.stock(PowerUpType.sweep), 0);
      // Everything above fell by 3 rows.
      expect(g.well.colorAt(20, 0), 1);
      expect(g.well.colorAt(21, 0), 2);
      expect(g.well.isFilled(19, 0), isFalse);
      expect(g.well.prismCountInRow(21), 0);
      expect(
        g.drainEvents().whereType<PowerUpUsed>().single.type,
        PowerUpType.sweep,
      );
    });

    test('sweep lines count towards the goal and level', () {
      final g = mk(stock: {PowerUpType.sweep: 3});
      for (var i = 0; i < 3; i++) {
        g.usePowerUp(PowerUpType.sweep);
      }
      expect(g.lines, 9);
      expect(g.goal, 1);
      expect(g.level, 1);
      g.addStock(PowerUpType.bomb, 0);
      expect(g.stock(PowerUpType.bomb), 1); // zero adds nothing
    });

    test('sweep does not touch combo or back-to-back', () {
      final g = mk(rows: ['7.........', gap3to6, gap3to6]);
      g.hardDrop();
      expect(g.combo, 1);
      g.usePowerUp(PowerUpType.sweep);
      expect(g.combo, 1);
    });
  });

  group('Slow (criterion 15)', () {
    test('doubles seconds per row for 20 s of game time', () {
      final g = mk();
      expect(g.usePowerUp(PowerUpType.slow), PowerUpResult.ok);
      expect(g.slowActive, isTrue);
      expect(g.secondsPerRow, 2.0);
      g.tick(1.9);
      expect(g.currentPiece!.row, 0);
      g.tick(0.2);
      expect(g.currentPiece!.row, 1);
      g.tick(17.9); // 20.0 s total
      expect(g.slowActive, isFalse);
      expect(g.secondsPerRow, 1.0);
    });

    test('the timer stops while paused', () {
      final g = mk();
      g.usePowerUp(PowerUpType.slow);
      g.tick(5);
      final left = g.slowRemaining;
      g.isPaused = true;
      g.tick(100);
      expect(g.slowRemaining, left);
      g.isPaused = false;
      g.tick(1);
      expect(g.slowRemaining, closeTo(left - 1, 1e-9));
    });

    test('using it while active is refused and costs nothing', () {
      final g = mk(stock: {PowerUpType.slow: 2});
      g.usePowerUp(PowerUpType.slow);
      expect(g.usePowerUp(PowerUpType.slow), PowerUpResult.alreadyActive);
      expect(g.stock(PowerUpType.slow), 1);
      expect(g.usesThisGame(PowerUpType.slow), 1);
    });

    test('gravity switches back exactly when slow ends inside one tick', () {
      final g = mk();
      g.usePowerUp(PowerUpType.slow);
      g.tick(
        20.0 + 1.0,
      ); // 20 s at 2.0 s/row = 10 rows, then 1 s at 1.0 s/row = 1 row
      expect(g.currentPiece!.row, 11);
    });
  });

  group('Bomb (criterion 15)', () {
    test(
      'replaces the piece with a single cell and clears the 3x3 on landing',
      () {
        final g = mk(
          rows: [
            '....7.....', // row 18, above the blast area: stays
            '....7.....', // row 19
            '...777....', // row 20
            '3333333333', // row 21 (full)
          ],
        );
        expect(g.usePowerUp(PowerUpType.bomb), PowerUpResult.ok);
        expect(g.currentPiece!.isBomb, isTrue);
        expect(g.currentPiece!.cells, hasLength(1));
        expect(g.currentPiece!.col, 4);
        final before = g.score;
        g.hardDrop();
        // Bomb rested on row 19 col 4 (row 19/col 4 filled) -> lands at row 17.
        expect(g.score, before); // no score at all
        expect(g.lines, 0);
        expect(g.currentPiece!.isBomb, isFalse); // next piece spawned
        expect(g.drainEvents().whereType<BombExploded>(), hasLength(1));
        // 3x3 around (17,4): rows 16..18, cols 3..5. Row 18 col 4 is gone.
        expect(g.well.isFilled(18, 4), isFalse);
        expect(g.well.isFilled(19, 4), isTrue); // below the blast, unmoved
        expect(g.well.isFilled(21, 4), isTrue);
      },
    );

    test('rows left full or emptied are not collapsed or cleared', () {
      final g = mk(
        rows: [
          '1111111111', // row 20, not touched by the blast (rows 18..20? see below)
          '1111111111',
        ],
      );
      g.usePowerUp(PowerUpType.bomb);
      g.hardDrop(); // lands at row 19, blast rows 18..20, cols 3..5
      expect(g.lines, 0);
      expect(g.well.isFilled(20, 4), isFalse);
      expect(g.well.isFilled(21, 4), isTrue);
      expect(g.well.isFilled(21, 0), isTrue);
    });

    test('pays no prism coins and leaves no cell behind', () {
      final g = mk(rows: ['aaaaaaaaaa', 'aaaaaaaaaa']);
      g.usePowerUp(PowerUpType.bomb);
      g.hardDrop();
      expect(g.coinsFromPrisms, 0);
      var cells = 0;
      for (var r = 0; r < Well.totalRows; r++) {
        for (var c = 0; c < Well.cols; c++) {
          if (g.well.isFilled(r, c)) cells++;
        }
      }
      expect(cells, 20 - 3); // blast covers rows 18-20: 3 cells of row 20
    });

    test('cannot be used while a bomb is already falling', () {
      final g = mk(stock: {PowerUpType.bomb: 3});
      g.usePowerUp(PowerUpType.bomb);
      expect(g.usePowerUp(PowerUpType.bomb), PowerUpResult.notAllowed);
      expect(g.stock(PowerUpType.bomb), 2);
    });

    test('a bomb does not rotate and cannot be held', () {
      final g = mk();
      g.usePowerUp(PowerUpType.bomb);
      expect(g.rotate(), isFalse);
      expect(g.hold(), isFalse);
    });
  });

  group('limits and stock (criterion 15)', () {
    test('a 4th use of one type in a game is refused', () {
      final g = mk(stock: {PowerUpType.sweep: 9});
      for (var i = 0; i < 3; i++) {
        expect(g.usePowerUp(PowerUpType.sweep), PowerUpResult.ok);
      }
      expect(g.usePowerUp(PowerUpType.sweep), PowerUpResult.limitReached);
      expect(g.stock(PowerUpType.sweep), 6);
      expect(g.usesThisGame(PowerUpType.sweep), 3);
      // Other types keep their own counter.
      expect(g.usePowerUp(PowerUpType.slow), PowerUpResult.ok);
    });

    test('stock never goes negative', () {
      final g = mk(stock: {PowerUpType.bomb: 0});
      expect(g.usePowerUp(PowerUpType.bomb), PowerUpResult.noStock);
      expect(g.stock(PowerUpType.bomb), 0);
      expect(g.currentPiece!.isBomb, isFalse);
    });

    test('default stock is 1 of each, prices are 60/40/50', () {
      final g = mk();
      for (final t in PowerUpType.values) {
        expect(g.stock(t), 1);
      }
      expect(PowerUpType.sweep.price, 60);
      expect(PowerUpType.slow.price, 40);
      expect(PowerUpType.bomb.price, 50);
    });

    test('rewarded refills: +1 each, at most 3 per game', () {
      final g = mk(stock: {PowerUpType.sweep: 0});
      expect(g.refillWithAd(PowerUpType.sweep), isTrue);
      expect(g.refillWithAd(PowerUpType.sweep), isTrue);
      expect(g.refillWithAd(PowerUpType.slow), isTrue);
      expect(g.adRefillsLeft, 0);
      expect(g.refillWithAd(PowerUpType.bomb), isFalse);
      expect(g.stock(PowerUpType.sweep), 2);
      expect(g.stock(PowerUpType.slow), 2);
      expect(g.stock(PowerUpType.bomb), 1);
    });

    test('power-ups are refused after game over and while paused', () {
      final g = mk();
      g.isPaused = true;
      expect(g.usePowerUp(PowerUpType.slow), PowerUpResult.notAllowed);
      expect(g.stock(PowerUpType.slow), 1);
    });
  });

  group('revive (criterion 16)', () {
    BlockfallGame lockedOut() {
      final w = Well();
      for (var r = 2; r < 22; r++) {
        for (var c = 3; c <= 6; c++) {
          w.set(r, c, 2);
        }
      }
      w.set(21, 0, 5);
      return mk(well: w);
    }

    test(
      'available exactly once: top 8 rows cleared, score and level kept',
      () {
        final g = lockedOut();
        expect(g.canRevive, isFalse); // not over yet
        g.hardDrop();
        expect(g.isGameOver, isTrue);
        expect(g.canRevive, isTrue);
        final score = g.score;
        final level = g.level;
        expect(g.revive(), isTrue);
        expect(g.isGameOver, isFalse);
        expect(g.currentPiece, isNotNull);
        expect(g.score, score);
        expect(g.level, level);
        for (var r = 0; r < 8; r++) {
          for (var c = 0; c < Well.cols; c++) {
            expect(g.well.isFilled(r, c), isFalse, reason: '($r,$c)');
          }
        }
        expect(g.well.isFilled(8, 3), isTrue); // below the top 8 rows
        expect(g.drainEvents().whereType<Revived>(), hasLength(1));
        expect(g.reviveUsed, isTrue);
      },
    );

    test('up to three revives per run, then none', () {
      final g = lockedOut();
      g.hardDrop();
      expect(g.revivesRemaining, 3);
      for (var i = 0; i < 3; i++) {
        expect(g.canRevive, isTrue, reason: 'revive $i');
        expect(g.revive(), isTrue);
        expect(g.revivesRemaining, 2 - i);
        for (var r = 2; r < 22; r++) {
          for (var c = 3; c <= 6; c++) {
            g.well.set(r, c, 2);
          }
        }
        g.hardDrop();
        expect(g.isGameOver, isTrue);
      }
      expect(g.canRevive, isFalse);
      expect(g.revive(), isFalse);
      expect(g.isGameOver, isTrue);
    });

    test('a new game starts with three revives again', () {
      final g = lockedOut();
      g.hardDrop();
      g.revive();
      expect(mk().revivesRemaining, 3);
    });

    test('revive after a block out re-spawns the piece that did not fit', () {
      final w = Well();
      for (var r = 3; r < 22; r++) {
        w.set(r, 4, 2);
        w.set(r, 5, 2);
      }
      final g = mk(seq: [PieceType.cube, PieceType.zig], well: w);
      g.hardDrop(); // cube locks in rows 1-2, zig can not spawn
      expect(g.gameOverReason, GameOverReason.blockOut);
      expect(g.revive(), isTrue);
      expect(g.currentPiece!.type, PieceType.zig);
    });

    test('revive is refused when the game is not over', () {
      final g = mk();
      expect(g.revive(), isFalse);
      expect(g.reviveUsed, isFalse);
    });
  });

  group('determinism', () {
    List<String> play(int seed) {
      final g = BlockfallGame.seeded(seed);
      final input = Random(seed + 100);
      final log = <String>[];
      for (var step = 0; step < 3000 && !g.isGameOver; step++) {
        switch (input.nextInt(9)) {
          case 0:
            g.moveLeft();
          case 1:
            g.moveRight();
          case 2:
            g.rotate();
          case 3:
            g.hold();
          case 4:
            g.hardDrop();
          case 5:
            g.softDrop(input.nextBool());
          case 6:
            g.usePowerUp(PowerUpType.values[input.nextInt(3)]);
          default:
            g.tick(input.nextDouble() * 0.6);
        }
        expect(g.score, greaterThanOrEqualTo(0));
        expect(g.next, hasLength(3));
        for (final e in g.drainEvents()) {
          log.add(e.runtimeType.toString());
        }
      }
      log
        ..add('score=${g.score}')
        ..add('lines=${g.lines}')
        ..add('pieces=${g.piecesPlaced}')
        ..addAll(g.well.toRows());
      return log;
    }

    test('the same seed and inputs replay identically', () {
      for (final seed in [1, 2, 3]) {
        expect(play(seed), play(seed));
      }
    });

    test('different seeds differ', () {
      expect(play(1), isNot(play(2)));
    });
  });

  group('purity', () {
    test(
      'lib/src/game/rules has no Flutter, Flame, dart:ui or dart:io imports',
      () {
        final files = Directory('lib/src/game/rules')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
        expect(files, isNotEmpty);
        final bad = RegExp(
          r'''import\s+['"](package:(flutter|flame)|dart:(ui|io|html))''',
        );
        for (final f in files) {
          expect(bad.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
          expect(
            f.readAsStringSync().contains('DateTime.now'),
            isFalse,
            reason: f.path,
          );
        }
      },
    );
  });
}
