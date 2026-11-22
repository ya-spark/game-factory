/// Wind-up dash rules. Pure Dart: no Flutter, Flame or Android imports. The track is generated from a seed
/// (`dash_courses.dart`), so it is the same every time for a seed and can be tested for fairness. Fixed step: the
/// screen calls [DashGame.step] with [dashStep] seconds each time.
library;

import 'dart:math';

import 'dash_courses.dart';
import 'dash_meter.dart';
import 'dash_stars.dart';

export 'dash_courses.dart';
export 'dash_meter.dart';
export 'dash_stars.dart';

/// A jump pressed up to this long before landing fires on landing (it only ever helps).
const double jumpBuffer = 0.1;

/// A jump pressed up to this long after the ground ran out under the car still jumps (it only ever helps).
const double coyoteTime = 0.08;

enum DashEnd { none, fell, hit, finished }

/// What happened in a step, for the screen's sound and effects.
enum DashEvent {
  jump,
  land,
  star,
  springFull,
  bounce,
  crash,
  checkpoint,
  finish,
  closeCall,
}

class DashGame {
  DashGame({required int seed, this.course})
    : track = course?.newTrack() ?? DashTrack(seed) {
    if (course == null) track.extendTo(600);
    _cpMeter = SpringMeter();
  }

  /// The course being played, or null for the free run.
  final DashCourse? course;
  final DashTrack track;

  /// Centre of the car along the track, and its height above the ground.
  double x = 0;
  double y = 0;
  double _vy = 0;
  double best = 0; // furthest distance
  DashEnd end = DashEnd.none;
  Hazard? _killer;
  double _buffer = 0;
  double _gapTime = 0;
  double time = 0;

  /// Stars picked up (indices into [DashTrack.stars]), the meter and the bounces used.
  Set<int> taken = {};
  SpringMeter meter = SpringMeter();
  int bounces = 0;

  /// Crashes in the whole course, and since the last checkpoint.
  int crashes = 0;
  int crashesHere = 0;

  /// Checkpoints passed (0 = none; the start is the restart point until the first flag).
  int checkpoint = 0;
  double _cpX = 0;
  Set<int> _cpTaken = {};
  late SpringMeter _cpMeter;
  final Map<Hazard, double> _clear = {};
  final Set<Hazard> _reported = {};
  final List<DashEvent> _events = [];

  bool get isCourse => course != null;
  bool get over => end != DashEnd.none;
  bool get finished => end == DashEnd.finished;
  bool get grounded => y <= 0 && _vy == 0;

  /// Units to the finish (null in the free run).
  double? get length => course?.length;

  /// Stars on the whole course (a course track is fully generated); in the free run the ones made so far.
  int get totalStars => track.stars.length;
  int get starCount => taken.length;

  /// 1 point per 10 units run, plus 5 for each star.
  int get score => dashScore(best, starCount);

  /// Course stars (0 to 3) once the flag is reached.
  int get courseStars =>
      dashCourseStars(finished: finished, picked: starCount, total: totalStars);

  /// The events since the last call, oldest first.
  List<DashEvent> drainEvents() {
    final e = List.of(_events);
    _events.clear();
    return e;
  }

  /// Starts a jump when on the ground (or within [coyoteTime] of running out of it). A jump pressed in the air is
  /// kept for [jumpBuffer] seconds and fires on landing. Returns true when a jump started now.
  bool jump() {
    if (over) return false;
    if (!grounded) {
      _buffer = jumpBuffer;
      return false;
    }
    _launch();
    return true;
  }

  void _launch() {
    _vy = dashJumpSpeed;
    _buffer = 0;
    _gapTime = 0;
    _events.add(DashEvent.jump);
  }

  /// One fixed step of [dashStep] seconds.
  void step() {
    if (over) return;
    const dt = dashStep;
    time += dt;
    if (_buffer > 0) {
      _buffer -= dt;
      if (grounded && _buffer > 0) _launch();
    }
    x += dashSpeed(x, start: course?.startSpeed ?? 32) * dt;
    if (x > best) best = x;
    track.extendTo(x + 600);
    if (_vy != 0 || y > 0) {
      _vy -= dashGravity * dt;
      y += _vy * dt;
      if (y <= 0) {
        y = 0;
        _vy = 0;
        _events.add(DashEvent.land);
        if (_buffer > 0) _launch();
      }
    }
    _check(dt);
    if (over) return;
    _pickStars();
    _passFlags();
    final len = length;
    if (len != null && x >= len) {
      end = DashEnd.finished;
      _events.add(DashEvent.finish);
    }
  }

