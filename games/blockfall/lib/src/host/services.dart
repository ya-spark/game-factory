import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'ad_service.dart';
import 'profile_store.dart';

/// The few config values Blockfall screens read.
abstract interface class BlockfallConfig {
  String get displayName;

  /// Play Games leaderboard id for the high score; empty when there is none.
  String get leaderboardHighScore;

  /// Whether streak features are shown.
  bool get streaksEnabled;
}

abstract interface class BlockfallLeaderboard {
  Future<void> submitScore(String leaderboardId, int score);
  Future<void> unlockAchievement(String achievementId);
}

abstract interface class BlockfallAnalytics {
  void logEvent(String name, [Map<String, Object?> params = const {}]);
}

abstract interface class BlockfallShare {
  /// Shares a score; [image] is the share card PNG (may be null).
  Future<void> shareScore({required int score, Uint8List? image});
}

/// What the Blockfall screens call "Services": everything the game needs from its container. The
/// standalone app and each hub provide one (an adapter over their own services).
abstract interface class BlockfallServices {
  BlockfallConfig get config;
  BlockfallProfileStore get profile;
  BlockfallAds get ads;
  BlockfallLeaderboard get leaderboard;
  BlockfallAnalytics get analytics;
  BlockfallShare get share;

  /// True while the game screen is on the navigator.
  bool get inRun;
  set inRun(bool v);
}

/// Makes the container's services available to the Blockfall screens.
class BlockfallServicesScope extends InheritedWidget {
  const BlockfallServicesScope({
    super.key,
    required this.services,
    required super.child,
  });
  final BlockfallServices services;

  static BlockfallServices of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BlockfallServicesScope>();
    assert(scope != null, 'No BlockfallServicesScope above this context');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(BlockfallServicesScope old) =>
      services != old.services;
}
