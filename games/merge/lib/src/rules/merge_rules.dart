/// Merge rules: a 4 x 4 garden where two plants of the same stage grow into the next stage when
/// they are swiped together. Pure Dart (no Flutter, Flame or Android imports). The random source
/// is injected.
library;

import 'dart:math';

/// Cells per side.
const int mergeSize = 4;

/// The last stage. Plants of this stage do not merge further.
const int maxStage = 12;

/// Names of the stages (index 0 is stage 1).
const List<String> stageNames = [
  'Seed',
  'Sprout',
  'Leaf',
  'Bud',
  'Blossom',
  'Lily',
  'Fern',
  'Orchid',
  'Bamboo',
  'Bonsai',
  'Grove',
  'Garden',
];

enum MergeDir { up, down, left, right }

/// Points a merge into [stage] is worth: 2 to the power of the stage.
int pointsForStage(int stage) => 1 << stage;

/// One game. A cell is 0 (empty) or the stage of its plant (1 to [maxStage]).
class MergeGame {
  MergeGame(this._rnd, {this.relaxed = false, List<int>? cells})
    : cells = cells ?? List.filled(mergeSize * mergeSize, 0) {
    if (cells == null) {
      _spawn();
      _spawn();
    }
  }

  final Random _rnd;

  /// Relaxed mode: there is no game over. When no move is left, the plants of the lowest stage
  /// are cleared from the board and play goes on.
  final bool relaxed;
  final List<int> cells;
  int score = 0;
  int moves = 0;
  int clears = 0;
  bool over = false;

  List<int>? _prevCells;
  int _prevScore = 0;
  bool _prevOver = false;

  /// Undo goes back one move only; it is offered again after the next move.
  bool get canUndo => _prevCells != null;

  int get highest => cells.fold(0, max);

  bool get full => !cells.contains(0);

  /// True when some swipe changes the board.
  bool get hasMove {
    if (!full) return true;
    for (var r = 0; r < mergeSize; r++) {
      for (var c = 0; c < mergeSize; c++) {
        final v = cells[r * mergeSize + c];
        if (v >= maxStage) continue;
        if (c + 1 < mergeSize && cells[r * mergeSize + c + 1] == v) return true;
        if (r + 1 < mergeSize && cells[(r + 1) * mergeSize + c] == v) {
          return true;
        }
      }
    }
    return false;
  }

  void _spawn() {
    final empty = [
      for (var i = 0; i < cells.length; i++)
        if (cells[i] == 0) i,
    ];
    if (empty.isEmpty) return;
    cells[empty[_rnd.nextInt(empty.length)]] = _rnd.nextInt(10) == 0 ? 2 : 1;
  }

  /// The cell indexes of line [k] in the direction of travel: first is the cell the plants move to.
  List<int> _line(MergeDir d, int k) => [
    for (var j = 0; j < mergeSize; j++)
      switch (d) {
        MergeDir.left => k * mergeSize + j,
        MergeDir.right => k * mergeSize + (mergeSize - 1 - j),
        MergeDir.up => j * mergeSize + k,
        MergeDir.down => (mergeSize - 1 - j) * mergeSize + k,
      },
  ];

  /// Swipes. Returns false (and changes nothing) when no plant moves or merges.
  bool swipe(MergeDir d) {
    if (over) return false;
    final before = List.of(cells);
    var gained = 0;
    for (var k = 0; k < mergeSize; k++) {
      final line = _line(d, k);
      final vals = [
        for (final i in line)
          if (cells[i] != 0) cells[i],
      ];
      final out = <int>[];
      for (var j = 0; j < vals.length; j++) {
        if (j + 1 < vals.length &&
            vals[j] == vals[j + 1] &&
            vals[j] < maxStage) {
          out.add(vals[j] + 1);
          gained += pointsForStage(vals[j] + 1);
          j++;
        } else {
          out.add(vals[j]);
        }
      }
      for (var j = 0; j < mergeSize; j++) {
        cells[line[j]] = j < out.length ? out[j] : 0;
      }
    }
    var same = true;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] != before[i]) same = false;
    }
    if (same) return false;
    _prevCells = before;
    _prevScore = score;
    _prevOver = over;
    score += gained;
    moves++;
    _spawn();
    if (!hasMove) {
      if (relaxed) {
        _clearLowest();
      } else {
        over = true;
      }
    }
    return true;
  }

  void _clearLowest() {
    final low = cells.where((v) => v > 0).reduce(min);
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] == low) cells[i] = 0;
    }
    clears++;
  }

  /// Takes back the last move. Returns false when there is none to take back.
  bool undo() {
    final p = _prevCells;
    if (p == null) return false;
    for (var i = 0; i < cells.length; i++) {
      cells[i] = p[i];
    }
    score = _prevScore;
    over = _prevOver;
    moves--;
    _prevCells = null;
    return true;
  }
}
