import 'dart:math';

import 'board.dart';
import 'piece.dart';

/// Deals pieces. Every dealt piece fits the board on its own whenever any piece does, so a
/// game never ends by a bad deal alone. Seedable for tests.
class PieceGenerator {
  /// [specialEvery] = every Nth dealt tray carries one special cell (0 = never).
  PieceGenerator([Random? random, this.specialEvery = specialEveryNthTray])
    : _rng = random ?? Random();

  final Random _rng;

  /// Every Nth dealt tray has exactly one special cell (the start tray is tray 1).
  static const int specialEveryNthTray = 4;

  /// Weights of the special kinds: gem 3, boom 2, gold 1.
  static const List<({CellKind kind, int weight})> specialWeights = [
    (kind: CellKind.gem, weight: 3),
    (kind: CellKind.boom, weight: 2),
    (kind: CellKind.gold, weight: 1),
  ];

  final int specialEvery;

  /// Trays dealt so far, counting the prepared start tray.
  int traysDealt = 0;

  /// The random source (also used to prepare the start board of a new game).
  Random get random => _rng;

  /// Soft preference for 4-cell pieces: weight 3 against 1 for every other shape.
  static const int fourCellWeight = 3;

  /// Lines cleared below which every deal is kind (all three pieces playable one after
  /// another, and one of them clears a line).
  static const int kindUntilLines = 20;

  /// Lines cleared from which the deal is plain (each piece only has to fit on its own).
  /// Between [kindUntilLines] and this, half of the deals (random) are kind.
  static const int plainFromLines = 60;

  /// Attempts at a kind deal before the guarantee is relaxed.
  static const int kindAttempts = 50;

  /// While at most this share of the board is filled there is plenty of room, so pieces
  /// smaller than [minRoomySize] cells are not dealt.
  static const double roomyFilledShare = 0.5;
  static const int minRoomySize = 3;

  Piece _pickWeighted(List<({Piece piece, int weight})> list) {
    final total = list.fold<int>(0, (s, w) => s + w.weight);
    var roll = _rng.nextInt(total);
    for (final w in list) {
      roll -= w.weight;
      if (roll < 0) return w.piece;
    }
    return list.last.piece;
  }

  /// Pieces of this many cells or more (the 2x3 rectangle and the 3x3 square) are never in
  /// the prepared start tray, which stays three 4-cell pieces.
  static const int bigPieceCells = 6;

  /// Dealing weight: 4-cell shapes [fourCellWeight], big pieces (6+ cells) their catalogue
  /// base weight, every other shape 1.
  static int _weightOf(Piece p) {
    if (p.size == 4) return fourCellWeight;
    if (p.size >= bigPieceCells) return PieceCatalog.baseWeightOf(p);
    return 1;
  }

  /// Three pieces for [board]. Every piece fits the board on its own whenever any piece does.
  ///
  /// Difficulty rises with [linesCleared] (this game's total) through how kind the deal is:
  /// below [kindUntilLines] the three pieces can all be played one after another and at least
  /// one clears a line (tried [kindAttempts] times, then relaxed); up to [plainFromLines]
  /// half of the deals are kind; after that the deal is plain.
  ///
  /// Every [specialEvery]th tray gets exactly one special cell (see [addSpecial]); the
  /// prepared start tray is passed with [allowSpecial] false.
  List<Piece> dealTray(
    Board board, {
    int count = 3,
    int linesCleared = 0,
    bool allowSpecial = true,
  }) {
    traysDealt++;
    final tray = recolor(
      _deal(board, count: count, linesCleared: linesCleared),
    );
    if (allowSpecial && specialEvery > 0 && traysDealt % specialEvery == 0) {
      return addSpecial(tray);
    }
    return tray;
  }

