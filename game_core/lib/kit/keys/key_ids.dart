import 'package:flutter/widgets.dart';

import 'game_action.dart';

/// Stable test IDs of the keyboard kit (hard rule 4).
abstract final class KeyIds {
  static const controlsScreen = Key('controls.screen');
  static const reset = Key('controls.reset');
  static const done = Key('controls.done');
  static const listening = Key('controls.listening');
  static const message = Key('controls.message');
  static Key row(KeySlot s) => Key('controls.row.${s.id}');
  static Key chip(KeySlot s) => Key('controls.chip.${s.id}');
  static const hints = Key('keys.hints');
  static Key hint(GameAction a) => Key('keys.hint.${a.name}');
}
