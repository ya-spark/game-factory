/// The five courses of Wind-up dash and the hazard track they use. Pure Dart: no Flutter, Flame or Android imports.
///
/// A track is generated from a seed, lazily for the free run and in full for a course, so it is the same every time
/// for a seed and can be tested for fairness. Fixed step: the screen calls `DashGame.step` with [dashStep] seconds.
library;

import 'dart:math';

const double dashStep = 1 / 120;

/// Jump: a fixed arc, so what can be cleared is known. Gravity 180 units/s squared, launch speed
/// 70 units/s: 0.78 s in the air, 13.6 units high at the top.
const double dashGravity = 180;
const double dashJumpSpeed = 70;
const double dashAirTime = 2 * dashJumpSpeed / dashGravity;

/// The car is [dashWidth] wide and [dashHeight] tall; its position is the centre of its width.
const double dashWidth = 4;
const double dashHeight = 3;

/// Run speed in units/s after [distance] units: [start] (32 in the free run), rising by 1 per 50 units to 60.
double dashSpeed(double distance, {double start = 32}) =>
    min(start + distance / 50, 60);

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
  double get mid => x + width / 2;
}

/// A paper star on the track. [ground] stars sit on the floor in lines of three between hazards; the others hang at
/// the top of the jump arc over the middle of a hazard.
class DashStar {
  const DashStar(this.x, this.y, {required this.ground});
  final double x;
  final double y;
  final bool ground;
}

/// Where the first hazard is, and how much free run the start has.
const double firstHazardAt = 90;

/// Largest gap, as a share of the distance a jump covers at the speed there: the rest is the
/// player's room to time the jump (at least 55 percent of the jump, 0.43 s at the start).
const double maxGapShare = 0.45;
const double blockMinWidth = 4;
const double blockMaxWidth = 6;
const double blockMinHeight = 4;
const double blockMaxHeight = 6;

/// A checkpoint flag every 300 units of a course.
const double checkpointEvery = 300;

/// Height of the stars that hang over a hazard, and the reach of a pick-up: the car (a circle of 2.2 around its
/// middle) takes a star (a circle of 2) when the two overlap.
const double hazardStarHeight = 12;
const double groundStarHeight = 2.5;
const double starPickRadius = 4.2;

/// The free ground kept clear of hazards around a checkpoint flag: none from 20 units before to 50 after, so a
/// restart on the flag has room to see the next hazard.
const double flagClearBefore = 20;
const double flagClearAfter = 50;

/// The least free ground between two hazards at [distance]: a full jump plus 0.3 s to react.
double minSpacing(double distance, {double start = 32}) =>
    dashSpeed(distance, start: start) * (dashAirTime + 0.3);

/// What hazards a course mixes.
enum DashMix { blocks, gaps, both }

/// One course: a fixed track (seed 1009 x number) that a child can learn.
class DashCourse {
  const DashCourse({
    required this.number,
    required this.name,
    required this.length,
    required this.startSpeed,
    required this.mix,
    this.tight = false,
  });

  /// 1 to 5.
  final int number;
  final String name;

  /// Units from the start to the flag (the finish).
  final double length;
  final double startSpeed;
  final DashMix mix;

  /// Closer pairs: free ground is the minimum plus 0 to 6 units instead of 0 to 30 (still fair).
  final bool tight;

  int get seed => 1009 * number;

  /// The checkpoint flags on the way (the finish is not one of them).
  List<double> get flags => [
    for (var f = checkpointEvery; f < length - 1; f += checkpointEvery) f,
  ];

  DashTrack newTrack() => DashTrack(
    seed,
    startSpeed: startSpeed,
    mix: mix,
    tight: tight,
    length: length,
  );
}

const int dashCourseCount = 5;

const List<DashCourse> dashCourses = [
  DashCourse(
    number: 1,
    name: 'Playroom floor',
    length: 600,
    startSpeed: 32,
    mix: DashMix.blocks,
  ),
  DashCourse(
    number: 2,
    name: 'Kitchen counter',
    length: 900,
    startSpeed: 36,
    mix: DashMix.gaps,
  ),
  DashCourse(
    number: 3,
    name: 'Toy shelf',
    length: 1200,
    startSpeed: 40,
    mix: DashMix.both,
  ),
  DashCourse(
    number: 4,
    name: 'Night desk',
    length: 1600,
    startSpeed: 46,
    mix: DashMix.both,
    tight: true,
  ),
  DashCourse(
    number: 5,
    name: 'Toy city roof',
    length: 2000,
    startSpeed: 52,
    mix: DashMix.both,
  ),
];

