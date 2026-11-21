import 'dart:math';

import 'spire.dart';
import 'world.dart';

/// Produces spire pairs deterministically from an injected [Random].
/// Exactly three random numbers are consumed per pair, so the gap sequence never depends on
/// the score or on how the player plays.
class GapGenerator {
  GapGenerator(this._rng);

  final Random _rng;
  int _count = 0;
  double? _prevCenter;
  bool _prevHadOrb = false;
  double _prevGap = WingyWorld.baseGapStart;

  int get generated => _count;

  /// Generator position for the autosave (the random stream itself starts anew on restore).
  Map<String, Object?> toJson() => {
    'count': _count,
    'prevCenter': _prevCenter,
    'prevHadOrb': _prevHadOrb,
    'prevGap': _prevGap,
  };

  void restoreState(Map j) {
    _count = (j['count']! as num).toInt();
    _prevCenter = (j['prevCenter'] as num?)?.toDouble();
    _prevHadOrb = j['prevHadOrb']! as bool;
    _prevGap = (j['prevGap']! as num).toDouble();
  }

  /// Base gap height for the pair with 0-based index [i].
  static double baseGap(int i) => max(
    WingyWorld.gapFloor,
    WingyWorld.baseGapStart - WingyWorld.gapShrinkPerPair * i,
  );

  static bool _guaranteedOrb(int number) =>
      number >= 3 && number % WingyWorld.orbChanceDenominator == 3;

  /// Next pair at horizontal position [x]. [score] only decides whether drifting gaps are
  /// allowed yet.
  SpirePair next({required double x, required int score}) {
    final number = ++_count;
    final i = number - 1;
    final base = baseGap(i);
    final offset =
        WingyWorld.gapOffsetMin +
        _rng.nextDouble() * (WingyWorld.gapOffsetMax - WingyWorld.gapOffsetMin);
    final centerRoll = _rng.nextDouble();
    final orbRoll = _rng.nextDouble();

    final breather = number % WingyWorld.breatherEvery == 0;
    final gap = breather
        ? base + WingyWorld.breatherBonus
        : max(WingyWorld.gapFloor, base + offset);

    final margin = WingyWorld.gapEdgeMargin + gap / 2;
    var lo = margin;
    var hi = WingyWorld.groundY - margin;
    final prev = _prevCenter;
    if (prev != null) {
      // Next to a (possibly) drifting pair the limit is tightened by the drift amplitude, so
      // that the effective vertical distance never exceeds the 200 u budget. This does not
      // depend on the score, which keeps the sequence the same for a given seed.
      final nearDrift =
          number % WingyWorld.driftEvery == 0 ||
          (number - 1) % WingyWorld.driftEvery == 0;
      // Narrow gaps get a smaller vertical step (140 u at the 150 u floor, 200 u from a
      // 210 u gap): a perfect player can always make it, even at top speed.
      final narrow = min(gap, _prevGap) - WingyWorld.gapFloor;
      final limit =
          min(WingyWorld.maxCenterDelta, 140 + narrow) -
          (nearDrift ? WingyWorld.driftAmplitude : 0);
      lo = max(lo, prev - limit);
      hi = min(hi, prev + limit);
    }
    final center = lo + (hi - lo) * centerRoll;

    final drifting =
        number % WingyWorld.driftEvery == 0 &&
        score >= WingyWorld.driftFromScore;

    final hasOrb =
        _guaranteedOrb(number) ||
        (orbRoll < WingyWorld.orbRandomChance &&
            !_prevHadOrb &&
            !_guaranteedOrb(number + 1));
    _prevHadOrb = hasOrb;
    _prevGap = gap;
    _prevCenter = center;

    return SpirePair(
      number: number,
      x: x,
      baseCenterY: center,
      gapHeight: gap,
      drifting: drifting,
      hasOrb: hasOrb,
    );
  }
}
