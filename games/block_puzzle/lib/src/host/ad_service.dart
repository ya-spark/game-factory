import 'package:flutter/widgets.dart';

/// What a BlockPuzzle screen asks an ad for. The container decides what actually shows.
enum BlockPuzzleAdPlacement { gameOver, revive, boostRefill }

/// The ad side of a container, as BlockPuzzle sees it.
abstract interface class BlockPuzzleAds {
  /// Shows a rewarded ad for [placement]; true when the reward is earned. A container may answer
  /// false for placements it does not offer.
  Future<bool> showRewarded(BlockPuzzleAdPlacement placement);

  /// Called after a game over, before the next run; the container applies its own ad pacing.
  Future<void> maybeShowInterstitialAfterGameOver();

  /// A banner for menu-like screens (an empty box when there is none).
  Widget buildBanner();
}
