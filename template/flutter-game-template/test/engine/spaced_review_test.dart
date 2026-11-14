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

ChildProgress _right(ChildProgress pr, String id, int day) =>
    pr.record(_p(id), correct: true, day: day);

void main() {
  group('box ladder', () {
    test('the ladder and caps are the spec values', () {
      expect(reviewLadder, [1, 3, 7, 21, 45]);
      expect(reviewCountCap, 20);
      expect(mistakeRoundSize, 10);
    });

    test('a correct answer on a new day moves up one box, to 4 at most', () {
      var pr = const ChildProgress();
      for (var d = 1; d <= 7; d++) {
        pr = _right(pr, 'a', d);
      }
      expect(pr.items['a']!.box, 4);
      expect(_right(const ChildProgress(), 'a', 1).items['a']!.box, 1);
      expect(
        _right(_right(const ChildProgress(), 'a', 1), 'a', 2).items['a']!.box,
        2,
      );
    });

    test('five answers on one day move the box only once', () {
      var pr = const ChildProgress();
      for (var i = 0; i < 5; i++) {
        pr = _right(pr, 'a', 10);
      }
      expect(pr.items['a']!.box, 1);
      expect(pr.items['a']!.lastSeenDay, 10);
    });

    test('a wrong answer drops to box 0', () {
      var pr = const ChildProgress();
      for (var d = 1; d <= 4; d++) {
        pr = _right(pr, 'a', d);
      }
      expect(pr.items['a']!.box, 4);
      pr = pr.record(_p('a'), correct: false, day: 5);
      expect(pr.items['a']!.box, 0);
    });

    test('due when today - lastSeenDay reaches the wait of the box', () {
      for (var b = 0; b < 5; b++) {
        final r = ItemResult(lastSeenDay: 100, box: b);
        expect(r.isDue(100 + reviewLadder[b] - 1), isFalse, reason: 'box $b');
        expect(r.isDue(100 + reviewLadder[b]), isTrue, reason: 'box $b');
      }
    });

    test('never-answered and undated items are not due', () {
      expect(const ItemResult().isDue(9999), isFalse);
      expect(const ChildProgress().reviewItems([_p('a')], today: 99), isEmpty);
    });

    test('box survives a JSON round trip', () {
      final pr = _right(_right(const ChildProgress(), 'a', 1), 'a', 2);
      expect(ChildProgress.fromJson(pr.toJson()).items['a']!.box, 2);
    });
  });

  group('clock cases', () {
    test('a clock moved back makes nothing due and writes no box change', () {
      var pr = _right(const ChildProgress(), 'a', 50);
      expect(pr.items['a']!.isDue(10), isFalse);
      expect(pr.reviewItems([_p('a')], today: 10), isEmpty);
      final back = _right(pr, 'a', 10);
      expect(back.items['a']!.box, pr.items['a']!.box);
      expect(back.items['a']!.lastSeenDay, 50);
      final wrongBack = pr.record(_p('a'), correct: false, day: 10);
      expect(wrongBack.items['a']!.box, pr.items['a']!.box);
    });

    test('a clock moved forward makes many due; the round is still 10', () {
      var pr = const ChildProgress();
      final open = <PoolItem>[];
      for (var i = 0; i < 30; i++) {
        final p = _p('i${i.toString().padLeft(2, '0')}');
        open.add(p);
        pr = pr.record(p, correct: true, day: 1);
      }
      final list = pr.reviewItems(open, today: 400);
      expect(list, hasLength(30));
      expect(pr.reviewRound(open, today: 400), hasLength(10));
    });

    test('children have separate schedules', () {
      final a = _right(const ChildProgress(), 'x', 1);
      const b = ChildProgress();
      expect(a.reviewItems([_p('x')], today: 5), hasLength(1));
      expect(b.reviewItems([_p('x')], today: 5), isEmpty);
    });
  });

  group('migration', () {
    test('a version 5 save gets a box and nothing becomes due', () {
      final migrated = SaveMigrator.migrate({
        'version': 5,
        'profiles': [
          {
            'id': 'c1',
            'name': 'Mia',
            'progress': {
              'items': {
                'passed': {'a': 3, 'p': 2, 'ok': true, 'cs': 2},
                'wrong': {'a': 1, 'p': 0, 'ok': false, 'cs': 0},
                'old': {'a': 2, 'p': 1, 'ok': false, 'cs': 0},
                'dated': {'a': 1, 'p': 1, 'ok': true, 'cs': 1, 'ls': 7},
              },
            },
          },
        ],
      });
      expect(migrated['version'], SaveData.currentVersion);
      final data = SaveData.fromJson(migrated);
      final items = data.profiles.single.progress.items;
      expect(items['passed']!.box, 1);
      expect(items['wrong']!.box, 0);
      expect(items['old']!.box, 0);
      expect(items['dated']!.box, 1);
      // Undated items are not due, however far the clock is.
      expect(items['passed']!.isDue(100000), isFalse);
      expect(items['wrong']!.isDue(100000), isFalse);
      expect(items['dated']!.isDue(7 + 3), isTrue);
      expect(data.spacedReview, isTrue);
    });

    test('the switch is saved', () {
      final d = SaveData.fromJson(
        SaveData().copyWith(spacedReview: false).toJson(),
      );
      expect(d.spacedReview, isFalse);
    });
  });

  group('review order', () {
    test('mistakes first, then most overdue, ties by id; open only', () {
      var pr = const ChildProgress();
      // due non-mistakes: m (box1 seen 1, overdue), n (box1 seen 5)
      pr = _right(pr, 'n', 5);
      pr = _right(pr, 'm', 1);
      // mistake seen day 9
      pr = pr.record(_p('w'), correct: false, day: 9);
      // not due yet
      pr = _right(pr, 'z', 10);
      pr = _right(pr, 'k', 1); // due, but not open
      final open = [_p('n'), _p('m'), _p('w'), _p('z')];
      final ids = [for (final p in pr.reviewItems(open, today: 10)) p.id];
      expect(ids, ['w', 'm', 'n']);
    });

    test('equal overdue ties go by id', () {
      var pr = _right(const ChildProgress(), 'b', 1);
      pr = _right(pr, 'a', 1);
      final ids = [
        for (final p in pr.reviewItems([_p('b'), _p('a')], today: 9)) p.id,
      ];
      expect(ids, ['a', 'b']);
    });

    test('spaced review off leaves the mistakes round only', () {
      var pr = _right(const ChildProgress(), 'm', 1);
      pr = pr.record(_p('w'), correct: false, day: 2);
      final ids = [
        for (final p in pr.reviewItems(
          [_p('m'), _p('w')],
          today: 20,
          spaced: false,
        ))
          p.id,
      ];
      expect(ids, ['w']);
    });
  });
}
