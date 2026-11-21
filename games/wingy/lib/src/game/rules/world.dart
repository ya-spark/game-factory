/// World constants for Wingy (logical units "u"). Pure Dart: no Flutter, Flame or Android
/// imports, so the rules run on the VM and stay portable.
abstract final class WingyWorld {
  static const double width = 360;
  static const double height = 640;
  static const double ceilingY = 0;
  static const double groundY = 584;

  /// Fixed simulation step.
  static const double step = 1 / 120;

  static const double heroX = 100;
  static const double heroRadius = 14;
  static const double heroStartY = 292;

  static const double gravity = 1500;
  static const double flapVelocity = -430;
  static const double terminalVelocity = 700;

  static const double startSpeed = 140;
  static const double speedPerPass = 2;
  static const double maxSpeed = 220;

  static const double spireWidth = 56;
  static const double pairSpacing = 220;
  static const double firstPairX = 360;

  static const double baseGapStart = 210;
  static const double gapShrinkPerPair = 1.5;
  static const double gapFloor = 150;
  static const double gapOffsetMin = -20;
  static const double gapOffsetMax = 30;
  static const double gapEdgeMargin = 40;
  static const double maxCenterDelta = 200;
  static const double breatherBonus = 60;
  static const int breatherEvery = 7;

  static const int driftEvery = 10;
  static const int driftFromScore = 20;
  static const double driftAmplitude = 30;
  static const double driftPeriod = 2.0;

  static const double orbRadius = 10;
  static const int orbChanceDenominator = 4;
  static const double orbRandomChance = 0.25;
  static const int runCoinCap = 40;

  static const double perfectFraction = 0.30;
  static const int bloomMax = 5;
  static const int dashPairPoints = 3;

  static const int meterMax = 3;
  static const double dashDuration = 1.2;
  static const double dashGrace = 0.4;

  /// Seconds of normal-speed travel kept clear ahead of Wingy when lightning ends.
  static const double dashExitBuffer = 1.75;
  static const double dashSpeedFactor = 1.8;
  static const double dashMinY = 40;
  static const double dashMaxY = 544;

  /// Recovery float after a dash: seconds, gravity factor and fall-speed cap (u/s).
  static const double recoveryFloatDuration = 0.5;
  static const double recoveryGravityFactor = 0.25;
  static const double recoveryMaxFall = 150;

  /// During a dash Wingy eases into this altitude band at no more than [dashEaseRate] u/s.
  static const double dashEaseMinY = 200;
  static const double dashEaseMaxY = 400;
  static const double dashEaseRate = 250;
  static const double dashEaseInset = 10;

  /// Wingy pulses for the last seconds of the dash (the "tap now" cue).
  static const double dashEndingCue = 0.3;

  static const double deathAnimation = 0.6;
  static const int maxRevives = 3;
  static const double reviveClearDistance = 300;
  static const double reviveInvulnerability = 2.0;
}

enum Palette { dusk, aurora, midnight, sunrise, emerald, ember }

/// Rotation order of the palettes.
const List<Palette> paletteOrder = Palette.values;

/// Points between two palette changes.
const int paletteStep = 20;

/// Palette for [score] in a run whose first palette is `paletteOrder[start]`.
Palette paletteForScore(int score, {int start = 0}) {
  final n = paletteOrder.length;
  return paletteOrder[((start % n) + score ~/ paletteStep) % n];
}

/// The `start` index for the next run: the palette after the one in use at game over.
int nextPaletteStart(int start, int score) =>
    (paletteForScore(score, start: start).index + 1) % paletteOrder.length;

/// Cross-fade between palettes (pure state, driven by the render loop).
class PaletteFade {
  PaletteFade(Palette initial) : from = initial, to = initial;

  static const double duration = 1.5;
  static const double reducedDuration = 0.3;

  Palette from;
  Palette to;

  /// 0..1; 1 means [to] is fully shown.
  double progress = 1;
  double _length = duration;

  bool get running => progress < 1;

  /// Starts a fade towards [target] when it differs from the current target.
  void setTarget(Palette target, {bool reduceMotion = false}) {
    if (target == to) return;
    from = progress >= 0.5 ? to : from;
    to = target;
    progress = 0;
    _length = reduceMotion ? reducedDuration : duration;
  }

  /// Jumps to [target] with no fade (new run, first frame).
  void snapTo(Palette target) {
    from = to = target;
    progress = 1;
  }

  void update(double dt) {
    if (progress >= 1) return;
    progress = (progress + dt / _length).clamp(0.0, 1.0);
  }
}

enum Medal { none, bronze, silver, gold, prism }

Medal medalForScore(int score) {
  if (score >= 100) return Medal.prism;
  if (score >= 50) return Medal.gold;
  if (score >= 25) return Medal.silver;
  if (score >= 10) return Medal.bronze;
  return Medal.none;
}
