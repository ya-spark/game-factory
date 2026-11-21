import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../block_puzzle.dart';

/// Counts rewarded ads and lets a test force their result (like the standalone's fake).
class FakeBlockPuzzleAds implements BlockPuzzleAds {
  FakeBlockPuzzleAds({this.rewardResult = true});
  bool rewardResult;
  int rewardedShown = 0;
  int interstitialsShown = 0;

  @override
  Future<bool> showRewarded(BlockPuzzleAdPlacement placement) async {
    rewardedShown++;
    return rewardResult;
  }

  @override
  Future<void> maybeShowInterstitialAfterGameOver() async {
    interstitialsShown++;
  }

  @override
  Widget buildBanner() => const SizedBox.shrink();
}

/// An in-memory profile: enough for the game screens (the container owns the real one).
class FakeBlockPuzzleProfile extends ChangeNotifier
    implements BlockPuzzleProfileStore {
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
  Future<void> removeCoins(int n) async =>
      _commit(_data.copyWith(coins: (_data.coins - n).clamp(0, 1 << 30)));
  @override
  Future<bool> spendCoins(int n) async {
    if (_data.coins < n) return false;
    _commit(_data.copyWith(coins: _data.coins - n));
    return true;
  }

  @override
  int itemCount(String key) => _data.itemCount(key);
  @override
  Future<void> addItem(String key, [int n = 1]) async => _commit(
    _data.copyWith(items: {..._data.items, key: _data.itemCount(key) + n}),
  );
  @override
  Future<bool> useItem(String key) async {
    final n = _data.itemCount(key);
    if (n <= 0) return false;
    _commit(_data.copyWith(items: {..._data.items, key: n - 1}));
    return true;
  }

  @override
  Future<bool> buyItem(String key) async {
    final def = Boosts.byKey(key);
    if (def == null || _data.coins < def.price) return false;
    _commit(
      _data.copyWith(
        coins: _data.coins - def.price,
        items: {..._data.items, key: _data.itemCount(key) + 1},
      ),
    );
    return true;
  }

  @override
  Future<void> setThemeIndex(int v) async =>
      _commit(_data.copyWith(themeIndex: v));
  @override
  bool get tipsEnabled => !_data.tipsOff;
  @override
  Future<void> setTipsEnabled(bool v) async =>
      _commit(_data.copyWith(tipsOff: !v));
}

class _Config implements BlockPuzzleConfig {
  @override
  String get displayName => 'Block Puzzle';
  @override
  String get leaderboardHighScore => '';
  @override
  bool get streaksEnabled => true;
}

class _Leaderboard implements BlockPuzzleLeaderboard {
  @override
  Future<void> submitScore(String leaderboardId, int score) async {}
  @override
  Future<void> unlockAchievement(String achievementId) async {}
}

class _Analytics implements BlockPuzzleAnalytics {
  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) {}
}

class _Share implements BlockPuzzleShare {
  @override
  Future<void> shareScore({required int score, Uint8List? image}) async {}
}

class FakeBlockPuzzleServices implements BlockPuzzleServices {
  FakeBlockPuzzleServices({FakeBlockPuzzleAds? ads})
    : ads = ads ?? FakeBlockPuzzleAds();
  @override
  final FakeBlockPuzzleProfile profile = FakeBlockPuzzleProfile();
  @override
  final FakeBlockPuzzleAds ads;
  @override
  BlockPuzzleConfig get config => _Config();
  @override
  BlockPuzzleLeaderboard get leaderboard => _Leaderboard();
  @override
  BlockPuzzleAnalytics get analytics => _Analytics();
  @override
  BlockPuzzleShare get share => _Share();
  @override
  bool inRun = false;
}

/// The package tests' stand-in for the standalone's `buildFakeBlockPuzzleServices`.
Future<FakeBlockPuzzleServices> buildFakeBlockPuzzleServices({
  FakeBlockPuzzleAds? ads,
}) async => FakeBlockPuzzleServices(ads: ads);
