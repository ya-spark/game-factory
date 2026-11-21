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
    this.quads = 0,
    this.prismRows = 0,
    this.holdsUsed = 0,
    this.perfectClears = 0,
    this.level = 1,
  });
  final int score;
  final int linesCleared;
  final int piecesPlaced;
  final int maxCombo;

  /// Quads (4 rows at once) cleared this game.
  final int quads;

  /// Rows holding a prism that were cleared this game.
  final int prismRows;
  final int holdsUsed;
  final int perfectClears;

  /// Level reached when the game ended.
  final int level;
}

/// The player's data as Blockfall sees it. The container stores it (the standalone app in its own save,
/// a hub in the hub's) and owns coins, Remove Ads and the day streak.
abstract interface class BlockfallProfileStore implements Listenable {
  SaveData get data;
  Future<void> saveGame(Map<String, Object?>? game);
  Future<List<AchievementDef>> recordGameFinished(GameSummary g);
  int get displayStreak;
  Future<void> addCoins(int n);
  Future<bool> spendCoins(int n);
  Future<void> setThemeIndex(int v);
  Future<void> setPowerUps(Map<String, int> stock);
  Future<void> setControls(ControlScheme v);
  ControlScheme get controlScheme;
  Future<void> setTipsEnabled(bool v);
  bool get tipsEnabled;
}
