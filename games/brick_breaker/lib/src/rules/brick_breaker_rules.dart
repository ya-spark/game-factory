/// Brick breaker rules. Pure Dart: no Flutter, Flame or Android imports. The random source is
/// injected. Fixed step: the screen calls [BrickGame.step] with [brickStep] seconds each time.
library;

import 'dart:math';

/// The world is [brickW] x [brickH] units; the screen scales it.
const double brickW = 100;
const double brickH = 150;
const int brickCols = 8;
const double brickCellW = brickW / brickCols;
const double brickCellH = 5;
const double brickTop = 14; // y of the first brick row
const double brickStep = 1 / 120;

const double paddleY = 140;
const double paddleH = 3;
const double paddleBaseW = 20;
const double paddleWideW = 32;
const double ballR = 2;

const int brickLevels = 20;
const int brickStartLives = 3;
const double widePaddleSeconds = 10;
const double slowBallSeconds = 8;
const double slowFactor = 0.7;
const double powerUpChance = 0.15;
const double powerUpFall = 30;
const double paddleSpeed = 90; // buttons

enum PowerUpKind { widePaddle, slowBall }

class PowerUp {
  PowerUp(this.kind, this.x, this.y);
  final PowerUpKind kind;
  final double x;
  double y;
}

/// Hit points of each brick of level [level] (1..20): `rows` lists of [brickCols] numbers, 0 is
/// empty. Rows and strength rise with the level; four patterns repeat (rows, checker, pyramid,
/// scattered). Every level has at least one brick and every brick is reachable (the ball
/// travels the whole field above the paddle).
List<List<int>> brickLevel(int level, Random random) {
  final lv = level.clamp(1, brickLevels);
  final rows = min(3 + (lv - 1) ~/ 3, 8);
  final strong = lv >= 6;
  final out = <List<int>>[];
  for (var r = 0; r < rows; r++) {
    final row = <int>[];
    for (var c = 0; c < brickCols; c++) {
      var present = switch (lv % 4) {
        1 => true,
        2 => (r + c) % 2 == 0,
        3 => c >= r && c < brickCols - r,
        _ => random.nextDouble() < 0.7,
      };
      if (r == 0 && c == 0) present = true; // never empty
      final hp = strong && (r == 0 || (lv >= 13 && r.isEven)) ? 2 : 1;
      row.add(present ? hp : 0);
    }
    out.add(row);
  }
  return out;
}

/// The seed of a level, so the same level is the same every time.
int brickSeed(int level) => 7000 + level;

/// Ball speed in units per second for a level: 60, rising by 2 a level to 98.
double brickBallSpeed(int level) => 60 + 2 * (level.clamp(1, brickLevels) - 1);

class BrickGame {
  BrickGame({
    required this.random,
    this.level = 1,
    this.lives = brickStartLives,
  }) {
    _loadLevel();
  }

  final Random random;
  int level;
  int lives;
  int score = 0;
  bool won = false;
  bool over = false;

  List<List<int>> bricks = [];
  double paddleX = brickW / 2; // centre
  double paddleW = paddleBaseW;
  double ballX = brickW / 2;
  double ballY = paddleY - ballR;
  double vx = 0;
  double vy = 0;
  bool launched = false;
  double wideLeft = 0;
  double slowLeft = 0;
  final List<PowerUp> powerUps = [];
  int _moveDir = 0;

  int get bricksLeft => [
    for (final r in bricks)
      for (final h in r)
        if (h > 0) h,
  ].length;

  void _loadLevel() {
    bricks = brickLevel(level, Random(brickSeed(level)));
    powerUps.clear();
    _resetBall();
  }

  void _resetBall() {
    launched = false;
    vx = 0;
    vy = 0;
    wideLeft = 0;
    slowLeft = 0;
    paddleW = paddleBaseW;
    _stick();
  }

  void _stick() {
    ballX = paddleX;
    ballY = paddleY - ballR;
  }

  /// Moves the paddle centre to [x] (a drag).
  void movePaddleTo(double x) {
    final h = paddleW / 2;
    paddleX = x.clamp(h, brickW - h);
    if (!launched) _stick();
  }

  /// Button control: -1 left, 1 right, 0 stop. Applied on every step.
  void setMove(int dir) => _moveDir = dir;

  /// Launches the ball, slightly off straight up by the paddle's side of the field.
  void launch() {
    if (launched || over) return;
    launched = true;
    final s = brickBallSpeed(level);
    final angle = (random.nextDouble() - 0.5) * 0.6; // radians from straight up
    vx = s * sin(angle);
    vy = -s * cos(angle);
  }

  /// After a lost-ball game over, a Continue gives one more life and a new ball.
  void grantContinue() {
    if (!over || won) return;
    over = false;
    lives = 1;
    _resetBall();
  }

