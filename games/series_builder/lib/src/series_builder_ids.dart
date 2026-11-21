import 'package:flutter/widgets.dart';

/// SeriesBuilder's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class SeriesBuilderIds {
  static const seriesExit = Key('series.exit');
  static const seriesFeedback = Key('series.feedback');
  static const seriesNext = Key('series.next');
  static const seriesProgress = Key('series.progress');
  static const seriesPrompt = Key('series.prompt');
  static const seriesScreen = Key('series.screen');
  static Key seriesSlot(int i) => Key('series.slot.$i');
  static const seriesSpeak = Key('series.speak');
  static const seriesStars = Key('series.stars');
  static const seriesSummary = Key('series.summary');
  static Key seriesTile(int i) => Key('series.tile.$i');
  static const seriesTimer = Key('series.timer');
}
