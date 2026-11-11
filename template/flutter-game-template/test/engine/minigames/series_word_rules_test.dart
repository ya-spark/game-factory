import 'dart:math';

import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

ContentItem _series(List<String> steps) => ContentItem({
  'id': 's',
  'seq': 1,
  'difficulty': 1,
  'type': 'series',
  'explanation': 'e',
  'prompt': 'Order them',
  'steps': steps,
});

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
  group('SeriesRound', () {
    final steps = ['1', '2', '3', '4', '5', '6', '7', '8'];

    test('level from the year; tiles are capped and never start in order', () {
      expect(SeriesLevel.forYear(1), SeriesLevel.younger);
      expect(SeriesLevel.forYear(4), SeriesLevel.older);
      expect(SeriesLevel.forYear(6, hard: true), SeriesLevel.hard);
      for (var seed = 0; seed < 20; seed++) {
        final r = SeriesRound.fromItem(
          _series(steps),
          SeriesLevel.younger,
          Random(seed),
        );
        expect(r.total, 5);
        expect(r.tiles.join(','), isNot(r.steps.join(',')));
        expect(r.tiles.toList()..sort(), r.steps.toList()..sort());
      }
    });

    test('tapping in order completes; a wrong tile is greyed (younger)', () {
      final r = SeriesRound.fromItem(
        _series(['a', 'b', 'c']),
        SeriesLevel.younger,
        Random(1),
      );
      final wrong = r.tiles.indexOf('b');
      expect(r.place(wrong), isFalse);
      expect(r.isGreyed(wrong), isTrue);
      expect(r.misses, 1);
      expect(r.place(wrong), isFalse); // greyed: ignored, no extra miss
      expect(r.misses, 1);
      for (final s in ['a', 'b', 'c']) {
        expect(r.place(r.tiles.indexOf(s)), isTrue);
      }
      expect(r.complete, isTrue);
      expect(r.passed(), isTrue); // younger never fails
    });

    test('older level fails on too many misses or time', () {
      SeriesRound mk() => SeriesRound.fromItem(
        _series(['a', 'b', 'c', 'd']),
        SeriesLevel.older,
        Random(2),
      );
      var r = mk();
      for (final s in ['a', 'b', 'c', 'd']) {
        r.place(r.tiles.indexOf(s));
      }
      expect(r.passed(elapsedSeconds: 3), isTrue);
      expect(r.passed(elapsedSeconds: 999), isFalse);
      r = mk();
      final bad = r.tiles.indexOf('d');
      for (var i = 0; i < 3; i++) {
        r.place(bad);
      }
      expect(r.isGreyed(bad), isFalse); // not greyed at the older level
      for (final s in ['a', 'b', 'c', 'd']) {
        r.place(r.tiles.indexOf(s));
      }
      expect(r.passed(elapsedSeconds: 3), isFalse);
    });

    test('repeated step texts are interchangeable', () {
      final r = SeriesRound.fromItem(
        _series(['go', 'go', 'stop']),
        SeriesLevel.older,
        Random(3),
      );
      expect(r.place(r.tiles.indexOf('stop')), isFalse);
      var tile = r.tiles.indexOf('go');
      expect(r.place(tile), isTrue);
      tile = r.tiles.indexWhere((t) => t == 'go') == tile
          ? r.tiles.lastIndexOf('go')
          : r.tiles.indexOf('go');
      expect(r.place(tile), isTrue);
    });

    test('plays only series', () {
      expect(seriesBuilderPlays(ItemType.series), isTrue);
      expect(seriesBuilderPlays(ItemType.word), isFalse);
    });
  });

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
