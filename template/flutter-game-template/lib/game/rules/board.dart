import 'piece.dart';

/// Result of placing a piece on a [Board].
class PlacementResult {
  const PlacementResult(this.board, this.clearedRows, this.clearedCols);
  final Board board;
  final List<int> clearedRows;
  final List<int> clearedCols;

  int get linesCleared => clearedRows.length + clearedCols.length;
}

/// Immutable 8x8 (configurable) occupancy grid. 0 = empty, n>0 = color index + 1. Pure Dart.
class Board {
  Board._(this.size, this._cells);

  factory Board.empty([int size = 8]) =>
      Board._(size, List.unmodifiable(List<int>.filled(size * size, 0)));

  factory Board.fromRows(List<String> rows) {
    final size = rows.length;
    final cells = <int>[];
    for (final r in rows) {
      assert(r.length == size);
      for (final ch in r.split('')) {
        cells.add(ch == '.' ? 0 : 1);
      }
    }
    return Board._(size, List.unmodifiable(cells));
  }

  final int size;
  final List<int> _cells;

  int at(int row, int col) => _cells[row * size + col];
  bool isFilled(int row, int col) => at(row, col) != 0;
  int get filledCount => _cells.where((c) => c != 0).length;
  bool get isEmpty => filledCount == 0;

  bool canPlace(Piece p, int row, int col) {
    for (final (dr, dc) in p.cells) {
      final r = row + dr, c = col + dc;
      if (r < 0 || c < 0 || r >= size || c >= size) return false;
      if (isFilled(r, c)) return false;
    }
    return true;
  }

  bool canPlaceAnywhere(Piece p) {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (canPlace(p, r, c)) return true;
      }
    }
    return false;
  }

  /// Places [p] at [row],[col] (top-left of its bounding box) and clears full lines.
  /// Throws if the placement is illegal; check [canPlace] first.
  PlacementResult place(Piece p, int row, int col) {
    if (!canPlace(p, row, col)) {
      throw ArgumentError('Illegal placement of ${p.id} at $row,$col');
    }
    final next = List<int>.of(_cells);
    for (final (dr, dc) in p.cells) {
      next[(row + dr) * size + (col + dc)] = p.colorIndex + 1;
    }
    final rows = <int>[
      for (var r = 0; r < size; r++)
        if (List.generate(size, (c) => next[r * size + c]).every((v) => v != 0))
          r,
    ];
    final cols = <int>[
      for (var c = 0; c < size; c++)
        if (List.generate(size, (r) => next[r * size + c]).every((v) => v != 0))
          c,
    ];
    // Clear after detecting both, so a row and a column crossing both disappear.
    for (final r in rows) {
      for (var c = 0; c < size; c++) {
        next[r * size + c] = 0;
      }
    }
    for (final c in cols) {
      for (var r = 0; r < size; r++) {
        next[r * size + c] = 0;
      }
    }
    return PlacementResult(Board._(size, List.unmodifiable(next)), rows, cols);
  }

  /// Returns a board with the [count] fullest rows emptied (used by the revive).
  Board clearFullestRows(int count) {
    final order = List<int>.generate(size, (i) => i)
      ..sort((a, b) => _rowCount(b).compareTo(_rowCount(a)));
    final next = List<int>.of(_cells);
    for (final r in order.take(count)) {
      for (var c = 0; c < size; c++) {
        next[r * size + c] = 0;
      }
    }
    return Board._(size, List.unmodifiable(next));
  }

  int _rowCount(int r) {
    var n = 0;
    for (var c = 0; c < size; c++) {
      if (isFilled(r, c)) n++;
    }
    return n;
  }
}
