import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_wind_up_dash/wind_up_dash.dart';

/// A bot that jumps once per hazard, timed so the top of the arc is over the middle of it.
/// It is the fairness test: if a fair track needs this and nothing else, it never dies.
DashGame _runBot(int seed, double distance, {double lateBy = 0}) {
  final g = DashGame(seed: seed);
  while (!g.over && g.best < distance) {
    final h = g.track.nextFrom(g.x - dashWidth);
    if (h != null && g.grounded) {
      final mid = h.x + h.width / 2;
      final reach = dashSpeed(g.x) * dashAirTime;
      if (g.x >= mid - reach / 2 + lateBy && g.x < h.end) g.jump();
    }
    g.step();
  }
  return g;
}

void main() {
  test('the same seed is the same track; different seeds differ', () {
    List<double> xs(int seed) {
      final t = DashTrack(seed)..extendTo(3000);
      return [for (final h in t.hazards) h.x];
    }

    expect(xs(5), xs(5));
    expect(xs(5), isNot(xs(6)));
  });

  test('fair by construction: gap size, block size and spacing', () {
    for (var seed = 1; seed <= 40; seed++) {
      final t = DashTrack(seed)..extendTo(8000);
      expect(t.hazards.first.x, firstHazardAt);
      for (var i = 0; i < t.hazards.length; i++) {
        final h = t.hazards[i];
        final v = dashSpeed(h.x);
        if (h.kind == HazardKind.gap) {
          expect(
            h.width,
            lessThanOrEqualTo(v * dashAirTime * maxGapShare + 1e-9),
          );
          expect(h.height, 0);
        } else {
          expect(h.width, inInclusiveRange(blockMinWidth, blockMaxWidth));
          expect(h.height, inInclusiveRange(blockMinHeight, blockMaxHeight));
          // The jump clears the block's height for long enough to cross it.
          expect(
            h.height,
            lessThan(dashJumpSpeed * dashJumpSpeed / (2 * dashGravity)),
          );
        }
        if (i > 0) {
          final prev = t.hazards[i - 1];
          expect(
            h.x - prev.end,
            greaterThanOrEqualTo(minSpacing(prev.end) - 1e-9),
          );
        }
      }
    }
  });

  test(
    'a well-timed jump always works: the bot runs 6000 units on 40 seeds',
    () {
      for (var seed = 1; seed <= 40; seed++) {
        final g = _runBot(seed, 6000);
        expect(g.over, isFalse, reason: 'seed $seed ended at ${g.x} ${g.end}');
      }
    },
  );

  test('not jumping dies on the first hazard', () {
    final g = DashGame(seed: 3);
    for (var i = 0; i < 120 * 20 && !g.over; i++) {
      g.step();
    }
    expect(g.over, isTrue);
    expect(g.end, isNot(DashEnd.none));
  });

  test('the jump is a fixed arc; no double jump in the air', () {
    final g = DashGame(seed: 1);
    expect(g.jump(), isTrue);
    expect(g.jump(), isFalse);
    var top = 0.0;
    var steps = 0;
    while (!g.grounded && steps < 1000) {
      g.step();
      top = max(top, g.y);
      steps++;
    }
    expect(
      top,
      closeTo(dashJumpSpeed * dashJumpSpeed / (2 * dashGravity), 0.3),
    );
    expect(steps * dashStep, closeTo(dashAirTime, 0.03));
  });

  test('speed rises with distance and is capped', () {
    expect(dashSpeed(0), 32);
    expect(dashSpeed(700), greaterThan(dashSpeed(0)));
    expect(dashSpeed(100000), 60);
  });

  test(
    'score is distance over 10; Continue returns to safe ground, keeps score',
    () {
      final g = DashGame(seed: 3);
      while (!g.over) {
        g.step();
      }
      final before = g.score;
      expect(before, greaterThan(0));
      g.grantContinue();
      expect(g.over, isFalse);
      expect(g.grounded, isTrue);
      expect(g.score, before);
      expect(g.x, lessThan(g.best));
      final h = g.track.nextFrom(g.x)!;
      expect(h.x - g.x, closeTo(20, 1e-9));
    },
  );
}
