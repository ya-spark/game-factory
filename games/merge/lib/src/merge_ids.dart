import 'package:flutter/widgets.dart';

/// Merge's own test IDs (the shared ones are `MindIds` and `GameIds` in game_core).
abstract final class MergeIds {
  static Key mergeCell(int i) => Key('merge.cell.$i');
}
