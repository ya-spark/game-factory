/// What a game asks its container (an app or the web app) for. A game never imports app code:
/// it reads this contract from [GameHostScope], and the container provides the real thing
/// (speech, ads, settings). Without a host a game still works: no read-aloud, no banners.
library;

import 'package:flutter/widgets.dart';

/// Where a container may show an ad banner for a game: menu-like screens only, never in play.
enum GameBannerSlot { preGame, postGame }

/// Reads text aloud: a recorded clip first when there is one, speech as the fallback.
abstract class GameReadAloud {
  Future<void> read(String text, {String? audioRef});
  Future<void> stop();
}

/// The container side of a game. Every method gets the [BuildContext] so a container can read its
/// own scopes (services, theme) lazily.
abstract class GameHost {
  const GameHost();

  /// Null when the container has no speech.
  GameReadAloud? readAloud(BuildContext context);

  /// Read the question aloud by itself (young levels).
  bool autoRead(BuildContext context);

  /// The container's reduce-motion setting (the system setting is read by the game).
  bool reduceMotion(BuildContext context);

  /// A banner for [slot]; an empty box when the container shows none.
  Widget banner(BuildContext context, GameBannerSlot slot);
}

/// The host used when a container provides none (tests, previews): nothing optional.
class NoGameHost extends GameHost {
  const NoGameHost();
  @override
  GameReadAloud? readAloud(BuildContext context) => null;
  @override
  bool autoRead(BuildContext context) => false;
  @override
  bool reduceMotion(BuildContext context) => false;
  @override
  Widget banner(BuildContext context, GameBannerSlot slot) =>
      const SizedBox.shrink();
}

/// Provides the container's [GameHost] to every game below it.
class GameHostScope extends InheritedWidget {
  const GameHostScope({super.key, required this.host, required super.child});
  final GameHost host;

  /// The host above [context], or [NoGameHost].
  static GameHost of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameHostScope>()?.host ??
      const NoGameHost();

  @override
  bool updateShouldNotify(GameHostScope old) => old.host != host;
}
