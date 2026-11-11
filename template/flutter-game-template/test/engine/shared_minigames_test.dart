import 'dart:math';

import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

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
  group('Door runner rules', () {
    test('settings: younger is gentle, older is timed, harder is tighter', () {
      final y = DoorRunnerSettings.forLevel(const MiniGameLevel.younger());
      final o = DoorRunnerSettings.forLevel(const MiniGameLevel.older());
      final h = DoorRunnerSettings.forLevel(
        const MiniGameLevel.older(harder: true),
      );
      expect(y.secondsPerQuestion, 0);
      expect(y.retry, isTrue);
      expect(y.doors, lessThan(o.doors));
      expect(o.secondsPerQuestion, greaterThan(0));
      expect(o.retry, isFalse);
      expect(h.secondsPerQuestion, lessThan(o.secondsPerQuestion));
      expect(h.runSeconds, lessThan(o.runSeconds));
      expect(h.doors, greaterThan(o.doors));
    });

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

  group('Registry', () {
    final door = MiniGame(
      id: doorRunnerId,
      title: 'Door runner',
      itemTypes: const {ItemType.mcq},
      build: (_) => Object(),
      modes: const {MiniGameMode.game},
    );
    final balloon = MiniGame(
      id: balloonPopId,
      title: 'Balloon pop',
      itemTypes: const {ItemType.mcq, ItemType.numeric},
      build: (_) => Object(),
      modes: const {MiniGameMode.game},
    );
    final reg = MiniGameRegistry([RegistryEntry(door), RegistryEntry(balloon)]);

    List<String> ids(
      List<PoolItem> open, {
      MiniGameMode m = MiniGameMode.game,
    }) => [
      for (final o in reg.offers(
        open: open,
        subject: 'm',
        year: 3,
        mode: m,
        unlocked: {},
      ))
        o.game.id,
    ];

    test('games appear only with enough open items', () {
      expect(
        ids([for (var i = 0; i < 3; i++) pool('a$i', ItemType.mcq)]),
        isEmpty,
      );
      expect(ids([for (var i = 0; i < 4; i++) pool('a$i', ItemType.mcq)]), [
        doorRunnerId,
        balloonPopId,
      ]);
    });

    test('numeric items count for balloon pop only', () {
      final open = [for (var i = 0; i < 4; i++) pool('n$i', ItemType.numeric)];
      expect(ids(open), [balloonPopId]);
    });

    test('Game mode only', () {
      final open = [for (var i = 0; i < 4; i++) pool('a$i', ItemType.mcq)];
      expect(ids(open, m: MiniGameMode.study), isEmpty);
    });
  });
}
