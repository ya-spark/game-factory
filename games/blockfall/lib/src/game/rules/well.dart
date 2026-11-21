/// What a cell is besides its colour. `prism` is the gem-like cell (its row's score is doubled
/// and it pays a coin), `boom` blasts the 3x3 area around it and `gold` starts Gold Rush,
/// both when the row that holds them clears.
enum CellKind { normal, prism, boom, gold }

/// The playfield: 10 columns, 20 visible rows plus 2 hidden rows above (rows 0 and 1).
///
/// Row 0 is the top of the hidden zone, row [totalRows] - 1 is the bottom row.
/// A cell holds a color id (0 = empty, 1..7 = gem color) and a [CellKind].
class Well {
  Well()
    : _colors = List.filled(cols * totalRows, 0),
      _kind = List.filled(cols * totalRows, CellKind.normal);

  /// Builds a well from text rows, aligned to the bottom. `.` is empty, `1`..`7` is a
  /// color, `a`..`g` is color 1..7 with a prism, `A`..`G` with a Boom block and `H`..`N`
  /// with a golden block. Handy for tests and debug hooks.
  factory Well.fromRows(List<String> rows) {
    final w = Well();
    final start = totalRows - rows.length;
    if (start < 0) throw ArgumentError('too many rows');
    for (var i = 0; i < rows.length; i++) {
      final s = rows[i];
      if (s.length != cols) throw ArgumentError('row must have $cols cells');
      for (var c = 0; c < cols; c++) {
        final ch = s[c];
        if (ch == '.') continue;
        final code = ch.codeUnitAt(0);
        if (code >= 0x31 && code <= 0x37) {
          w.set(start + i, c, code - 0x30);
        } else if (code >= 0x61 && code <= 0x67) {
          w.set(start + i, c, code - 0x60, kind: CellKind.prism);
        } else if (code >= 0x41 && code <= 0x47) {
          w.set(start + i, c, code - 0x40, kind: CellKind.boom);
        } else if (code >= 0x48 && code <= 0x4e) {
          w.set(start + i, c, code - 0x47, kind: CellKind.gold);
        } else {
          throw ArgumentError('bad cell char "$ch"');
        }
      }
    }
    return w;
  }

  /// A well from saved data (see [colorList] and [kindList]).
  factory Well.restore(List<int> colors, List<CellKind> kinds) {
    if (colors.length != cols * totalRows || kinds.length != colors.length) {
      throw ArgumentError('bad well size');
    }
    final w = Well();
    for (var i = 0; i < colors.length; i++) {
      w._colors[i] = colors[i];
      w._kind[i] = colors[i] == 0 ? CellKind.normal : kinds[i];
    }
    return w;
  }

  /// Row-major colour ids and cell kinds, for the autosave.
  List<int> get colorList => List.unmodifiable(_colors);
  List<CellKind> get kindList => List.unmodifiable(_kind);

  static const int cols = 10;
  static const int visibleRows = 20;
  static const int hiddenRows = 2;
  static const int totalRows = visibleRows + hiddenRows;

  final List<int> _colors;
  final List<CellKind> _kind;

  static bool inBounds(int row, int col) =>
      row >= 0 && row < totalRows && col >= 0 && col < cols;

  /// Color id at the cell (0 when empty).
  int colorAt(int row, int col) => _colors[row * cols + col];
  CellKind kindAt(int row, int col) => _kind[row * cols + col];
  bool prismAt(int row, int col) => kindAt(row, col) == CellKind.prism;
  bool isFilled(int row, int col) => _colors[row * cols + col] != 0;

  /// Sets a cell. [prism] is the older spelling of `kind: CellKind.prism`.
  void set(
    int row,
    int col,
    int color, {
    bool prism = false,
    CellKind kind = CellKind.normal,
  }) {
    _colors[row * cols + col] = color;
    _kind[row * cols + col] = color == 0
        ? CellKind.normal
        : (prism ? CellKind.prism : kind);
  }

  void clearCell(int row, int col) => set(row, col, 0);

  bool isRowFull(int row) {
    for (var c = 0; c < cols; c++) {
      if (!isFilled(row, c)) return false;
    }
    return true;
  }

  bool rowHasPrism(int row) => countKindInRow(row, CellKind.prism) > 0;

  int prismCountInRow(int row) => countKindInRow(row, CellKind.prism);

  int countKindInRow(int row, CellKind kind) {
    var n = 0;
    for (var c = 0; c < cols; c++) {
      if (kindAt(row, c) == kind) n++;
    }
    return n;
  }

  bool get isEmpty => _colors.every((c) => c == 0);

  /// Removes the given rows; rows above fall by the number of removed rows below them.
  void removeRows(Iterable<int> rows) {
    final gone = rows.toSet();
    if (gone.isEmpty) return;
    var write = totalRows - 1;
    for (var read = totalRows - 1; read >= 0; read--) {
      if (gone.contains(read)) continue;
      if (write != read) _copyRow(read, write);
      write--;
    }
    for (var r = write; r >= 0; r--) {
      _blankRow(r);
    }
  }

  /// Empties rows `[from, to)`.
  void clearRowRange(int from, int to) {
    for (var r = from; r < to; r++) {
      _blankRow(r);
    }
  }

  void _copyRow(int from, int to) {
    for (var c = 0; c < cols; c++) {
      _colors[to * cols + c] = _colors[from * cols + c];
      _kind[to * cols + c] = _kind[from * cols + c];
    }
  }

  void _blankRow(int r) {
    for (var c = 0; c < cols; c++) {
      _colors[r * cols + c] = 0;
      _kind[r * cols + c] = CellKind.normal;
    }
  }

  /// Text form of the whole well (same alphabet as [Well.fromRows]), top to bottom.
  List<String> toRows() => [
    for (var r = 0; r < totalRows; r++)
      [
        for (var c = 0; c < cols; c++)
          if (!isFilled(r, c))
            '.'
          else
            switch (kindAt(r, c)) {
              CellKind.normal => '${colorAt(r, c)}',
              CellKind.prism => String.fromCharCode(0x60 + colorAt(r, c)),
              CellKind.boom => String.fromCharCode(0x40 + colorAt(r, c)),
              CellKind.gold => String.fromCharCode(0x47 + colorAt(r, c)),
            },
      ].join(),
  ];

  Well copy() {
    final w = Well();
    for (var i = 0; i < _colors.length; i++) {
      w._colors[i] = _colors[i];
      w._kind[i] = _kind[i];
    }
    return w;
  }
}
