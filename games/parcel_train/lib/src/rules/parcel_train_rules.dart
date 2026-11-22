/// Parcel train rules. Pure Dart: no Flutter, Flame or Android imports. The random source is injected.
library;

import 'dart:math';

enum TrainDir {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const TrainDir(this.dx, this.dy);
  final int dx;
  final int dy;

  TrainDir get opposite => switch (this) {
    TrainDir.up => TrainDir.down,
    TrainDir.down => TrainDir.up,
    TrainDir.left => TrainDir.right,
    TrainDir.right => TrainDir.left,
  };
}

/// Why a game ended.
enum TrainEnd { none, wall, self, filled }

class TrainCell {
  const TrainCell(this.x, this.y);
  final int x;
  final int y;
  @override
  bool operator ==(Object other) =>
      other is TrainCell && other.x == x && other.y == y;
  @override
  int get hashCode => x * 1000 + y;
  @override
  String toString() => '($x,$y)';
}

const int trainStartLength = 3;
const int trainPointsPerParcel = 10;

/// Seconds per move: 0.20 at the start length, 0.006 faster per segment, never under 0.08.
double trainInterval(int length) {
  final v = 0.20 - 0.006 * (length - trainStartLength);
  return v < 0.08 ? 0.08 : v;
}

class TrainGame {
  TrainGame({
    this.cols = 15,
    this.rows = 15,
    this.wrap = false,
    required this.random,
  }) {
    final y = rows ~/ 2;
    for (var i = 0; i < trainStartLength; i++) {
      body.add(TrainCell(cols ~/ 2 - i, y)); // head first
    }
    _placeFood();
  }

  final int cols;
  final int rows;

  /// Walls wrap round to the other side instead of ending the game.
  final bool wrap;
  final Random random;

  /// Head first.
  final List<TrainCell> body = [];
  TrainCell? food;
  TrainDir dir = TrainDir.right;
  final List<TrainDir> _queue = [];
  int eaten = 0;
  TrainEnd end = TrainEnd.none;
  double _clock = 0;

  bool get over => end != TrainEnd.none;
  int get score => eaten * trainPointsPerParcel;
  int get length => body.length;
  TrainCell get head => body.first;

  /// Queues a turn (at most two waiting). A turn straight back is ignored.
  void turn(TrainDir d) {
    if (over || _queue.length >= 2) return;
    final last = _queue.isEmpty ? dir : _queue.last;
    if (d == last || d == last.opposite) return;
    _queue.add(d);
  }

  /// Advances the clock by [dt] seconds and moves as often as it is due.
  /// Returns the number of moves.
  int update(double dt) {
    var moves = 0;
    _clock += dt;
    while (!over && _clock >= trainInterval(length)) {
      _clock -= trainInterval(length);
      move();
      moves++;
    }
    return moves;
  }

  /// One move.
  void move() {
    if (over) return;
    if (_queue.isNotEmpty) dir = _queue.removeAt(0);
    var nx = head.x + dir.dx;
    var ny = head.y + dir.dy;
    if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) {
      if (!wrap) {
        end = TrainEnd.wall;
        return;
      }
      nx = (nx + cols) % cols;
      ny = (ny + rows) % rows;
    }
    final next = TrainCell(nx, ny);
    final grows = next == food;
    // The tail steps away this move, so its cell is free unless the train grows.
    final blocking = grows ? body : body.sublist(0, body.length - 1);
    if (blocking.contains(next)) {
      end = TrainEnd.self;
      return;
    }
    body.insert(0, next);
    if (grows) {
      eaten++;
      _placeFood();
    } else {
      body.removeLast();
    }
  }

  void _placeFood() {
    final taken = body.toSet();
    final free = <TrainCell>[
      for (var y = 0; y < rows; y++)
        for (var x = 0; x < cols; x++)
          if (!taken.contains(TrainCell(x, y))) TrainCell(x, y),
    ];
    if (free.isEmpty) {
      food = null;
      end = TrainEnd.filled;
      return;
    }
    food = free[random.nextInt(free.length)];
  }
}
