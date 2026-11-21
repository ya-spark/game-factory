/// What a Blockfall screen asks an ad for. The container decides what actually shows.
enum BlockfallAdPlacement { gameOver, revive, powerUp }

/// The ad side of a container, as Blockfall sees it.
abstract interface class BlockfallAds {
  /// Shows a rewarded ad for [placement]; true when the reward is earned. A container may answer
  /// false for placements it does not offer.
  Future<bool> showRewarded(BlockfallAdPlacement placement);

  /// Called after a game over, before the next run; the container applies its own ad pacing.
  Future<void> maybeShowInterstitialAfterGameOver();
}
