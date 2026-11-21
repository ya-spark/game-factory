import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_balloon_pop/balloon_pop.dart';

ContentItem mcq({Object correct = 1, List<String>? options}) => ContentItem({
  'id': 'a.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': 'e',
  'prompt': 'p',
  'options': options ?? ['a', 'b', 'c', 'd'],
  'correct': correct,
});

ContentItem numeric(Object answer, {Object tolerance = 0}) => ContentItem({
  'id': 'n.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'numeric',
  'explanation': 'e',
  'prompt': 'p',
  'answer': answer,
  'tolerance': tolerance,
});

PoolItem pool(String id, ItemType type) => PoolItem(
  packId: 'p',
  subject: 'm',
  year: 3,
  topic: 't',
  item: ContentItem({
    'id': id,
    'seq': 1,
    'difficulty': 1,
    'type': type.name,
    'explanation': 'e',
    'prompt': 'p',
    'options': ['a', 'b'],
    'correct': 0,
    'answer': 4,
  }),
);

void main() {
  group('Balloon pop rules', () {
    test('settings by level', () {
      final y = BalloonPopSettings.forLevel(const MiniGameLevel.younger());
      final o = BalloonPopSettings.forLevel(const MiniGameLevel.older());
      final h = BalloonPopSettings.forLevel(
        const MiniGameLevel.older(harder: true),
      );
      expect(y.large, isTrue);
      expect(y.secondsPerQuestion, 0);
      expect(o.balloons, greaterThan(y.balloons));
      expect(o.secondsPerQuestion, greaterThan(0));
      expect(h.balloons, greaterThan(o.balloons));
      expect(h.riseSeconds, lessThan(o.riseSeconds));
    });

    test('mcq balloons carry the options with one correct', () {
      final b = layoutBalloons(mcq(), 3, Random(2))!;
      expect(b, hasLength(3));
      expect(b.where((x) => x.correct).single.label, 'b');
    });

    test('numeric balloons: the answer and distinct wrong numbers', () {
      for (var seed = 0; seed < 30; seed++) {
        final b = layoutBalloons(numeric(7), 6, Random(seed))!;
        expect(b, hasLength(6));
        expect(b.where((x) => x.correct).single.label, '7');
        expect({for (final x in b) x.label}, hasLength(6));
      }
    });

    test('numeric wrong balloons never fall inside the tolerance', () {
      final b = layoutBalloons(numeric(10, tolerance: 1), 5, Random(4))!;
      for (final x in b.where((x) => !x.correct)) {
        expect((double.parse(x.label) - 10).abs(), greaterThan(1));
      }
    });

    test('numeric answers stay non-negative and decimals are formatted', () {
      final b = layoutBalloons(numeric(1), 5, Random(5))!;
      expect(b.every((x) => double.parse(x.label) >= 0), isTrue);
      final d = layoutBalloons(numeric(0.5), 4, Random(6))!;
      expect(d.where((x) => x.correct).single.label, '0.5');
      expect(formatNumber(3), '3');
      expect(formatNumber(2.5), '2.5');
    });

    test('other item types cannot be laid out; a text answer is read', () {
      final cloze = ContentItem({...mcq().json, 'type': 'cloze'});
      expect(layoutBalloons(cloze, 3, Random(1)), isNull);
      expect(
        layoutBalloons(numeric('1,000'), 3, Random(1))!.first.label,
        isNotEmpty,
      );
    });

    test('lanes are inside the screen and heights wrap', () {
      for (var i = 0; i < 5; i++) {
        final l = balloonLane(i, 5);
        expect(l > 0 && l < 1, isTrue);
        for (final t in [0.0, 0.3, 0.99]) {
          final h = balloonHeight(i, 5, t);
          expect(h >= 0 && h < 1, isTrue);
        }
      }
      expect(balloonHeight(0, 4, 0.5), closeTo(0.5, 1e-9));
    });
  });
}
