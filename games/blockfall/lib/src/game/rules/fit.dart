import 'piece_type.dart';
import 'well.dart';

/// Probability of taking the best-fitting piece: `max(0, (9 - level) / 8)`.
double fitProbability(int level) => level >= 9 ? 0 : (9 - level) / 8;

/// How well a piece fits the surface; lower is better, compared in this order:
/// holes, then bumpiness, then height.
class FitScore implements Comparable<FitScore> {
  const FitScore(this.holes, this.bumpiness, this.height);
  final int holes;
  final int bumpiness;
  final int height;

  @override
  int compareTo(FitScore other) {
    if (holes != other.holes) return holes.compareTo(other.holes);
    if (bumpiness != other.bumpiness) {
      return bumpiness.compareTo(other.bumpiness);
    }
    return height.compareTo(other.height);
  }
}

/// Best (lowest) score over every rotation and column of a hard drop of [type];
/// null when the piece cannot be placed at all.
FitScore? bestFit(Well well, PieceType type) {
  FitScore? best;
  for (final cells in type.states) {
    var minC = 99, maxC = 0, minR = 99, maxR = 0;
    for (final (c, r) in cells) {
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
    }
    for (var x = -minC; x + maxC < Well.cols; x++) {
      var y = -minR;
      bool fits(int dy) => cells.every((e) {
        final row = e.$2 + dy, col = e.$1 + x;
        return Well.inBounds(row, col) && !well.isFilled(row, col);
      });
      if (!fits(y)) continue;
      while (y + 1 + maxR < Well.totalRows && fits(y + 1)) {
        y++;
      }
      final s = _score(well, cells, x, y);
      if (best == null || s.compareTo(best) < 0) best = s;
    }
  }
  return best;
}

FitScore _score(Well well, List<(int, int)> cells, int x, int y) {
  final placed = {for (final (c, r) in cells) (r + y) * Well.cols + c + x};
  bool filled(int r, int c) =>
      well.isFilled(r, c) || placed.contains(r * Well.cols + c);
  var holes = 0;
  final heights = List.filled(Well.cols, 0);
  for (var c = 0; c < Well.cols; c++) {
    var top = -1;
    for (var r = 0; r < Well.totalRows; r++) {
      if (filled(r, c)) {
        if (top < 0) {
          top = r;
          heights[c] = Well.totalRows - r;
        }
      } else if (top >= 0) {
        holes++;
      }
    }
  }
  var bump = 0, tallest = 0;
  for (var c = 0; c < Well.cols; c++) {
    if (c > 0) bump += (heights[c] - heights[c - 1]).abs();
    if (heights[c] > tallest) tallest = heights[c];
  }
  return FitScore(holes, bump, tallest);
}

/// Index into [pool] of the piece that fits [well] best (ties: first in [pool]).
int bestFitIndex(Well well, List<PieceType> pool) {
  var bestI = 0;
  FitScore? best;
  for (var i = 0; i < pool.length; i++) {
    final s = bestFit(well, pool[i]);
    if (s != null && (best == null || s.compareTo(best) < 0)) {
      best = s;
      bestI = i;
    }
  }
  return bestI;
}
