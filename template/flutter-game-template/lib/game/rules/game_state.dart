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
    this.gems = 0,
    this.blastCells = const [],
    this.startedRush = false,
    this.rushDoubled = false,
    this.rushLeft = 0,
  });

  /// Gems paid by this placement (each is also +1 coin; the UI grants the coins).
  final int gems;

  /// Cells emptied by blast blocks beyond the cleared lines, as (row, col).
  final List<(int, int)> blastCells;

  /// A golden block cleared: Gold Rush started or was extended.
  final bool startedRush;

  /// The points of this placement were doubled by a running Gold Rush.
  final bool rushDoubled;

  /// Rush placements left after this placement.
  final int rushLeft;
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
    final dealt = tray ?? _generator.dealTray(this.board, allowSpecial: false);
    _tray = List<Piece?>.of(dealt);
    _checkGameOver();
  }

  static const int traySlots = 3;
  static const int maxRevives = 3;
  static const int maxCombo = 5;

  /// Gold Rush: points are doubled for this many more placements.
  static const int rushPlacements = 5;
  static const int rushExtend = 5;
  static const int rushCap = 15;
  static const int rushMultiplier = 2;

  /// Special cell points: a gem pays [gemPoints] (inside the line base, so the combo
  /// multiplier applies) and one coin; every extra cell a blast block empties pays
  /// [blastCellPoints].
  static const int gemPoints = 50;
  static const int blastCellPoints = 5;

  final PieceGenerator _generator;

  /// Placements left in the running Gold Rush (0 = off).
  int rushLeft = 0;

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

  /// Ad-based revives left in this run (resets with every new [GameState]).
  int get revivesRemaining => maxRevives - revivesUsed;

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
    final gems = result.gems + result.blastGems;
    if (lines > 0) {
      multiplier = min(comboStreak + 1, maxCombo);
      gained += (10 * lines * lines + gemPoints * gems) * multiplier;
      gained += blastCellPoints * result.blastCells.length;
      comboStreak++;
      linesClearedTotal += lines;
      maxComboReached = max(maxComboReached, multiplier);
    } else {
      comboStreak = 0;
    }
    // Gold Rush doubles everything after the combo multiplier. It covers the next
    // placements, so the placement that clears the golden block is not doubled.
    final doubled = rushLeft > 0;
    if (doubled) {
      gained *= rushMultiplier;
      rushLeft--;
    }
    if (result.golds > 0) {
      rushLeft = rushLeft == 0
          ? rushPlacements
          : min(rushLeft + rushExtend * result.golds, rushCap);
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
      gems: gems,
      blastCells: result.blastCells,
      startedRush: result.golds > 0,
      rushDoubled: doubled,
      rushLeft: rushLeft,
    );
  }

  /// Game over when none of the remaining pieces fits anywhere.
  void _checkGameOver() {
    isGameOver = !_tray.whereType<Piece>().any(board.canPlaceAnywhere);
  }

  /// Revive after a game over, up to [maxRevives] per run (granted by a rewarded ad): empties the two fullest
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
