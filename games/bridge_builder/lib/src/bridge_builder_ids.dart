import 'package:flutter/widgets.dart';

/// Bridge builder's own test IDs (the shared ones are `GameIds` in game_core).
abstract final class BridgeBuilderIds {
  static Key mgCheck(String g) => Key('$g.check');
  static Key mgClear(String g) => Key('$g.clear');
  static Key mgSlot(String g, int i) => Key('$g.slot.$i');
  static Key mgTile(String g, int i) => Key('$g.tile.$i');
  static Key mgSign(String g) => Key('$g.sign');
  static Key mgScene(String g) => Key('$g.scene');
  static Key mgPlank(String g) => Key('$g.plank');
  static Key mgFlag(String g) => Key('$g.flag');
  static Key mgStageStars(String g) => Key('$g.stage_stars');
  static Key mgTray(String g) => Key('$g.tray');
  static Key mgIntroHeading(String g) => Key('$g.intro_heading');
  static Key mgIntroTask(String g) => Key('$g.intro_task');
  static Key mgStartKeys(String g) => Key('$g.start_keys');
  static Key mgGhost(String g) => Key('$g.ghost');
}
