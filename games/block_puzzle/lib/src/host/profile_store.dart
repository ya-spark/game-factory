import 'package:flutter/foundation.dart';

import '../core/retention/achievements.dart';
import '../core/save/save_data.dart';

/// Result of one finished game, fed into stats / challenges / achievements.
class GameSummary {
  const GameSummary({
    required this.score,
    required this.linesCleared,
    required this.piecesPlaced,
    required this.maxCombo,
  });
  final int score;
  final int linesCleared;
  final int piecesPlaced;
  final int maxCombo;
}

/// The player's data as BlockPuzzle sees it. The container stores it (the standalone app in its own save,
/// a hub in the hub's) and owns coins, Remove Ads and the day streak.
abstract interface class BlockPuzzleProfileStore implements Listenable {
  SaveData get data;
  Future<void> saveGame(Map<String, Object?>? game);
  Future<List<AchievementDef>> recordGameFinished(GameSummary g);
  int get displayStreak;
  Future<void> addCoins(int n);
  Future<void> removeCoins(int n);
  Future<bool> spendCoins(int n);
  Future<bool> buyItem(String key);
  Future<bool> useItem(String key);
  Future<void> addItem(String key, [int n = 1]);
  int itemCount(String key);
  Future<void> setThemeIndex(int v);
  Future<void> setTipsEnabled(bool v);
  bool get tipsEnabled;
}
