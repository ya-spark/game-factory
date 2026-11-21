import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_wingy/src/game/rules/gap_generator.dart';
import 'package:game_wingy/src/game/rules/spire.dart';
import 'package:game_wingy/src/game/rules/wingy_run.dart';
import 'package:game_wingy/src/game/rules/world.dart';

import 'autopilot.dart';

void tick(WingyRun run, double seconds) {
  final n = (seconds / WingyWorld.step).round();
  for (var i = 0; i < n; i++) {
    run.advance(WingyWorld.step);
  }
}

SpirePair? nextPair(WingyRun run) =>
    run.pairs.where((p) => !p.passed).firstOrNull;

/// Holds the hero [offsetFraction] of the gap height away from the center of each gap
/// until [count] pairs have been passed. Returns points from pass/perfect events.
List<int> passPairs(WingyRun run, int count, {double offsetFraction = 0}) {
  final points = <int>[];
  var guard = 0;
  while (run.pairsPassed < count && !run.isDead && guard++ < 400000) {
    final p = nextPair(run)!;
    run.y = p.centerY + p.gapHeight * offsetFraction;
    run.vy = 0;
    run.advance(WingyWorld.step);
    for (final e in run.drainEvents()) {
      if (e.type == RunEventType.pass ||
          e.type == RunEventType.perfect ||
          e.type == RunEventType.shatter) {
        points.add(e.points);
      }
    }
  }
  return points;
}

