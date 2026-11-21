import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'ad_service.dart';
import 'profile_store.dart';

/// The few config values Wingy screens read.
abstract interface class WingyConfig {
  String get displayName;

  /// Play Games leaderboard id for the high score; empty when there is none.
  String get leaderboardHighScore;
}

abstract interface class WingyLeaderboard {
  Future<void> submitScore(String leaderboardId, int score);
  Future<void> unlockAchievement(String achievementId);
}

abstract interface class WingyAnalytics {
  void logEvent(String name, [Map<String, Object?> params = const {}]);
}

abstract interface class WingyShare {
  /// Shares a score; [image] is the share card PNG (may be null).
  Future<void> shareScore({required int score, Uint8List? image});
}

/// What the Wingy screens call "Services": everything the game needs from its container. The
/// standalone app and each hub provide one (an adapter over their own services).
abstract interface class WingyServices {
  WingyConfig get config;
  WingyProfileStore get profile;
  WingyAds get ads;
  WingyLeaderboard get leaderboard;
  WingyAnalytics get analytics;
  WingyShare get share;

  /// True while the game screen is on the navigator.
  bool get inRun;
  set inRun(bool v);

  /// Shows a rewarded ad and returns true when the reward is earned (Remove Ads grants it at once).
  Future<bool> rewarded(WingyAdPlacement placement);
}

/// Makes the container's services available to the Wingy screens.
class WingyServicesScope extends InheritedWidget {
  const WingyServicesScope({
    super.key,
    required this.services,
    required super.child,
  });
  final WingyServices services;

  static WingyServices of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<WingyServicesScope>();
    assert(scope != null, 'No WingyServicesScope above this context');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(WingyServicesScope old) => services != old.services;
}
