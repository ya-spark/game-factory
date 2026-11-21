/// Klondike solitaire rules: the deal, legal moves, undo, auto-complete, scoring and a solver
/// that proves a deal winnable. Pure Dart (no Flutter, Flame or Android imports). The random
/// source is injected.
library;

import 'dart:math';

/// Suits in foundation order: spades, hearts, diamonds, clubs.
const List<String> suitNames = ['spades', 'hearts', 'diamonds', 'clubs'];
const List<String> suitGlyphs = ['♠', '♥', '♦', '♣'];
const List<String> rankNames = [
  'ace',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  'jack',
  'queen',
  'king',
];
const List<String> rankGlyphs = [
  'A',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  'J',
  'Q',
  'K',
];

/// A card is an int 0 to 51: `suit * 13 + (rank - 1)`, rank 1 (ace) to 13 (king).
int suitOf(int card) => card ~/ 13;
int rankOf(int card) => card % 13 + 1;
bool isRed(int card) => suitOf(card) == 1 || suitOf(card) == 2;
String cardName(int card) =>
    '${rankNames[rankOf(card) - 1]} of ${suitNames[suitOf(card)]}';

/// Kinds of move.
enum MoveKind {
  draw,
  wasteToFoundation,
  wasteToTableau,
  tableauToFoundation,
  tableauToTableau,
  foundationToTableau,
}

/// One move. [from] and [to] are column or suit indexes by kind; [count] is the run length of a
/// tableau to tableau move.
class KlondikeMove {
  const KlondikeMove(this.kind, {this.from = 0, this.to = 0, this.count = 1});
  final MoveKind kind;
  final int from;
  final int to;
  final int count;
}

/// The whole table. Tableau columns list cards bottom to top; the first `down[c]` cards of a column
/// are face down. [stock] and [waste] list cards with the top card last.
class KlondikeState {
  KlondikeState({
    required this.drawCount,
    required this.stock,
    required this.waste,
    required this.tableau,
    required this.down,
    required this.foundation,
    this.score = 0,
    this.moves = 0,
    this.recycles = 0,
  });

  /// Deals a game from a shuffled [deck] of 52 cards.
  factory KlondikeState.deal(List<int> deck, {required int drawCount}) {
    final tableau = <List<int>>[];
    var k = 0;
    for (var c = 0; c < 7; c++) {
      tableau.add(deck.sublist(k, k + c + 1));
      k += c + 1;
    }
    return KlondikeState(
      drawCount: drawCount,
      stock: deck.sublist(k),
      waste: [],
      tableau: tableau,
      down: [for (var c = 0; c < 7; c++) c],
      foundation: [0, 0, 0, 0],
    );
  }

  final int drawCount;
  final List<int> stock;
  final List<int> waste;
  final List<List<int>> tableau;
  final List<int> down;

  /// Cards on each foundation (the top card has rank = count).
  final List<int> foundation;
  int score;
  int moves;
  int recycles;

  KlondikeState copy() => KlondikeState(
    drawCount: drawCount,
    stock: List.of(stock),
    waste: List.of(waste),
    tableau: [for (final t in tableau) List.of(t)],
    down: List.of(down),
    foundation: List.of(foundation),
    score: score,
    moves: moves,
    recycles: recycles,
  );

  bool get won => foundation.every((n) => n == 13);

  bool isFaceUp(int col, int index) => index >= down[col];

  /// A key for the position (not the score), used by the solver.
  String get key {
    final b = StringBuffer()
      ..writeAll(stock, ',')
      ..write('|')
      ..writeAll(waste, ',')
      ..write('|')
      ..writeAll(foundation, ',');
    for (var c = 0; c < 7; c++) {
      b
        ..write('|')
        ..write(down[c])
        ..write(':')
        ..writeAll(tableau[c], ',');
    }
    return b.toString();
  }

  bool _canFoundation(int card) => foundation[suitOf(card)] == rankOf(card) - 1;

  bool _canStack(int card, int col) {
    final t = tableau[col];
    if (t.isEmpty) return rankOf(card) == 13;
    final top = t.last;
    return isRed(top) != isRed(card) && rankOf(top) == rankOf(card) + 1;
  }

