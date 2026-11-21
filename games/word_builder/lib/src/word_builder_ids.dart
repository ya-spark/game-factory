import 'package:flutter/widgets.dart';

/// WordBuilder's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class WordBuilderIds {
  static const wordBuilderBuilt = Key('wordb.built');
  static const wordBuilderCheck = Key('wordb.check');
  static const wordBuilderClear = Key('wordb.clear');
  static const wordBuilderExit = Key('wordb.exit');
  static const wordBuilderFeedback = Key('wordb.feedback');
  static const wordBuilderHint = Key('wordb.hint');
  static const wordBuilderNext = Key('wordb.next');
  static const wordBuilderProgress = Key('wordb.progress');
  static const wordBuilderScreen = Key('wordb.screen');
  static const wordBuilderSpeak = Key('wordb.speak');
  static const wordBuilderStars = Key('wordb.stars');
  static const wordBuilderSummary = Key('wordb.summary');
  static Key wordBuilderTile(int i) => Key('wordb.tile.$i');
  static const wordBuilderTimer = Key('wordb.timer');
  static const wordBuilderUndo = Key('wordb.undo');
}
