import 'package:flutter_game_template/core/save/save_data.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

PoolItem _p(String id) => PoolItem(
  item: ContentItem({
    'id': id,
    'type': 'mcq',
    'seq': 1,
    'difficulty': 1,
    'explanation': 'e',
    'prompt': 'p',
    'options': ['a', 'b'],
    'correct': 0,
  }),
  packId: 'pk',
  subject: 'maths',
  year: 3,
  topic: 'T',
);

void main() {
  group('clear rule: two correct answers in a row', () {
    test('a wrong answer puts the item in the notebook', () {
      final a = _p('a');
      final pr = const ChildProgress().record(a, correct: false, day: 5);
      expect(pr.mistakeIds, ['a']);
    });

    test('one correct answer does not clear it, two in a row do', () {
      final a = _p('a');
      var pr = const ChildProgress().record(a, correct: false);
      pr = pr.record(a, correct: true);
      expect(pr.items['a']!.streak, 1);
      expect(pr.mistakeIds, ['a']);
      pr = pr.record(a, correct: true);
      expect(pr.mistakeIds, isEmpty);
    });

    test('a wrong answer resets the streak and puts the item back', () {
      final a = _p('a');
      var pr = const ChildProgress()
          .record(a, correct: false)
          .record(a, correct: true)
          .record(a, correct: true);
      expect(pr.mistakeIds, isEmpty);
      pr = pr.record(a, correct: false);
      expect(pr.items['a']!.streak, 0);
      expect(pr.mistakeIds, ['a']);
      pr = pr.record(a, correct: true);
      expect(pr.mistakeIds, ['a']);
    });

    test('an item never answered wrongly is not a mistake', () {
      final pr = const ChildProgress().record(_p('a'), correct: true);
      expect(pr.mistakeIds, isEmpty);
    });

    test('lastSeenDay is written on every answer', () {
      final a = _p('a');
      var pr = const ChildProgress().record(a, correct: true, day: 7);
      expect(pr.items['a']!.lastSeenDay, 7);
      pr = pr.record(a, correct: false, day: 9);
      expect(pr.items['a']!.lastSeenDay, 9);
    });

    test('a quiz session records the day clock', () {
      final s = QuizSession(
        items: [_p('a')],
        progress: const ChildProgress(),
        packs: const [],
        rewardsConfig: const RewardsConfig(),
        today: 42,
      )..answer(correct: false);
      expect(s.progress.items['a']!.lastSeenDay, 42);
    });
  });

  group('old saves', () {
    test('an old item last answered right counts as cleared', () {
      final r = ItemResult.fromJson({'a': 3, 'p': 1, 'ok': true});
      expect(r.streak, mistakeClearStreak);
      expect(r.lastSeenDay, isNull);
      expect(r.isMistake, isFalse);
    });

    test('an old item last answered wrong stays a mistake with streak 0', () {
      final r = ItemResult.fromJson({'a': 1, 'p': 0, 'ok': false});
      expect(r.streak, 0);
      expect(r.isMistake, isTrue);
    });

    test('a version 4 save migrates without items reappearing', () {
      final migrated = SaveMigrator.migrate({
        'version': 4,
        'profiles': [
          {
            'id': 'p1',
            'nickname': 'Mia',
            'progress': {
              'items': {
                'right': {'a': 2, 'p': 1, 'ok': true},
                'wrong': {'a': 1, 'p': 0, 'ok': false},
              },
            },
          },
        ],
      });
      expect(migrated['version'], SaveData.currentVersion);
      final data = SaveData.fromJson(migrated);
      final progress = data.profiles.single.progress;
      expect(progress.items['right']!.streak, 2);
      expect(progress.items['wrong']!.streak, 0);
      expect(progress.mistakeIds, ['wrong']);
    });

    test('the new fields survive a round trip', () {
      final pr = const ChildProgress()
          .record(_p('a'), correct: false, day: 3)
          .record(_p('a'), correct: true, day: 4);
      final back = ChildProgress.fromJson(pr.toJson());
      expect(back.items['a']!.streak, 1);
      expect(back.items['a']!.lastSeenDay, 4);
      expect(back.mistakeIds, ['a']);
    });
  });

  group('mistake round order', () {
    ChildProgress wrongOn(Map<String, int?> days) {
      var pr = const ChildProgress();
      for (final e in days.entries) {
        pr = pr.record(_p(e.key), correct: false, day: e.value);
      }
      return pr;
    }

    test('oldest lastSeenDay first, ties by id', () {
      final pr = wrongOn({'c': 5, 'a': 9, 'b': 5, 'd': 1});
      final round = pr.mistakeRound([for (final i in 'abcd'.split('')) _p(i)]);
      expect([for (final p in round) p.id], ['d', 'b', 'c', 'a']);
    });

    test('never-dated items come first', () {
      final pr = ChildProgress(
        items: {
          'x': const ItemResult(attempts: 1),
          'y': const ItemResult(attempts: 1, lastSeenDay: 2),
        },
      );
      final round = pr.mistakeRound([_p('y'), _p('x')]);
      expect([for (final p in round) p.id], ['x', 'y']);
    });

    test('up to 10, open items only, cleared items left out', () {
      var pr = const ChildProgress();
      final open = <PoolItem>[];
      for (var i = 0; i < 14; i++) {
        final p = _p('i${i.toString().padLeft(2, '0')}');
        pr = pr.record(p, correct: false, day: i);
        if (i != 3) open.add(p); // i03 is not open
      }
      final cleared = _p('i00');
      pr = pr.record(cleared, correct: true).record(cleared, correct: true);
      final round = pr.mistakeRound(open);
      expect(round, hasLength(mistakeRoundSize));
      expect(mistakeRoundSize, 10);
      expect(round.map((p) => p.id), isNot(contains('i03')));
      expect(round.map((p) => p.id), isNot(contains('i00')));
      expect(round.first.id, 'i01');
    });

    test('fewer than 3 items still make a round', () {
      final pr = wrongOn({'a': 1});
      expect(pr.mistakeRound([_p('a')]), hasLength(1));
      expect(const ChildProgress().mistakeRound([_p('a')]), isEmpty);
    });
  });
}
