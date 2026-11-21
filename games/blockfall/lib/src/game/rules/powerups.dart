/// Power-up types, limits and coin prices.
enum PowerUpType {
  sweep(60),
  slow(40),
  bomb(50);

  const PowerUpType(this.price);

  /// Coin price to buy one more.
  final int price;
}

abstract final class PowerUpRules {
  static const int maxUsesPerTypePerGame = 3;
  static const int maxAdRefillsPerGame = 3;
  static const int sweepRows = 3;
  static const double slowSeconds = 20;
  static const double slowFactor = 2;
  static const int bombRadius = 1;
  static const int reviveClearRows = 8;
  static const int maxRevivesPerRun = 3;
}

/// Outcome of [BlockfallGame.usePowerUp].
enum PowerUpResult {
  ok,
  noStock,
  limitReached,
  alreadyActive,

  /// Game over, paused, or no free falling piece (e.g. a bomb is already falling).
  notAllowed,
}
