import 'dart:math';

import 'board.dart';
import 'piece.dart';

/// Deals pieces. Guarantees every dealt tray has at least one piece that fits when any move
/// is still possible, so a game never ends by a bad deal alone. Seedable for tests.
class PieceGenerator {
  PieceGenerator([Random? random]) : _rng = random ?? Random();

  final Random _rng;

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

  /// Three pieces for [board].
  List<Piece> dealTray(Board board, {int count = 3}) {
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
}
