import 'package:flutter/material.dart';

import '../core/profile/profile_store.dart';
import '../engine/engine.dart';
import 'test_ids.dart';

/// The hook a hub-native game screen uses to report a finished run (M2): the score and what only
/// the game knows (won, mistakes, hints, the variant). The hub wraps each standalone game in this
/// scope, joins the report with the seconds it measured and records it. Call [finished] once per
/// run, when the run ends, right before the existing `onScore` call. Outside a scope (tests, a
/// daily run) reporting does nothing. Games that never call it (the copied games) are recorded
/// from their `onScore` call alone: plays, best, average and time.
class RunReportScope extends InheritedWidget {
  const RunReportScope({super.key, required this.sink, required super.child});

  final void Function(int score, RunExtras extras) sink;

  static void finished(BuildContext context, int score, RunExtras extras) {
    context.dependOnInheritedWidgetOfExactType<RunReportScope>()?.sink(
      score,
      extras,
    );
  }

  @override
  bool updateShouldNotify(RunReportScope old) => false;
}

/// Times the screen below it: seconds count only while the app is in the foreground.
/// [timer] starts with the widget and pauses on `paused`/`inactive`/`hidden`/`detached`.
class ActiveTimeScope extends StatefulWidget {
  const ActiveTimeScope({super.key, required this.timer, required this.child});
  final ActiveTimer timer;
  final Widget child;

  @override
  State<ActiveTimeScope> createState() => _ActiveTimeScopeState();
}

class _ActiveTimeScopeState extends State<ActiveTimeScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      widget.timer.start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.timer.resume();
    } else {
      widget.timer.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.timer.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// One play of a standalone game from the hub (M2): times the screen, takes the run reports,
/// adds the seconds and records them, and after the screen closes shows the calm "New personal
/// best" line. The hub's `_playStandalone` uses it like this:
///
/// ```dart
/// final run = StandaloneRun(profile: s.profile, gameId: id, title: title);
/// // in onScore(score): await run.onScore(score);   (before the tile best is updated)
/// // push run.wrap(buildStandalone(onScore)), then: run.announce(messenger);
/// ```
class StandaloneRun {
  StandaloneRun({
    required this.profile,
    required this.gameId,
    required this.title,
    this.reportsRuns = false,
  }) : timer = ActiveTimer(() => profile.trustedNow);

  final ProfileStore profile;
  final String gameId;
  final String title;
  final ActiveTimer timer;

  /// The game reports its own runs through [RunReportScope] (the hub-native games): its plain
  /// `onScore` call is then not a run (Merge calls it on every move).
  final bool reportsRuns;

  /// Wraps the game screen: foreground timing and the report hook.
  Widget wrap(Widget screen) => ActiveTimeScope(
    timer: timer,
    child: RunReportScope(sink: _finished, child: screen),
  );

  /// Test seam: runs [body] with the report sink and waits for the recording.
  @visibleForTesting
  Future<void> wrapForTest(
    void Function(void Function(int, RunExtras) sink) body,
  ) async {
    body(_finished);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _finished(int score, RunExtras x) {
    return _record(score, x);
  }

  /// The game's plain score call. A game that reports through [RunReportScope] ([reportsRuns])
  /// is recorded there; the others (the copied games) are recorded here, once per call.
  Future<void> onScore(int score) =>
      reportsRuns ? Future.value() : _record(score, null);

  /// Each run on a screen is timed on its own.
  Future<void> _record(int score, RunExtras? x) {
    final seconds = timer.lap();
    return profile.recordRun(
      RunReport(
        gameId: gameId,
        score: score,
        won: x?.won,
        seconds: x?.seconds ?? seconds,
        mistakes: x?.mistakes,
        hints: x?.hints,
        variant: x?.variant,
      ),
      gameTitle: title,
    );
  }

  /// The screen is closed: show the "New personal best" line once, if a run set a record.
  void announce(ScaffoldMessengerState messenger) {
    final best = profile.takeNewBestMessage();
    if (best == null) return;
    messenger.showSnackBar(
      SnackBar(key: TestIds.newBestMessage, content: Text(best)),
    );
  }
}
