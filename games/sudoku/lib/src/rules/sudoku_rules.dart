/// Sudoku rules: a solver, a generator of unique-solution puzzles and the play state. Pure Dart
/// (no Flutter, Flame or Android imports). The random source is injected.
library;

import 'dart:math';

/// The four levels and the number of given digits (clues) of each.
enum SudokuLevel {
  easy('Easy', 40, 300),
  medium('Medium', 34, 600),
  hard('Hard', 30, 1000),
  expert('Expert', 26, 1500);

  const SudokuLevel(this.label, this.clues, this.baseScore);
  final String label;

  /// Target clue count. The generator never goes below it and may stop above it.
  final int clues;

  /// Score of a clean win (no hints, no mistakes).
  final int baseScore;
}

int _bits(int m) {
  var n = 0;
  while (m != 0) {
    m &= m - 1;
    n++;
  }
  return n;
}

bool _peers(int a, int b) =>
    a ~/ 9 == b ~/ 9 ||
    a % 9 == b % 9 ||
    (a ~/ 27 == b ~/ 27 && a % 9 ~/ 3 == b % 9 ~/ 3);

/// Counts solutions of an 81-cell grid (0 = empty), stopping at [limit]. Uses bitmasks and always
/// picks the empty cell with the fewest candidates. Fills [solutionOut] with the first solution.
int countSolutions(List<int> grid, {int limit = 2, List<int>? solutionOut}) {
  final g = List<int>.of(grid);
  final rows = List<int>.filled(9, 0);
  final cols = List<int>.filled(9, 0);
  final boxes = List<int>.filled(9, 0);
  for (var i = 0; i < 81; i++) {
    final v = g[i];
    if (v == 0) continue;
    final bit = 1 << v;
    final r = i ~/ 9, c = i % 9, b = (r ~/ 3) * 3 + c ~/ 3;
    if ((rows[r] & bit) != 0 || (cols[c] & bit) != 0 || (boxes[b] & bit) != 0) {
      return 0;
    }
    rows[r] |= bit;
    cols[c] |= bit;
    boxes[b] |= bit;
  }
  var found = 0;
  void go() {
    if (found >= limit) return;
    var best = -1;
    var bestMask = 0;
    var bestCount = 10;
    for (var i = 0; i < 81; i++) {
      if (g[i] != 0) continue;
      final r = i ~/ 9, c = i % 9, b = (r ~/ 3) * 3 + c ~/ 3;
      final mask = ~(rows[r] | cols[c] | boxes[b]) & 0x3FE;
      final n = _bits(mask);
      if (n < bestCount) {
        best = i;
        bestMask = mask;
        bestCount = n;
        if (n == 0) return;
        if (n == 1) break;
      }
    }
    if (best == -1) {
      found++;
      if (found == 1 && solutionOut != null) {
        solutionOut
          ..clear()
          ..addAll(g);
      }
      return;
    }
    final r = best ~/ 9, c = best % 9, b = (r ~/ 3) * 3 + c ~/ 3;
    for (var v = 1; v <= 9; v++) {
      final bit = 1 << v;
      if ((bestMask & bit) == 0) continue;
      g[best] = v;
      rows[r] |= bit;
      cols[c] |= bit;
      boxes[b] |= bit;
      go();
      g[best] = 0;
      rows[r] &= ~bit;
      cols[c] &= ~bit;
      boxes[b] &= ~bit;
      if (found >= limit) return;
    }
  }

  go();
  return found;
}

/// A generated puzzle: [puzzle] has 0 for empty cells, [solution] is the one full grid.
class SudokuPuzzle {
  const SudokuPuzzle(this.level, this.puzzle, this.solution);
  final SudokuLevel level;
  final List<int> puzzle;
  final List<int> solution;
  int get clues => puzzle.where((v) => v != 0).length;
}

