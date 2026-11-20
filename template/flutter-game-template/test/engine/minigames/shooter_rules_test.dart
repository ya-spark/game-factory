import 'dart:math';

import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

ContentItem mcq({int options = 4, int correct = 0}) => ContentItem({
  'id': 'm.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': 'e',
  'prompt': 'What is 3 × 4?',
  'options': [for (var i = 0; i < options; i++) 'o$i'],
  'correct': correct,
});

ContentItem category() => ContentItem({
  'id': 'c.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'category',
  'explanation': 'e',
  'prompt': 'Sort',
  'categories': ['Even', 'Odd'],
  'items': [
    {'text': '2', 'category': 'Even'},
    {'text': '7', 'category': 'Odd'},
    {'text': '10', 'category': 'Even'},
    {'text': '13', 'category': 'Odd'},
  ],
});

void main() {
  group('mcq', () {
    test(
      'the right answer is one target; the rest are wrong; at most the limit',
      () {
        final t = layoutTargets(mcq(), 3, Random(1))!;
        expect(t.length, 3);
        expect(t.where((x) => x.correct).length, 1);
        expect(t.firstWhere((x) => x.correct).label, 'o0');
        expect(layoutTargets(mcq(), 4, Random(1))!.length, 4);
        expect(layoutTargets(mcq(options: 2), 4, Random(1))!.length, 2);
      },
    );

    test('a different right answer is found', () {
      expect(
        layoutTargets(
          mcq(correct: 2),
          4,
          Random(2),
        )!.firstWhere((x) => x.correct).label,
        'o2',
      );
    });

    test('a multi-answer item cannot be played', () {
      final multi = ContentItem({
        ...mcq().json,
        'correct': [0, 1],
      });
      expect(layoutTargets(multi, 4, Random(1)), isNull);
      expect(shooterPlaysItem(multi), isFalse);
    });

    test('the prompt is the question', () {
      expect(shooterPrompt(mcq()), 'What is 3 × 4?');
    });
  });

  group('category', () {
    test('asks about one entry and targets are the groups', () {
      final c = category();
      final prompt = shooterPrompt(c);
      expect(prompt, startsWith('Shoot the group for "'));
      final entry = categoryEntry(c)!;
      expect(prompt, contains('"${entry['text']}"'));
      final t = layoutTargets(c, 4, Random(1))!;
      expect(t.map((x) => x.label).toSet(), {'Even', 'Odd'});
      expect(t.firstWhere((x) => x.correct).label, entry['category']);
    });

    test('the entry is the same every time for an item', () {
      final c = category();
      expect(categoryEntry(c), categoryEntry(c));
      expect(shooterPrompt(c), shooterPrompt(c));
    });
  });

  test('other formats are not played', () {
    final series = ContentItem({
      'id': 's.1',
      'seq': 1,
      'difficulty': 1,
      'type': 'series',
      'explanation': 'e',
      'prompt': 'p',
      'steps': ['1', '2', '3'],
    });
    expect(layoutTargets(series, 4, Random(1)), isNull);
  });

  test('settings: younger has no timer, older is timed, harder is tighter', () {
    expect(
      ShooterSettings.forLevel(const MiniGameLevel.younger())
          .secondsPerQuestion,
      0,
    );
    final o = ShooterSettings.forLevel(const MiniGameLevel.older());
    final h = ShooterSettings.forLevel(const MiniGameLevel.older(harder: true));
    expect(o.secondsPerQuestion, greaterThan(h.secondsPerQuestion));
    expect(h.swaySeconds, lessThan(o.swaySeconds));
  });
}
