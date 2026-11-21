import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_memory_match/memory_match.dart';

ContentItem pairsItem(int n) => ContentItem({
  'id': 'm.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'pairs',
  'explanation': 'e',
  'prompt': 'Match',
  'pairs': [
    for (var k = 0; k < n; k++) {'left': 'L$k', 'right': 'R$k'},
  ],
});

MemoryTurnBoard board({int pairs = 3, int starter = 1}) => MemoryTurnBoard(
  MemoryMatchBoard.fromItem(pairsItem(pairs), MatchLevel.older, Random(1)),
  starter: starter,
);

/// The two card indexes of pair [p].
List<int> pairIdx(MemoryMatchBoard b, int p) => [
  for (var i = 0; i < b.cards.length; i++)
    if (b.cards[i].pairIndex == p) i,
];

/// Two cards of different pairs.
(int, int) mismatchIdx(MemoryMatchBoard b) {
  final a = pairIdx(b, 0)[0], c = pairIdx(b, 1)[0];
  return (a, c);
}

void main() {
  group('a board played by turns', () {
    test('the starter has the first turn', () {
      expect(board().player, 1);
      expect(board(starter: 2).player, 2);
    });

    test('a match scores for the active player, who keeps the turn', () {
      final t = board();
      final idx = pairIdx(t.board, 0);
      expect(t.flip(idx[0]), FlipOutcome.firstFlip);
      expect(t.flip(idx[1]), FlipOutcome.match);
      expect(t.pairsOf(1), 1);
      expect(t.pairsOf(2), 0);
      expect(t.player, 1);
      expect(t.ownerOf(idx[0]), 1);
      expect(t.ownerOf(idx[1]), 1);
    });

    test('a mismatch waits face up, then turns back and passes the turn', () {
      final t = board();
      final (a, c) = mismatchIdx(t.board);
      t.flip(a);
      expect(t.flip(c), FlipOutcome.mismatch);
      expect(t.waitingToSettle, isTrue);
      expect(t.player, 1); // not yet
      // no card can be turned while the mismatch shows
      final other = [
        for (var i = 0; i < t.board.cards.length; i++)
          if (i != a && i != c) i,
      ].first;
      expect(t.flip(other), FlipOutcome.ignored);
      t.settleMismatch();
      expect(t.waitingToSettle, isFalse);
      expect(t.board.faceUp, isEmpty);
      expect(t.player, 2);
    });

    test('settling with nothing showing changes nothing', () {
      final t = board();
      t.settleMismatch();
      expect(t.player, 1);
    });

    test(
      'pairs go to whoever matched them; the winner is the one with more',
      () {
        final t = board(pairs: 3);
        for (final p in [0, 1]) {
          final i = pairIdx(t.board, p);
          t.flip(i[0]);
          t.flip(i[1]); // player 1 takes two pairs
        }
        expect(t.winner, isNull);
        // player 1 mismatches, player 2 takes the last pair
        final rest = pairIdx(t.board, 2);
        t.flip(rest[0]);
        t.flip(rest[1]);
        expect(t.complete, isTrue);
        expect(t.pairsOf(1), 3);
        expect(t.winner, 1);
      },
    );

    test('player 2 wins a board by finding more', () {
      final t = board(pairs: 3);
      final (a, c) = mismatchIdx(t.board);
      t.flip(a);
      t.flip(c);
      t.settleMismatch(); // now player 2
      for (final p in [0, 1, 2]) {
        final i = pairIdx(t.board, p);
        t.flip(i[0]);
        t.flip(i[1]);
      }
      expect(t.winner, 2);
      expect(t.pairsOf(2), 3);
    });

    test('an even split is a draw', () {
      final t = board(pairs: 6);
      void take(int p) {
        final i = pairIdx(t.board, p);
        t.flip(i[0]);
        t.flip(i[1]);
      }

      for (final p in [0, 1, 2]) {
        take(p); // player 1 keeps the turn on every match
      }
      // a mismatch of pairs 3 and 4 passes the turn
      t.flip(pairIdx(t.board, 3)[0]);
      t.flip(pairIdx(t.board, 4)[0]);
      t.settleMismatch();
      expect(t.player, 2);
      for (final p in [3, 4, 5]) {
        take(p);
      }
      expect(t.complete, isTrue);
      expect(t.pairsOf(1), 3);
      expect(t.pairsOf(2), 3);
      expect(t.winner, 0);
    });
  });

  group('a round of boards', () {
    MemoryTurnBoard finished(MemoryTurnsMatch m, int index, int winner) {
      final t = board(pairs: 3, starter: m.starterFor(index));
      if (t.player != winner) {
        final (a, c) = mismatchIdx(t.board);
        t.flip(a);
        t.flip(c);
        t.settleMismatch();
      }
      for (var p = 0; p < 3; p++) {
        final i = pairIdx(t.board, p);
        t.flip(i[0]);
        t.flip(i[1]);
      }
      return t;
    }

    test('the starting player alternates and Play again swaps it', () {
      final m = MemoryTurnsMatch(boardCount: 3);
      expect([for (var i = 0; i < 3; i++) m.starterFor(i)], [1, 2, 1]);
      final swapped = MemoryTurnsMatch(boardCount: 3, firstStarter: 2);
      expect([for (var i = 0; i < 3; i++) swapped.starterFor(i)], [2, 1, 2]);
    });

    test('most boards won wins the round', () {
      final m = MemoryTurnsMatch(boardCount: 3);
      expect(m.winner, isNull);
      m.record(finished(m, 0, 1));
      m.record(finished(m, 1, 1));
      expect(m.over, isFalse);
      m.record(finished(m, 2, 2));
      expect(m.over, isTrue);
      expect(m.boardsWonBy(1), 2);
      expect(m.winner, 1);
    });

    test('equal boards are decided by total pairs, then a draw', () {
      final m = MemoryTurnsMatch(boardCount: 2);
      m.record(finished(m, 0, 1)); // p1 takes all 3 pairs
      m.record(finished(m, 1, 2)); // p2 takes all 3 pairs
      expect(m.boardsWonBy(1), 1);
      expect(m.boardsWonBy(2), 1);
      expect(m.pairsBy(1), 3);
      expect(m.pairsBy(2), 3);
      expect(m.winner, 0);
    });
  });
}