/// Course k+1 opens when course k has at least 1 star; the first is always open ([stars] is the best stars of each
/// course, 0 to 3).
bool dashCourseOpen(int index, List<int> stars) =>
    index == 0 || (index <= stars.length && stars[index - 1] >= 1);

/// The track of a seed, generated as far as it is asked for. A course track (a [length]) is generated to the end:
/// no hazard in the last 40 units, and the flags are kept clear.
class DashTrack {
  DashTrack(
    int seed, {
    this.startSpeed = 32,
    this.mix = DashMix.both,
    this.tight = false,
    this.length,
  }) : _random = Random(seed) {
    final len = length;
    if (len != null) extendTo(len);
  }

  final Random _random;
  final double startSpeed;
  final DashMix mix;
  final bool tight;

  /// Units to the finish, or null for the endless free run.
  final double? length;
  final List<Hazard> hazards = [];
  final List<DashStar> stars = [];
  double _frontier = firstHazardAt;
  double _lastEnd = 0;
  int _spans = 0;
  bool _closed = false;

  /// The flags of a course.
  List<double> get flags => length == null
      ? const []
      : [
          for (var f = checkpointEvery; f < length! - 1; f += checkpointEvery)
            f,
        ];

  double _speed(double d) => dashSpeed(d, start: startSpeed);

  bool _inFlagZone(double a, double b) {
    for (final f in flags) {
      if (a < f + flagClearAfter && b > f - flagClearBefore) return true;
    }
    return false;
  }

  /// Makes sure hazards (and their stars) exist up to [distance] units.
  void extendTo(double distance) {
    final limit = length == null ? double.infinity : length! - 40;
    while (_frontier < distance && !_closed) {
      if (_frontier >= limit) {
        _closeTrack();
        break;
      }
      final d = _frontier;
      final v = _speed(d);
      final gap = switch (mix) {
        DashMix.gaps => true,
        DashMix.blocks => false,
        DashMix.both => _random.nextDouble() < 0.45,
      };
      final double w;
      double h = 0;
      if (gap) {
        final reach = v * dashAirTime * maxGapShare;
        w = 10 + _random.nextDouble() * (reach - 10);
      } else {
        w =
            blockMinWidth +
            _random.nextDouble() * (blockMaxWidth - blockMinWidth);
        h =
            blockMinHeight +
            _random.nextDouble() * (blockMaxHeight - blockMinHeight);
      }
      if (_inFlagZone(d, d + w)) {
        // never a hazard on a flag: the next try starts after the clear zone
        final f = flags.firstWhere(
          (f) => d < f + flagClearAfter && d + w > f - flagClearBefore,
        );
        _frontier = f + flagClearAfter;
        continue;
      }
      if (length != null && d + w > limit) {
        _closeTrack();
        break;
      }
      _addSpanStars(_lastEnd, d);
      hazards.add(
        gap ? Hazard(HazardKind.gap, d, w) : Hazard(HazardKind.block, d, w, h),
      );
      stars.add(DashStar(d + w / 2, hazardStarHeight, ground: false));
      _lastEnd = d + w;
      _frontier = d + w;
      _frontier +=
          minSpacing(_frontier, start: startSpeed) +
          _random.nextDouble() * (tight ? 6 : 30);
    }
  }

  void _closeTrack() {
    if (_closed) return;
    _closed = true;
    _addSpanStars(_lastEnd, length!);
  }

  /// A line of three stars on the ground in the middle of every second free span.
  void _addSpanStars(double from, double to) {
    final index = _spans++;
    if (index.isOdd || to - from < 30) return;
    final mid = (from + to) / 2;
    for (final dx in const [-4.0, 0.0, 4.0]) {
      stars.add(DashStar(mid + dx, groundStarHeight, ground: true));
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