void main() {
  group('physics', () {
    test('gravity: vy is 150 u/s after 0.1 s; fall speed is capped at 700', () {
      final run = WingyRun(random: Random(1))..start();
      tick(run, 0.1);
      expect(run.vy, closeTo(150, 0.01));
      run.y = 100;
      var maxV = 0.0;
      for (var i = 0; i < 70; i++) {
        run.advance(WingyWorld.step);
        maxV = max(maxV, run.vy);
        expect(run.vy, lessThanOrEqualTo(700));
      }
      expect(maxV, 700);
    });

    test('flap sets vy to -430 and does not stack', () {
      final run = WingyRun(random: Random(1))..start();
      run.vy = 300;
      run.flap();
      expect(run.vy, -430);
      run.flap();
      expect(run.vy, -430);
    });

    test('first tap starts the run', () {
      final run = WingyRun(random: Random(1));
      expect(run.phase, RunPhase.ready);
      run.flap();
      expect(run.phase, RunPhase.playing);
    });

    test('ground and ceiling end the run', () {
      final a = WingyRun(random: Random(1))..start();
      a.y = WingyWorld.groundY - WingyWorld.heroRadius - 0.1;
      a.vy = 100;
      tick(a, 0.05);
      expect(a.isDead, isTrue);
      final b = WingyRun(random: Random(1))..start();
      b.y = WingyWorld.heroRadius + 0.1;
      b.vy = -200;
      tick(b, 0.05);
      expect(b.isDead, isTrue);
    });

    test('a spire hit ends the run', () {
      final run = WingyRun(random: Random(1))..start();
      final p = run.pairs.first;
      var guard = 0;
      while (!run.isDead && guard++ < 100000) {
        run.y = p.gapBottom + 30;
        run.vy = 0;
        run.advance(WingyWorld.step);
      }
      expect(run.isDead, isTrue);
      expect(run.score, 0);
    });

    test('paused run does not advance', () {
      final run = WingyRun(random: Random(1))..start();
      run.paused = true;
      tick(run, 1);
      expect(run.time, 0);
      expect(run.vy, 0);
    });
  });

  group('scoring', () {
    test('first pass: 1 point off-center, 2 when centered', () {
      final off = WingyRun(random: Random(2))..start();
      expect(passPairs(off, 1, offsetFraction: 0.3), [1]);
      final mid = WingyRun(random: Random(2))..start();
      expect(passPairs(mid, 1), [2]);
    });

    test('perfect streak with Bloom bonus, capped at +5, reset by a miss', () {
      final run = WingyRun(random: Random(3))..start();
      final pts = passPairs(run, 3);
      expect(pts, [2, 2, 3]);
      expect(passPairs(run, 4).last, 4);
      expect(run.perfectStreak, 4);
      passPairs(run, 12);
      expect(run.perfectStreak, 12);
      expect(passPairs(run, 13).last, 2 + 5);
      expect(run.maxBloomBonus, 5);
      passPairs(run, 14, offsetFraction: 0.3);
      expect(run.perfectStreak, 0);
    });

    test('scroll speed: 140, 142 after one pass, capped at 220', () {
      final run = WingyRun(random: Random(1))..start();
      expect(run.scrollSpeed, 140);
      passPairs(run, 1);
      expect(run.scrollSpeed, 142);
      run.pairsPassed = 500;
      expect(run.scrollSpeed, 220);
    });

    test('medals and palettes', () {
      expect(medalForScore(9), Medal.none);
      expect(medalForScore(10), Medal.bronze);
      expect(medalForScore(25), Medal.silver);
      expect(medalForScore(50), Medal.gold);
      expect(medalForScore(100), Medal.prism);
    });

    test('palettes rotate every 20 points and wrap around', () {
      expect(paletteOrder, [
        Palette.dusk,
        Palette.aurora,
        Palette.midnight,
        Palette.sunrise,
        Palette.emerald,
        Palette.ember,
      ]);
      expect(paletteForScore(0), Palette.dusk);
      expect(paletteForScore(19), Palette.dusk);
      expect(paletteForScore(20), Palette.aurora);
      expect(paletteForScore(100), Palette.ember);
      expect(paletteForScore(120), Palette.dusk);
      expect(paletteForScore(121), Palette.dusk);
      expect(paletteForScore(20, start: 5), Palette.dusk);
      expect(paletteForScore(0, start: 3), Palette.sunrise);
      final run = WingyRun(random: Random(1), paletteStart: 4)..score = 20;
      expect(run.palette, Palette.ember);
    });

    test('next start is the palette after the one at game over', () {
      expect(nextPaletteStart(0, 0), 1);
      expect(nextPaletteStart(0, 45), 3);
      expect(nextPaletteStart(5, 20), 1);
      expect(nextPaletteStart(2, 100), 2);
    });

    test('palette fade runs 1.5 s (0.3 s with reduce motion)', () {
      final f = PaletteFade(Palette.dusk);
      expect(f.running, isFalse);
      f.setTarget(Palette.aurora);
      expect(f.running, isTrue);
      f.update(0.75);
      expect(f.progress, closeTo(0.5, 1e-9));
      f.update(0.74);
      expect(f.running, isTrue);
      f.update(0.02);
      expect(f.running, isFalse);
      expect(f.to, Palette.aurora);
      f.setTarget(Palette.midnight, reduceMotion: true);
      f.update(0.29);
      expect(f.running, isTrue);
      f.update(0.02);
      expect(f.running, isFalse);
    });

    test('score coins are 1 per 5 points', () {
      final run = WingyRun(random: Random(1))..score = 23;
      expect(run.scoreCoins, 4);
    });
  });

  group('generator', () {
    test('20 seeds x 500 pairs satisfy the gap rules', () {
      for (var seed = 0; seed < 20; seed++) {
        final g = GapGenerator(Random(seed));
        double? prev;
        for (var i = 0; i < 500; i++) {
          final p = g.next(x: 0, score: 0);
          final base = GapGenerator.baseGap(i);
          expect(p.gapHeight, greaterThanOrEqualTo(150));
          expect(p.baseCenterY - p.gapHeight / 2, greaterThanOrEqualTo(40));
          expect(p.baseCenterY + p.gapHeight / 2, lessThanOrEqualTo(584 - 40));
          if (prev != null) {
            expect((p.baseCenterY - prev).abs(), lessThanOrEqualTo(200.0001));
          }
          if (p.number % 7 == 0) {
            expect(p.gapHeight, greaterThanOrEqualTo(base + 60));
          }
          prev = p.baseCenterY;
        }
      }
    });

    test('base gap shrinks 1.5 u per pair from 210 to the 150 floor', () {
      expect(GapGenerator.baseGap(0), 210);
      expect(GapGenerator.baseGap(10), 195);
      expect(GapGenerator.baseGap(40), 150);
      expect(GapGenerator.baseGap(300), 150);
    });

    test('orbs: pairs 3, 7, 11 have one; never in adjacent pairs', () {
      for (var seed = 0; seed < 20; seed++) {
        final g = GapGenerator(Random(seed));
        var prevOrb = false;
        for (var i = 1; i <= 500; i++) {
          final p = g.next(x: 0, score: 0);
          if (i % 4 == 3) expect(p.hasOrb, isTrue);
          expect(prevOrb && p.hasOrb, isFalse, reason: 'seed $seed pair $i');
          prevOrb = p.hasOrb;
        }
      }
    });

    test(
      'drifting gaps only from score 20, one in ten, +/-30 u, 2 s period',
      () {
        final low = GapGenerator(Random(1));
        final high = GapGenerator(Random(1));
        var drifting = 0;
        for (var i = 1; i <= 100; i++) {
          expect(low.next(x: 0, score: 19).drifting, isFalse);
          final p = high.next(x: 0, score: 20);
          if (p.drifting) {
            drifting++;
            expect(i % 10, 0);
            expect(p.centerAt(0.5), closeTo(p.baseCenterY + 30, 1e-9));
            expect(p.centerAt(1.5), closeTo(p.baseCenterY - 30, 1e-9));
            expect(p.centerAt(2.0), closeTo(p.baseCenterY, 1e-9));
          }
        }
        expect(drifting, 10);
      },
    );

    test('score does not change the gap sequence (same seed)', () {
      final a = GapGenerator(Random(9));
      final b = GapGenerator(Random(9));
      for (var i = 0; i < 50; i++) {
        final pa = a.next(x: 0, score: 0);
        final pb = b.next(x: 0, score: 99);
        expect(pa.baseCenterY, pb.baseCenterY);
        expect(pa.gapHeight, pb.gapHeight);
        expect(pa.hasOrb, pb.hasOrb);
      }
    });
  });

  group('reachability and determinism', () {
    test('autopilot survives 500 pairs on 20 seeds', () {
      for (var seed = 0; seed < 20; seed++) {
        final run = WingyRun(random: Random(seed))..start();
        fly(run, Autopilot(), pairs: 500);
        expect(run.isDead, isFalse, reason: 'seed $seed died at ${run.score}');
        expect(run.pairsPassed, 500);
      }
    });

    test('same seed and tap trace give identical results', () {
      WingyRun go() {
        final r = WingyRun(random: Random(77))..start();
        fly(r, Autopilot(), pairs: 60);
        return r;
      }

      final a = go();
      final b = go();
      expect(a.score, b.score);
      expect(a.y, b.y);
      expect(a.perfectStreak, b.perfectStreak);
      expect(
        [for (final p in a.pairs) p.baseCenterY],
        [for (final p in b.pairs) p.baseCenterY],
      );
    });
  });

  group('orbs', () {
    test('touching an orb: +1 score, +1 pip, +1 coin; coin cap 40', () {
      final run = WingyRun(random: Random(4))..start();
      passPairs(run, 3);
      expect(run.orbsCollected, greaterThanOrEqualTo(1));
      expect(run.meter, run.orbsCollected);
      expect(run.coins, run.orbsCollected);
      expect(run.score, 2 + 2 + 3 + run.orbsCollected);

      final capped = WingyRun(random: Random(4))
        ..start()
        ..coins = 40;
      passPairs(capped, 3);
      expect(capped.coins, 40);
      expect(capped.orbsCollected, greaterThanOrEqualTo(1));
    });

    test('meter never exceeds 3', () {
      final run = WingyRun(random: Random(4), startMeter: 9);
      expect(run.meter, 3);
    });
  });

  group('glow dash', () {
    test('needs a full meter; sets meter to 0, lasts 1.2 s, no stacking', () {
      final run = WingyRun(random: Random(5))..start();
      run.meter = 2;
      expect(run.dash(), isFalse);
      run.meter = 3;
      expect(run.dash(), isTrue);
      expect(run.meter, 0);
      expect(run.isDashing, isTrue);
      run.meter = 3;
      expect(run.dash(), isFalse);
      tick(run, 1.1);
      expect(run.isDashing, isTrue);
      tick(run, 0.15);
      expect(run.isDashing, isFalse);
      expect(run.isGrace, isTrue);
      tick(run, 0.45);
      expect(run.isGrace, isFalse);
    });

    test('lightning exit leaves a clear gap before the next obstacle', () {
      for (var seed = 1; seed <= 20; seed++) {
        final run = WingyRun(random: Random(seed))..start();
        run.meter = 3;
        run.dash();
        var guard = 0;
        while (run.isDashing && guard++ < 10000) {
          run.advance(WingyWorld.step);
        }
        final minLeft =
            WingyWorld.heroX +
            WingyWorld.heroRadius +
            run.scrollSpeed * WingyWorld.dashExitBuffer;
        final ahead = run.pairs
            .where((p) => !p.passed && p.left > WingyWorld.heroX)
            .toList();
        expect(ahead, isNotEmpty);
        expect(ahead.first.left, greaterThanOrEqualTo(minLeft - 1e-6));
        for (var i = 1; i < ahead.length; i++) {
          expect(
            ahead[i].x - ahead[i - 1].x,
            closeTo(WingyWorld.pairSpacing, 1e-6),
          );
        }
      }
    });

    test('shatters pairs for exactly 3 each and keeps the streak', () {
      final run = WingyRun(random: Random(5))..start();
      run.perfectStreak = 2;
      final p = run.pairs.first;
      run.y = p.gapBottom + 40;
      run.meter = 3;
      expect(run.dash(), isTrue);
      final before = run.pairsPassed;
      while (run.isDashing && run.pairsPassed == before) {
        run.advance(WingyWorld.step);
      }
      expect(run.isDead, isFalse);
      expect(run.dashShattered, 1);
      expect(run.score, 3);
      expect(run.perfectStreak, 2);
      expect(run.isDashing, isTrue);
      expect(run.scrollSpeed, 142);
    });

    test(
      'start altitude is clamped into [40, 544]; vy stays 0; flap ignored',
      () {
        final run = WingyRun(random: Random(5))..start();
        run.y = 570;
        run.meter = 3;
        run.dash();
        expect(run.y, 544);
        tick(run, 0.2);
        expect(run.y, lessThan(544));
        expect(run.vy, 0);
        run.flap();
        expect(run.vy, 0);
      },
    );

    test('a dash started outside 200..400 ends inside that band', () {
      for (final startY in [570.0, 544.0, 450.0, 40.0, 100.0, 300.0]) {
        final run = WingyRun(random: Random(5))..start();
        run.y = startY;
        run.meter = 3;
        run.dash();
        var guard = 0;
        while (run.isDashing && guard++ < 10000) {
          run.advance(WingyWorld.step);
        }
        expect(run.isDead, isFalse);
        expect(run.y, inInclusiveRange(200, 400), reason: 'start $startY');
      }
    });

    test('ease never moves faster than 250 u/s', () {
      final run = WingyRun(random: Random(5))..start();
      run.y = 544;
      run.meter = 3;
      run.dash();
      var prev = run.y;
      for (var i = 0; i < 100; i++) {
        run.advance(WingyWorld.step);
        expect(
          (run.y - prev).abs(),
          lessThanOrEqualTo(WingyWorld.dashEaseRate * WingyWorld.step + 1e-9),
        );
        prev = run.y;
      }
    });

    test('dashEnding is true only in the last 0.3 s of the dash', () {
      final run = WingyRun(random: Random(5))..start();
      expect(run.dashEnding, isFalse);
      run.meter = 3;
      run.dash();
      expect(run.dashEnding, isFalse);
      tick(run, 0.85);
      expect(run.dashEnding, isFalse);
      tick(run, 0.1);
      expect(run.dashEnding, isTrue);
      tick(run, 0.3);
      expect(run.isDashing, isFalse);
      expect(run.dashEnding, isFalse);
    });

    test('pausing stops the dash timer and the float timer', () {
      final run = WingyRun(random: Random(5))..start();
      run.meter = 3;
      run.dash();
      tick(run, 0.2);
      final t = run.dashTimer;
      run.paused = true;
      tick(run, 5);
      expect(run.dashTimer, t);
      run.paused = false;
      tick(run, 1.1);
      expect(run.isFloating, isTrue);
      final f = run.floatTimer;
      run.paused = true;
      tick(run, 5);
      expect(run.floatTimer, f);
    });

    group('recovery float', () {
      WingyRun endedLow() {
        final run = WingyRun(random: Random(5))..start();
        run.y = 544;
        run.meter = 3;
        run.dash();
        var guard = 0;
        while (run.isDashing && guard++ < 10000) {
          run.advance(WingyWorld.step);
        }
        return run;
      }

      test('no tap for 0.5 s after a low dash: still alive', () {
        final run = endedLow();
        expect(run.isFloating, isTrue);
        tick(run, WingyWorld.recoveryFloatDuration - 0.05);
        expect(run.vy, lessThanOrEqualTo(WingyWorld.recoveryMaxFall));
        tick(run, 0.05);
        expect(run.isDead, isFalse);
      });

      test('a tap during the float flaps normally and ends it', () {
        final run = endedLow();
        tick(run, 0.2);
        run.flap();
        expect(run.vy, WingyWorld.flapVelocity);
        expect(run.isFloating, isFalse);
      });

      test('without a tap the ground still kills after the float', () {
        final run = WingyRun(random: Random(5))..start();
        run.meter = 3;
        run.dash();
        var guard = 0;
        while (run.isDashing && guard++ < 10000) {
          run.advance(WingyWorld.step);
        }
        run.y = 560;
        tick(run, 3);
        expect(run.isDead, isTrue);
      });
    });

    test('grace after dash: spire contact does not kill', () {
      final run = WingyRun(random: Random(5))..start();
      run.meter = 3;
      run.y = 300;
      run.dash();
      tick(run, 1.21);
      expect(run.isGrace, isTrue);
      expect(run.vy, lessThan(100));
    });
  });

  group('revive', () {
    WingyRun died() {
      final run = WingyRun(random: Random(6))..start();
      passPairs(run, 2);
      run.y = 570;
      tick(run, 0.2);
      expect(run.isDead, isTrue);
      return run;
    }

    test('up to three per run: clears spires ahead, 2 s invulnerability', () {
      final run = died();
      final score = run.score;
      final streak = run.perfectStreak;
      final meter = run.meter;
      expect(run.canRevive, isTrue);
      expect(run.revive(), isTrue);
      expect(run.phase, RunPhase.playing);
      expect(run.score, score);
      expect(run.perfectStreak, streak);
      expect(run.meter, meter);
      expect(run.invulnTimer, 2.0);
      for (final p in run.pairs) {
        expect(p.passed || p.left > WingyWorld.heroX + 300, isTrue);
      }
      for (var i = 1; i < WingyWorld.maxRevives; i++) {
        run.invulnTimer = 0;
        run.y = 570;
        run.vy = 100;
        tick(run, 0.2);
        expect(run.isDead, isTrue);
        expect(run.canRevive, isTrue);
        expect(run.revive(), isTrue);
      }
      // Fourth death: no revive left.
      run.invulnTimer = 0;
      run.y = 570;
      run.vy = 100;
      tick(run, 0.2);
      expect(run.isDead, isTrue);
      expect(run.canRevive, isFalse);
      expect(run.revive(), isFalse);
    });

    test('invulnerable hero survives touching the ground', () {
      final run = died();
      run.revive();
      run.y = 575;
      run.vy = 200;
      tick(run, 0.5);
      expect(run.isDead, isFalse);
    });

    test('death animation lasts 0.6 s', () {
      final run = died();
      expect(run.deathAnimationDone, isFalse);
      tick(run, 0.7);
      expect(run.deathAnimationDone, isTrue);
    });
  });
}
