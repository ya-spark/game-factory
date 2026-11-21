/// A fixed-step clock for the arcade games. Pure Dart.
///
/// The screen feeds it the real frame time; it answers how many whole steps of [dt] to run.
/// Rules advance only by whole steps, so a game plays the same at any frame rate and a test
/// can run it step by step.
library;

class FixedStepper {
  FixedStepper({this.dt = 1 / 60, this.maxFrame = 0.25});

  /// Seconds per step.
  final double dt;

  /// A frame longer than this is cut down (after a pause or a slow frame), so there is no
  /// burst of catch-up steps.
  final double maxFrame;

  double _acc = 0;

  /// Adds [elapsed] seconds; returns the number of steps to run now.
  int advance(double elapsed) {
    _acc += elapsed > maxFrame ? maxFrame : elapsed;
    var n = 0;
    while (_acc >= dt) {
      _acc -= dt;
      n++;
    }
    return n;
  }

  void reset() => _acc = 0;
}

/// Coins paid for a run: [score] divided by [perCoins], at most [cap]. The hub pays them to the
/// wallet when a run ends.
int arcadeCoins(int score, {required int perCoins, int cap = 20}) {
  if (score <= 0) return 0;
  final c = score ~/ perCoins;
  return c > cap ? cap : c;
}

/// Number of stars (0 to 3) for [score] against ascending [thresholds].
int arcadeStars(int score, List<int> thresholds) =>
    thresholds.where((t) => score >= t).length;
