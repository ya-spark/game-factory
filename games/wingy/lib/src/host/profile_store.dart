import 'package:flutter/foundation.dart';

import '../core/retention/achievements.dart';
import '../core/save/save_data.dart';

/// Result of one finished run, fed to the container's profile.
class GameSummary {
  const GameSummary({
    required this.score,
    this.pairsPassed = 0,
    this.perfectStreak = 0,
    this.orbs = 0,
    this.dashUses = 0,
    this.dashShattered = 0,
    this.bloomHits = 0,
    this.coins = 0,
  });
  final int score;
  final int pairsPassed;

  /// Longest run of consecutive Perfect passes.
  final int perfectStreak;
  final int orbs;
  final int dashUses;
  final int dashShattered;

  /// Perfect passes that earned a Bloom bonus of +3 or more.
  final int bloomHits;

  /// Coins earned in the run (orbs plus score coins).
  final int coins;
}

/// The player's data as Wingy sees it. The container stores it (the standalone app in its own save,
/// a hub in the hub's) and owns coins, Remove Ads and the day streak.
abstract interface class WingyProfileStore implements Listenable {
  static const int dashRefillCoinCost = 40;
  static const int maxAdRefillsPerDay = 3;

  SaveData get data;
  int get displayStreak;

  Future<void> saveGame(Map<String, Object?>? game);
  Future<List<AchievementDef>> recordGameFinished(GameSummary g);

  Future<void> addCoins(int n);
  Future<bool> spendCoins(int n);

  bool ownsSkin(String id);
  String get equippedSkin;
  Future<bool> equipSkin(String id);

  int get dashRefills;
  int get adRefillsLeft;
  Future<bool> consumeDashRefill();
  Future<bool> buyDashRefillWithCoins();
  Future<bool> grantAdDashRefill();

  Future<void> setReduceMotion(bool v);
  Future<void> setSfx(bool v);
  bool get tipsEnabled;
  Future<void> setTipsEnabled(bool v);
}
