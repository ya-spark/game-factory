import 'dart:math';

import 'board.dart';
import 'boosts.dart';
import 'piece.dart';
import 'piece_generator.dart';
import 'start_board.dart';

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

  /// Cells emptied by Boom blocks beyond the cleared lines, as (row, col).
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

/// Everything Undo restores, taken before each placement.
class _Snapshot {
  _Snapshot(GameState g)
    : board = g.board,
      tray = List<Piece?>.of(g._tray),
      score = g.score,
      bestScore = g.bestScore,
      comboStreak = g.comboStreak,
      linesClearedTotal = g.linesClearedTotal,
      piecesPlaced = g.piecesPlaced,
      maxComboReached = g.maxComboReached,
      rushLeft = g.rushLeft,
      traysDealt = g._generator.traysDealt,
      trayStartBoard = g.trayStartBoard,
      trayStartPieces = g.trayStartPieces;
  final Board board;
  final Board trayStartBoard;
  final List<Piece> trayStartPieces;
  final List<Piece?> tray;
  final int score;
  final int bestScore;
  final int comboStreak;
  final int linesClearedTotal;
  final int piecesPlaced;
  final int maxComboReached;
  final int rushLeft;
  final int traysDealt;

  /// Gem coins the placement after this snapshot paid.
  int gemCoins = 0;
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
    _markTray();
    _checkGameOver();
  }

  /// A fresh game: a prepared, mostly full board (see [StartBoard]) and a first tray whose
  /// pieces each clear lines. Deterministic for a seeded [generator]. Not used by Continue.
  factory GameState.newGame({PieceGenerator? generator, int bestScore = 0}) {
    final gen = generator ?? PieceGenerator();
    final start = StartBoard.generate(gen.random);
    gen.traysDealt =
        1; // the prepared start tray is tray 1 and has no special cells
    return GameState(
      board: start.board,
      generator: gen,
      bestScore: bestScore,
      tray: gen.recolor(start.tray),
    );
  }

  /// Saved game (see [toJson]). Undo history is not kept. The pieces come back from the
  /// catalogue by id, so a game saved by this version always loads on the same version.
  /// Returns null when [j] is unusable, so a bad save starts a fresh game instead of crashing.
  static GameState? fromJson(
    Map<String, Object?> j, {
    required int bestScore,
    PieceGenerator? generator,
  }) {
    try {
      final b = j['board']! as Map;
      final size = (b['size']! as num).toInt();
      final board = Board.restore(
        size,
        [for (final c in b['cells']! as List) (c as num).toInt()],
        [
          for (final k in b['kinds']! as List)
            CellKind.values[(k as num).toInt()],
        ],
      );
      final tray = <Piece?>[
        for (final p in j['tray']! as List)
          p == null ? null : _pieceFromJson(p as Map),
      ];
      if (tray.length != traySlots) return null;
      final gen = generator ?? PieceGenerator();
      gen.traysDealt = (j['traysDealt']! as num).toInt();
      final g = GameState(board: board, generator: gen, bestScore: bestScore);
      g._tray = tray;
      g._markTray();
      g.score = (j['score']! as num).toInt();
      if (g.score > g.bestScore) g.bestScore = g.score;
      g.comboStreak = (j['comboStreak']! as num).toInt();
      g.linesClearedTotal = (j['linesClearedTotal']! as num).toInt();
      g.piecesPlaced = (j['piecesPlaced']! as num).toInt();
      g.maxComboReached = (j['maxComboReached']! as num).toInt();
      g.revivesUsed = (j['revivesUsed']! as num).toInt();
      g.rushLeft = (j['rushLeft']! as num).toInt();
      g.adRefillsUsed = (j['adRefillsUsed']! as num).toInt();
      final uses = j['boostUses']! as Map;
      for (final id in BoostId.values) {
        final n = (uses[id.name] as num?)?.toInt() ?? 0;
        if (n > 0) g._boostUses[id] = n;
      }
      g._checkGameOver();
      return g.isGameOver ? null : g;
    } on Object {
      return null;
    }
  }

  /// The running game as JSON, for the autosave. Not meaningful once the game is over.
  Map<String, Object?> toJson() => {
    'board': {
      'size': board.size,
      'cells': board.cells,
      'kinds': [for (final k in board.kinds) k.index],
    },
    'tray': [
      for (final p in _tray)
        p == null
            ? null
            : {
                'id': p.id,
                'color': p.colorIndex,
                if (p.kinds != null)
                  'kinds': [for (final k in p.kinds!) k.index],
              },
    ],
    'score': score,
    'comboStreak': comboStreak,
    'linesClearedTotal': linesClearedTotal,
    'piecesPlaced': piecesPlaced,
    'maxComboReached': maxComboReached,
    'revivesUsed': revivesUsed,
    'rushLeft': rushLeft,
    'adRefillsUsed': adRefillsUsed,
    'traysDealt': _generator.traysDealt,
    'boostUses': {for (final e in _boostUses.entries) e.key.name: e.value},
  };

  static Piece _pieceFromJson(Map p) {
    final base = PieceCatalog.byId(p['id']! as String);
    final kinds = p['kinds'] as List?;
    return Piece(
      base.id,
      base.cells,
      (p['color']! as num).toInt() % Piece.colorCount,
      kinds == null
          ? null
          : List.unmodifiable([
              for (final k in kinds) CellKind.values[(k as num).toInt()],
            ]),
    );
  }

  static const int traySlots = 3;
  static const int maxRevives = 3;
  static const int maxCombo = 8;

  /// Lines cleared per scoring stage, and the cap of the stage multiplier.
  static const int linesPerStage = 5;
  static const int maxStage = 13;

  /// Exponent applied to the stage multiplier in the line bonus (1.0 = linear).
  static const double stageExponent = 1.25;

  /// Gold Rush: points are doubled for this many more placements.
  static const int rushPlacements = 5;
  static const int rushExtend = 5;
  static const int rushCap = 15;
  static const int rushMultiplier = 2;

  /// Special cell points: a gem pays [gemPoints] (inside the line base, so the combo and
  /// stage multipliers apply) and one coin; every extra cell a Boom block empties pays
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

  _Snapshot? _snapshot;
  final Map<BoostId, int> _boostUses = {};

  /// Ad refills taken in this game (all boosts together).
  int adRefillsUsed = 0;

  /// Boost uses this game for [id] (hard cap per game, whatever the stock source).
  int boostUses(BoostId id) => _boostUses[id] ?? 0;
  int boostUsesLeft(BoostId id) => Boosts.def(id).maxUses - boostUses(id);

  int get adRefillsLeft => Boosts.maxAdRefillsPerGame - adRefillsUsed;

  /// Takes one ad refill from this game's allowance. False when none is left.
  bool takeAdRefill() {
    if (adRefillsLeft <= 0) return false;
    adRefillsUsed++;
    return true;
  }

  /// Undo has something to take back (greyed otherwise).
  bool get canUndo => _snapshot != null && !isGameOver;

  /// A boost may be used now: game running and per-game cap not reached (Undo also needs
  /// a snapshot). The stock is checked by the caller.
  bool canUseBoost(BoostId id) {
    if (isGameOver || boostUsesLeft(id) <= 0) return false;
    return id != BoostId.undo || _snapshot != null;
  }

  /// Common tail of a successful boost: counts the use, drops the Undo snapshot and
  /// re-checks game over. Score, combo, stage, lines and Gold Rush are untouched.
  void _boostDone(BoostId id) {
    _boostUses[id] = boostUses(id) + 1;
    _snapshot = null;
    _checkGameOver();
  }

  /// Blast at [row],[col]. Null (nothing spent) when not allowed or nothing is filled there.
  BoostResult? useBlast(int row, int col) {
    if (!canUseBoost(BoostId.blast)) return null;
    final r = Boosts.blast(board, row, col);
    if (r == null) return null;
    board = r.board;
    _boostDone(BoostId.blast);
    return r;
  }

  /// Hammer on [row],[col].
  BoostResult? useHammer(int row, int col) {
    if (!canUseBoost(BoostId.hammer)) return null;
    final r = Boosts.hammer(board, row, col);
    if (r == null) return null;
    board = r.board;
    _boostDone(BoostId.hammer);
    return r;
  }

  /// Line Sweep.
  BoostResult? useSweep() {
    if (!canUseBoost(BoostId.sweep)) return null;
    final r = Boosts.sweep(board);
    if (r == null) return null;
    board = r.board;
    _boostDone(BoostId.sweep);
    return r;
  }

  /// Shuffle: a whole new tray from the seeded generator. The tray counter that drives
  /// special blocks does not advance, and a special cell on the old tray is gone.
  bool useShuffle() {
    if (!canUseBoost(BoostId.shuffle)) return false;
    _tray = List<Piece?>.of(
      _generator.dealShuffle(board, linesCleared: linesClearedTotal),
    );
    _markTray();
    _boostDone(BoostId.shuffle);
    return true;
  }

  /// Undo: restores the state before the last placement. Returns the gem coins that
  /// placement paid (the caller takes them back, balance not below 0), or null if disabled.
  int? useUndo() {
    if (!canUseBoost(BoostId.undo)) return null;
    final s = _snapshot!;
    board = s.board;
    _tray = List<Piece?>.of(s.tray);
    trayStartBoard = s.trayStartBoard;
    trayStartPieces = s.trayStartPieces;
    score = s.score;
    bestScore = s.bestScore;
    comboStreak = s.comboStreak;
    linesClearedTotal = s.linesClearedTotal;
    piecesPlaced = s.piecesPlaced;
    maxComboReached = s.maxComboReached;
    rushLeft = s.rushLeft;
    _generator.traysDealt = s.traysDealt;
    _boostDone(BoostId.undo);
    return s.gemCoins;
  }

  /// The board and pieces when the current tray was dealt, for the game over "best move".
  late Board trayStartBoard;
  late List<Piece> trayStartPieces;

  void _markTray() {
    trayStartBoard = board;
    trayStartPieces = [for (final p in _tray) ?p];
  }

  /// Pieces offered; a slot is null once used.
  List<Piece?> get tray => List.unmodifiable(_tray);

  /// Ad-based revives left in this run (resets with every new [GameState]).
  int get revivesRemaining => maxRevives - revivesUsed;

  /// Stage multiplier for the line bonus: `1 + linesClearedTotal ~/ 5`, at most [maxStage].
  int get stage => min(1 + linesClearedTotal ~/ linesPerStage, maxStage);

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
    final snapshot = _Snapshot(this);
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
      final base = 10 * lines * lines + gemPoints * gems;
      gained += (base * multiplier * pow(stage, stageExponent)).round();
      gained += blastCellPoints * result.blastCells.length;
      comboStreak++;
      linesClearedTotal += lines;
      maxComboReached = max(maxComboReached, multiplier);
    } else {
      comboStreak = 0;
    }
    // Gold Rush doubles everything after the stage and combo multipliers. It covers the
    // next placements, so the placement that clears the golden block is not doubled.
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
    snapshot.gemCoins = gems;
    _snapshot = snapshot;

    if (_tray.every((p) => p == null)) {
      _tray = List<Piece?>.of(
        _generator.dealTray(board, linesCleared: linesClearedTotal),
      );
      _markTray();
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
    _snapshot = null;
    board = board.clearFullestRows(2);
    _tray = List<Piece?>.of(
      _generator.dealTray(board, linesCleared: linesClearedTotal),
    );
    _markTray();
    comboStreak = 0;
    _checkGameOver();
    return true;
  }
}
