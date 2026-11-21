import 'powerups.dart';

/// Things that happened inside the game; the UI/retention layer consumes them via
/// [BlockfallGame.drainEvents] to drive sounds, haptics, flashes, stats and challenges.
sealed class GameEvent {
  const GameEvent();
}

class PieceSpawned extends GameEvent {
  const PieceSpawned();
}

class PieceMoved extends GameEvent {
  const PieceMoved();
}

class PieceRotated extends GameEvent {
  const PieceRotated();
}

class HoldUsed extends GameEvent {
  const HoldUsed();
}

class HardDropped extends GameEvent {
  const HardDropped(this.rows);
  final int rows;
}

class PieceLocked extends GameEvent {
  const PieceLocked({required this.hidden});

  /// True when the piece locked fully inside the hidden rows (lock out).
  final bool hidden;
}

class LinesCleared extends GameEvent {
  const LinesCleared({
    required this.rows,
    required this.prismRows,
    required this.prismCoins,
    required this.scoreGained,
    required this.combo,
    required this.backToBack,
    required this.perfectClear,
    this.blastCells = const [],
    this.goldBlocks = 0,
    this.rushDoubled = false,
  });

  /// Cells removed by Boom blocks beyond the cleared rows, as (row, col) in the well after
  /// the rows collapsed (where a burst is drawn).
  final List<(int, int)> blastCells;

  /// Golden blocks that cleared with these rows (they start or extend Gold Rush).
  final int goldBlocks;

  /// This clear's score was doubled by a running Gold Rush.
  final bool rushDoubled;

  /// Well row indices (0 = top hidden row) that were removed, ascending.
  final List<int> rows;
  final int prismRows;

  /// Coins actually paid (after the per-game cap).
  final int prismCoins;
  final int scoreGained;
  final int combo;
  final bool backToBack;
  final bool perfectClear;

  int get count => rows.length;
}

class PrismCoinsEarned extends GameEvent {
  const PrismCoinsEarned(this.coins);
  final int coins;
}

class LevelUp extends GameEvent {
  const LevelUp(this.level);
  final int level;
}

class PowerUpUsed extends GameEvent {
  const PowerUpUsed(this.type);
  final PowerUpType type;
}

class BombExploded extends GameEvent {
  const BombExploded({required this.centerRow, required this.centerCol});
  final int centerRow;
  final int centerCol;
}

enum GameOverReason { blockOut, lockOut }

class GameOver extends GameEvent {
  const GameOver(this.reason);
  final GameOverReason reason;
}

class Revived extends GameEvent {
  const Revived();
}
