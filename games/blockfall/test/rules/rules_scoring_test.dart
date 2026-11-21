import 'package:game_blockfall/src/game/rules/blockfall_game.dart';
import 'package:game_blockfall/src/game/rules/events.dart';
import 'package:game_blockfall/src/game/rules/piece_type.dart';
import 'package:game_blockfall/src/game/rules/scoring.dart';
import 'package:game_blockfall/src/game/rules/well.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('line clear (criteria 1-2)', () {
    test('a full bottom row clears, rows above shift down by 1, +100', () {
      final g = mk(rows: ['5.........', gap3to6]);
      final d = g.hardDrop();
      expect(d, 20);
      expect(g.lines, 1);
      expect(g.score, 100 + 2 * d);
      expect(g.well.colorAt(21, 0), 5); // marker fell by one row
      expect(g.well.isFilled(20, 0), isFalse);
      expect(g.well.isFilled(21, 4), isFalse);
    });

    test('doubles, triples and quads score 300, 500, 800 at level 1', () {
      final two = mk(
        rows: ['7.........', gap4to5, gap4to5],
        seq: [PieceType.cube],
      );
      final d2 = two.hardDrop();
      expect(two.score, 300 + 2 * d2);

      final three = mk(rows: ['.........7', gap0, gap0, gap0]);
      verticalBarAt(three, 0);
      final d3 = three.hardDrop();
      expect(three.lines, 3);
      expect(three.score, 500 + 2 * d3);

      final four = mk(rows: ['.........7', gap0, gap0, gap0, gap0]);
      verticalBarAt(four, 0);
      final d4 = four.hardDrop();
      expect(four.lines, 4);
      expect(four.score, 800 + 2 * d4);
    });

    test('line scores are multiplied by the level', () {
      expect(
        lineClearScore(rows: 3, prismRows: 0, level: 4, backToBack: false),
        2000,
      );
    });
  });

  group('prism (criterion 3)', () {
    test('a single with a prism scores 200 and pays 1 coin', () {
      final g = mk(rows: ['7.........', '11a....111']);
      final d = g.hardDrop();
      expect(g.score, 200 + 2 * d);
      expect(g.coinsFromPrisms, 1);
      final ev = g.drainEvents();
      expect(ev.whereType<PrismCoinsEarned>().single.coins, 1);
      expect(ev.whereType<LinesCleared>().single.prismRows, 1);
    });

    test('only the prism rows get the doubled share', () {
      // Triple with one prism row: 500 + 500/3 (rounded).
      expect(
        lineClearScore(rows: 3, prismRows: 1, level: 1, backToBack: false),
        500 + 167,
      );
      expect(
        lineClearScore(rows: 2, prismRows: 2, level: 1, backToBack: false),
        600,
      );
    });

    test('coins are capped at 40 per game; the score bonus is not', () {
      final g = mk(seq: [PieceType.cube]);
      g.well.set(5, 0, 7); // keeps the well from being empty (no perfect clear)
      final paid = <int>[];
      for (var i = 0; i < 3; i++) {
        for (final r in [20, 21]) {
          for (var c = 0; c < Well.cols; c++) {
            if (c == 4 || c == 5) continue;
            g.well.set(r, c, 1, prism: true);
          }
        }
        final before = g.score;
        final d = g.hardDrop();
        final ev = clears(g).single;
        paid.add(ev.prismCoins);
        expect(
          g.score - before,
          600 + 2 * d + 50 * i,
        ); // doubled even beyond the cap
      }
      expect(paid, [16, 16, 8]);
      expect(g.coinsFromPrisms, 40);
    });

    test('every 4th piece carries exactly one prism cell', () {
      final g = BlockfallGame.seeded(7);
      final all = [g.currentPiece!.spec!, ...g.upcoming];
      for (var i = 0; i < all.length; i++) {
        expect(all[i].prismCell != null, i % 4 == 3, reason: 'piece $i');
        if (all[i].prismCell != null) {
          expect(all[i].prismCell, inInclusiveRange(0, 3));
        }
      }
    });

    test('the prism stays with its cell when the piece locks', () {
      final g = mk(seq: [PieceType.cube], prismInterval: 1);
      final spec = g.currentPiece!.spec!;
      final expected = g.ghostPiece!.cells[spec.prismCell!];
      g.hardDrop();
      var count = 0;
      for (var r = 0; r < Well.totalRows; r++) {
        count += g.well.prismCountInRow(r);
      }
      expect(count, 1);
      expect(g.well.prismAt(expected.row, expected.col), isTrue);
    });
  });

  group('combo and back-to-back (criteria 4-5)', () {
    test('second consecutive clear adds 50, a non-clearing lock resets', () {
      final g = mk(rows: ['5.........', '..........', gap3to6, gap3to6]);
      final d1 = g.hardDrop();
      final c1 = clears(g).single;
      expect(c1.combo, 1);
      expect(c1.scoreGained, 100);
      expect(g.score, 100 + 2 * d1);
      g.hardDrop();
      final c2 = clears(g).single;
      expect(c2.combo, 2);
      expect(c2.scoreGained, 150);
      expect(g.combo, 2);
      g.hardDrop(); // lands without clearing
      expect(g.combo, 0);
      expect(g.maxCombo, 2);
    });

    test('quad after quad scores 1200 (x1.5) plus combo', () {
      final rows = ['.........7', for (var i = 0; i < 8; i++) gap0];
      final g = mk(rows: rows);
      verticalBarAt(g, 0);
      g.hardDrop();
      final q1 = clears(g).single;
      expect(q1.count, 4);
      expect(q1.scoreGained, 800);
      verticalBarAt(g, 0);
      g.hardDrop();
      final q2 = clears(g).single;
      expect(q2.backToBack, isTrue);
      expect(q2.scoreGained, 1200 + 50);
      expect(g.quads, 2);
    });

    test('a non-quad lock between two quads resets back-to-back', () {
      final rows = [for (var i = 0; i < 8; i++) gap0];
      final g = mk(rows: rows);
      verticalBarAt(g, 0);
      g.hardDrop();
      expect(clears(g).single.scoreGained, 800);
      expect(g.backToBackReady, isTrue);
      g.hardDrop(); // horizontal bar locks without clearing
      expect(g.backToBackReady, isFalse);
      verticalBarAt(g, 0);
      g.hardDrop();
      final q = clears(g).single;
      expect(q.backToBack, isFalse);
      expect(q.scoreGained, 800);
    });
  });

  group('perfect clear (criterion 6)', () {
    test('an empty well after a clear adds 1000 x level', () {
      final g = mk(rows: [gap3to6]);
      g.hardDrop();
      final c = clears(g).single;
      expect(c.perfectClear, isTrue);
      expect(c.scoreGained, 100 + 1000);
      expect(g.perfectClears, 1);
    });

    test('is multiplied by the level', () {
      final g = mk();
      for (var i = 0; i < 10; i++) {
        for (var c = 0; c < 10; c++) {
          if (c < 3 || c > 6) g.well.set(21, c, 1);
        }
        g.hardDrop();
        g.drainEvents();
      }
      expect(g.level, 2);
      for (var c = 0; c < 10; c++) {
        if (c < 3 || c > 6) g.well.set(21, c, 1);
      }
      g.hardDrop();
      // 200 line score + 2000 perfect clear + combo bonus (11th clear: 50 * 10 * 2).
      expect(clears(g).single.scoreGained, 200 + 2000 + 1000);
    });
  });

  group('drop points (criterion 7)', () {
    test('hard drop adds 2 per row, soft drop adds 1 per row', () {
      final g = mk();
      final d = g.hardDrop();
      expect(d, 20);
      expect(g.score, 40);

      final s = mk();
      s.softDrop(true);
      s.tick(0.05 * 3);
      expect(s.currentPiece!.row, 3);
      expect(s.score, 3);
      s.softDrop(false);
      s.tick(0.2);
      expect(s.score, 3); // gravity alone gives no points
    });
  });

  group('level and goal (criterion 11)', () {
    test('level = 1 + lines ~/ 10 and goal counts down', () {
      expect(levelForLines(0), 1);
      expect(levelForLines(9), 1);
      expect(levelForLines(10), 2);
      expect(goalForLines(0), 10);
      expect(goalForLines(7), 3);
      expect(goalForLines(10), 10);
    });

    test('after 10 lines the level is 2, goal 10, gravity 0.80', () {
      final g = mk();
      for (var i = 0; i < 10; i++) {
        for (var c = 0; c < 10; c++) {
          if (c < 3 || c > 6) g.well.set(21, c, 1);
        }
        g.hardDrop();
      }
      expect(g.lines, 10);
      expect(g.level, 2);
      expect(g.goal, 10);
      expect(g.secondsPerRow, 0.80);
      expect(g.drainEvents().whereType<LevelUp>().single.level, 2);
    });
  });
}