  /// Three new pieces for Shuffle: same dealing rules as [dealTray], but it does not advance
  /// [traysDealt] (so the special-block cadence is untouched) and never has a special cell.
  List<Piece> dealShuffle(Board board, {int count = 3, int linesCleared = 0}) =>
      recolor(_deal(board, count: count, linesCleared: linesCleared));

  /// Puts one special cell (weights gem 3, boom 2, gold 1) on a random piece of at
  /// least 2 cells. Returns [tray] unchanged when no piece qualifies.
  List<Piece> addSpecial(List<Piece> tray) {
    final candidates = [
      for (var i = 0; i < tray.length; i++)
        if (tray[i].size >= 2) i,
    ];
    if (candidates.isEmpty) return tray;
    final pi = candidates[_rng.nextInt(candidates.length)];
    final ci = _rng.nextInt(tray[pi].size);
    var roll = _rng.nextInt(
      specialWeights.fold<int>(0, (s, w) => s + w.weight),
    );
    var kind = specialWeights.last.kind;
    for (final w in specialWeights) {
      roll -= w.weight;
      if (roll < 0) {
        kind = w.kind;
        break;
      }
    }
    return [
      for (var i = 0; i < tray.length; i++)
        i == pi ? tray[i].withKind(ci, kind) : tray[i],
    ];
  }

  /// Gives each piece a random colour index (seeded with the generator, so tests are
  /// deterministic). The index is the position in the current theme's palette.
  List<Piece> recolor(List<Piece> pieces) => [
    for (final p in pieces) p.withColor(_rng.nextInt(Piece.colorCount)),
  ];

  List<Piece> _deal(
    Board board, {
    required int count,
    required int linesCleared,
  }) {
    final roomy =
        board.filledCount <= board.size * board.size * roomyFilledShare;
    final fitting = [
      for (final w in PieceCatalog.weighted)
        if ((!roomy || w.piece.size >= minRoomySize) &&
            board.canPlaceAnywhere(w.piece))
          w,
    ];
    if (fitting.isNotEmpty) {
      final pool = [
        for (final w in fitting) (piece: w.piece, weight: _weightOf(w.piece)),
      ];
      List<Piece> draw() => [
        for (var i = 0; i < count; i++) _pickWeighted(pool),
      ];
      final kind =
          linesCleared < kindUntilLines ||
          (linesCleared < plainFromLines && _rng.nextBool());
      if (kind) {
        for (var attempt = 0; attempt < kindAttempts; attempt++) {
          final tray = draw();
          if (_clearsALine(board, tray) && _playableInSequence(board, tray)) {
            return tray;
          }
        }
        for (var attempt = 0; attempt < kindAttempts; attempt++) {
          final tray = draw();
          if (_playableInSequence(board, tray)) return tray;
        }
      }
      return draw();
    }
    // Board nearly full: fall back to the smallest piece so the player is not dealt a dead hand.
    return [
      for (var i = 0; i < count; i++)
        i == 0 && board.canPlaceAnywhere(PieceCatalog.dot)
            ? PieceCatalog.dot
            : _pickWeighted(PieceCatalog.weighted),
    ];
  }

  /// True when some piece of [pieces] clears a line at some position on [board].
  bool _clearsALine(Board board, List<Piece> pieces) {
    for (final piece in pieces) {
      for (var r = 0; r < board.size; r++) {
        for (var c = 0; c < board.size; c++) {
          if (board.canPlace(piece, r, c) &&
              board.place(piece, r, c).linesCleared > 0) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// True when all of [pieces] can be placed one after another in some order, counting the
  /// lines cleared along the way.
  bool _playableInSequence(Board board, List<Piece> pieces) {
    if (pieces.isEmpty) return true;
    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      final rest = [...pieces.sublist(0, i), ...pieces.sublist(i + 1)];
      for (var r = 0; r < board.size; r++) {
        for (var c = 0; c < board.size; c++) {
          if (!board.canPlace(piece, r, c)) continue;
          if (_playableInSequence(board.place(piece, r, c).board, rest)) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
