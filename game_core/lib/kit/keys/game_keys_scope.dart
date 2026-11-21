import 'package:flutter/widgets.dart';

import 'game_key_map.dart';

/// Provides the player's [GameKeyMap] above the games. A container loads it once at start-up
/// (`loadGameKeyMap`) and wraps the app; without a scope a game uses the starting keys.
class GameKeysScope extends InheritedNotifier<GameKeyMap> {
  const GameKeysScope({
    super.key,
    required GameKeyMap keys,
    required super.child,
  }) : super(notifier: keys);

  static final GameKeyMap _starting = GameKeyMap();

  /// The map in force here (listens, so a change redraws the key hints).
  static GameKeyMap of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameKeysScope>()?.notifier ??
      _starting;

  /// The map without listening (event handlers).
  static GameKeyMap read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GameKeysScope>()?.notifier ??
      _starting;
}