  void _check(double dt) {
    final left = x - dashWidth / 2;
    final right = x + dashWidth / 2;
    var overGap = false;
    for (final h in track.hazards) {
      if (h.end < left - 1) continue;
      if (h.x > right + 1) break;
      switch (h.kind) {
        case HazardKind.block:
          if (right > h.x && left < h.end) {
            _clear[h] = min(_clear[h] ?? 99, y - h.height);
            if (y < h.height) {
              if (meter.absorb()) {
                _bounce(h);
              } else {
                _die(DashEnd.hit, h);
                return;
              }
            }
          } else if (left >= h.end && _clear.containsKey(h)) {
            _reportClear(h);
          }
        case HazardKind.gap:
          // Standing on the ground with the centre over the gap: falls, after the coyote time.
          if (y <= 0 && _vy == 0 && x > h.x && x < h.end) overGap = true;
      }
    }
    if (overGap) {
      _gapTime += dt;
      if (_gapTime >= coyoteTime) {
        final h = track.hazards.firstWhere(
          (h) => h.kind == HazardKind.gap && x > h.x && x < h.end,
        );
        _die(DashEnd.fell, h);
      }
    } else {
      _gapTime = 0;
    }
  }

  void _reportClear(Hazard h) {
    final c = _clear.remove(h);
    if (c != null && c >= 0 && c < 1 && _reported.add(h)) {
      _events.add(DashEvent.closeCall);
    }
  }

  /// The spring takes a block hit: the car is thrown back [bounceBack] units and hops over the brick.
  void _bounce(Hazard h) {
    x = h.x - dashWidth / 2 - bounceBack;
    _vy = dashJumpSpeed;
    _buffer = 0;
    bounces++;
    _events.add(DashEvent.bounce);
  }

  void _pickStars() {
    final cy = y + dashHeight / 2;
    final stars = track.stars;
    for (var i = 0; i < stars.length; i++) {
      final s = stars[i];
      if (s.x < x - 8) continue;
      if (s.x > x + 8) break;
      if (taken.contains(i)) continue;
      final dx = s.x - x;
      final dy = s.y - cy;
      if (dx * dx + dy * dy <= starPickRadius * starPickRadius) {
        taken.add(i);
        _events.add(DashEvent.star);
        if (meter.add()) _events.add(DashEvent.springFull);
      }
    }
  }

  void _passFlags() {
    final flags = track.flags;
    while (checkpoint < flags.length && x >= flags[checkpoint]) {
      _cpX = flags[checkpoint];
      checkpoint++;
      _cpTaken = Set.of(taken);
      _cpMeter = meter.copy();
      crashesHere = 0;
      _events.add(DashEvent.checkpoint);
    }
  }

  void _die(DashEnd how, Hazard h) {
    end = how;
    _killer = h;
    crashes++;
    crashesHere++;
    _events.add(DashEvent.crash);
  }

  /// A Continue after a crash in the free run: the car starts again on safe ground 20 units before the hazard that
  /// stopped it; the distance reached is kept. (Apps only; the web has no rewarded Continue.)
  void grantContinue() {
    final h = _killer;
    if (!over || h == null || finished) return;
    end = DashEnd.none;
    x = max(0, h.x - 20);
    y = 0;
    _vy = 0;
    _killer = null;
    _gapTime = 0;
    _buffer = 0;
  }

  /// The free checkpoint restart of a course: back on the ground on the last flag (or the start), the stars picked
  /// up since that flag put back, the meter as it was there. The crash count stays.
  void restartAtCheckpoint() {
    if (!isCourse || !over || finished) return;
    end = DashEnd.none;
    x = _cpX;
    y = 0;
    _vy = 0;
    _killer = null;
    _gapTime = 0;
    _buffer = 0;
    taken = Set.of(_cpTaken);
    meter = _cpMeter.copy();
    _clear.clear();
  }

  /// 0 to 1 while the ground has run out under the car (the coyote time), for the dip into the gap.
  double get gapProgress => (_gapTime / coyoteTime).clamp(0.0, 1.0);

  /// The x of the last checkpoint flag passed (0 at the start).
  double get checkpointX => _cpX;

  /// Where a jump for the next hazard ahead should start so the top of the arc is over its middle (for the hint),
  /// or null.
  double? get hintJumpAt {
    final h = track.nextFrom(x - dashWidth);
    if (h == null) return null;
    final reach = dashSpeed(h.x, start: course?.startSpeed ?? 32) * dashAirTime;
    return h.mid - reach / 2;
  }
}
