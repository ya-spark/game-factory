/// Parcel train rules. Pure Dart: no Flutter, Flame or Android imports. The random source is injected.
library;

import 'dart:math';

import 'train_courses.dart';

export 'train_courses.dart';

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

/// Why a round ended. [derail] and [arrived] are course endings.
enum TrainEnd { none, wall, self, filled, derail, arrived }

/// What happened during a move, for the picture and the sound hooks.
enum TrainEvent { step, parcel, golden, bump, derail, gateOpen, arrive, tunnel }

const int trainStartLength = 3;
const int trainPointsPerParcel = 10;
const int trainGoldenPoints = 30;
const int trainBumperPoints = 5;
const int trainBumpers = 3;

/// Best-score thresholds of the Games tab tile (Free ride): 5, 15 and 30 parcels.
const List<int> trainStarScores = [50, 150, 300];

/// Seconds per move: [base] at the start length, [perSegment] faster per segment over 3, never under [floor].
/// Free ride: 0.20, 0.006, 0.08. Courses: the course's base, 0.004, 0.12.
double trainInterval(
  int length, {
  double base = 0.20,
  double perSegment = 0.006,
  double floor = 0.08,
}) {
  final v = base - perSegment * (length - trainStartLength);
  return v < floor ? floor : v;
}

/// Course stars (0 to 3): 1 delivered, 2 also the golden parcel, 3 also no bumper and no derail in the run.
int trainCourseStars({
  required bool arrived,
  required bool golden,
  required int bumpersUsed,
  required int derails,
}) {
  if (!arrived) return 0;
  if (!golden) return 1;
  return (bumpersUsed == 0 && derails == 0) ? 3 : 2;
}

/// Coins of a score: 1 per 20 points, at most 20 a round.
int trainCoins(int score) => min(20, score ~/ 20);

/// Whether course [index] (0 based) is open: course 1 always, later ones when the one before has a star.
bool trainCourseOpen(int index, List<int> stars) =>
    index == 0 || (index <= stars.length && stars[index - 1] >= 1);

class TrainGame {
  /// A Free ride when [course] is null (a [cols] x [rows] mat, edge wrap optional, one life), else the course.
  TrainGame({
    this.course,
    int cols = 15,
    int rows = 15,
    this.wrap = false,
    int? bumpers,
    this.derailsBefore = 0,
    required this.random,
  }) : cols = course?.cols ?? cols,
       rows = course?.rows ?? rows,
       bumpers = course == null ? 0 : (bumpers ?? trainBumpers) {
    final start = course?.start ?? TrainCell(cols ~/ 2, rows ~/ 2);
    for (var i = 0; i < trainStartLength; i++) {
      body.add(TrainCell(start.x - i, start.y)); // head first
      colors.add(4); // an empty wagon
    }
    if (course != null) _placeGolden();
    _placeParcel(first: true);
    prevBody = List.of(body);
  }

  final TrainCourse? course;
  final int cols;
  final int rows;

  /// Edges wrap round to the other side (Free ride only).
  final bool wrap;
  final Random random;

  /// Derails of this course before this try (for the third star).
  final int derailsBefore;

  /// Head first.
  final List<TrainCell> body = [];

  /// The body before the last move (the picture slides from it to [body]).
  List<TrainCell> prevBody = [];

  /// The cargo colour (0 to 3, 4 empty) of each segment, aligned with [body] by index.
  final List<int> colors = [];
  TrainCell? parcel;
  int parcelColor = 0;
  TrainCell? golden;
  bool goldenTaken = false;
  TrainDir dir = TrainDir.right;
  final List<TrainDir> _queue = [];
  int eaten = 0;
  int bumpers;
  int bumpersUsed = 0;
  TrainEnd end = TrainEnd.none;
  bool gateOpen = false;

  /// True after a bump: the train stands still until a turn key points it at a free cell.
  bool waiting = false;
  int _placed = 0;
  double _clock = 0;

  /// Events since the last [drainEvents].
  final List<TrainEvent> _events = [];

  /// 0 to 1: how far the clock is to the next move (for smooth drawing); 1 while standing or over.
  double get stepProgress =>
      over || waiting ? 1.0 : (_clock / interval).clamp(0.0, 1.0);

  bool get isCourse => course != null;
  bool get over => end != TrainEnd.none;
  int get length => body.length;
  TrainCell get head => body.first;
  int get queued => _queue.length;
  int get goal => course?.goal ?? 0;

