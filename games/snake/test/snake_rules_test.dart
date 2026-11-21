import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_snake/snake.dart';
import 'package:game_core/game_core.dart';

SnakeGame _game({bool wrap = false}) =>
    SnakeGame(wrap: wrap, random: Random(1));

void main() {
  test('starts with three segments heading right, food off the snake', () {
    final g = _game();
    expect(g.length, 3);
    expect(g.dir, SnakeDir.right);
    expect(g.body.contains(g.food), isFalse);
  });

  test('a turn straight back or a repeat is ignored; two turns queue', () {
    final g = _game();
    g.turn(SnakeDir.left);
    g.move();
    expect(g.dir, SnakeDir.right);
    g.turn(SnakeDir.up);
    g.turn(SnakeDir.left);
    g.turn(SnakeDir.down); // third is dropped
    g.move();
    expect(g.dir, SnakeDir.up);
    g.move();
    expect(g.dir, SnakeDir.left);
    g.move();
    expect(g.dir, SnakeDir.left);
  });

  test('eating grows by one and scores ten', () {
    final g = _game();
    final h = g.head;
    g.food = SnakeCell(h.x + 1, h.y);
    g.move();
    expect(g.length, 4);
    expect(g.score, 10);
    expect(g.body.contains(g.food), isFalse);
  });

  test('a wall ends the game, or wraps when wrap is on', () {
    final g = _game();
    for (var i = 0; i < 20 && !g.over; i++) {
      g.move();
    }
    expect(g.end, SnakeEnd.wall);
    final w = _game(wrap: true);
    for (var i = 0; i < 40; i++) {
      w.move();
    }
    expect(w.over, isFalse);
  });

  test('running into itself ends the game; the moving tail cell is free', () {
    final g = _game();
    g.body
      ..clear()
      ..addAll(const [
        SnakeCell(5, 5),
        SnakeCell(5, 6),
        SnakeCell(6, 6),
        SnakeCell(6, 5),
      ]);
    g.dir = SnakeDir.up;
    g.food = const SnakeCell(0, 0);
    g.turn(SnakeDir.right);
    g.move(); // into the tail's cell (6,5): the tail leaves it, so it is fine
    expect(g.over, isFalse);
    final h = _game();
    h.body
      ..clear()
      ..addAll(const [
        SnakeCell(5, 5),
        SnakeCell(5, 6),
        SnakeCell(6, 6),
        SnakeCell(6, 5),
        SnakeCell(6, 4),
        SnakeCell(5, 4),
      ]);
    h.dir = SnakeDir.up;
    h.food = const SnakeCell(0, 0);
    h.turn(SnakeDir.right);
    h.move(); // (6,5) is a body cell, not the tail
    expect(h.end, SnakeEnd.self);
  });

  test('speed rises with length and is capped', () {
    expect(snakeInterval(3), closeTo(0.20, 1e-9));
    expect(snakeInterval(13), lessThan(snakeInterval(3)));
    expect(snakeInterval(500), 0.08);
  });

  test('update moves by the interval and is deterministic by seed', () {
    final a = _game();
    final b = _game();
    expect(a.update(0.19), 0);
    expect(a.update(0.02), 1);
    expect(a.head.x, b.head.x + 1);
    expect(a.food, b.food);
  });

  test('a full board ends the game as filled', () {
    final g = SnakeGame(cols: 4, rows: 1, random: Random(1));
    expect(g.length, 3);
    g.food = const SnakeCell(3, 0);
    g.move();
    expect(g.end, SnakeEnd.filled);
  });

  test('fixed stepper, coins and stars', () {
    final s = FixedStepper(dt: 0.125);
    expect(s.advance(0.25), 2);
    expect(s.advance(0.125), 1);
    expect(s.advance(10), 2); // cut to maxFrame 0.25
    expect(arcadeCoins(95, perCoins: 20), 4);
    expect(arcadeCoins(5000, perCoins: 20), 20);
    expect(arcadeStars(150, const [50, 150, 300]), 2);
  });
}
