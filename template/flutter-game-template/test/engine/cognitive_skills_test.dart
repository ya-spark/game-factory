import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

GameStats withRuns(Map<String, List<(int day, int score)>> runs) {
  var book = const GameStats();
  final all = <(String, int, int)>[
    for (final e in runs.entries)
      for (final r in e.value) (e.key, r.$1, r.$2),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  for (final r in all) {
    book = book
        .record(RunReport(gameId: r.$1, score: r.$3, seconds: 30), r.$2)
        .book;
  }
  return book;
}

const stars = <String, List<int>?>{
  'sudoku': [100, 400, 1000],
  'solitaire': [100, 400, 1000],
  'block_puzzle': [500, 2000, 5000],
  'mahjong': [100, 400, 1000],
  'merge': [100, 400, 1000],
  'wingy': [10, 25, 50],
};

void main() {
  group('levels', () {
    test('thresholds ascend, start at a quarter of the first star score and end above the last', () {
      final t = levelThresholds([100, 400, 1000]);
      expect(t.length, skillLevels);
      expect(t.first, 25);
      expect(t[2], 100);
      expect(t[4], 400);
      expect(t[6], 1000);
      expect(t.last, 1500);
      for (var i = 1; i < t.length; i++) {
        expect(t[i], greaterThan(t[i - 1]));
      }
    });

    test('tiny scales still ascend', () {
      final t = levelThresholds([2, 3, 4]);
      for (var i = 1; i < t.length; i++) {
        expect(t[i], greaterThan(t[i - 1]));
      }
      expect(t.first, greaterThanOrEqualTo(1));
    });

    test('a game with no star scores gets a plain ladder', () {
      expect(levelThresholds(null).length, skillLevels);
      expect(levelThresholds(const [1]).length, skillLevels);
    });

    test('a score reaches the number of thresholds it meets', () {
      final t = levelThresholds([100, 400, 1000]);
      expect(levelFor(0, t), 0);
      expect(levelFor(24, t), 0);
      expect(levelFor(25, t), 1);
      expect(levelFor(100, t), 3);
      expect(levelFor(1000, t), 7);
      expect(levelFor(1500, t), skillLevels);
      expect(levelFor(99999, t), skillLevels);
    });
  });

  group('skills', () {
    test('every standalone game of the hubs is mapped to a skill', () {
      for (final id in [
        'block_puzzle',
        'blockfall',
        'sudoku',
        'solitaire',
        'ball_sort',
        'mahjong',
        'merge',
        'wingy',
        'snake',
        'bricks',
        'stack',
        'runner',
      ]) {
        expect(gameSkill.containsKey(id), isTrue, reason: id);
      }
    });

    test('a skill takes the highest level of its games and lists them', () {
      final book = withRuns({
        'sudoku': [(1, 120)],
        'solitaire': [(2, 450)],
      });
      final s = MindSkills.summaries(book, stars);
      final logic = s.firstWhere((x) => x.skill == CognitiveSkill.logic);
      expect(logic.gameIds, ['sudoku', 'solitaire']);
      expect(
        logic.level,
        5,
        reason: '450 reaches 5 thresholds of [25,50,100,250,400,700,1000,1500]',
      );
      expect(logic.plays, 2);
      final memory = s.firstWhere((x) => x.skill == CognitiveSkill.memory);
      expect(memory.level, 0);
    });

    test('a skill with no available game is left out', () {
      final s = MindSkills.summaries(const GameStats(), {
        'sudoku': stars['sudoku'],
      });
      expect(s.map((x) => x.skill), [CognitiveSkill.logic]);
    });

    test('the trend compares the latest three runs with the three before', () {
      final up = withRuns({
        'sudoku': [(1, 100), (2, 100), (3, 100), (4, 150), (5, 150), (6, 150)],
      });
      final s = MindSkills.summaries(up, {'sudoku': stars['sudoku']}).single;
      expect(s.trendPercent, 50);
      expect(s.trendText, contains('up 50%'));
      final down = withRuns({
        'sudoku': [(1, 200), (2, 200), (3, 200), (4, 100), (5, 100), (6, 100)],
      });
      expect(
        MindSkills.summaries(down, {
          'sudoku': stars['sudoku'],
        }).single.trendPercent,
        -50,
      );
    });

    test('too few runs: no trend and no text', () {
      final few = withRuns({
        'sudoku': [(1, 100), (2, 150), (3, 200)],
      });
      final s = MindSkills.summaries(few, {'sudoku': stars['sudoku']}).single;
      expect(s.trendPercent, isNull);
      expect(s.trendText, isNull);
    });

    test('the wording makes no health claim', () {
      for (final s in CognitiveSkill.values) {
        final text =
            '${s.label} Your ${s.label} scores are up 5% over your last few games.'
                .toLowerCase();
        for (final banned in [
          'prevent',
          'cure',
          'treat',
          'decline',
          'dementia',
          'brain age',
        ]) {
          expect(text.contains(banned), isFalse, reason: '${s.label}: $banned');
        }
      }
    });
  });

  group('daily workout', () {
    final ember = [
      'block_puzzle',
      'blockfall',
      'sudoku',
      'solitaire',
      'ball_sort',
      'mahjong',
      'merge',
    ];

    test('one game from each of four different skills', () {
      final w = DailyWorkout.plan(
        const GameStats(),
        today: 100,
        gameIds: ember,
      );
      expect(w.items.length, 4);
      expect({for (final i in w.items) i.skill}.length, 4);
      expect(w.complete, isFalse);
      expect(w.next, isNotNull);
    });

    test('the same all day, whatever is played today', () {
      final before = DailyWorkout.plan(
        const GameStats(),
        today: 100,
        gameIds: ember,
      );
      final first = before.items.first.gameId;
      final played = withRuns({
        first: [(100, 500)],
      });
      final after = DailyWorkout.plan(played, today: 100, gameIds: ember);
      expect(
        [for (final i in after.items) i.gameId],
        [for (final i in before.items) i.gameId],
      );
      expect(after.items.first.done, isTrue);
      expect(after.doneCount, 1);
      expect(after.next!.gameId, isNot(first));
    });

    test('it changes from one day to the next', () {
      final a = DailyWorkout.plan(
        const GameStats(),
        today: 100,
        gameIds: ember,
      );
      final days = {
        for (var d = 101; d < 121; d++)
          [
            for (final i in DailyWorkout.plan(
              const GameStats(),
              today: d,
              gameIds: ember,
            ).items)
              i.gameId,
          ].join(','),
      };
      expect(days.length, greaterThan(1));
      expect(a.items.length, 4);
    });

    test('lower and less recently played skills come first', () {
      final book = withRuns({
        'sudoku': [(90, 2000)],
        'block_puzzle': [(99, 5000)],
      });
      // logic and spatial have been played; memory, maths and so on have not
      final w = DailyWorkout.plan(
        book,
        today: 100,
        gameIds: [...ember, 'wingy', 'bricks'],
        starScores: stars,
      );
      final skills = [for (final i in w.items) i.skill];
      expect(skills, isNot(contains(CognitiveSkill.logic)));
      expect(skills, isNot(contains(CognitiveSkill.spatial)));
    });

    test(
      'with fewer skills than slots the rest is topped up from other games',
      () {
        final presto = ['wingy', 'snake', 'bricks', 'stack', 'runner'];
        final w = DailyWorkout.plan(
          const GameStats(),
          today: 5,
          gameIds: presto,
        );
        expect(w.items.length, 4);
        expect({for (final i in w.items) i.gameId}.length, 4);
      },
    );

    test('games that are not skill games are ignored; nothing available is an empty workout', () {
      expect(
        DailyWorkout.plan(
          const GameStats(),
          today: 1,
          gameIds: ['quick_quiz'],
        ).items,
        isEmpty,
      );
      expect(
        DailyWorkout.plan(
          const GameStats(),
          today: 1,
          gameIds: const [],
        ).complete,
        isFalse,
      );
    });

    test('complete when every game has a run today', () {
      final ids = [
        for (final i in DailyWorkout.plan(
          const GameStats(),
          today: 100,
          gameIds: ember,
        ).items)
          i.gameId,
      ];
      final book = withRuns({
        for (final id in ids) id: [(100, 10)],
      });
      final w = DailyWorkout.plan(book, today: 100, gameIds: ember);
      expect(w.complete, isTrue);
      expect(w.next, isNull);
    });
  });
}