  int get score =>
      eaten * trainPointsPerParcel +
      (goldenTaken ? trainGoldenPoints : 0) +
      (end == TrainEnd.arrived ? bumpers * trainBumperPoints : 0);

  int get stars => trainCourseStars(
    arrived: end == TrainEnd.arrived,
    golden: goldenTaken,
    bumpersUsed: bumpersUsed,
    derails: derailsBefore,
  );

  /// Seconds per move now.
  double get interval => course == null
      ? trainInterval(length)
      : trainInterval(
          length,
          base: course!.baseInterval,
          perSegment: 0.004,
          floor: 0.12,
        );

  List<TrainEvent> drainEvents() {
    final e = List<TrainEvent>.of(_events);
    _events.clear();
    return e;
  }

  // ---- the mat ----

  bool _solidAt(int x, int y) {
    final c = course;
    if (c == null) return false;
    if (!c.inside(x, y)) return true;
    return c.solid(x, y);
  }

  /// Where a step from [c] in [d] lands, looking only at the mat (not the wagons): null when the edge, an
  /// obstacle or the closed gate is in the way. A tunnel mouth lands on its partner mouth.
  TrainCell? landing(TrainCell c, TrainDir d) {
    var nx = c.x + d.dx;
    var ny = c.y + d.dy;
    if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) {
      if (!wrap) return null;
      nx = (nx + cols) % cols;
      ny = (ny + rows) % rows;
    }
    final cr = course;
    if (cr != null) {
      if (cr.solid(nx, ny)) return null;
      final t = cr.tile(nx, ny);
      if (t == TrainTile.gate) return gateOpen ? TrainCell(nx, ny) : null;
      if (t == TrainTile.tunnel) return cr.tunnelPairs[TrainCell(nx, ny)];
    }
    return TrainCell(nx, ny);
  }

  bool _isGate(TrainCell c) => course != null && c == course!.gate;

  /// The wagons that block a step this move (the tail steps away unless the train grows).
  Iterable<TrainCell> _blockingBody(TrainCell target) =>
      target == parcel ? body : body.sublist(0, body.length - 1);

  /// Whether a step in [d] from the head is blocked now (mat or wagons).
  bool blocked(TrainDir d) {
    final t = landing(head, d);
    if (t == null) return true;
    if (_isGate(t)) return false;
    return _blockingBody(t).contains(t);
  }

  // ---- steering ----

  /// Queues a turn (at most two waiting). A turn straight back or a repeat is ignored. After a bump a turn to a
  /// free direction frees the train at once.
  void turn(TrainDir d) {
    if (over) return;
    if (waiting) {
      if (d == dir.opposite || blocked(d)) return;
      dir = d;
      _queue.clear();
      waiting = false;
      _clock = interval; // moves on the next update
      return;
    }
    if (_queue.length >= 2) return;
    final last = _queue.isEmpty ? dir : _queue.last;
    if (d == last || d == last.opposite) return;
    _queue.add(d);
  }

  /// Advances the clock by [dt] seconds and moves as often as it is due. Returns the number of moves.
  int update(double dt) {
    var moves = 0;
    if (waiting) return 0; // the clock does not run while the train stands
    _clock += dt;
    while (!over && !waiting && _clock >= interval) {
      _clock -= interval;
      move();
      moves++;
    }
    return moves;
  }

  /// One move.
  void move() {
    if (over || waiting) return;
    if (_queue.isNotEmpty) dir = _queue.removeAt(0);
    final t = landing(head, dir);
    if (t == null) return _hit(wallHit: true);
    if (_isGate(t)) {
      prevBody = List.of(body);
      body.insert(0, t);
      body.removeLast();
      end = TrainEnd.arrived;
      _events.add(TrainEvent.arrive);
      return;
    }
    final grows = t == parcel;
    if (_blockingBody(t).contains(t)) return _hit(wallHit: false);
    prevBody = List.of(body);
    final tunnelled =
        (t.x - head.x).abs() + (t.y - head.y).abs() != 1 &&
        !(wrap && (t.x == 0 || t.y == 0 || t.x == cols - 1 || t.y == rows - 1));
    body.insert(0, t);
    if (grows) {
      colors.add(parcelColor);
      eaten++;
      _events.add(TrainEvent.parcel);
    } else {
      body.removeLast();
    }
    _events.add(
      tunnelled && course != null ? TrainEvent.tunnel : TrainEvent.step,
    );
    if (t == golden && !goldenTaken) {
      goldenTaken = true;
      golden = null;
      _events.add(TrainEvent.golden);
    }
    if (grows) {
      _placeParcel();
      if (course != null && !gateOpen && eaten >= course!.goal) {
        gateOpen = true;
        _events.add(TrainEvent.gateOpen);
      }
    }
  }

  void _hit({required bool wallHit}) {
    if (course == null) {
      end = wallHit ? TrainEnd.wall : TrainEnd.self;
      return;
    }
    if (bumpers > 0) {
      bumpers--;
      bumpersUsed++;
      waiting = true;
      _events.add(TrainEvent.bump);
    } else {
      end = TrainEnd.derail;
      _events.add(TrainEvent.derail);
    }
  }

  // ---- parcels ----

  int _freeNeighbours(int x, int y) {
    var n = 0;
    for (final d in TrainDir.values) {
      var nx = x + d.dx;
      var ny = y + d.dy;
      if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) {
        if (!wrap) continue;
        nx = (nx + cols) % cols;
        ny = (ny + rows) % rows;
      }
      if (_solidAt(nx, ny)) continue;
      if (course != null && course!.tile(nx, ny) == TrainTile.gate) continue;
      n++;
    }
    return n;
  }

  /// A nook has fewer than two ways in: a parcel there would be a forced crash.
  bool isNook(int x, int y) => _freeNeighbours(x, y) < 2;

  bool _plain(int x, int y) {
    final c = course;
    if (c == null) return true;
    final t = c.tile(x, y);
    return t == TrainTile.free;
  }

  void _placeParcel({bool first = false}) {
    final taken = body.toSet();
    final ahead = <TrainCell>{
      TrainCell(head.x + dir.dx, head.y + dir.dy),
      TrainCell(head.x + 2 * dir.dx, head.y + 2 * dir.dy),
    };
    bool ok(int x, int y, {required bool strict}) {
      final c = TrainCell(x, y);
      if (taken.contains(c) || c == golden || !_plain(x, y)) return false;
      if (strict && (ahead.contains(c) || isNook(x, y))) return false;
      return true;
    }

    if (first) {
      final x = head.x + 4 * dir.dx;
      final y = head.y + 4 * dir.dy;
      if (x >= 0 && y >= 0 && x < cols && y < rows && ok(x, y, strict: false)) {
        _setParcel(TrainCell(x, y));
        return;
      }
    }
    for (final strict in [true, false]) {
      final free = <TrainCell>[
        for (var y = 0; y < rows; y++)
          for (var x = 0; x < cols; x++)
            if (ok(x, y, strict: strict)) TrainCell(x, y),
      ];
      if (free.isNotEmpty) {
        _setParcel(free[random.nextInt(free.length)]);
        return;
      }
    }
    parcel = null;
    end = TrainEnd.filled;
  }

  void _setParcel(TrainCell c) {
    parcel = c;
    parcelColor = _placed % 4;
    _placed++;
  }

  /// The golden parcel: a corner next to walls (two perpendicular blocked sides), never a nook, never on the
  /// way of the first parcel.
  void _placeGolden() {
    final c = course!;
    final first = TrainCell(head.x + 4, head.y);
    bool blockedSide(int x, int y) =>
        x < 0 ||
        y < 0 ||
        x >= cols ||
        y >= rows ||
        _solidAt(x, y) ||
        c.tile(x, y) == TrainTile.gate;
    final corners = <TrainCell>[];
    final sides = <TrainCell>[];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final cell = TrainCell(x, y);
        if (!_plain(x, y) || body.contains(cell) || cell == first) continue;
        if (isNook(x, y)) continue;
        final u = blockedSide(x, y - 1), d = blockedSide(x, y + 1);
        final l = blockedSide(x - 1, y), r = blockedSide(x + 1, y);
        final n = [u, d, l, r].where((b) => b).length;
        if (n == 2 && !(u && d) && !(l && r)) {
          corners.add(cell);
        } else if (n >= 1) {
          sides.add(cell);
        }
      }
    }
    final pool = corners.isNotEmpty ? corners : sides;
    golden = pool[random.nextInt(pool.length)];
  }
}
