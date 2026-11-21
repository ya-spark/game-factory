import 'package:flutter/foundation.dart';

import 'package:game_blockfall/blockfall.dart';

/// Counts rewarded ads and lets a test force their result (like the standalone's fake).
class FakeBlockfallAds implements BlockfallAds {
  FakeBlockfallAds({this.rewardResult = true});
  bool rewardResult;
  int rewardedShown = 0;
  int interstitialsShown = 0;

  @override
  Future<bool> showRewarded(BlockfallAdPlacement placement) async {
    rewardedShown++;
    return rewardResult;
  }

  @override
  Future<void> maybeShowInterstitialAfterGameOver() async {
    interstitialsShown++;
  }
}

/// The tests' name for "an ad service" (the standalone's tests used its `AdService`).
typedef AdService = FakeBlockfallAds;

/// An in-memory profile: enough for the game screens (the container owns the real one).
class FakeBlockfallProfile extends ChangeNotifier
    implements BlockfallProfileStore {
  SaveData _data = const SaveData();

  @override
  SaveData get data => _data;
  @override
  int get displayStreak => 0;

  void _commit(SaveData d) {
    _data = d;
    notifyListeners();
  }

  @override
  Future<void> saveGame(Map<String, Object?>? game) async => _commit(
    game == null ? _data.copyWith(clearGame: true) : _data.copyWith(game: game),
  );

  @override
  Future<List<AchievementDef>> recordGameFinished(GameSummary g) async {
    if (g.score > _data.bestScore) _commit(_data.copyWith(bestScore: g.score));
    return const [];
  }

  @override
  Future<void> addCoins(int n) async =>
      _commit(_data.copyWith(coins: _data.coins + n));
  @override
  Future<bool> spendCoins(int n) async {
    if (_data.coins < n) return false;
    _commit(_data.copyWith(coins: _data.coins - n));
    return true;
  }

  @override
  Future<void> setThemeIndex(int v) async =>
      _commit(_data.copyWith(themeIndex: v));
  @override
  Future<void> setPowerUps(Map<String, int> stock) async =>
      _commit(_data.copyWith(powerUps: stock));
  @override
  Future<void> setControls(ControlScheme v) async =>
      _commit(_data.copyWith(controls: v));
  @override
  ControlScheme get controlScheme => _data.controls ?? ControlScheme.touch;
  @override
  bool get tipsEnabled => !_data.tipsOff;
  @override
  Future<void> setTipsEnabled(bool v) async =>
      _commit(_data.copyWith(tipsOff: !v));
}

class _Config implements BlockfallConfig {
  @override
  String get displayName => 'Blockfall';
  @override
  String get leaderboardHighScore => '';
  @override
  bool get streaksEnabled => true;
}

class _Leaderboard implements BlockfallLeaderboard {
  @override
  Future<void> submitScore(String leaderboardId, int score) async {}
  @override
  Future<void> unlockAchievement(String achievementId) async {}
}

class _Analytics implements BlockfallAnalytics {
  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) {}
}

class _Share implements BlockfallShare {
  @override
  Future<void> shareScore({required int score, Uint8List? image}) async {}
}

class FakeBlockfallServices implements BlockfallServices {
  FakeBlockfallServices({FakeBlockfallAds? ads})
    : ads = ads ?? FakeBlockfallAds();
  @override
  final FakeBlockfallProfile profile = FakeBlockfallProfile();
  @override
  final FakeBlockfallAds ads;
  @override
  BlockfallConfig get config => _Config();
  @override
  BlockfallLeaderboard get leaderboard => _Leaderboard();
  @override
  BlockfallAnalytics get analytics => _Analytics();
  @override
  BlockfallShare get share => _Share();
  @override
  bool inRun = false;

  @override
  Future<bool> rewarded(BlockfallAdPlacement placement) async {
    if (profile.data.adsRemoved) return true;
    return ads.showRewarded(placement);
  }
}

/// The package tests' stand-in for the standalone's `buildFakeServices`.
Future<FakeBlockfallServices> buildFakeServices({
  FakeBlockfallAds? ads,
}) async => FakeBlockfallServices(ads: ads);
