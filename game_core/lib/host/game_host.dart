/// What a game asks its container (an app or the web app) for. A game never imports app code:
/// it reads this contract from [GameHostScope], and the container provides the real thing
/// (speech, ads, settings). Without a host a game still works: no read-aloud, no banners.
library;

import 'package:flutter/widgets.dart';

/// Where a container may show an ad banner for a game: menu-like screens only, never in play.
enum GameBannerSlot { menu, preGame, postGame }

/// Reads text aloud: a recorded clip first when there is one, speech as the fallback.
abstract class GameReadAloud {
  Future<void> read(String text, {String? audioRef});
  Future<void> stop();
}

/// The colours a game uses for plain game UI. A container maps its own theme onto this (the games
/// never import a theme). Null from the host: the game falls back to the Material colour scheme.
class GamePalette {
  const GamePalette({
    required this.bg,
    required this.surface,
    required this.text,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.border,
    required this.success,
    this.reduceMotion = false,
  });
  final Color bg;
  final Color surface;
  final Color text;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color onAccent;
  final Color border;
  final Color success;
  final bool reduceMotion;
}

/// The ad formats a frame can ask a container for, by where they fit.
enum GameAdFormat {
  /// 300 x 600, in the right rail of a wide window.
  halfPage(Size(300, 600)),

  /// 160 x 600, in the right rail when the window is only just wide enough.
  skyscraper(Size(160, 600)),

  /// 728 x 90, a strip above the game on a medium window.
  leaderboard(Size(728, 90));

  const GameAdFormat(this.size);
  final Size size;
}

/// An ad ready to show, and the size it takes (so the frame can keep the game centered around it).
class GameAdUnit {
  const GameAdUnit({required this.widget, required this.size});
  final Widget widget;
  final Size size;
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

  /// An ad of [format] for the frame around the game, or null when the container has none (apps
  /// without web ads, Remove Ads, child profiles). The frame shows it only outside play.
  GameAdUnit? adUnit(BuildContext context, GameAdFormat format) => null;

  /// The container's colours, or null to use the Material colour scheme.
  GamePalette? palette(BuildContext context) => null;

  /// True for the younger interface level (pictures first, no timers, bigger targets).
  bool youngerLevel(BuildContext context) => false;

  // ---- hooks of the Mind hubs (calm and arcade games); safe no-ops elsewhere ----

  /// A button that opens the container's leaderboards for [gameId] (a shrunk box when there is none).
  Widget leaderboardEntry(BuildContext context, String gameId) =>
      const SizedBox.shrink();

  /// A note about achievements just earned (a shrunk box when there is none).
  Widget achievementNote(BuildContext context) => const SizedBox.shrink();

  /// Offers a rewarded "Continue": true when the player earned it. With no ads to show (no host, or
  /// Remove Ads) the Continue is free: an ad must never trap the player.
  Future<bool> rewardedContinue(BuildContext context) async => true;

  /// Pays [n] coins into the container's balance.
  Future<void> addCoins(BuildContext context, int n) async {}
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