/// Makes a puzzle with exactly one solution. Deterministic for a given [random].
SudokuPuzzle generateSudoku(SudokuLevel level, Random random) {
  final full = List<int>.filled(81, 0);
  _fill(full, random);
  final puzzle = List<int>.of(full);
  final order = List<int>.generate(81, (i) => i)..shuffle(random);
  var clues = 81;
  for (final i in order) {
    if (clues <= level.clues) break;
    final keep = puzzle[i];
    puzzle[i] = 0;
    if (countSolutions(puzzle, limit: 2) != 1) {
      puzzle[i] = keep;
    } else {
      clues--;
    }
  }
  return SudokuPuzzle(level, puzzle, full);
}

bool _fill(List<int> g, Random random) {
  var best = -1;
  var cands = <int>[];
  for (var i = 0; i < 81; i++) {
    if (g[i] != 0) continue;
    final c = _candidates(g, i);
    if (best == -1 || c.length < cands.length) {
      best = i;
      cands = c;
      if (c.length <= 1) break;
    }
  }
  if (best == -1) return true;
  cands.shuffle(random);
  for (final v in cands) {
    g[best] = v;
    if (_fill(g, random)) return true;
  }
  g[best] = 0;
  return false;
}

List<int> _candidates(List<int> g, int i) {
  var used = 0;
  for (var k = 0; k < 81; k++) {
    if (k != i && _peers(i, k)) used |= 1 << g[k];
  }
  return [
    for (var v = 1; v <= 9; v++)
      if ((used & (1 << v)) == 0) v,
  ];
}

/// One undoable change of a cell.
class _Move {
  _Move(this.index, this.value, this.notes);
  final int index;
  final int value;
  final int notes;
}

/// The state of one game: given digits, entries, pencil notes, undo, hints and mistakes.
class SudokuGame {
  SudokuGame(this.puzzle, {this.hintLimit = 3})
    : values = List<int>.of(puzzle.puzzle),
      notes = List<int>.filled(81, 0);

