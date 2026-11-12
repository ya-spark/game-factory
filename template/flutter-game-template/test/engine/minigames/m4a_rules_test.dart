import 'dart:math';

import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

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
  group('Tug of war rules', () {
    test('younger never pulls back and has no timer; older is timed', () {
      final y = TugSettings.forLevel(const MiniGameLevel.younger());
      final o = TugSettings.forLevel(const MiniGameLevel.older());
      final h = TugSettings.forLevel(const MiniGameLevel.older(harder: true));
      expect(y.secondsPerQuestion, 0);
      expect(y.pullsBack, isFalse);
      expect(o.pullsBack, isTrue);
      expect(h.secondsPerQuestion, lessThan(o.secondsPerQuestion));
      expect(h.reach, greaterThan(o.reach));
    });

    test(
      'right moves toward the child, wrong moves back, an end wins a round',
      () {
        final run = TugOfWarRun(const MiniGameLevel.older());
        run.answer(correct: false);
        expect(run.position, -1);
        run.answer(correct: true);
        run.answer(correct: true);
        expect(run.position, 1);
        for (var i = 0; i < 2; i++) {
          expect(run.answer(correct: true), TugRoundEnd.none);
        }
        expect(run.answer(correct: true), TugRoundEnd.won);
        expect(run.roundsWon, 1);
        expect(run.position, 0);
      },
    );

    test('losing a round resets the rope', () {
      final run = TugOfWarRun(const MiniGameLevel.older());
      TugRoundEnd last = TugRoundEnd.none;
      for (var i = 0; i < run.settings.reach; i++) {
        last = run.answer(correct: false);
      }
      expect(last, TugRoundEnd.lost);
      expect(run.roundsLost, 1);
      expect(run.position, 0);
    });

    test('younger wrong answers do not move the rope', () {
      final run = TugOfWarRun(const MiniGameLevel.younger());
      run.answer(correct: false);
      expect(run.position, 0);
    });

    test('layout: one right option, count respected, only mcq', () {
      final o = layoutTugOptions(mcq(), 3, Random(1))!;
      expect(o, hasLength(3));
      expect(o.where((x) => x.correct), hasLength(1));
      expect(o.firstWhere((x) => x.correct).label, 'b');
      expect(layoutTugOptions(mcq(), 9, Random(1)), hasLength(4));
      expect(layoutTugOptions(mcq(options: ['x']), 2, Random(1)), isNull);
      expect(
        layoutTugOptions(other({'type': 'numeric', 'answer': 3}), 2, Random(1)),
        isNull,
      );
    });
  });

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

  group('Flash review rules', () {
    test('every item type has a front and a back', () {
      final cases = <ContentItem, (String, String)>{
        mcq(): ('Pick', 'b'),
        other({'type': 'numeric', 'prompt': 'q', 'answer': 4.0, 'unit': 'cm'}):
            ('q', '4 cm'),
        other({
          'type': 'series',
          'prompt': 'Order',
          'steps': ['one', 'two'],
        }): (
          'Order',
          'one, then two',
        ),
        other({
          'type': 'pairs',
          'pairs': [
            {'left': 'cat', 'right': 'meow'},
            {'left': 'dog', 'right': 'woof'},
          ],
        }): (
          'Match each pair\ncat, dog',
          'cat goes with meow\ndog goes with woof',
        ),
        other({'type': 'word', 'answer': 'cat', 'hint': 'pet'}): (
          'Spell the word. Hint: pet',
          'cat',
        ),
        other({
          'type': 'category',
          'prompt': 'Sort',
          'categories': ['A', 'B'],
          'items': [
            {'text': 'x', 'category': 'A'},
            {'text': 'y', 'category': 'B'},
          ],
        }): (
          'Sort\nA, B',
          'x: A\ny: B',
        ),
        other({
          'type': 'cloze',
          'text': 'The {{1}} sat.',
          'gaps': {
            '1': ['cat', 'kitten'],
          },
        }): (
          'The ___ sat.',
          'The cat sat.',
        ),
      };
      cases.forEach((item, want) {
        expect(flashPrompt(item), want.$1, reason: item.type.name);
        expect(flashAnswer(item), want.$2, reason: item.type.name);
      });
    });

    test('the run counts known and not yet', () {
      final r = FlashReviewRun()
        ..mark(knew: true)
        ..mark(knew: false)
        ..mark(knew: true);
      expect((r.known, r.notYet, r.total), (2, 1, 3));
    });
  });
}
