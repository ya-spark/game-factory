import 'board.dart';
import 'piece.dart';

/// One placement of the best sequence: [piece] goes to [row],[col] on [before].
class BestMoveStep {
  const BestMoveStep({
    required this.piece,
    required this.row,
    required this.col,
    required this.before,
    required this.clearedRows,
    required this.clearedCols,
  });

  final Piece piece;
  final int row;
  final int col;

  /// The board before this piece is placed.
  final Board before;

  /// Lines this placement completes (they clear right after it).
  final List<int> clearedRows;
  final List<int> clearedCols;
}

/// The best way to play a set of pieces: the order and cells with the most lines cleared.
class BestMove {
  const BestMove(this.steps, this.lines);
  final List<BestMoveStep> steps;

  /// Total lines the sequence clears.
  final int lines;
}

/// Finds the best sequence for a tray (used on the game over screen, for the last tray).
/// Pure Dart. Order of preference: most lines cleared, then most pieces placed, then the
/// emptiest board. Special cells (Boom, gem, gold) are ignored when searching.
abstract final class BestMoveSolver {
  static const int _size = 8;

  static final List<int> _rowMasks = [
    for (var r = 0; r < _size; r++) 0xFF << (8 * r),
  ];
  static final List<int> _colMasks = [
    for (var c = 0; c < _size; c++) _columnMask(c),
  ];

  static int _columnMask(int c) {
    var m = 0;
    for (var r = 0; r < _size; r++) {
      m |= 1 << (8 * r + c);
    }
    return m;
  }

  /// The best sequence for [pieces] on [board], or null when the board is not 8x8 or no
  /// piece fits at all.
  static BestMove? solve(Board board, List<Piece> pieces) {
    if (board.size != _size || pieces.isEmpty) return null;
    var start = 0;
    for (var i = 0; i < _size * _size; i++) {
      if (board.cells[i] != 0) start |= 1 << i;
    }
    // Every legal placement of every piece as a bit mask.
    final masks = <List<(int, int, int)>>[
      for (final p in pieces)
        [
          for (var r = 0; r + p.height <= _size; r++)
            for (var c = 0; c + p.width <= _size; c++) (r, c, _maskOf(p, r, c)),
        ],
    ];
    final used = List<bool>.filled(pieces.length, false);
    final seq = <(int, int, int)>[];
    var bestValue = -1;
    var bestSeq = <(int, int, int)>[];

    void dfs(int bits, int lines) {
      final value = lines * 10000 + seq.length * 100 + (64 - _count(bits));
      if (seq.isNotEmpty && value > bestValue) {
        bestValue = value;
        bestSeq = List.of(seq);
      }
      for (var i = 0; i < pieces.length; i++) {
        if (used[i]) continue;
        used[i] = true;
        for (final (r, c, m) in masks[i]) {
          if (bits & m != 0) continue;
          var next = bits | m;
          var clear = 0;
          var n = 0;
          for (var k = 0; k < _size; k++) {
            if (next & _rowMasks[k] == _rowMasks[k]) {
              clear |= _rowMasks[k];
              n++;
            }
            if (next & _colMasks[k] == _colMasks[k]) {
              clear |= _colMasks[k];
              n++;
            }
          }
          next &= ~clear;
          seq.add((i, r, c));
          dfs(next, lines + n);
          seq.removeLast();
        }
        used[i] = false;
      }
    }

    dfs(start, 0);
    if (bestSeq.isEmpty) return null;

    // Replay on the real board to get the pictures (and the exact clears).
    final steps = <BestMoveStep>[];
    var current = board;
    var total = 0;
    for (final (i, r, c) in bestSeq) {
      final res = current.place(pieces[i], r, c);
      steps.add(
        BestMoveStep(
          piece: pieces[i],
          row: r,
          col: c,
          before: current,
          clearedRows: res.clearedRows,
          clearedCols: res.clearedCols,
        ),
      );
      total += res.linesCleared;
      current = res.board;
    }
    return BestMove(steps, total);
  }

  static int _maskOf(Piece p, int row, int col) {
    var m = 0;
    for (final (dr, dc) in p.cells) {
      m |= 1 << ((row + dr) * _size + col + dc);
    }
    return m;
  }

  static int _count(int bits) {
    var n = 0;
    var b = bits;
    while (b != 0) {
      b &= b - 1;
      n++;
    }
    return n;
  }
}
