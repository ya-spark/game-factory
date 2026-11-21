import 'dart:math';

import 'board.dart';
import 'piece.dart';

/// Maximum distance, in cells, between the dragged top-left and a snap cell.
const double snapTolerance = 1.0;

/// Nearest legal placement for [piece] whose top-left is at unrounded cell position
/// ([fy], [fx]), or null when none lies within [snapTolerance] cells. Ties: more lines
/// cleared, then smaller row, then smaller column. Pure Dart.
(int, int)? snapToLegalCell(Board board, Piece piece, double fy, double fx) {
  (int, int)? best;
  var bestD = double.infinity;
  var bestLines = -1;
  const eps = 1e-9;
  final r0 = (fy - snapTolerance).floor(), r1 = (fy + snapTolerance).ceil();
  final c0 = (fx - snapTolerance).floor(), c1 = (fx + snapTolerance).ceil();
  for (var r = r0; r <= r1; r++) {
    for (var c = c0; c <= c1; c++) {
      final d = sqrt((r - fy) * (r - fy) + (c - fx) * (c - fx));
      if (d > snapTolerance + eps) continue;
      if (!board.canPlace(piece, r, c)) continue;
      final lines = board.place(piece, r, c).linesCleared;
      final closer = d < bestD - eps;
      final tied = !closer && d <= bestD + eps;
      // Scan order is row-major ascending, so on a full tie the earlier cell is kept.
      if (closer || (tied && lines > bestLines)) {
        best = (r, c);
        bestD = d;
        bestLines = lines;
      }
    }
  }
  return best;
}
