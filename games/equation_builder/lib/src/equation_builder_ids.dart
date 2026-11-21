import 'package:flutter/widgets.dart';

/// EquationBuilder's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class EquationBuilderIds {
  static Key mgCheck(String g) => Key('$g.check');
  static Key mgClear(String g) => Key('$g.clear');
  static Key mgSlot(String g, int i) => Key('$g.slot.$i');
  static Key mgTile(String g, int i) => Key('$g.tile.$i');
}
