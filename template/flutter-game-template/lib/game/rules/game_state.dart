import 'dart:math';

import 'board.dart';
import 'piece.dart';
import 'piece_generator.dart';

class PlaceOutcome {
  const PlaceOutcome({
    required this.cellsPlaced,
    required this.linesCleared,
    required this.scoreGained,
    required this.combo,
    required this.gameOver,
    this.clearedRows = const [],
    this.clearedCols = const [],
  });
  final List<int> clearedRows;
  final List<int> clearedCols;
  final int cellsPlaced;
  final int linesCleared;
  final int scoreGained;

  /// Combo multiplier in effect for this placement (1 = no combo).
  final int combo;
  final bool gameOver;
}

/// Full state of one block-puzzle game. Pure Dart: no Flutter, Flame or Android imports,
/// so it is unit-testable on the VM and reusable on any platform.
class GameState {
  GameState({
    Board? board,
    PieceGenerator? generator,
    this.bestScore = 0,
    List<Piece>? tray,
  }) : _generator = generator ?? PieceGenerator(),
       board = board ?? Board.empty() {
    final dealt = tray ?? _generator.dealTray(this.board);
    _tray = List<Piece?>.of(dealt);
    _checkGameOver();
  }

  static const int traySlots = 3;
  static const int maxRevives = 1;
  static const int maxCombo = 5;

  final PieceGenerator _generator;

  Board board;
  late List<Piece?> _tray;
  int score = 0;
  int bestScore;
  int comboStreak = 0;
  int linesClearedTotal = 0;
  int piecesPlaced = 0;
  int maxComboReached = 1;
  int revivesUsed = 0;
  bool isGameOver = false;

  /// Pieces offered; a slot is null once used.
  List<Piece?> get tray => List.unmodifiable(_tray);

  bool get canRevive => isGameOver && revivesUsed < maxRevives;

  bool canPlace(int slot, int row, int col) {
    if (isGameOver) return false;
    final p = _tray[slot];
    return p != null && board.canPlace(p, row, col);
  }

  /// Places the piece in [slot] with its top-left at [row],[col]. Returns null if illegal.
  PlaceOutcome? place(int slot, int row, int col) {
    if (!canPlace(slot, row, col)) return null;
    final piece = _tray[slot]!;
    final result = board.place(piece, row, col);
    board = result.board;
    _tray[slot] = null;
    piecesPlaced++;

    final lines = result.linesCleared;
    var gained = piece.size;
    var multiplier = 1;
    if (lines > 0) {
      multiplier = min(comboStreak + 1, maxCombo);
      gained += 10 * lines * lines * multiplier;
      comboStreak++;
      linesClearedTotal += lines;
      maxComboReached = max(maxComboReached, multiplier);
    } else {
      comboStreak = 0;
    }
    score += gained;
    if (score > bestScore) bestScore = score;

    if (_tray.every((p) => p == null)) {
      _tray = List<Piece?>.of(_generator.dealTray(board));
    }
    _checkGameOver();
    return PlaceOutcome(
      cellsPlaced: piece.size,
      linesCleared: lines,
      scoreGained: gained,
      combo: multiplier,
      gameOver: isGameOver,
      clearedRows: result.clearedRows,
      clearedCols: result.clearedCols,
    );
  }

  /// Game over when none of the remaining pieces fits anywhere.
  void _checkGameOver() {
    isGameOver = !_tray.whereType<Piece>().any(board.canPlaceAnywhere);
  }

  /// One-time revive after a game over (granted by a rewarded ad): empties the two fullest
  /// rows and deals a fresh tray. Returns false if not allowed.
  bool revive() {
    if (!canRevive) return false;
    revivesUsed++;
    board = board.clearFullestRows(2);
    _tray = List<Piece?>.of(_generator.dealTray(board));
    comboStreak = 0;
    _checkGameOver();
    return true;
  }
}
