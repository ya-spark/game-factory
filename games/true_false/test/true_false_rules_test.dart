import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_true_false/true_false.dart';

ContentItem mcq({
  Object correct = 1,
  List<String> options = const ['a', 'b', 'c', 'd'],
}) => ContentItem({
  'id': 'a.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': 'e',
  'prompt': 'Pick',
  'options': options,
  'correct': correct,
});

ContentItem other(Map<String, dynamic> j) => ContentItem({
  'id': 'o.1',
  'seq': 1,
  'difficulty': 1,
  'explanation': 'e',
  ...j,
});

void main() {
  group('True or false rules', () {
    test('settings: no timer for younger, harder is quicker', () {
      expect(
        TrueFalseSettings.forLevel(const MiniGameLevel.younger())
            .secondsPerQuestion,
        0,
      );
      final o = TrueFalseSettings.forLevel(const MiniGameLevel.older());
      final h = TrueFalseSettings.forLevel(
        const MiniGameLevel.older(harder: true),
      );
      expect(h.secondsPerQuestion, lessThan(o.secondsPerQuestion));
    });

    test('a True/False item keeps its prompt and answer', () {
      final item = mcq(options: ['True', 'False'], correct: 1);
      expect(isTrueFalseItem(item), isTrue);
      final s = buildStatement(item, Random(1))!;
      expect(s.text, 'Pick');
      expect(s.isTrue, isFalse);
    });

    test('other mcq items give true statements with the right answer and false with a wrong one', () {
      var sawTrue = false;
      var sawFalse = false;
      for (var seed = 0; seed < 30; seed++) {
        final s = buildStatement(mcq(), Random(seed))!;
        expect(s.text.startsWith('Pick Answer: '), isTrue);
        final shown = s.text.substring('Pick Answer: '.length);
        expect(s.isTrue, shown == 'b');
        sawTrue |= s.isTrue;
        sawFalse |= !s.isTrue;
      }
      expect(sawTrue && sawFalse, isTrue);
    });

    test('items that cannot be used give null', () {
      expect(buildStatement(mcq(options: ['x']), Random(1)), isNull);
      expect(
        buildStatement(other({'type': 'word', 'answer': 'cat'}), Random(1)),
        isNull,
      );
    });
  });
}
