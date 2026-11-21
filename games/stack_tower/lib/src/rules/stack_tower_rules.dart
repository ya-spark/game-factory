/// Stack tower rules. Pure Dart: no Flutter, Flame or Android imports. The random source is
/// injected (it picks the side each block comes from). Fixed step: the screen calls
/// [StackGame.step] with [stackStep] seconds each time.
library;

import 'dart:math';

const double stackW = 100;
const double stackStep = 1 / 120;
const double stackStartWidth = 40;

/// A drop within this many units of the block below is perfect: it snaps and keeps its width.
const double stackPerfectTolerance = 1.2;
const int stackDropPoints = 10;
const int stackStreakPoints = 5;
const int stackStreakCap = 10;

/// Units per second of the sliding block for a tower of [height] blocks: 40, +2.5 a block, at most 120.
double stackSpeed(int height) => min(40 + 2.5 * height, 120);

class StackBlock {
  const StackBlock(this.x, this.width);

  /// Left edge.
  final double x;
  final double width;
  double get right => x + width;
}

class StackGame {
  StackGame({required this.random}) {
    blocks.add(
      const StackBlock((stackW - stackStartWidth) / 2, stackStartWidth),
    );
    _spawn();
  }

  final Random random;

  /// The tower, base first. The base counts as height 0.
  final List<StackBlock> blocks = [];

  /// The sliding block: left edge and width (the width of the block below it).
  double x = 0;
  double width = stackStartWidth;
  int _dir = 1;
  int streak = 0;
  int perfects = 0;
  int score = 0;
  bool over = false;

  /// The last dropped piece that fell off (for the view); null when none.
  StackBlock? lastCut;

  /// Blocks stacked, not counting the base.
  int get height => blocks.length - 1;
  StackBlock get top => blocks.last;

  void _spawn() {
    width = top.width;
    _dir = random.nextBool() ? 1 : -1;
    x = _dir == 1 ? 0 : stackW - width;
  }

  /// One fixed step: the block slides and turns round at the edges.
  void step() {
    if (over) return;
    x += _dir * stackSpeed(height) * stackStep;
    if (x <= 0) {
      x = 0;
      _dir = 1;
    } else if (x + width >= stackW) {
      x = stackW - width;
      _dir = -1;
    }
  }

  /// Drops the sliding block. Returns true when it landed (some overlap), false on a miss.
  bool drop() {
    if (over) return false;
    final below = top;
    final left = max(x, below.x);
    final right = min(x + width, below.right);
    final overlap = right - left;
    if (overlap <= 0) {
      over = true;
      lastCut = StackBlock(x, width);
      return false;
    }
    final offset = (x - below.x).abs();
    if (offset <= stackPerfectTolerance) {
      streak++;
      perfects++;
      blocks.add(StackBlock(below.x, below.width));
      score +=
          stackDropPoints + stackStreakPoints * min(streak, stackStreakCap);
      lastCut = null;
    } else {
      streak = 0;
      blocks.add(StackBlock(left, overlap));
      score += stackDropPoints;
      lastCut = x < below.x
          ? StackBlock(x, below.x - x)
          : StackBlock(below.right, x + width - below.right);
    }
    _spawn();
    return true;
  }

  /// A Continue after a miss: the missed block slides in again over the same tower.
  void grantContinue() {
    if (!over) return;
    over = false;
    streak = 0;
    lastCut = null;
    _spawn();
  }
}
