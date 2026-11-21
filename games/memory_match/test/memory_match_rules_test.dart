import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_memory_match/memory_match.dart';

ContentItem pairsItem(int n) => ContentItem({
  'id': 'p.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'pairs',
  'explanation': 'x',
  'prompt': 'Match them',
  'pairs': [
    for (var i = 0; i < n; i++) {'left': 'L$i', 'right': 'R$i'},
  ],
});

ContentItem categoryItem() => ContentItem({
  'id': 'c.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'category',
  'explanation': 'x',
  'prompt': 'Sort',
  'categories': ['A', 'B', 'C', 'D'],
  'items': [
    for (final c in ['A', 'B', 'C', 'D'])
      for (var i = 0; i < 3; i++) {'text': '$c$i', 'category': c},
  ],
});

MemoryMatchBoard board(int pairs, MatchLevel l, [int seed = 1]) =>
    MemoryMatchBoard.fromItem(pairsItem(pairs), l, Random(seed));

/// Flips [wrong] mismatches, then solves every pair.
void solve(MemoryMatchBoard b, {int wrong = 0}) {
  for (var k = 0; k < wrong; k++) {
    b.flip(0);
    b.flip(b.cards.indexWhere((c) => c.pairIndex != b.cards[0].pairIndex));
    b.hideMismatch();
  }
  for (var p = 0; p < b.pairCount; p++) {
    final idx = [
      for (var i = 0; i < b.cards.length; i++)
        if (b.cards[i].pairIndex == p) i,
    ];
    b.flip(idx[0]);
    b.flip(idx[1]);
  }
}

void main() {
  group('MemoryMatchBoard', () {
    test('caps pairs by level and doubles them into cards', () {
      final y = board(8, MatchLevel.younger);
      expect(y.pairCount, 3);
      expect(y.cards.length, 6);
      expect(y.columns, 2);
      expect(board(8, MatchLevel.hard).cards.length, 16);
    });

    test('a match stays up, a mismatch hides on request', () {
      final b = board(3, MatchLevel.older, 2);
      final mate = b.cards.indexWhere(
        (c) => c.pairIndex == b.cards[0].pairIndex && c != b.cards[0],
      );
      expect(b.flip(0), FlipOutcome.firstFlip);
      expect(b.flip(0), FlipOutcome.ignored);
      expect(b.flip(mate), FlipOutcome.match);
      expect(b.matched.length, 2);
      final a = b.cards.indexWhere((c) => c.pairIndex != b.cards[0].pairIndex);
      final other = b.cards.indexWhere(
        (c) =>
            c.pairIndex != b.cards[a].pairIndex &&
            c.pairIndex != b.cards[0].pairIndex,
      );
      b.flip(a);
      expect(b.flip(other), FlipOutcome.mismatch);
      expect(b.flip(0), FlipOutcome.ignored);
      expect(b.misses, 1);
      b.hideMismatch();
      expect(b.faceUp, isEmpty);
    });

    test('younger never fails; older fails on many misses or time', () {
      final y = board(3, MatchLevel.younger, 3);
      solve(y, wrong: 9);
      expect(y.complete, isTrue);
      expect(y.passed(), isTrue);
      expect(y.timeLimit, isNull);

      final bad = board(3, MatchLevel.older, 3);
      solve(bad, wrong: 7);
      expect(bad.passed(elapsedSeconds: 1), isFalse);

      final ok = board(3, MatchLevel.older, 3);
      solve(ok, wrong: 2);
      expect(ok.passed(elapsedSeconds: 10), isTrue);
      expect(ok.passed(elapsedSeconds: 61), isFalse);
    });

    test('forYear splits at year 2', () {
      expect(MatchLevel.forYear(2), MatchLevel.younger);
      expect(MatchLevel.forYear(4), MatchLevel.older);
      expect(MatchLevel.forYear(4, hard: true), MatchLevel.hard);
    });
  });
}
