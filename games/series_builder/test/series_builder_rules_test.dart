import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_series_builder/series_builder.dart';

ContentItem _series(List<String> steps) => ContentItem({
  'id': 's',
  'seq': 1,
  'difficulty': 1,
  'type': 'series',
  'explanation': 'e',
  'prompt': 'Order them',
  'steps': steps,
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
}