  double get _speedFactor => slowLeft > 0 ? slowFactor : 1;

  /// One fixed step of [brickStep] seconds.
  void step() {
    if (over) return;
    const dt = brickStep;
    if (_moveDir != 0) movePaddleTo(paddleX + _moveDir * paddleSpeed * dt);
    if (wideLeft > 0) {
      wideLeft -= dt;
      if (wideLeft <= 0) {
        paddleW = paddleBaseW;
        movePaddleTo(paddleX);
      }
    }
    if (slowLeft > 0) slowLeft -= dt;
    _stepPowerUps(dt);
    if (!launched) return;
    _moveBall(dt * _speedFactor);
  }

  void _stepPowerUps(double dt) {
    for (final p in powerUps.toList()) {
      p.y += powerUpFall * dt;
      final caught =
          p.y >= paddleY - 2 &&
          p.y <= paddleY + paddleH + 2 &&
          (p.x - paddleX).abs() <= paddleW / 2 + 2;
      if (caught) {
        powerUps.remove(p);
        switch (p.kind) {
          case PowerUpKind.widePaddle:
            wideLeft = widePaddleSeconds;
            paddleW = paddleWideW;
            movePaddleTo(paddleX);
          case PowerUpKind.slowBall:
            slowLeft = slowBallSeconds;
        }
      } else if (p.y > brickH) {
        powerUps.remove(p);
      }
    }
  }

  void _moveBall(double dt) {
    ballX += vx * dt;
    ballY += vy * dt;
    if (ballX < ballR) {
      ballX = ballR;
      vx = vx.abs();
    } else if (ballX > brickW - ballR) {
      ballX = brickW - ballR;
      vx = -vx.abs();
    }
    if (ballY < ballR) {
      ballY = ballR;
      vy = vy.abs();
    }
    _hitPaddle();
    _hitBricks();
    if (ballY > brickH + ballR) _lostBall();
  }

  void _hitPaddle() {
    if (vy <= 0) return;
    final left = paddleX - paddleW / 2;
    if (ballY + ballR >= paddleY &&
        ballY - ballR <= paddleY + paddleH &&
        ballX >= left - ballR &&
        ballX <= left + paddleW + ballR) {
      final s = sqrt(vx * vx + vy * vy);
      final off = ((ballX - paddleX) / (paddleW / 2 + ballR)).clamp(-1.0, 1.0);
      final angle = off * (pi / 3); // up to 60 degrees from straight up
      vx = s * sin(angle);
      vy = -s * cos(angle);
      ballY = paddleY - ballR;
    }
  }

  void _hitBricks() {
    for (var r = 0; r < bricks.length; r++) {
      for (var c = 0; c < brickCols; c++) {
        if (bricks[r][c] == 0) continue;
        final bx = c * brickCellW;
        final by = brickTop + r * brickCellH;
        final nx = ballX.clamp(bx, bx + brickCellW);
        final ny = ballY.clamp(by, by + brickCellH);
        final dx = ballX - nx;
        final dy = ballY - ny;
        if (dx * dx + dy * dy > ballR * ballR) continue;
        // Reflect on the axis of least overlap.
        final penX = min(ballX + ballR - bx, bx + brickCellW - (ballX - ballR));
        final penY = min(ballY + ballR - by, by + brickCellH - (ballY - ballR));
        if (penX < penY) {
          vx = ballX < bx + brickCellW / 2 ? -vx.abs() : vx.abs();
        } else {
          vy = ballY < by + brickCellH / 2 ? -vy.abs() : vy.abs();
        }
        _keepRising();
        bricks[r][c]--;
        if (bricks[r][c] == 0) {
          score += 10;
          if (random.nextDouble() < powerUpChance) {
            powerUps.add(
              PowerUp(
                random.nextBool()
                    ? PowerUpKind.widePaddle
                    : PowerUpKind.slowBall,
                bx + brickCellW / 2,
                by + brickCellH,
              ),
            );
          }
        } else {
          score += 5;
        }
        if (bricksLeft == 0) _levelCleared();
        return; // one brick a step
      }
    }
  }

  /// Keeps a flat ball from bouncing sideways for ever: at least a quarter of its speed is
  /// vertical.
  void _keepRising() {
    final s = sqrt(vx * vx + vy * vy);
    if (vy.abs() < s * 0.25) {
      final sign = vy < 0 ? -1 : 1;
      vy = sign * s * 0.25;
      vx = (vx < 0 ? -1 : 1) * sqrt(s * s - vy * vy);
    }
  }

  void _levelCleared() {
    score += 50;
    if (level >= brickLevels) {
      won = true;
      over = true;
      return;
    }
    level++;
    _loadLevel();
  }

  void _lostBall() {
    lives--;
    if (lives <= 0) {
      over = true;
      launched = false;
      return;
    }
    _resetBall();
  }
}