  /// All legal moves. Draw is listed once (it recycles the waste when the stock is empty).
  List<KlondikeMove> legalMoves() {
    final out = <KlondikeMove>[];
    if (waste.isNotEmpty) {
      final w = waste.last;
      if (_canFoundation(w)) {
        out.add(const KlondikeMove(MoveKind.wasteToFoundation));
      }
      for (var c = 0; c < 7; c++) {
        if (_canStack(w, c)) {
          out.add(KlondikeMove(MoveKind.wasteToTableau, to: c));
        }
      }
    }
    for (var c = 0; c < 7; c++) {
      final t = tableau[c];
      if (t.isEmpty) continue;
      if (_canFoundation(t.last)) {
        out.add(KlondikeMove(MoveKind.tableauToFoundation, from: c));
      }
      for (var i = down[c]; i < t.length; i++) {
        for (var d = 0; d < 7; d++) {
          if (d == c || !_canStack(t[i], d)) continue;
          // Moving a whole king-led pile to an empty column changes nothing.
          if (tableau[d].isEmpty && i == 0) continue;
          out.add(
            KlondikeMove(
              MoveKind.tableauToTableau,
              from: c,
              to: d,
              count: t.length - i,
            ),
          );
        }
      }
    }
    for (var s = 0; s < 4; s++) {
      if (foundation[s] == 0) continue;
      final card = s * 13 + foundation[s] - 1;
      for (var c = 0; c < 7; c++) {
        if (_canStack(card, c)) {
          out.add(KlondikeMove(MoveKind.foundationToTableau, from: s, to: c));
        }
      }
    }
    if (stock.isNotEmpty || waste.isNotEmpty) {
      out.add(const KlondikeMove(MoveKind.draw));
    }
    return out;
  }

  /// True when [m] is legal now.
  bool isLegal(KlondikeMove m) => legalMoves().any(
    (x) =>
        x.kind == m.kind &&
        x.from == m.from &&
        x.to == m.to &&
        (m.kind != MoveKind.tableauToTableau || x.count == m.count),
  );

  /// Applies [m] (which must be legal) and updates score and move count.
  void apply(KlondikeMove m) {
    moves++;
    switch (m.kind) {
      case MoveKind.draw:
        if (stock.isEmpty) {
          stock.addAll(waste.reversed);
          waste.clear();
          recycles++;
          score = max(0, score - (drawCount == 1 ? 100 : 20));
        } else {
          for (var n = 0; n < drawCount && stock.isNotEmpty; n++) {
            waste.add(stock.removeLast());
          }
        }
      case MoveKind.wasteToFoundation:
        final w = waste.removeLast();
        foundation[suitOf(w)]++;
        score += 10;
      case MoveKind.wasteToTableau:
        tableau[m.to].add(waste.removeLast());
        score += 5;
      case MoveKind.tableauToFoundation:
        final c = tableau[m.from].removeLast();
        foundation[suitOf(c)]++;
        score += 10;
        _reveal(m.from);
      case MoveKind.tableauToTableau:
        final src = tableau[m.from];
        final run = src.sublist(src.length - m.count);
        src.removeRange(src.length - m.count, src.length);
        tableau[m.to].addAll(run);
        _reveal(m.from);
      case MoveKind.foundationToTableau:
        foundation[m.from]--;
        tableau[m.to].add(m.from * 13 + foundation[m.from]);
        score = max(0, score - 15);
    }
  }

  void _reveal(int col) {
    final t = tableau[col];
    if (t.isNotEmpty && down[col] >= t.length) {
      down[col] = t.length - 1;
      score += 5;
    }
  }

  /// All cards are face up and the stock and waste are empty: the rest is certain to be won by
  /// moving cards to the foundations.
  bool get canAutoComplete {
    if (won || stock.isNotEmpty || waste.isNotEmpty) return false;
    for (var c = 0; c < 7; c++) {
      if (down[c] != 0 && tableau[c].isNotEmpty) return false;
    }
    return true;
  }

  /// The next card to send to a foundation during auto-complete, or null.
  KlondikeMove? nextAutoMove() {
    for (var c = 0; c < 7; c++) {
      final t = tableau[c];
      if (t.isNotEmpty && _canFoundation(t.last)) {
        return KlondikeMove(MoveKind.tableauToFoundation, from: c);
      }
    }
    return null;
  }

  /// The best simple move for a tap on a tableau top card, the waste top or a foundation top:
  /// the foundation first, else the first column it fits.
  KlondikeMove? tapMove(MoveKind from, {int index = 0, int col = 0}) {
    switch (from) {
      case MoveKind.wasteToFoundation:
      case MoveKind.wasteToTableau:
        if (waste.isEmpty) return null;
        if (_canFoundation(waste.last)) {
          return const KlondikeMove(MoveKind.wasteToFoundation);
        }
        for (var d = 0; d < 7; d++) {
          if (_canStack(waste.last, d)) {
            return KlondikeMove(MoveKind.wasteToTableau, to: d);
          }
        }
        return null;
      default:
        final t = tableau[col];
        if (index < down[col] || index >= t.length) return null;
        if (index == t.length - 1 && _canFoundation(t.last)) {
          return KlondikeMove(MoveKind.tableauToFoundation, from: col);
        }
        for (var d = 0; d < 7; d++) {
          if (d == col || !_canStack(t[index], d)) continue;
          if (tableau[d].isEmpty && index == 0) continue;
          return KlondikeMove(
            MoveKind.tableauToTableau,
            from: col,
            to: d,
            count: t.length - index,
          );
        }
        return null;
    }
  }
}

