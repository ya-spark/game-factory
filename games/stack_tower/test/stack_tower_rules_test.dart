import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_stack_tower/stack_tower.dart';

StackGame _game([int seed = 1]) => StackGame(random: Random(seed));

/// Steps until the block's left edge is as close as it gets to [target], then drops.
void _dropAt(StackGame g, double target) {
  var best = double.infinity;
  for (var i = 0; i < 4000; i++) {
    final d = (g.x - target).abs();
    if (d < 0.2 || i > 0 && d > best + 5) break;
    best = min(best, d);
    g.step();
  }
  g.x = target; // exact, so the test does not depend on the step phase
  g.drop();
}

void main() {
  test('starts with a base block and a sliding block of the same width', () {
    final g = _game();
    expect(g.height, 0);
    expect(g.width, stackStartWidth);
    expect(g.top.x, (stackW - stackStartWidth) / 2);
  });

  test('the sliding block turns round at both edges and speeds up', () {
    final g = _game();
    var minX = 1e9;
    var maxX = -1e9;
    for (var i = 0; i < 4000; i++) {
      g.step();
      minX = min(minX, g.x);
      maxX = max(maxX, g.x + g.width);
    }
    expect(minX, 0);
    expect(maxX, stackW);
    expect(stackSpeed(10), greaterThan(stackSpeed(0)));
    expect(stackSpeed(1000), 120);
  });

  test('a drop with overhang is trimmed to the overlap', () {
    final g = _game();
    _dropAt(g, g.top.x + 10);
    expect(g.height, 1);
    expect(g.top.width, closeTo(stackStartWidth - 10, 1e-9));
    expect(g.top.x, closeTo(g.blocks[0].x + 10, 1e-9));
    expect(g.score, stackDropPoints);
    expect(g.streak, 0);
    expect(g.lastCut, isNotNull);
    expect(g.width, g.top.width);
  });

  test('a perfect drop keeps the width and builds a streak bonus', () {
    final g = _game();
    _dropAt(g, g.top.x + 0.5);
    expect(g.top.width, stackStartWidth);
    expect(g.streak, 1);
    expect(g.score, stackDropPoints + stackStreakPoints);
    _dropAt(g, g.top.x);
    expect(g.streak, 2);
    expect(g.score, 2 * stackDropPoints + 3 * stackStreakPoints);
    g.x = g.top.x + 5; // not perfect: the streak resets
    g.drop();
    expect(g.streak, 0);
  });

  test('the streak bonus is capped', () {
    final g = _game();
    for (var i = 0; i < 15; i++) {
      g.x = g.top.x;
      g.drop();
    }
    final before = g.score;
    g.x = g.top.x;
    g.drop();
    expect(
      g.score - before,
      stackDropPoints + stackStreakPoints * stackStreakCap,
    );
  });

  test('missing the tower ends the game; Continue brings the block back', () {
    final g = _game();
    g.x = g.top.right + 1;
    expect(g.drop(), isFalse);
    expect(g.over, isTrue);
    g.step();
    expect(g.drop(), isFalse);
    g.grantContinue();
    expect(g.over, isFalse);
    expect(g.height, 0);
    expect(g.width, g.top.width);
  });

  test('the same seed plays the same game', () {
    final a = _game(7);
    final b = _game(7);
    for (var i = 0; i < 300; i++) {
      a.step();
      b.step();
    }
    expect(a.x, b.x);
  });
}
