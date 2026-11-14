import 'package:flutter_game_template/core/save/save_data.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

PoolItem _p(String id, {String topic = 'T'}) => PoolItem(
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
  topic: topic,
);

DayActivity _a(int n) => DayActivity(answers: n, correct: n, topics: {'k'});

void main() {
  group('activity log', () {
    test('adds to the same day and rolls over to the next', () {
      var log = const ActivityLog().add(10, _a(2)).add(10, _a(3));
      expect(log.days[10]!.answers, 5);
      log = log.add(11, _a(1));
      expect(log.days.keys, [10, 11]);
    });

    test('keeps 8 weeks and drops older days', () {
      var log = const ActivityLog().add(1, _a(1));
      log = log.add(1 + ActivityLog.keepDays, _a(1));
      expect(log.days.containsKey(1), isFalse);
      log = const ActivityLog().add(1, _a(1)).add(ActivityLog.keepDays, _a(1));
      expect(log.days.containsKey(1), isTrue);
    });

    test('a clock moved back writes nothing and keeps the later day', () {
      final log = const ActivityLog().add(20, _a(4));
      final back = log.add(15, _a(9));
      expect(back.days.keys, [20]);
      expect(back.days[20]!.answers, 4);
    });

    test('recordChange counts answers, passes and topics', () {
      final before = const ChildProgress().record(
        _p('a'),
        correct: false,
        day: 1,
      );
      final after = before
          .record(_p('a'), correct: true, day: 2)
          .record(_p('b', topic: 'U'), correct: true, day: 2);
      final log = const ActivityLog().recordChange(2, before, after);
      final d = log.days[2]!;
      expect(d.answers, 2);
      expect(d.correct, 2);
      expect(d.newlyPassed, 2);
      expect(d.topics, {'maths/3/T', 'maths/3/U'});
      // no change: no entry
      expect(const ActivityLog().recordChange(2, after, after).days, isEmpty);
    });

    test('JSON round trip', () {
      final log = const ActivityLog().add(3, _a(2)).add(4, _a(1));
      final back = ActivityLog.fromJson(log.toJson());
      expect(back.days[3]!.answers, 2);
      expect(back.days[4]!.topics, {'k'});
      expect(ActivityLog.fromJson('x').days, isEmpty);
    });
  });

  group('weekly report', () {
    test('this week and last week sums, days played and run', () {
      var log = const ActivityLog().add(
        90,
        const DayActivity(answers: 4, correct: 2),
      );
      for (final d in [94, 95, 97, 100]) {
        log = log.add(d, _a(2)); // this week: days 94..100
      }
      final play = const PlayTimeLog().add(100, 600).add(90, 120);
      final w = ProgressReport.week(log, play, 100);
      expect((w.answers, w.correct, w.daysPlayed, w.longestRun), (8, 8, 4, 2));
      expect(w.playSeconds, 600);
      expect(w.accuracyPercent, 100);
      final l = ProgressReport.week(log, play, 100, weeksAgo: 1);
      expect((l.answers, l.accuracyPercent, l.playSeconds), (4, 50, 120));
      expect(
        ProgressReport.week(const ActivityLog(), play, 5).accuracyPercent,
        isNull,
      );
    });

    test('strongest uses the mastery rule', () {
      final sizes = {'maths/3/T': 2, 'maths/3/U': 2};
      var pr = const ChildProgress();
      for (final id in ['a', 'b']) {
        pr = pr.record(_p(id), correct: true, day: 1);
      }
      pr = pr.record(_p('c', topic: 'U'), correct: true, day: 1);
      final s = ProgressReport.strongest(pr, sizes);
      expect(s.map((t) => t.key), ['maths/3/T']);
    });

    test('needs attention: up to 3 topics, most mistakes first', () {
      var pr = const ChildProgress();
      final map = <String, String>{};
      void wrong(String id, String topic) {
        pr = pr.record(_p(id, topic: topic), correct: false, day: 1);
        map[id] = 'maths/3/$topic';
      }

      wrong('a1', 'A');
      wrong('b1', 'B');
      wrong('b2', 'B');
      wrong('b3', 'B');
      wrong('c1', 'C');
      wrong('c2', 'C');
      wrong('d1', 'D');
      final n = ProgressReport.needsAttention(pr, map);
      expect(n.map((e) => e.topic.name), ['B', 'C', 'A']);
      expect(n.first.mistakes, 3);
      expect(
        ProgressReport.needsAttention(const ChildProgress(), map),
        isEmpty,
      );
    });

    test('share text: nickname only when given, no coins', () {
      final w = ProgressReport.week(
        const ActivityLog(),
        const PlayTimeLog(),
        100,
      );
      String t(String? n) => ProgressReport.shareText(
        gameName: 'G',
        thisWeek: w,
        lastWeek: w,
        strongest: const [],
        attention: const [],
        nickname: n,
      );
      expect(t(null), isNot(contains('Kit')));
      expect(t('Kit'), contains('Kit'));
      expect(t(null), contains('Needs attention: nothing right now'));
      expect(t(null).toLowerCase(), isNot(contains('coin')));
    });
  });

  group('save v7', () {
    test('a version 6 save migrates with an empty log', () {
      final m = SaveMigrator.migrate({
        'version': 6,
        'profiles': [
          {'id': 'x', 'nickname': 'N'},
        ],
      });
      expect(m['version'], 7);
      final data = SaveData.fromJson(m);
      expect(data.profiles.single.activity.days, isEmpty);
    });
  });
}
