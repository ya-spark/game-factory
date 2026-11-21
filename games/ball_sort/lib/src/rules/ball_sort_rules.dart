/// Ball sort rules: tubes of coloured balls, moves, undo, add-a-tube, a solver that proves a level
/// solvable and a level generator. Pure Dart (no Flutter, Flame or Android imports). The random
/// source is injected.
library;

import 'dart:math';

/// Balls per tube.
const int tubeCapacity = 4;

/// Most colours in a level.
const int maxColours = 10;

/// Colours in level [level] (1 based): 3 at the start, one more every two levels, up to 10.
int coloursForLevel(int level) => min(maxColours, 3 + (max(1, level) - 1) ~/ 2);

/// The seed a level is generated from, so a level is always the same layout.
int seedForLevel(int level) => level * 7919 + 13;

/// The state of one level. Each tube lists its balls bottom to top (colour ids from 0).
class BallSortState {
  BallSortState(this.tubes, {this.added = false, this.moves = 0});

  final List<List<int>> tubes;

  /// True once the extra tube was added for this level.
  bool added;
  int moves;

  BallSortState copy() => BallSortState(
    [for (final t in tubes) List.of(t)],
    added: added,
    moves: moves,
  );

  /// True when every tube is empty or full of one colour.
  bool get solved => tubes.every(
    (t) =>
        t.isEmpty || (t.length == tubeCapacity && t.every((b) => b == t.first)),
  );

  bool get canAddTube => !added && !solved;

  /// How many balls a move from [from] to [to] would carry: the run of the top colour, as many as
  /// fit. 0 when the move is not allowed.
  int movable(int from, int to) {
    if (from == to) return 0;
    final a = tubes[from], b = tubes[to];
    if (a.isEmpty || b.length >= tubeCapacity) return 0;
    final colour = a.last;
    if (b.isNotEmpty && b.last != colour) return 0;
    var run = 0;
    for (var i = a.length - 1; i >= 0 && a[i] == colour; i--) {
      run++;
    }
    return min(run, tubeCapacity - b.length);
  }

  /// Moves the top run of [from] onto [to]. Returns the number of balls moved (0: not allowed).
  int move(int from, int to) {
    final n = movable(from, to);
    if (n == 0) return 0;
    final a = tubes[from];
    final run = a.sublist(a.length - n);
    a.removeRange(a.length - n, a.length);
    tubes[to].addAll(run);
    moves++;
    return n;
  }

  /// Adds one empty tube, once per level. Returns whether it was added.
  bool addTube() {
    if (!canAddTube) return false;
    tubes.add([]);
    added = true;
    return true;
  }

  /// A key for the position that ignores the order of the tubes.
  String get key {
    final k = [for (final t in tubes) t.join(',')]..sort();
    return k.join('|');
  }
}

/// A game with undo.
class BallSortGame {
  BallSortGame(this.state, {this.level = 1});
  BallSortState state;
  final int level;

  /// True once undo or the extra tube was used (they cost the clean-play bonus).
  bool helped = false;
  final List<BallSortState> _undo = [];

  bool get canUndo => _undo.isNotEmpty;

  /// Moves a run; returns the number of balls moved.
  int move(int from, int to) {
    if (state.solved) return 0;
    final snapshot = state.copy();
    final n = state.move(from, to);
    if (n > 0) _undo.add(snapshot);
    return n;
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    final moves = state.moves;
    state = _undo.removeLast()..moves = moves;
    helped = true;
    return true;
  }

  bool addTube() {
    final snapshot = state.copy();
    if (!state.addTube()) return false;
    _undo.add(snapshot);
    helped = true;
    return true;
  }

  /// Score of a win: 200 plus 50 per colour, minus one per move (at least 50), plus 100 when no
  /// undo and no extra tube were used.
  int get score {
    final colours = state.tubes.where((t) => t.isNotEmpty).length;
    final base = max(50, 200 + 50 * colours - state.moves);
    return base + (helped ? 0 : 100);
  }
}

/// Tries to solve [start] with a depth-first search over at most [maxNodes] positions. True only
/// when a solution was found, so a true answer is a proof.
bool solveBallSort(BallSortState start, {int maxNodes = 20000}) {
  final seen = <String>{};
  var nodes = 0;
  bool go(BallSortState s) {
    if (s.solved) return true;
    if (++nodes > maxNodes) return false;
    if (!seen.add(s.key)) return false;
    final candidates = <(int, int, int)>[];
    for (var i = 0; i < s.tubes.length; i++) {
      final a = s.tubes[i];
      if (a.isEmpty) continue;
      // A tube of one colour that is already full has nothing to do.
      if (a.length == tubeCapacity && a.every((b) => b == a.first)) continue;
      final pure = a.every((b) => b == a.first);
      for (var j = 0; j < s.tubes.length; j++) {
        final n = s.movable(i, j);
        if (n == 0) continue;
        final b = s.tubes[j];
        // Pouring a pure tube into an empty one only swaps the tubes.
        if (pure && b.isEmpty) continue;
        // Prefer joining the same colour, and finishing a tube.
        final priority = b.isNotEmpty ? (pure ? 0 : 1) : 2;
        candidates.add((priority, i, j));
      }
    }
    candidates.sort((x, y) => x.$1.compareTo(y.$1));
    for (final c in candidates) {
      final n = s.copy()..move(c.$2, c.$3);
      if (go(n)) return true;
      if (nodes > maxNodes) return false;
    }
    return false;
  }

  return go(start.copy());
}

/// A generated level.
class BallSortLevel {
  const BallSortLevel(this.level, this.state, this.proven);
  final int level;
  final BallSortState state;

  /// True when the solver proved it solvable (always, unless the search budget ran out on every
  /// attempt, which does not happen for the levels of this game).
  final bool proven;
}

/// Makes level [level]: shuffles the balls of [coloursForLevel] colours into that many tubes, adds
/// two empty tubes and keeps the first layout the solver proves solvable. A layout that is already
/// sorted is never used.
BallSortLevel generateBallSort(
  int level,
  Random random, {
  int attempts = 30,
  int maxNodes = 20000,
}) {
  final colours = coloursForLevel(level);
  BallSortState shuffled() {
    final balls = <int>[
      for (var c = 0; c < colours; c++)
        for (var k = 0; k < tubeCapacity; k++) c,
    ]..shuffle(random);
    final tubes = <List<int>>[
      for (var t = 0; t < colours; t++)
        balls.sublist(t * tubeCapacity, (t + 1) * tubeCapacity),
      [],
      [],
    ];
    return BallSortState(tubes);
  }

  var s = shuffled();
  for (var a = 0; a < attempts; a++) {
    if (!s.solved && solveBallSort(s, maxNodes: maxNodes)) {
      return BallSortLevel(level, s, true);
    }
    s = shuffled();
  }
  return BallSortLevel(level, s, false);
}
