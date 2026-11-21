import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/engine/engine.dart';
import 'package:game_door_runner/src/rules/door_runner_rules.dart';

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

void main() {
  group('Door runner door choice and score', () {
    test('layout has exactly one correct door and no repeats', () {
      for (var seed = 0; seed < 20; seed++) {
        final d = layoutDoors(mcq(), 3, Random(seed))!;
        expect(d, hasLength(3));
        expect(d.where((x) => x.correct), hasLength(1));
        expect(d.firstWhere((x) => x.correct).label, 'b');
        expect({for (final x in d) x.label}, hasLength(3));
      }
    });

    test('layout is repeatable for one seed and varies between seeds', () {
      List<String> labels(int s) => [
        for (final d in layoutDoors(mcq(), 4, Random(s))!) d.label,
      ];
      expect(labels(1), labels(1));
      expect(
        {for (var s = 0; s < 20; s++) labels(s).join()}.length,
        greaterThan(1),
      );
    });

    test('an item with several correct options shows one of them', () {
      final d = layoutDoors(mcq(correct: [0, 2]), 3, Random(3))!;
      expect(d.where((x) => x.correct), hasLength(1));
      expect(['a', 'c'], contains(d.firstWhere((x) => x.correct).label));
    });

    test('fewer options than doors: uses what there is; one option: null', () {
      expect(layoutDoors(mcq(options: ['x', 'y']), 4, Random(1)), hasLength(2));
      expect(
        layoutDoors(mcq(correct: 0, options: ['x']), 3, Random(1)),
        isNull,
      );
    });

    test(
      'score and streak: bonus for older only, a miss resets the streak',
      () {
        final young = DoorRunnerRun(const MiniGameLevel.younger())
          ..right()
          ..right();
        expect(young.score, 20);
        final old = DoorRunnerRun(const MiniGameLevel.older())
          ..right()
          ..right()
          ..right();
        expect(old.score, 10 + 12 + 14);
        old.miss();
        expect(old.streak, 0);
        expect(old.bestStreak, 3);
        expect(old.score, 36); // never taken away
        expect(old.passed, 3);
      },
    );
  });
}
