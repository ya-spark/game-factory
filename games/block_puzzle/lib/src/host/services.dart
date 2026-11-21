import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'ad_service.dart';
import 'profile_store.dart';

/// The few config values BlockPuzzle screens read.
abstract interface class BlockPuzzleConfig {
  String get displayName;

  /// Play Games leaderboard id for the high score; empty when there is none.
  String get leaderboardHighScore;

  /// Whether streak features are shown.
  bool get streaksEnabled;
}

abstract interface class BlockPuzzleLeaderboard {
  Future<void> submitScore(String leaderboardId, int score);
  Future<void> unlockAchievement(String achievementId);
}

abstract interface class BlockPuzzleAnalytics {
  void logEvent(String name, [Map<String, Object?> params = const {}]);
}

abstract interface class BlockPuzzleShare {
  /// Shares a score; [image] is the share card PNG (may be null).
  Future<void> shareScore({required int score, Uint8List? image});
}

/// What the BlockPuzzle screens call "Services": everything the game needs from its container. The
/// standalone app and each hub provide one (an adapter over their own services).
abstract interface class BlockPuzzleServices {
  BlockPuzzleConfig get config;
  BlockPuzzleProfileStore get profile;
  BlockPuzzleAds get ads;
  BlockPuzzleLeaderboard get leaderboard;
  BlockPuzzleAnalytics get analytics;
  BlockPuzzleShare get share;

  /// True while the game screen is on the navigator.
  bool get inRun;
  set inRun(bool v);
}

/// Makes the container's services available to the BlockPuzzle screens.
class BlockPuzzleServicesScope extends InheritedWidget {
  const BlockPuzzleServicesScope({
    super.key,
    required this.services,
    required super.child,
  });
  final BlockPuzzleServices services;

  static BlockPuzzleServices of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BlockPuzzleServicesScope>();
    assert(scope != null, 'No BlockPuzzleServicesScope above this context');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(BlockPuzzleServicesScope old) =>
      services != old.services;
}
