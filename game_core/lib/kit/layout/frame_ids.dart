import 'package:flutter/widgets.dart';

/// Stable test IDs of the game frame (hard rule 4).
abstract final class FrameIds {
  static const frame = Key('frame.frame');
  static const stage = Key('frame.stage');
  static const rail = Key('frame.rail');
  static const strip = Key('frame.strip');
  static const banner = Key('frame.banner');
}
