import 'package:flutter/widgets.dart';

/// SortBins's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class SortBinsIds {
  static Key sortBin(int i) => Key('sort.bin.$i');
  static const sortExit = Key('sort.exit');
  static const sortFeedback = Key('sort.feedback');
  static const sortItem = Key('sort.item');
  static const sortNext = Key('sort.next');
  static const sortProgress = Key('sort.progress');
  static const sortPrompt = Key('sort.prompt');
  static const sortScreen = Key('sort.screen');
  static const sortSpeak = Key('sort.speak');
  static const sortStars = Key('sort.stars');
  static const sortSummary = Key('sort.summary');
  static const sortTimer = Key('sort.timer');
}
