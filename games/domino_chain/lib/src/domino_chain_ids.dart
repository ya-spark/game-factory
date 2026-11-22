import 'package:flutter/widgets.dart';

/// Domino chain's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class DominoChainIds {
  static Key tile(String g, int i) => Key('$g.tile.$i');
  static Key slot(String g, int i) => Key('$g.slot.$i');
  static Key tray(String g) => Key('$g.tray');
  static Key row(String g) => Key('$g.row');
  static Key sign(String g) => Key('$g.sign');
  static Key scene(String g) => Key('$g.scene');
  static Key go(String g) => Key('$g.go');
  static Key hint(String g) => Key('$g.hint');
  static Key flag(String g) => Key('$g.flag');
  static Key broken(String g) => Key('$g.broken');
  static Key message(String g) => Key('$g.message');
  static Key caption(String g) => Key('$g.caption');
  static Key tableScroll(String g) => Key('$g.table_scroll');
  static Key stageStars(String g) => Key('$g.stage_stars');
}
