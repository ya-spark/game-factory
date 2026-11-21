import 'board.dart';

/// The five coin boosts. Pure Dart: no Flutter, Flame or Android imports.
enum BoostId { blast, shuffle, undo, sweep, hammer }

/// One boost: price in coins and the hard cap of uses per game.
class BoostDef {
  const BoostDef(
    this.id,
    this.name,
    this.description,
    this.price,
    this.maxUses,
  );
  final BoostId id;
  final String name;
  final String description;
  final int price;
  final int maxUses;

  /// Stable string id used in the save and in test IDs.
  String get key => id.name;
}

/// What a board boost emptied.
class BoostResult {
  const BoostResult(this.board, this.cells);
  final Board board;

  /// Filled cells that were emptied, as (row, col).
  final List<(int, int)> cells;
}

abstract final class Boosts {
  static const List<BoostDef> all = [
    BoostDef(
      BoostId.blast,
      'Blast',
      'Tap a cell to empty the 3x3 around it.',
      50,
      2,
    ),
    BoostDef(
      BoostId.shuffle,
      'Shuffle',
      'Swap the three pieces for new ones.',
      40,
      2,
    ),
    BoostDef(BoostId.undo, 'Undo', 'Take back your last move.', 30, 3),
    BoostDef(
      BoostId.sweep,
      'Line Sweep',
      'Empty the fullest row or column.',
      60,
      1,
    ),
    BoostDef(BoostId.hammer, 'Hammer', 'Tap a block to empty it.', 25, 3),
  ];

  static BoostDef def(BoostId id) => all.firstWhere((d) => d.id == id);

  static BoostDef? byKey(String key) {
    for (final d in all) {
      if (d.key == key) return d;
    }
    return null;
  }

  /// Every install, new or existing, starts with this many of each boost.
  static const int startingStock = 1;

  /// At most this many ad refills per game, across all boosts.
  static const int maxAdRefillsPerGame = 3;

  /// Boost size of Blast: every filled cell within this distance (3x3).
  static const int blastRadius = 1;

  static Map<String, int> startingItems() => {
    for (final d in all) d.key: startingStock,
  };

  /// Blast: every filled cell in the 3x3 around [row],[col] is emptied (clipped at the
  /// edges, no gravity, no chain). Null when nothing there is filled (nothing to spend).
  static BoostResult? blast(Board board, int row, int col) {
    final cells = <(int, int)>[];
    for (var r = row - blastRadius; r <= row + blastRadius; r++) {
      for (var c = col - blastRadius; c <= col + blastRadius; c++) {
        if (r < 0 || c < 0 || r >= board.size || c >= board.size) continue;
        if (board.isFilled(r, c)) cells.add((r, c));
      }
    }
    if (cells.isEmpty) return null;
    return BoostResult(board.clearCells(cells), cells);
  }

  /// Hammer: empties one filled cell (any kind). Null when the cell is empty.
  static BoostResult? hammer(Board board, int row, int col) {
    if (row < 0 || col < 0 || row >= board.size || col >= board.size) {
      return null;
    }
    if (!board.isFilled(row, col)) return null;
    return BoostResult(board.clearCells([(row, col)]), [(row, col)]);
  }

  /// Line Sweep: empties the fullest row or column. Ties: rows before columns, then the
  /// lowest index. Null on an empty board.
  static BoostResult? sweep(Board board) {
    var bestCount = 0;
    var bestIsRow = true;
    var bestIndex = 0;
    for (var r = 0; r < board.size; r++) {
      if (board.rowCount(r) > bestCount) {
        bestCount = board.rowCount(r);
        bestIsRow = true;
        bestIndex = r;
      }
    }
    for (var c = 0; c < board.size; c++) {
      if (board.colCount(c) > bestCount) {
        bestCount = board.colCount(c);
        bestIsRow = false;
        bestIndex = c;
      }
    }
    if (bestCount == 0) return null;
    final cells = <(int, int)>[
      for (var i = 0; i < board.size; i++)
        if (bestIsRow
            ? board.isFilled(bestIndex, i)
            : board.isFilled(i, bestIndex))
          bestIsRow ? (bestIndex, i) : (i, bestIndex),
    ];
    return BoostResult(board.clearCells(cells), cells);
  }
}