/// A shuffled deck.
List<int> shuffledDeck(Random random) =>
    List<int>.generate(52, (i) => i)..shuffle(random);

/// Tries to win from [start] with a depth-first search, looking at no more than [maxNodes]
/// positions. True only when a win was found, so a true answer is a proof.
bool solveKlondike(KlondikeState start, {int maxNodes = 20000}) {
  final seen = <String>{};
  var nodes = 0;
  bool go(KlondikeState s) {
    if (s.won) return true;
    if (++nodes > maxNodes) return false;
    if (!seen.add(s.key)) return false;
    final moves = s.legalMoves()
      ..removeWhere((m) => m.kind == MoveKind.foundationToTableau);
    int rank(KlondikeMove m) => switch (m.kind) {
      MoveKind.tableauToFoundation || MoveKind.wasteToFoundation => 0,
      MoveKind.tableauToTableau =>
        s.down[m.from] == s.tableau[m.from].length - m.count ? 1 : 2,
      MoveKind.wasteToTableau => 3,
      _ => 4,
    };
    moves.sort((a, b) => rank(a).compareTo(rank(b)));
    for (final m in moves) {
      final n = s.copy()..apply(m);
      if (go(n)) return true;
      if (nodes > maxNodes) return false;
    }
    return false;
  }

  return go(start.copy());
}

/// Deals a game. With [winnable], tries up to [attempts] shuffles and keeps the first that the
/// solver proves winnable; when none is proven the last shuffle is used (so it is only a best
/// effort for hard deals), and [DealResult.proven] says which.
DealResult dealKlondike(
  Random random, {
  required int drawCount,
  required bool winnable,
  int attempts = 40,
  int maxNodes = 20000,
}) {
  var state = KlondikeState.deal(shuffledDeck(random), drawCount: drawCount);
  if (!winnable) return DealResult(state, false);
  for (var a = 0; a < attempts; a++) {
    if (solveKlondike(state, maxNodes: maxNodes)) {
      return DealResult(state, true);
    }
    state = KlondikeState.deal(shuffledDeck(random), drawCount: drawCount);
  }
  return DealResult(state, false);
}

class DealResult {
  const DealResult(this.state, this.proven);
  final KlondikeState state;

  /// True when the solver proved this deal can be won.
  final bool proven;
}

/// Solitaire difficulty presets (docs/SPEC.md, 4.3). [custom] keeps the Draw and Winnable switches.
enum SolitaireLevel {
  easy('Easy', 1, true, 3, 300),
  medium('Medium', 1, false, 3, 500),
  hard('Hard', 3, true, 1, 800),
  expert('Expert', 3, false, 0, 1200),
  custom('Custom', 1, true, 3, 500);

  const SolitaireLevel(
    this.label,
    this.drawCount,
    this.winnable,
    this.hints,
    this.winBonus,
  );

  final String label;

  /// Cards drawn at a time (a custom game takes its own value).
  final int drawCount;

  /// Whether the deal is one the solver proved winnable.
  final bool winnable;

  /// Hints per game (0 = none).
  final int hints;

  /// Points added to the score on a win.
  final int winBonus;

  /// The preset that matches the old menu choices (draw three, winnable deals).
  static SolitaireLevel fromLegacy({
    required bool draw3,
    required bool winnable,
  }) => switch ((draw3, winnable)) {
    (false, true) => easy,
    (false, false) => medium,
    (true, true) => hard,
    (true, false) => expert,
  };

  static SolitaireLevel? byName(String? name) {
    for (final l in values) {
      if (l.name == name) return l;
    }
    return null;
  }
}

/// Points a hint costs (the score never goes below 0).
const int solitaireHintCost = 10;

/// A suggested move and where to look: the source and target are named in [text] and shown by
/// the screen with a border (not colour alone).
class KlondikeHint {
  const KlondikeHint(this.move, this.text);
  final KlondikeMove move;
  final String text;
}

