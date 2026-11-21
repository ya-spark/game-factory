import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_sort_bins/sort_bins.dart';

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

void main() {
  group('SortRound', () {
    SortRound round(SortLevel l, [int seed = 1]) =>
        SortRound.fromItem(categoryItem(), l, Random(seed));

    test('younger has 2 bins and only their items', () {
      final r = round(SortLevel.younger);
      expect(r.bins.length, 2);
      expect(r.total, 6);
      expect(r.timeLimit, isNull);
    });

    test('older has 3 bins, hard has 4', () {
      expect(round(SortLevel.older).bins.length, 3);
      final h = round(SortLevel.hard);
      expect(h.bins.length, 4);
      expect(h.total, 12);
    });

    test('a wrong drop keeps the item; the right drop moves on', () {
      final r = round(SortLevel.older, 4);
      final right = r.current!.bin;
      expect(r.drop((right + 1) % r.bins.length), isFalse);
      expect(r.index, 0);
      expect(r.misses, 1);
      expect(r.drop(right), isTrue);
      expect(r.index, 1);
    });

    test('passing: younger always, older by misses and time', () {
      SortRound play(SortLevel l, int wrongs) {
        final r = round(l, 5);
        for (var k = 0; k < wrongs; k++) {
          r.drop((r.current!.bin + 1) % r.bins.length);
        }
        while (!r.complete) {
          r.drop(r.current!.bin);
        }
        return r;
      }

      expect(play(SortLevel.younger, 20).passed(), isTrue);
      expect(play(SortLevel.older, 1).passed(elapsedSeconds: 10), isTrue);
      expect(play(SortLevel.older, 6).passed(elapsedSeconds: 10), isFalse);
      expect(play(SortLevel.older, 0).passed(elapsedSeconds: 81), isFalse);
    });
  });
}
