import 'dart:math';

import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

PoolItem pool(
  String id, {
  String type = 'mcq',
  int options = 4,
  String skill = 'maths/3/tt_1',
}) => PoolItem(
  item: ContentItem({
    'id': id,
    'seq': 1,
    'difficulty': 1,
    'type': type,
    'explanation': 'e',
    if (type == 'mcq') 'options': [for (var i = 0; i < options; i++) 'o$i'],
    if (type == 'mcq') 'correct': 0,
  }),
  packId: 'p',
  subject: 'maths',
  year: 3,
  topic: 'times_tables',
  skillKey: skill,
);

SkillEvidence ev(bool c, int day, {String f = 'mcq', double w = 1}) =>
    SkillEvidence(correct: c, day: day, format: f, weight: w);

SkillProgress feed(SkillRules r, List<SkillEvidence> list) {
  var s = const SkillProgress();
  for (final e in list) {
    s = s.add(e, r);
  }
  return s;
}

void main() {
  group('evidence', () {
    const r = SkillRules.ranger;
    test(
      'a 2-option question counts half; a hint is wrong; a timeout is wrong',
      () {
        expect(
          evidenceFor(
            pool('a', options: 2),
            correct: true,
            day: 1,
            rules: r,
          )!.weight,
          0.5,
        );
        expect(
          evidenceFor(pool('a'), correct: true, day: 1, rules: r)!.weight,
          1,
        );
        expect(
          evidenceFor(
            pool('a'),
            correct: true,
            day: 1,
            rules: r,
            hinted: true,
          )!.correct,
          isFalse,
        );
        expect(
          evidenceFor(
            pool('a'),
            correct: true,
            day: 1,
            rules: r,
            timedOut: true,
          )!.correct,
          isFalse,
        );
      },
    );
    test('Scout never penalises a timeout: no evidence at all', () {
      expect(
        evidenceFor(
          pool('a'),
          correct: false,
          day: 1,
          rules: SkillRules.scout,
          timedOut: true,
        ),
        isNull,
      );
    });
  });

  group('the advance rule', () {
    List<SkillEvidence> run(int n, {int days = 2, int wrong = 0}) => [
      for (var i = 0; i < n; i++) ev(i >= wrong, 1 + i % days),
    ];
    test('Ranger: 80% of the last 10 on 2 days', () {
      const r = SkillRules.ranger;
      expect(feed(r, run(10, wrong: 2)).metBy(r), isTrue);
      expect(feed(r, run(10, wrong: 3)).metBy(r), isFalse);
      expect(feed(r, run(10, days: 1)).metBy(r), isFalse, reason: 'one day');
      expect(feed(r, run(5)).metBy(r), isFalse, reason: 'fewer than 6 results');
    });
    test('Scout: 75% of the last 8; Champion: 85% of the last 10', () {
      expect(
        feed(SkillRules.scout, run(8, wrong: 2)).metBy(SkillRules.scout),
        isTrue,
      );
      expect(
        feed(SkillRules.scout, run(8, wrong: 3)).metBy(SkillRules.scout),
        isFalse,
      );
      expect(
        feed(SkillRules.champion, run(10, wrong: 1)).metBy(SkillRules.champion),
        isTrue,
      );
      expect(
        feed(SkillRules.champion, run(10, wrong: 2)).metBy(SkillRules.champion),
        isFalse,
      );
    });
    test('only the latest window counts', () {
      const r = SkillRules.ranger;
      final bad = [for (var i = 0; i < 10; i++) ev(false, 1 + i % 2)];
      final good = [for (var i = 0; i < 10; i++) ev(true, 3 + i % 2)];
      expect(feed(r, [...bad, ...good]).metBy(r), isTrue);
      expect(feed(r, [...good, ...bad]).metBy(r), isFalse);
    });
    test('half-weight answers weigh half', () {
      const r = SkillRules.ranger;
      // 4 right full-weight, 6 wrong half-weight: 4 / 7 < 0.8, but 8 right + 2 wrong half is fine.
      final s = feed(r, [
        for (var i = 0; i < 8; i++) ev(true, 1 + i % 2),
        ev(false, 1, w: 0.5),
        ev(false, 2, w: 0.5),
      ]);
      expect(s.accuracy(r), closeTo(8 / 9, 1e-9));
      expect(s.metBy(r), isTrue);
    });
  });

  group('states', () {
    const r = SkillRules.ranger;
    SkillProgress secure() =>
        feed(r, [for (var i = 0; i < 10; i++) ev(true, 1 + i % 2, f: 'mcq')]);

    test('unseen, practising, secure', () {
      expect(const SkillProgress().stateOf(r, today: 5), SkillState.unseen);
      expect(
        feed(r, [ev(true, 1)]).stateOf(r, today: 5),
        SkillState.practising,
      );
      expect(secure().stateOf(r, today: 5), SkillState.secure);
    });

    test('mastered needs a second format and a revision pass 3 days later', () {
      var s = secure();
      expect(s.secureDay, 2);
      // a second format, but no revision pass yet
      s = s.add(ev(true, 3, f: 'series'), r);
      expect(s.stateOf(r, today: 3), SkillState.secure);
      // a correct answer 3 days after becoming secure
      s = s.add(ev(true, 5, f: 'mcq'), r);
      expect(s.revisionDay, 5);
      expect(s.stateOf(r, today: 5), SkillState.mastered);
    });

    test('a rung with one format only needs the revision pass', () {
      var s = secure().add(ev(true, 6), r);
      expect(s.stateOf(r, today: 6, formatsInRung: 1), SkillState.mastered);
      expect(s.stateOf(r, today: 6, formatsInRung: 2), SkillState.secure);
    });

    test('a mastered skill not answered for 42 days falls back to secure', () {
      final s = secure().add(ev(true, 3, f: 'series'), r).add(ev(true, 6), r);
      expect(s.stateOf(r, today: 6), SkillState.mastered);
      expect(s.stateOf(r, today: 6 + 42), SkillState.mastered);
      expect(s.stateOf(r, today: 6 + 43), SkillState.secure);
    });

    test('wrong answers can take a secure skill back to practising', () {
      var s = secure();
      for (var i = 0; i < 4; i++) {
        s = s.add(ev(false, 3 + i), r);
      }
      expect(s.stateOf(r, today: 8), SkillState.practising);
    });

    test('survives a JSON round trip', () {
      final s = secure().add(ev(true, 5, f: 'series'), r);
      final back = SkillProgress.fromJson(s.toJson());
      expect(back.toJson(), s.toJson());
      expect(back.stateOf(r, today: 5), s.stateOf(r, today: 5));
    });
  });

  group('recording on ChildProgress', () {
    test('an answer adds evidence for its skill; a game score does not', () {
      var p = const ChildProgress();
      p = p.record(pool('a'), correct: true, day: 10);
      expect(p.skills['maths/3/tt_1']!.evidence.single.correct, isTrue);
      p = p.recordScore('door_runner', 500);
      expect(p.skills['maths/3/tt_1']!.evidence.length, 1);
    });
    test('an item without a skill key adds none', () {
      final noSkill = PoolItem(
        item: pool('a').item,
        packId: 'p',
        subject: 'maths',
        year: 3,
        topic: 't',
      );
      expect(
        const ChildProgress().record(noSkill, correct: true, day: 1).skills,
        isEmpty,
      );
    });
    test('a clock that went back adds no evidence', () {
      var p = const ChildProgress().record(pool('a'), correct: true, day: 10);
      p = p.record(pool('a'), correct: true, day: 5);
      expect(p.skills['maths/3/tt_1']!.evidence.length, 1);
    });
    test('skills survive the ChildProgress JSON round trip', () {
      final p = const ChildProgress().record(pool('a'), correct: true, day: 10);
      final back = ChildProgress.fromJson(p.toJson());
      expect(back.skills.keys, p.skills.keys);
      expect(ChildProgress.fromJson({'items': {}}).skills, isEmpty);
    });
  });

  group('skip-ahead check', () {
    final topics = Topics.parse('''
maths:
  3:
    times_tables: A
    fractions: B
''');
    final map = SkillMap.parse('''
maths:
  3:
    times_tables:
      - {id: tt_1, name: A, seq: [1, 6]}
      - {id: tt_2, name: B, seq: [7, 13]}
      - {id: tt_3, name: C, seq: [14, 20]}
    fractions:
      - {id: fr_1, name: D, seq: [1, 20]}
''', topics);
    const r = SkillRules.ranger;

    test(
      '4 of 5 passes; the pass unlocks the rung and marks the ones before it',
      () {
        expect(SkipCheck.passed(4, r), isTrue);
        expect(SkipCheck.passed(3, r), isFalse);
        final tt3 = map.byKey('maths/3/tt_3')!;
        final p = SkipCheck.apply(
          const ChildProgress(),
          tt3,
          map,
          passed: true,
          day: 7,
          rules: r,
        );
        expect(p.skills['maths/3/tt_3']!.byCheck, isTrue);
        expect(p.skills['maths/3/tt_2']!.byCheck, isTrue);
        expect(p.skills['maths/3/tt_1']!.byCheck, isTrue);
        expect(
          p.skills['maths/3/tt_3']!.stateOf(r, today: 7),
          SkillState.secure,
        );
        expect(p.skills.containsKey('maths/3/fr_1'), isFalse);
      },
    );

    test('a miss only starts a short wait', () {
      final tt2 = map.byKey('maths/3/tt_2')!;
      final p = SkipCheck.apply(
        const ChildProgress(),
        tt2,
        map,
        passed: false,
        day: 7,
        rules: r,
      );
      expect(SkipCheck.canTry(p, tt2, 7, r), isFalse);
      expect(SkipCheck.canTry(p, tt2, 8, r), isTrue);
      expect(p.skills['maths/3/tt_2']!.byCheck, isFalse);
      expect(p.skills['maths/3/tt_2']!.stateOf(r, today: 8), SkillState.unseen);
    });

    test('a check prefers items that are hard to guess', () {
      final items = [
        pool('t1', options: 2),
        pool('t2', options: 2),
        for (var i = 0; i < 6; i++) pool('m$i'),
      ];
      final picked = SkipCheck.pick(items, r, Random(1));
      expect(picked.length, 5);
      expect(
        picked.every((p) => (p.item.json['options'] as List).length >= 3),
        isTrue,
      );
      final few = SkipCheck.pick(
        [pool('t1', options: 2), pool('m1')],
        r,
        Random(1),
      );
      expect(few.length, 2, reason: 'falls back to guessable items');
    });
  });

  group('migration from per-item results', () {
    test(
      'answered items become starting evidence; mastered is never granted',
      () {
        final items = [for (var i = 0; i < 8; i++) pool('i$i')];
        var old = const ChildProgress();
        for (var i = 0; i < 8; i++) {
          old = old.record(
            items[i].withSkillKeyForTest(null),
            correct: true,
            day: 1 + i,
          );
        }
        expect(
          old.skills,
          isEmpty,
          reason: 'recorded without a skill key, as before skills',
        );
        final migrated = migrateToSkills(old, items, SkillRules.ranger);
        final sp = migrated.skills['maths/3/tt_1']!;
        expect(sp.evidence.length, 8);
        expect(sp.metBy(SkillRules.ranger), isTrue);
        expect(sp.stateOf(SkillRules.ranger, today: 30), SkillState.secure);
        expect(sp.revisionDay, isNull);
      },
    );
    test('does nothing when skills already exist or nothing was answered', () {
      const empty = ChildProgress();
      expect(
        migrateToSkills(empty, [pool('a')], SkillRules.ranger).skills,
        isEmpty,
      );
      final has = const ChildProgress().record(
        pool('a'),
        correct: true,
        day: 1,
      );
      expect(
        identical(migrateToSkills(has, [pool('a')], SkillRules.ranger), has),
        isTrue,
      );
    });
  });
}

extension on PoolItem {
  PoolItem withSkillKeyForTest(String? key) => PoolItem(
    item: item,
    packId: packId,
    subject: subject,
    year: year,
    topic: topic,
    skillKey: key,
  );
}