/// The best move now, or null when nothing useful exists. Priority: a move to a foundation; a
/// move that turns a face-down card; a king (or king-led run) to an empty column; another column
/// move; draw from the stock.
KlondikeHint? findKlondikeHint(KlondikeState s) {
  final moves = s.legalMoves();
  String top(int col, int i) => cardName(s.tableau[col][i]);

  for (final m in moves) {
    if (m.kind == MoveKind.wasteToFoundation) {
      return KlondikeHint(
        m,
        'Move ${cardName(s.waste.last)} from the waste to its foundation',
      );
    }
    if (m.kind == MoveKind.tableauToFoundation) {
      return KlondikeHint(
        m,
        'Move ${top(m.from, s.tableau[m.from].length - 1)} '
        'from column ${m.from + 1} to its foundation',
      );
    }
  }
  bool pointless(KlondikeMove m) {
    // A run that already sits on a card it could stack on gains nothing by moving.
    final t = s.tableau[m.from];
    final i = t.length - m.count;
    if (i <= s.down[m.from] || i == 0) return false;
    final below = t[i - 1];
    final c = t[i];
    return isRed(below) != isRed(c) && rankOf(below) == rankOf(c) + 1;
  }

  KlondikeHint colMove(KlondikeMove m, String why) {
    final t = s.tableau[m.from];
    return KlondikeHint(
      m,
      'Move ${cardName(t[t.length - m.count])} from column ${m.from + 1} '
      'to column ${m.to + 1}$why',
    );
  }

  for (final m in moves) {
    if (m.kind == MoveKind.tableauToTableau &&
        s.down[m.from] > 0 &&
        s.tableau[m.from].length - m.count == s.down[m.from]) {
      return colMove(m, ' to turn a face-down card');
    }
  }
  for (final m in moves) {
    if (m.kind == MoveKind.wasteToTableau &&
        rankOf(s.waste.last) == 13 &&
        s.tableau[m.to].isEmpty) {
      return KlondikeHint(
        m,
        'Move ${cardName(s.waste.last)} from the waste to empty column '
        '${m.to + 1}',
      );
    }
    if (m.kind == MoveKind.tableauToTableau &&
        s.tableau[m.to].isEmpty &&
        !pointless(m)) {
      return colMove(m, '');
    }
  }
  for (final m in moves) {
    if (m.kind == MoveKind.wasteToTableau) {
      return KlondikeHint(
        m,
        'Move ${cardName(s.waste.last)} from the waste to column ${m.to + 1}',
      );
    }
    if (m.kind == MoveKind.tableauToTableau && !pointless(m)) {
      return colMove(m, '');
    }
  }
  if (s.stock.isNotEmpty) {
    return const KlondikeHint(
      KlondikeMove(MoveKind.draw),
      'Draw from the stock',
    );
  }
  if (s.waste.isNotEmpty && s.recycles < 2) {
    return const KlondikeHint(
      KlondikeMove(MoveKind.draw),
      'Turn the waste over to draw again',
    );
  }
  return null;
}

/// A game with undo.
class KlondikeGame {
  KlondikeGame(
    this.state, {
    this.proven = false,
    this.winBonus = 500,
    this.hintLimit = 3,
  });
  KlondikeState state;
  final bool proven;

  /// Points added on a win (the level's bonus).
  final int winBonus;

  /// Hints allowed in this game.
  final int hintLimit;

  /// Hints taken so far (undo does not give one back).
  int hintsUsed = 0;

  /// Zen (M5): hints never run out. Set by the screen for the run.
  bool unlimitedHints = false;
  final List<KlondikeState> _undo = [];
  final List<int> _undoHints = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canHint => (unlimitedHints || hintsUsed < hintLimit) && !state.won;

  /// Takes a hint when one is left: costs [solitaireHintCost] points (never below 0). Returns the
  /// hint, or null when none is left or nothing useful exists (nothing is charged then).
  KlondikeHint? takeHint() {
    if (!canHint) return null;
    final h = findKlondikeHint(state);
    if (h == null) return null;
    hintsUsed++;
    state.score = max(0, state.score - solitaireHintCost);
    return h;
  }

  /// Plays [m] when legal. Returns whether it was played.
  bool play(KlondikeMove m) {
    if (state.won || !state.isLegal(m)) return false;
    _undo.add(state.copy());
    _undoHints.add(hintsUsed);
    state.apply(m);
    return true;
  }

  /// Takes back the last move (the move count stays, so undo is not a free retry for stars, and
  /// hint costs taken since stay paid).
  bool undo() {
    if (_undo.isEmpty) return false;
    final moves = state.moves;
    final paid = hintsUsed - _undoHints.removeLast();
    final restored = _undo.removeLast()..moves = moves;
    restored.score = max(0, restored.score - paid * solitaireHintCost);
    state = restored;
    return true;
  }

  /// Win score: the points plus the level's bonus.
  int get finalScore => state.score + winBonus;
}
