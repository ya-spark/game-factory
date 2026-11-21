import 'package:flutter/widgets.dart';

/// How a puzzle screen is started for the daily puzzle (docs/SPEC.md, "Daily puzzle"): from a given
/// seed and difficulty with a fixed layout, no menu. [onSolved] reports the active seconds and the
/// mistakes; [onProgress] saves them when the child leaves, so the puzzle resumes the same day.
class DailyRun {
  const DailyRun({
    required this.day,
    required this.seed,
    required this.tier,
    this.initialSeconds = 0,
    this.initialMistakes = 0,
    this.onProgress,
    this.onSolved,
  });

  /// Calendar day index the puzzle belongs to.
  final int day;

  /// Seed of the puzzle (`DailyPuzzle.gameSeed`): the same on every device for [day].
  final int seed;

  /// Difficulty tier 0..3 (`DailyPuzzle.tierByWeekday`).
  final int tier;

  /// Active seconds already played on this puzzle today (a resumed puzzle continues from them).
  final int initialSeconds;
  final int initialMistakes;
  final void Function(int seconds, int mistakes)? onProgress;
  final void Function(int seconds, int mistakes)? onSolved;
}

/// Counts the active seconds of a puzzle: foreground only (paused while the app is in the
/// background) and continuing from [base]. [now] is injectable for tests.
class ActiveSeconds with WidgetsBindingObserver {
  ActiveSeconds({int base = 0, DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _base = base;
    WidgetsBinding.instance.addObserver(this);
    _start = _now();
  }

  late int _base;
  final DateTime Function() _now;
  DateTime? _start;

  /// Seconds played so far.
  int get seconds =>
      _base + (_start == null ? 0 : _now().difference(_start!).inSeconds);

  void _pause() {
    if (_start == null) return;
    _base += _now().difference(_start!).inSeconds;
    _start = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start ??= _now();
    } else {
      _pause();
    }
  }

  /// Stops the clock for good.
  void dispose() {
    _pause();
    WidgetsBinding.instance.removeObserver(this);
  }
}
