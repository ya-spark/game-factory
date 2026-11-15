import 'package:flutter/material.dart';

import '../core/profile/profile_store.dart';
import '../engine/engine.dart';
import 'test_ids.dart';

/// The hook a game screen uses to say more about the run that just finished (M2): whether it was
/// won, mistakes, hints, the variant. The hub wraps each standalone game in this scope and joins
/// the extras with the score and the seconds it measured. Outside a scope (tests, a daily run)
/// reporting does nothing. Call it right before the existing score call.
class RunReportScope extends InheritedWidget {
  const RunReportScope({super.key, required this.sink, required super.child});

  final void Function(RunExtras extras) sink;

  static void report(BuildContext context, RunExtras extras) {
    context.dependOnInheritedWidgetOfExactType<RunReportScope>()?.sink(extras);
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

/// One play of a standalone game from the hub (M2): times the screen, collects the extras the
/// game reports, builds the [RunReport] when the score arrives and, after the screen closes,
/// shows the calm "New personal best" line. The hub's `_playStandalone` uses it like this:
///
/// ```dart
/// final run = StandaloneRun(profile: s.profile, gameId: id, title: title);
/// // in onScore(score): await run.finish(score);  (before the tile best is updated)
/// // push run.wrap(buildStandalone(onScore)), then: run.announce(messenger);
/// ```
class StandaloneRun {
  StandaloneRun({
    required this.profile,
    required this.gameId,
    required this.title,
  }) : timer = ActiveTimer(() => profile.trustedNow);

  final ProfileStore profile;
  final String gameId;
  final String title;
  final ActiveTimer timer;
  RunExtras? _extras;

  /// Wraps the game screen: foreground timing and the extras hook.
  Widget wrap(Widget screen) => ActiveTimeScope(
    timer: timer,
    child: RunReportScope(sink: (x) => _extras = x, child: screen),
  );

  /// A run ended with [score]: report it with the extras and the seconds since the last run
  /// (each run on a screen is timed on its own).
  Future<void> finish(int score) {
    final x = _extras;
    _extras = null;
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

  /// The screen is closed: show the "New personal best" line once, if the run set a record.
  void announce(ScaffoldMessengerState messenger) {
    final best = profile.takeNewBestMessage();
    if (best == null) return;
    messenger.showSnackBar(
      SnackBar(key: TestIds.newBestMessage, content: Text(best)),
    );
  }
}
