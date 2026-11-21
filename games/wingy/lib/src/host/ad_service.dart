/// What a Wingy screen asks an ad for. The container decides what actually shows.
enum WingyAdPlacement { gameOver, revive, dashRefill }

/// The ad side of a container, as Wingy sees it.
abstract interface class WingyAds {
  /// Shows a rewarded ad for [placement]; true when the reward is earned. A container may answer
  /// false for placements it does not offer.
  Future<bool> showRewarded(WingyAdPlacement placement);

  /// Called after a game over, before the next run; the container applies its own ad pacing.
  Future<void> maybeShowInterstitialAfterGameOver();
}
