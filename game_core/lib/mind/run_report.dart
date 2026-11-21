import 'package:flutter/widgets.dart';

import '../engine/stats/game_stats.dart';

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
