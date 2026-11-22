/// Wind-up dash rules. Pure Dart: no Flutter, Flame or Android imports. The track is generated from a
/// seed, so it is the same every time for a seed and can be tested for fairness. Fixed step: the
/// screen calls [DashGame.step] with [dashStep] seconds each time.
library;

import 'dart:math';

const double dashStep = 1 / 120;

/// Jump: a fixed arc, so what can be cleared is known. Gravity 180 units/s squared, launch speed
/// 70 units/s: 0.78 s in the air, 13.6 units high at the top.
const double dashGravity = 180;
const double dashJumpSpeed = 70;
const double dashAirTime = 2 * dashJumpSpeed / dashGravity;

/// The car is [dashWidth] wide; its position is its centre.
const double dashWidth = 4;

/// Run speed in units/s after [distance] units: 32, rising to 60 at 1400 units.
double dashSpeed(double distance) => min(32 + distance / 50, 60);

enum HazardKind { gap, block }

/// A hazard on the track: a gap in the ground, or a block standing on it.
class Hazard {
  const Hazard(this.kind, this.x, this.width, [this.height = 0]);
  final HazardKind kind;
  final double x;
  final double width;

  /// Height of a block (0 for a gap).
  final double height;
  double get end => x + width;
}

const double firstHazardAt = 90;

/// Largest gap, as a share of the distance a jump covers at the speed there: the rest is the
/// player's room to time the jump (at least 55 percent of the jump, 0.43 s at the start).
const double maxGapShare = 0.45;
const double blockMinWidth = 4;
const double blockMaxWidth = 6;
const double blockMinHeight = 4;
const double blockMaxHeight = 6;

/// The least free ground between two hazards at [distance]: a full jump plus 0.3 s to react.
double minSpacing(double distance) =>
    dashSpeed(distance) * (dashAirTime + 0.3);

/// The track of a seed, generated as far as it is asked for.
class DashTrack {
  DashTrack(int seed) : _random = Random(seed);
  final Random _random;
  final List<Hazard> hazards = [];
  double _frontier = firstHazardAt;

  /// Makes sure hazards exist up to [distance] units.
  void extendTo(double distance) {
    while (_frontier < distance) {
      final d = _frontier;
      final v = dashSpeed(d);
      if (_random.nextDouble() < 0.45) {
        final reach = v * dashAirTime * maxGapShare;
        final w = 10 + _random.nextDouble() * (reach - 10);
        hazards.add(Hazard(HazardKind.gap, d, w));
        _frontier = d + w;
      } else {
        final w =
            blockMinWidth +
            _random.nextDouble() * (blockMaxWidth - blockMinWidth);
        final h =
            blockMinHeight +
            _random.nextDouble() * (blockMaxHeight - blockMinHeight);
        hazards.add(Hazard(HazardKind.block, d, w, h));
        _frontier = d + w;
      }
      _frontier += minSpacing(_frontier) + _random.nextDouble() * 30;
    }
  }

  /// The hazard the point [x] is in or the next one ahead of it, or null.
  Hazard? nextFrom(double x) {
    extendTo(x + 400);
    for (final h in hazards) {
      if (h.end >= x) return h;
    }
    return null;
  }
}

enum DashEnd { none, fell, hit }

class DashGame {
  DashGame({required int seed}) : track = DashTrack(seed) {
    track.extendTo(600);
  }

  final DashTrack track;

  /// Centre of the car along the track, and its height above the ground.
  double x = 0;
  double y = 0;
  double _vy = 0;
  double best = 0; // furthest distance
  DashEnd end = DashEnd.none;
  Hazard? _killer;

  bool get over => end != DashEnd.none;
  bool get grounded => y <= 0 && _vy == 0;

  /// 1 point per 10 units run.
  int get score => (best / 10).floor();

  /// Starts a jump when on the ground. Returns true when it started.
  bool jump() {
    if (over || !grounded) return false;
    _vy = dashJumpSpeed;
    return true;
  }

  /// One fixed step of [dashStep] seconds.
  void step() {
    if (over) return;
    const dt = dashStep;
    x += dashSpeed(x) * dt;
    if (x > best) best = x;
    track.extendTo(x + 600);
    if (_vy != 0 || y > 0) {
      _vy -= dashGravity * dt;
      y += _vy * dt;
      if (y <= 0) {
        y = 0;
        _vy = 0;
      }
    }
    _check();
  }

  void _check() {
    final left = x - dashWidth / 2;
    final right = x + dashWidth / 2;
    for (final h in track.hazards) {
      if (h.end < left - 1) continue;
      if (h.x > right + 1) break;
      switch (h.kind) {
        case HazardKind.block:
          if (right > h.x && left < h.end && y < h.height) {
            _die(DashEnd.hit, h);
            return;
          }
        case HazardKind.gap:
          // Standing on the ground with the centre over the gap: falls.
          if (y <= 0 && x > h.x && x < h.end) {
            _die(DashEnd.fell, h);
            return;
          }
      }
    }
  }

  void _die(DashEnd how, Hazard h) {
    end = how;
    _killer = h;
  }

  /// A Continue after a crash: the car starts again on safe ground 20 units before the hazard
  /// that stopped it; the distance reached is kept.
  void grantContinue() {
    final h = _killer;
    if (!over || h == null) return;
    end = DashEnd.none;
    x = max(0, h.x - 20);
    y = 0;
    _vy = 0;
    _killer = null;
  }
}