  /// Restores a saved game ([toJson]); null when the data is not a valid game.
  static SudokuGame? fromJson(Object? json) {
    try {
      final m = json as Map<String, dynamic>;
      final level = SudokuLevel.values.byName(m['level'] as String);
      List<int> list(String k) => [for (final v in m[k] as List) v as int];
      final p = list('puzzle'), s = list('solution'), v = list('values');
      final n = list('notes');
      if ([p, s, v, n].any((l) => l.length != 81)) return null;
      final g = SudokuGame(SudokuPuzzle(level, p, s));
      for (var i = 0; i < 81; i++) {
        g.values[i] = v[i];
        g.notes[i] = n[i];
      }
      g.hintsUsed = m['hints'] as int;
      g.mistakes = m['mistakes'] as int;
      return g;
    } on Object {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'level': puzzle.level.name,
    'puzzle': puzzle.puzzle,
    'solution': puzzle.solution,
    'values': values,
    'notes': notes,
    'hints': hintsUsed,
    'mistakes': mistakes,
  };

  final SudokuPuzzle puzzle;
  final int hintLimit;
  final List<int> values;

  /// Pencil notes: bit `1 << d` set when digit d is noted.
  final List<int> notes;
  int hintsUsed = 0;
  int mistakes = 0;

  /// Zen (M5): hints never run out. Set by the screen for the run; never saved.
  bool unlimitedHints = false;
  final List<_Move> _undo = [];

  bool isGiven(int i) => puzzle.puzzle[i] != 0;
  bool isWrong(int i) =>
      values[i] != 0 && !isGiven(i) && values[i] != puzzle.solution[i];
  bool get canUndo => _undo.isNotEmpty;
  int get hintsLeft => unlimitedHints ? 1 << 20 : hintLimit - hintsUsed;
  bool get solved {
    for (var i = 0; i < 81; i++) {
      if (values[i] != puzzle.solution[i]) return false;
    }
    return true;
  }

  bool hasNote(int i, int d) => (notes[i] & (1 << d)) != 0;

  /// Puts digit [d] (1 to 9) in cell [i]; with [pencil] toggles a note instead. Givens never
  /// change. Entering the same digit again clears the cell. Returns false when nothing changed.
  bool enter(int i, int d, {bool pencil = false}) {
    if (isGiven(i) || solved) return false;
    if (pencil) {
      if (values[i] != 0) return false;
      _undo.add(_Move(i, values[i], notes[i]));
      notes[i] ^= 1 << d;
      return true;
    }
    _undo.add(_Move(i, values[i], notes[i]));
    if (values[i] == d) {
      values[i] = 0;
      return true;
    }
    values[i] = d;
    notes[i] = 0;
    if (d != puzzle.solution[i]) {
      mistakes++;
    } else {
      _dropNotes(i, d);
    }
    return true;
  }

  /// Clears cell [i].
  bool erase(int i) {
    if (isGiven(i) || solved || (values[i] == 0 && notes[i] == 0)) return false;
    _undo.add(_Move(i, values[i], notes[i]));
    values[i] = 0;
    notes[i] = 0;
    return true;
  }

  void _dropNotes(int i, int d) {
    for (var k = 0; k < 81; k++) {
      if (_peers(i, k)) notes[k] &= ~(1 << d);
    }
  }

  /// Takes back the last change.
  bool undo() {
    if (_undo.isEmpty) return false;
    final m = _undo.removeLast();
    values[m.index] = m.value;
    notes[m.index] = m.notes;
    return true;
  }

  /// Fills the correct digit into [i] (or into the first empty or wrong cell when [i] is null or
  /// already right). Limited per puzzle. Returns the cell, or null when no hint is left.
  int? hint(int? i) {
    if (hintsLeft <= 0 || solved) return null;
    var cell = i;
    if (cell == null ||
        isGiven(cell) ||
        values[cell] == puzzle.solution[cell]) {
      cell = null;
      for (var k = 0; k < 81; k++) {
        if (values[k] != puzzle.solution[k]) {
          cell = k;
          break;
        }
      }
    }
    if (cell == null) return null;
    _undo.add(_Move(cell, values[cell], notes[cell]));
    values[cell] = puzzle.solution[cell];
    notes[cell] = 0;
    _dropNotes(cell, values[cell]);
    hintsUsed++;
    return cell;
  }

  /// Fills the correct digit into cell [cell] as one of the puzzle's hints (the last stage of a
  /// stepped hint). False when no hint is left or the cell is a given or already right.
  bool fillHint(int cell) {
    if (hintsLeft <= 0 ||
        solved ||
        isGiven(cell) ||
        values[cell] == puzzle.solution[cell]) {
      return false;
    }
    _undo.add(_Move(cell, values[cell], notes[cell]));
    values[cell] = puzzle.solution[cell];
    notes[cell] = 0;
    _dropNotes(cell, values[cell]);
    hintsUsed++;
    return true;
  }

  /// Score of a win: the level's base, minus 50 per mistake and 100 per hint, never below a tenth
  /// of the base.
  int get score {
    final base = puzzle.level.baseScore;
    return max(base ~/ 10, base - 50 * mistakes - 100 * hintsUsed);
  }
}

/// How a stepped hint finds its digit.
enum SudokuTechnique { nakedSingle, hiddenSingle, reveal }

/// One stepped hint (docs/SPEC.md, 4.2): where to look (free), the reason in words (free), then
/// the digit (one of the puzzle's hints). Only naked singles and hidden singles are explained; a
/// puzzle that needs more falls back to [SudokuTechnique.reveal], which fills a cell as before.
class SudokuHintStep {
  const SudokuHintStep({
    required this.technique,
    required this.cell,
    required this.digit,
    required this.area,
    required this.where,
    required this.reason,
  });
  final SudokuTechnique technique;

  /// The cell to fill and its correct digit.
  final int cell;
  final int digit;

  /// The cells to look at: the row, column or box for a hidden single, the cell for a naked one.
  final List<int> area;

  /// Stage one: where to look, in words.
  final String where;

