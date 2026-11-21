/// Two players taking turns on one board. Pure Dart, no Flutter. The board is
/// [MemoryMatchBoard]; this adds whose turn it is, the pairs each player found and the winner
/// of a board and of the whole round. Nothing here touches a quiz session: a two-player round
/// records no progress.
library;

import 'memory_match_rules.dart';

/// The other player (1 or 2).
int otherPlayer(int p) => p == 1 ? 2 : 1;

/// One board played by turns. A match keeps the turn and scores the pair; a mismatch stays face
/// up until [settleMismatch], which turns the cards back and passes the turn.
class MemoryTurnBoard {
  MemoryTurnBoard(this.board, {this.starter = 1}) : player = starter;

  final MemoryMatchBoard board;

  /// The player who had the first turn.
  final int starter;

  /// Whose turn it is now (1 or 2).
  int player;

  final Map<int, int> _pairs = {1: 0, 2: 0};
  final Map<int, int> _owner = {};

  /// Pairs found by [p].
  int pairsOf(int p) => _pairs[p]!;

  /// The player who matched card [i], or null (face down or not matched).
  int? ownerOf(int i) => _owner[i];

  bool get complete => board.complete;

  /// A mismatch is face up and waits for [settleMismatch]; no card can be turned meanwhile.
  bool get waitingToSettle => board.waitingToHide;

  /// 1 or 2, or 0 for a draw; null while the board is not finished.
  int? get winner {
    if (!complete) return null;
    final a = _pairs[1]!, b = _pairs[2]!;
    return a == b ? 0 : (a > b ? 1 : 2);
  }

  /// The active player turns card [i].
  FlipOutcome flip(int i) {
    final before = board.matched;
    final o = board.flip(i);
    if (o == FlipOutcome.match) {
      _pairs[player] = _pairs[player]! + 1;
      for (final c in board.matched) {
        if (!before.contains(c)) _owner[c] = player;
      }
    }
    return o;
  }

  /// Turns a mismatched pair back and passes the turn. No effect when no mismatch is showing.
  void settleMismatch() {
    if (!board.waitingToHide) return;
    board.hideMismatch();
    player = otherPlayer(player);
  }
}

/// A whole round: a number of boards, the starting player alternating, boards and pairs counted.
class MemoryTurnsMatch {
  MemoryTurnsMatch({required this.boardCount, this.firstStarter = 1});

  final int boardCount;

  /// Who starts the first board (Play again swaps it).
  final int firstStarter;

  final Map<int, int> _boardsWon = {1: 0, 2: 0};
  final Map<int, int> _pairs = {1: 0, 2: 0};
  int _played = 0;

  int get played => _played;
  bool get over => _played >= boardCount;
  int boardsWonBy(int p) => _boardsWon[p]!;
  int pairsBy(int p) => _pairs[p]!;

  /// Who starts board [index] (0 based): the starter, then the other player, and so on.
  int starterFor(int index) =>
      index.isEven ? firstStarter : otherPlayer(firstStarter);

  /// Adds a finished board to the tally. A drawn board counts for nobody.
  void record(MemoryTurnBoard b) {
    assert(b.complete);
    _played++;
    _pairs[1] = _pairs[1]! + b.pairsOf(1);
    _pairs[2] = _pairs[2]! + b.pairsOf(2);
    final w = b.winner;
    if (w == 1 || w == 2) _boardsWon[w!] = _boardsWon[w]! + 1;
  }

  /// 1 or 2, or 0 for a draw: most boards won, then most pairs. Null until the round is over.
  int? get winner {
    if (!over) return null;
    final a = _boardsWon[1]!, b = _boardsWon[2]!;
    if (a != b) return a > b ? 1 : 2;
    final pa = _pairs[1]!, pb = _pairs[2]!;
    if (pa != pb) return pa > pb ? 1 : 2;
    return 0;
  }
}
