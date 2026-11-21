import 'package:flutter/widgets.dart';

/// BallSort's own test IDs (the shared ones are `MindIds` and `GameIds` in game_core).
abstract final class BallSortIds {
  static Key ballSortTube(int i) => Key('ballsort.tube.$i');
}
