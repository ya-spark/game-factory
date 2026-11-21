import 'package:flutter/widgets.dart';

/// SortBins's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class SortBinsIds {
  static const sortScreen = Key('sort.screen');
  static const sortExit = Key('sort.exit');
  static const sortStars = Key('sort.stars');
  static const sortProgress = Key('sort.progress');
  static const sortSpeak = Key('sort.speak');
  static const sortPrompt = Key('sort.prompt');
  static const sortItem = Key('sort.item');
  static Key sortBin(int i) => Key('sort.bin.$i');
  static const sortFeedback = Key('sort.feedback');
  static const sortNext = Key('sort.next');
  static const sortSummary = Key('sort.summary');
  static const sortTimer = Key('sort.timer');
}
