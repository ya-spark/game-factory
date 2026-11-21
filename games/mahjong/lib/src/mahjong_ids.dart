import 'package:flutter/widgets.dart';

/// Mahjong's own test IDs (the shared ones are `MindIds` and `GameIds` in game_core).
abstract final class MahjongIds {
  static Key mahjongTile(int i) => Key('mahjong.tile.$i');
}
