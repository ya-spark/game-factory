import 'piece.dart';

export 'piece.dart' show CellKind;

/// Result of placing a piece on a [Board].
class PlacementResult {
  const PlacementResult(
    this.board,
    this.clearedRows,
    this.clearedCols, {
    this.gems = 0,
    this.golds = 0,
    this.booms = 0,
    this.blastCells = const [],
    this.blastGems = 0,
  });
  final Board board;
  final List<int> clearedRows;
  final List<int> clearedCols;

  /// Gems cleared with a line (not counting [blastGems]).
  final int gems;

  /// Golden blocks cleared with a line.
  final int golds;

  /// Blast blocks cleared with a line.
  final int booms;

  /// Extra cells emptied by blast blocks (outside the cleared lines), as (row, col).
  final List<(int, int)> blastCells;

  /// Gems among [blastCells]; they still pay.
  final int blastGems;

  int get linesCleared => clearedRows.length + clearedCols.length;
}

/// Immutable 8x8 (configurable) occupancy grid. 0 = empty, n>0 = color index + 1; a parallel
/// list holds the [CellKind] of each cell. Pure Dart.
class Board {
  Board._(this.size, this._cells, [List<CellKind>? kinds])
    : _plain = kinds == null || kinds.every((k) => k == CellKind.normal),
      _kinds = kinds == null
          ? (_normalKinds[size] ??= List.unmodifiable(
              List<CellKind>.filled(size * size, CellKind.normal),
            ))
          : List.unmodifiable(kinds);

  static final Map<int, List<CellKind>> _normalKinds = {};

  /// True when no cell is special (the fast path of [place]).
  final bool _plain;

  factory Board.empty([int size = 8]) =>
      Board._(size, List.unmodifiable(List<int>.filled(size * size, 0)));

  /// [kinds] marks special cells by (row, col); they must be filled cells.
  factory Board.fromRows(
    List<String> rows, {
    Map<(int, int), CellKind> kinds = const {},
  }) {
    final size = rows.length;
    final cells = <int>[];
    for (final r in rows) {
      assert(r.length == size);
      for (final ch in r.split('')) {
        cells.add(ch == '.' ? 0 : 1);
      }
    }
    final k = List<CellKind>.filled(size * size, CellKind.normal);
    kinds.forEach((pos, kind) {
      assert(cells[pos.$1 * size + pos.$2] != 0);
      k[pos.$1 * size + pos.$2] = kind;
    });
    return Board._(size, List.unmodifiable(cells), k);
  }

  final int size;
  final List<int> _cells;
  final List<CellKind> _kinds;

  CellKind kindAt(int row, int col) => _kinds[row * size + col];

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
    if (_plain && !p.hasSpecial) {
      // Fast path (dealing tries many placements): no special cells anywhere.
      for (final (dr, dc) in p.cells) {
        next[(row + dr) * size + (col + dc)] = p.colorIndex + 1;
      }
      final rows = <int>[
        for (var r = 0; r < size; r++)
          if (_lineFull(next, r * size, 1)) r,
      ];
      final cols = <int>[
        for (var c = 0; c < size; c++)
          if (_lineFull(next, c, size)) c,
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
      return PlacementResult(
        Board._(size, List.unmodifiable(next)),
        rows,
        cols,
      );
    }
    final nextKinds = List<CellKind>.of(_kinds);
    for (var i = 0; i < p.cells.length; i++) {
      final (dr, dc) = p.cells[i];
      next[(row + dr) * size + (col + dc)] = p.colorIndex + 1;
      nextKinds[(row + dr) * size + (col + dc)] = p.kindAt(i);
    }
    final rows = <int>[
      for (var r = 0; r < size; r++)
        if (_lineFull(next, r * size, 1)) r,
    ];
    final cols = <int>[
      for (var c = 0; c < size; c++)
        if (_lineFull(next, c, size)) c,
    ];
    final clearedIdx = <int>{
      for (final r in rows)
        for (var c = 0; c < size; c++) r * size + c,
      for (final c in cols)
        for (var r = 0; r < size; r++) r * size + c,
    };
    var gems = 0, golds = 0;
    final boomAt = <int>[];
    for (final i in clearedIdx) {
      switch (nextKinds[i]) {
        case CellKind.gem:
          gems++;
        case CellKind.gold:
          golds++;
        case CellKind.boom:
          boomAt.add(i);
        case CellKind.normal:
          break;
      }
    }
    for (final i in clearedIdx) {
      next[i] = 0;
      nextKinds[i] = CellKind.normal;
    }
    // Blast blocks: empty the 3x3 area around each (no chain reactions, no gravity).
    final blast = <int>{};
    var blastGems = 0;
    for (final i in boomAt) {
      final br = i ~/ size, bc = i % size;
      for (var r = br - 1; r <= br + 1; r++) {
        for (var c = bc - 1; c <= bc + 1; c++) {
          if (r < 0 || c < 0 || r >= size || c >= size) continue;
          final j = r * size + c;
          if (next[j] == 0) continue;
          if (nextKinds[j] == CellKind.gem) blastGems++;
          blast.add(j);
          next[j] = 0;
          nextKinds[j] = CellKind.normal;
        }
      }
    }
    return PlacementResult(
      Board._(size, List.unmodifiable(next), nextKinds),
      rows,
      cols,
      gems: gems,
      golds: golds,
      booms: boomAt.length,
      blastCells: [for (final j in blast) (j ~/ size, j % size)],
      blastGems: blastGems,
    );
  }

  bool _lineFull(List<int> cells, int start, int step) {
    for (var i = 0; i < size; i++) {
      if (cells[start + i * step] == 0) return false;
    }
    return true;
  }

  /// Returns a board with the [count] fullest rows emptied (used by the revive).
  Board clearFullestRows(int count) {
    final order = List<int>.generate(size, (i) => i)
      ..sort((a, b) => _rowCount(b).compareTo(_rowCount(a)));
    final next = List<int>.of(_cells);
    final nextKinds = List<CellKind>.of(_kinds);
    for (final r in order.take(count)) {
      for (var c = 0; c < size; c++) {
        next[r * size + c] = 0;
        nextKinds[r * size + c] = CellKind.normal;
      }
    }
    return Board._(size, List.unmodifiable(next), nextKinds);
  }

  int _rowCount(int r) {
    var n = 0;
    for (var c = 0; c < size; c++) {
      if (isFilled(r, c)) n++;
    }
    return n;
  }
}
