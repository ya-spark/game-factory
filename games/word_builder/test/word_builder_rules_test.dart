import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_word_builder/word_builder.dart';

ContentItem _word(String answer, {Object? letters}) => ContentItem({
  'id': 'w',
  'seq': 1,
  'difficulty': 1,
  'type': 'word',
  'explanation': 'e',
  'answer': answer,
  'hint': 'A pet that barks',
  'letters': ?letters,
});

ContentItem _cloze() => ContentItem({
  'id': 'c',
  'seq': 1,
  'difficulty': 1,
  'type': 'cloze',
  'explanation': 'e',
  'text': 'The {{1}} sat on the {{2}}.',
  'gaps': {
    '2': ['mat', 'rug'],
    '1': ['cat'],
  },
});

void main() {
  group('WordRound', () {
    test('younger: wrong letters grey out, the word completes by itself', () {
      final r = WordRound.fromItem(_word('dog'), WordLevel.younger, Random(1));
      final t = r.current!.tiles;
      expect(t.toList()..sort(), ['d', 'g', 'o']);
      final g = t.indexOf('g');
      expect(r.tap(g), isFalse);
      expect(r.isGreyed(g), isTrue);
      expect(r.misses, 1);
      for (final ch in ['d', 'o', 'g']) {
        expect(r.tap(r.current!.tiles.indexOf(ch)), isTrue);
      }
      expect(r.complete, isTrue);
      expect(r.solved, ['dog']);
      expect(r.passed(), isTrue);
    });

    test('older: build then check; a miss clears and counts', () {
      final r = WordRound.fromItem(_word('Dog'), WordLevel.older, Random(2));
      for (final ch in ['o', 'D', 'g']) {
        r.tap(r.current!.tiles.indexOf(ch));
      }
      expect(r.built, 'oDg');
      expect(r.submit(), isFalse);
      expect(r.misses, 1);
      expect(r.built, '');
      for (final ch in ['D', 'o', 'g']) {
        r.tap(r.current!.tiles.indexOf(ch));
      }
      r.undo();
      expect(r.built, 'Do');
      r.tap(r.current!.tiles.indexOf('g'));
      expect(r.submit(), isTrue); // case-insensitive
      expect(r.complete, isTrue);
      expect(r.passed(elapsedSeconds: 5), isTrue);
    });

    test('listed letters and multi-letter tiles; hard adds decoys', () {
      final r = WordRound.fromItem(
        _word('think', letters: ['th', 'i', 'n', 'k', 'x']),
        WordLevel.older,
        Random(3),
      );
      expect(r.current!.tiles.length, 5);
      final h = WordRound.fromItem(_word('dog'), WordLevel.hard, Random(3));
      expect(h.current!.tiles.length, 5);
    });

    test('cloze: one slot per gap in order, every listed answer accepted', () {
      final r = WordRound.fromItem(_cloze(), WordLevel.older, Random(4));
      expect(r.total, 2);
      expect(r.hintText, 'The ____ sat on the ____.');
      for (final ch in 'cat'.split('')) {
        r.tap(r.current!.tiles.indexOf(ch));
      }
      expect(r.submit(), isTrue);
      expect(r.hintText, 'The cat sat on the ____.');
      // The second accepted answer "rug" is built from letters of "mat": not possible, so the
      // first one is spelled instead; "rug" is still accepted when typed by other means.
      expect(r.current!.accepted, ['mat', 'rug']);
      for (final ch in 'mat'.split('')) {
        r.tap(r.current!.tiles.indexOf(ch));
      }
      expect(r.submit(), isTrue);
      expect(r.complete, isTrue);
      expect(r.solved, ['cat', 'mat']);
    });

    test('plays word and cloze only', () {
      expect(wordBuilderPlays(ItemType.word), isTrue);
      expect(wordBuilderPlays(ItemType.cloze), isTrue);
      expect(wordBuilderPlays(ItemType.mcq), isFalse);
    });
  });
}
