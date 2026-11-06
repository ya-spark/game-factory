import 'dart:math';

import 'board.dart';
import 'piece.dart';

/// Deals pieces. Guarantees every dealt tray has at least one piece that fits when any move
/// is still possible, so a game never ends by a bad deal alone. Seedable for tests.
class PieceGenerator {
  /// [specialEvery] = every Nth dealt tray carries one special cell (0 = never).
  PieceGenerator([Random? random, this.specialEvery = specialEveryNthTray])
    : _rng = random ?? Random();

  final Random _rng;

  /// Every Nth dealt tray has exactly one special cell (the first tray is tray 1 and has none).
  static const int specialEveryNthTray = 4;

  /// Weights of the special kinds: gem 3, blast (`boom`) 2, gold 1.
  static const List<({CellKind kind, int weight})> specialWeights = [
    (kind: CellKind.gem, weight: 3),
    (kind: CellKind.boom, weight: 2),
    (kind: CellKind.gold, weight: 1),
  ];

  final int specialEvery;

  /// Trays dealt so far, including the first one.
  int traysDealt = 0;

  Piece _pickWeighted() {
    final list = PieceCatalog.weighted;
    final total = list.fold<int>(0, (s, w) => s + w.weight);
    var roll = _rng.nextInt(total);
    for (final w in list) {
      roll -= w.weight;
      if (roll < 0) return w.piece;
    }
    return list.last.piece;
  }

  /// Three pieces for [board]. Every [specialEvery]th tray gets exactly one special cell
  /// (see [addSpecial]); the first tray of a game is passed with [allowSpecial] false.
  List<Piece> dealTray(Board board, {int count = 3, bool allowSpecial = true}) {
    traysDealt++;
    final tray = _deal(board, count);
    if (allowSpecial && specialEvery > 0 && traysDealt % specialEvery == 0) {
      return addSpecial(tray);
    }
    return tray;
  }

  List<Piece> _deal(Board board, int count) {
    for (var attempt = 0; attempt < 50; attempt++) {
      final tray = [for (var i = 0; i < count; i++) _pickWeighted()];
      if (tray.any(board.canPlaceAnywhere)) return tray;
    }
    // Board nearly full: fall back to the smallest piece so the player is not dealt a dead hand.
    return [
      for (var i = 0; i < count; i++)
        i == 0 && board.canPlaceAnywhere(PieceCatalog.dot)
            ? PieceCatalog.dot
            : _pickWeighted(),
    ];
  }

  /// Puts one special cell (weights gem 3, blast 2, gold 1) on a random piece of at least
  /// 2 cells. Returns [tray] unchanged when no piece qualifies.
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
}
