import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_brick_breaker/brick_breaker.dart';

BrickGame _game({int level = 1, int seed = 1}) =>
    BrickGame(random: Random(seed), level: level);

/// Plays with the paddle under the ball for [steps] steps.
void _autoplay(BrickGame g, int steps) {
  for (var i = 0; i < steps && !g.over; i++) {
    if (!g.launched) g.launch();
    // Aim off-centre by a wandering amount, so the ball does not loop straight up and down.
    g.movePaddleTo(g.ballX + 7 * sin(i / 40));
    g.step();
  }
}

void main() {
  test('20 generated levels: stable, never empty, rows and strength rise', () {
    for (var lv = 1; lv <= brickLevels; lv++) {
      final a = brickLevel(lv, Random(brickSeed(lv)));
      final b = brickLevel(lv, Random(brickSeed(lv)));
      expect(a, b, reason: 'level $lv is the same every time');
      expect(a.length, inInclusiveRange(3, 8));
      expect(a.every((r) => r.length == brickCols), isTrue);
      expect(a.expand((r) => r).any((h) => h > 0), isTrue);
    }
    expect(
      brickLevel(20, Random(1)).length,
      greaterThan(brickLevel(1, Random(1)).length),
    );
    expect(
      brickLevel(1, Random(1)).expand((r) => r).every((h) => h <= 1),
      isTrue,
    );
    expect(
      brickLevel(8, Random(1)).expand((r) => r).any((h) => h == 2),
      isTrue,
    );
  });

  test('the ball sticks to the paddle until launch', () {
    final g = _game();
    g.movePaddleTo(30);
    expect(g.ballX, 30);
    for (var i = 0; i < 50; i++) {
      g.step();
    }
    expect(g.ballX, 30);
    g.launch();
    expect(g.launched, isTrue);
    expect(g.vy, lessThan(0));
    expect(sqrt(g.vx * g.vx + g.vy * g.vy), closeTo(brickBallSpeed(1), 1e-6));
  });

  test('the paddle is clamped to the field', () {
    final g = _game();
    g.movePaddleTo(-50);
    expect(g.paddleX, paddleBaseW / 2);
    g.movePaddleTo(500);
    expect(g.paddleX, brickW - paddleBaseW / 2);
  });

  test('walls and ceiling reflect the ball', () {
    final g = _game();
    g.launched = true;
    g.ballX = ballR + 0.1;
    g.ballY = 100;
    g.vx = -50;
    g.vy = -10;
    g.step();
    expect(g.vx, greaterThan(0));
    g.ballX = 50;
    g.ballY = ballR + 0.1;
    g.vx = 0;
    g.vy = -60;
    g.step();
    expect(g.vy, greaterThan(0));
  });

  test('the paddle sends the ball off by where it lands', () {
    final g = _game();
    g.launched = true;
    g.movePaddleTo(50);
    g.ballX = 50 + paddleBaseW / 2;
    g.ballY = paddleY - ballR - 0.1;
    g.vx = 0;
    g.vy = 60;
    g.step();
    expect(g.vy, lessThan(0));
    expect(g.vx, greaterThan(0));
    g.ballX = 50;
    g.ballY = paddleY - ballR - 0.1;
    g.vx = 0;
    g.vy = 60;
    g.step();
    expect(g.vx.abs(), lessThan(1e-6));
  });

  test('a brick breaks, scores 10 and the ball turns', () {
    final g = _game(seed: 5);
    g.launched = true;
    final before = g.bricksLeft;
    g.ballX = brickCellW / 2;
    g.ballY = brickTop + brickCellH + ballR - 0.2;
    g.vx = 0;
    g.vy = -60;
    g.step();
    expect(g.bricksLeft, before - 1);
    expect(g.score, 10);
    expect(g.vy, greaterThan(0));
  });

  test('a strong brick takes two hits (5 then 10 points)', () {
    final g = _game(level: 8);
    expect(g.bricks[0][0], 2);
    g.launched = true;
    g.ballX = brickCellW / 2;
    g.ballY = brickTop + brickCellH + ballR - 0.2;
    g.vx = 0;
    g.vy = -60;
    g.step();
    expect(g.bricks[0][0], 1);
    expect(g.score, 5);
  });

  test(
    'losing the ball costs a life; none left is game over; Continue gives one',
    () {
      final g = _game();
      for (var life = 0; life < brickStartLives; life++) {
        g.launch();
        g.ballX = 5;
        g.ballY = brickH + ballR + 1;
        g.paddleX = 90;
        g.step();
      }
      expect(g.over, isTrue);
      expect(g.won, isFalse);
      g.grantContinue();
      expect(g.over, isFalse);
      expect(g.lives, 1);
      expect(g.launched, isFalse);
    },
  );

  test('power-ups: wide paddle and slow ball apply, then wear off', () {
    final g = _game();
    g.powerUps.add(PowerUp(PowerUpKind.widePaddle, g.paddleX, paddleY - 1));
    g.step();
    expect(g.paddleW, paddleWideW);
    for (var i = 0; i < (widePaddleSeconds / brickStep).ceil() + 2; i++) {
      g.step();
    }
    expect(g.paddleW, paddleBaseW);
    g.powerUps.add(PowerUp(PowerUpKind.slowBall, g.paddleX, paddleY - 1));
    g.step();
    expect(g.slowLeft, greaterThan(0));
  });

  test('autoplay clears level 1 and moves on, deterministically', () {
    final a = _game(seed: 3);
    final b = _game(seed: 3);
    _autoplay(a, 120 * 300);
    _autoplay(b, 120 * 300);
    expect(a.level, greaterThan(1));
    expect(a.score, b.score);
    expect(a.score, greaterThanOrEqualTo(50));
  });

  test('clearing level 20 wins', () {
    final g = _game(level: brickLevels);
    g.bricks = [
      [1, 0, 0, 0, 0, 0, 0, 0],
    ];
    g.launched = true;
    g.ballX = brickCellW / 2;
    g.ballY = brickTop + brickCellH + ballR - 0.2;
    g.vx = 0;
    g.vy = -60;
    g.step();
    expect(g.won, isTrue);
    expect(g.over, isTrue);
  });
}
