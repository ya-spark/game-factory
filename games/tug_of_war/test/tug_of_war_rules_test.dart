import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_tug_of_war/tug_of_war.dart';

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
}