  /// Stage two: why, in words, for example "Only one place for 7 in this row".
  final String reason;
}

/// The next stepped hint for [g], or null when the puzzle is solved. [selected] is preferred when
/// it is an empty or wrong cell that a single explains. Wrong digits the player entered are
/// ignored, so a hint never rests on a mistake.
SudokuHintStep? findSudokuHint(SudokuGame g, int? selected) {
  if (g.solved) return null;
  final grid = List<int>.generate(
    81,
    (i) =>
        g.isGiven(i) || g.values[i] == g.puzzle.solution[i] ? g.values[i] : 0,
  );
  final cand = List<int>.filled(81, 0);
  for (var i = 0; i < 81; i++) {
    if (grid[i] != 0) continue;
    var used = 0;
    for (var k = 0; k < 81; k++) {
      if (grid[k] != 0 && _peers(i, k)) used |= 1 << grid[k];
    }
    cand[i] = ~used & 0x3FE;
  }
  String cellWords(int i) => 'row ${i ~/ 9 + 1}, column ${i % 9 + 1}';

  SudokuHintStep? naked(int i) {
    if (grid[i] != 0 || _bits(cand[i]) != 1) return null;
    final d = cand[i].bitLength - 1;
    return SudokuHintStep(
      technique: SudokuTechnique.nakedSingle,
      cell: i,
      digit: d,
      area: [i],
      where: 'Look at the square in ${cellWords(i)}.',
      reason:
          'Only one digit fits here: every other digit is already in its row, '
          'column or box, so it must be $d.',
    );
  }

  // Units: 0-8 rows, 9-17 columns, 18-26 boxes.
  List<int> unit(int u) {
    final n = u % 9;
    return [
      for (var k = 0; k < 9; k++)
        if (u < 9)
          n * 9 + k
        else if (u < 18)
          k * 9 + n
        else
          (n ~/ 3) * 27 + (n % 3) * 3 + (k ~/ 3) * 9 + k % 3,
    ];
  }

  SudokuHintStep? hidden({int? only}) {
    for (var u = 0; u < 27; u++) {
      final cells = unit(u);
      for (var d = 1; d <= 9; d++) {
        if (cells.any((c) => grid[c] == d)) continue;
        final spots = [
          for (final c in cells)
            if (grid[c] == 0 && (cand[c] & (1 << d)) != 0) c,
        ];
        if (spots.length != 1) continue;
        if (only != null && spots.first != only) continue;
        final name = u < 9
            ? 'row ${u + 1}'
            : u < 18
            ? 'column ${u - 8}'
            : 'box ${u - 17}';
        final kind = u < 9
            ? 'row'
            : u < 18
            ? 'column'
            : 'box';
        return SudokuHintStep(
          technique: SudokuTechnique.hiddenSingle,
          cell: spots.first,
          digit: d,
          area: cells,
          where: 'Look at $name.',
          reason: 'Only one place for $d in this $kind.',
        );
      }
    }
    return null;
  }

  final sel = selected;
  if (sel != null && !g.isGiven(sel) && grid[sel] == 0) {
    final s = naked(sel) ?? hidden(only: sel);
    if (s != null) return s;
  }
  for (var i = 0; i < 81; i++) {
    final s = naked(i);
    if (s != null) return s;
  }
  final h = hidden();
  if (h != null) return h;
  // Needs more than a single: reveal a cell, the selected one when it is empty or wrong.
  var cell = -1;
  if (sel != null &&
      !g.isGiven(sel) &&
      g.values[sel] != g.puzzle.solution[sel]) {
    cell = sel;
  } else {
    for (var k = 0; k < 81; k++) {
      if (g.values[k] != g.puzzle.solution[k]) {
        cell = k;
        break;
      }
    }
  }
  if (cell < 0) return null;
  return SudokuHintStep(
    technique: SudokuTechnique.reveal,
    cell: cell,
    digit: g.puzzle.solution[cell],
    area: [cell],
    where:
        'This one needs more than a single. Look at the square in '
        '${cellWords(cell)}.',
    reason: 'No simple step explains this square, so the hint shows the digit.',
  );
}
