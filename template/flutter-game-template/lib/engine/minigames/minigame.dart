/// The minigame interface, the per-app registry and the access rule. Pure Dart.
library;

import '../content/models.dart';
import '../content/progress.dart';
import 'quiz_session.dart';

/// How a child plays: Game (scored, playful) or Study (calm, explanation first).
enum MiniGameMode { game, study }

/// `free_with_ads` games are always playable (ads follow the app's ad rules).
/// `coins` games are locked until unlocked with coins, which is permanent on this device.
enum GameAccess {
  freeWithAds,
  coins;

  static GameAccess parse(Object? v) =>
      v == 'coins' ? GameAccess.coins : GameAccess.freeWithAds;
}

/// What a minigame gets when it is built.
class MiniGameContext {
  const MiniGameContext({
    required this.session,
    required this.mode,
    required this.onExit,
    this.onAnswered,
    this.onScore,
  });

  /// Called after every answer: save `session.progress` and add `result.coins` to the wallet.
  final void Function(AnswerResult result, QuizSession session)? onAnswered;

  /// Called once when a round ends with the game's own score; the app keeps the best one
  /// (`ChildProgress.recordScore`). Games without a score of their own do not call it.
  final void Function(int score)? onScore;
  final QuizSession session;
  final MiniGameMode mode;

  /// Called when the child leaves the game or finishes the round.
  final void Function() onExit;
}

/// Builds the game's screen. The engine is pure Dart, so the result is an `Object`; the app
/// passes a `Widget`.
typedef MiniGameBuilder = Object Function(MiniGameContext context);

/// One pluggable minigame.
class MiniGame {
  const MiniGame({
    required this.id,
    required this.title,
    required this.itemTypes,
    required this.build,
    this.minPool = 4,
    this.modes = const {MiniGameMode.game, MiniGameMode.study},
    this.access = GameAccess.freeWithAds,
    this.coinPrice = 0,
  });

  final String id;
  final String title;

  /// Item types the game can play. Only these count towards [minPool].
  final Set<ItemType> itemTypes;

  /// Open items of the child's subject and year needed before the game appears.
  final int minPool;
  final Set<MiniGameMode> modes;
  final GameAccess access;

  /// Price in coins; only used when [access] is `coins`.
  final int coinPrice;
  final MiniGameBuilder build;

  MiniGame withAccess(GameAccess access, int coinPrice) => MiniGame(
    id: id,
    title: title,
    itemTypes: itemTypes,
    build: build,
    minPool: minPool,
    modes: modes,
    access: access,
    coinPrice: coinPrice,
  );
}

/// One app's choice of a minigame: which modes and which year levels.
class RegistryEntry {
  const RegistryEntry(
    this.game, {
    this.modes,
    this.minYear = 0,
    this.maxYear = 12,
  });
  final MiniGame game;

  /// Null: the game's own modes.
  final Set<MiniGameMode>? modes;
  final int minYear;
  final int maxYear;
}

/// A game as the menu shows it.
class MiniGameOffer {
  const MiniGameOffer(this.game, {required this.locked});
  final MiniGame game;
  final bool locked;

  /// The price to show on a locked game, else 0.
  int get price => locked ? game.coinPrice : 0;
}

class UnlockResult {
  const UnlockResult({
    required this.ok,
    required this.unlocked,
    required this.coins,
  });
  final bool ok;
  final Set<String> unlocked;
  final int coins;
}

/// The per-app list of minigames.
class MiniGameRegistry {
  const MiniGameRegistry(this.entries);
  final List<RegistryEntry> entries;

  MiniGame? byId(String id) {
    for (final e in entries) {
      if (e.game.id == id) return e.game;
    }
    return null;
  }

  /// The games to show for a child: right mode and year, enough open items, locked ones marked.
  List<MiniGameOffer> offers({
    required List<PoolItem> open,
    required String subject,
    required int year,
    required MiniGameMode mode,
    required Set<String> unlocked,
  }) {
    final out = <MiniGameOffer>[];
    for (final e in entries) {
      final g = e.game;
      if (!(e.modes ?? g.modes).contains(mode)) continue;
      if (year < e.minYear || year > e.maxYear) continue;
      final pool = open
          .where(
            (p) =>
                p.subject == subject &&
                p.year == year &&
                g.itemTypes.contains(p.item.type),
          )
          .length;
      if (pool < g.minPool) continue;
      out.add(MiniGameOffer(g, locked: !isPlayable(g, unlocked)));
    }
    return out;
  }

  static bool isPlayable(MiniGame g, Set<String> unlocked) =>
      g.access == GameAccess.freeWithAds || unlocked.contains(g.id);

  /// Spends coins to unlock [g] for good. Nothing changes when the coins are not enough.
  /// A free or already unlocked game costs nothing.
  static UnlockResult tryUnlock(MiniGame g, Set<String> unlocked, int coins) {
    if (isPlayable(g, unlocked)) {
      return UnlockResult(ok: true, unlocked: unlocked, coins: coins);
    }
    if (coins < g.coinPrice) {
      return UnlockResult(ok: false, unlocked: unlocked, coins: coins);
    }
    return UnlockResult(
      ok: true,
      unlocked: {...unlocked, g.id},
      coins: coins - g.coinPrice,
    );
  }
}
