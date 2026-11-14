import 'dart:math';

import 'package:flutter_game_template/core/save/save_data.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

PoolItem _mcq(String id, {String topic = 'a', String subject = 'maths'}) =>
    PoolItem(
      item: ContentItem({
        'id': id,
        'type': 'mcq',
        'seq': 1,
        'difficulty': 1,
        'explanation': 'because',
        'prompt': 'p $id',
        'options': ['x', 'y', 'z'],
        'correct': 1,
      }),
      packId: 'pk',
      subject: subject,
      year: 5,
      topic: topic,
    );

PoolItem _num(String id, {String topic = 'a'}) => PoolItem(
  item: ContentItem({
    'id': id,
    'type': 'numeric',
    'seq': 1,
    'difficulty': 1,
    'explanation': 'sum',
    'prompt': 'n $id',
    'answer': 12,
    'tolerance': 0,
    'unit': '',
  }),
  packId: 'pk',
  subject: 'maths',
  year: 5,
  topic: topic,
);

PoolItem _cloze(String id) => PoolItem(
  item: ContentItem({
    'id': id,
    'type': 'cloze',
    'seq': 1,
    'difficulty': 1,
    'explanation': 'e',
  }),
  packId: 'pk',
  subject: 'maths',
  year: 5,
  topic: 'a',
);

List<PoolItem> _pool(int n) => [
  for (var i = 0; i < n; i++)
    i.isEven ? _mcq('m$i', topic: i % 3 == 0 ? 'a' : 'b') : _num('n$i'),
];

class _Clock {
  DateTime t = DateTime.utc(2026, 11, 14, 9);
  DateTime call() => t;
  void tick(int s) => t = t.add(Duration(seconds: s));
}

ExamSession _start(
  List<PoolItem> open, {
  int count = 10,
  int? minutes = 10,
  ExtraTime extra = ExtraTime.none,
  _Clock? clock,
  String? topic,
}) => ExamSession.start(
  open: open,
  subject: 'maths',
  year: 5,
  topic: topic,
  count: count,
  minutes: minutes,
  extra: extra,
  random: Random(1),
  clock: (clock ?? _Clock()).call,
)!;

void main() {
  group('set building', () {
    test('fewer than 10 matching questions: no exam', () {
      expect(
        ExamSession.start(
          open: _pool(9),
          subject: 'maths',
          year: 5,
          count: 10,
          random: Random(1),
        ),
        isNull,
      );
    });

    test('the count is capped by what is open', () {
      final s = _start(_pool(14), count: 30);
      expect(s.total, 14);
      expect(ExamSession.countChoices(14), [10]);
      expect(ExamSession.countChoices(25), [10, 20]);
      expect(ExamSession.countChoices(40), [10, 20, 30]);
      expect(_start(_pool(40), count: 20).total, 20);
    });

    test('only multiple choice and numeric items are drawn', () {
      final open = [..._pool(12), _cloze('c1'), _cloze('c2')];
      final s = _start(open, count: 30);
      expect(s.total, 12);
      expect(
        s.items.every((p) => ExamSession.types.contains(p.item.type)),
        isTrue,
      );
    });

    test('a mixed set spreads over topics; a topic set keeps one topic', () {
      final s = _start(_pool(30), count: 10);
      expect({for (final p in s.items) p.topic}, {'a', 'b'});
      final t = _start(_pool(30), count: 10, topic: 'b');
      expect({for (final p in t.items) p.topic}, {'b'});
    });

    test('the same seed gives the same set', () {
      final a = _start(_pool(30)).items.map((p) => p.id).toList();
      final b = _start(_pool(30)).items.map((p) => p.id).toList();
      expect(a, b);
    });
  });

  group('timer', () {
    test('counts down on the injected clock', () {
      final c = _Clock();
      final s = _start(_pool(10), minutes: 10, clock: c);
      expect(s.limitSeconds, 600);
      c.tick(90);
      expect(s.remainingSeconds, 510);
      expect(s.timeUp, isFalse);
    });

    test('pauses in the background', () {
      final c = _Clock();
      final s = _start(_pool(10), minutes: 10, clock: c);
      c.tick(60);
      s.pause();
      c.tick(3600); // the app is away for an hour
      expect(s.remainingSeconds, 540);
      s.resume();
      c.tick(40);
      expect(s.remainingSeconds, 500);
      expect(s.elapsed.inSeconds, 100);
    });

    test('extra time lengthens the countdown', () {
      expect(ExamSession.limitFor(10, ExtraTime.none), 600);
      expect(ExamSession.limitFor(10, ExtraTime.quarter), 750);
      expect(ExamSession.limitFor(20, ExtraTime.half), 1800);
      expect(ExamSession.limitFor(null, ExtraTime.half), isNull);
      final s = _start(_pool(10), minutes: 10, extra: ExtraTime.quarter);
      expect(s.limitSeconds, 750);
    });

    test('time up is detected and a result is marked timed out', () {
      final c = _Clock();
      final s = _start(_pool(10), minutes: 10, clock: c);
      c.tick(601);
      expect(s.timeUp, isTrue);
      expect(s.remainingSeconds, 0);
      final r = s.submit();
      expect(r.timedOut, isTrue);
    });

    test('no timer never runs out', () {
      final c = _Clock();
      final s = _start(_pool(10), minutes: null, clock: c);
      c.tick(100000);
      expect(s.remainingSeconds, isNull);
      expect(s.timeUp, isFalse);
    });

    test('submit freezes the time used', () {
      final c = _Clock();
      final s = _start(_pool(10), clock: c);
      c.tick(75);
      final r = s.submit();
      c.tick(500);
      expect(r.seconds, 75);
      expect(s.elapsed.inSeconds, 75);
    });
  });

  group('answers, scoring and recording', () {
    test('navigation, flags and the unanswered list', () {
      final s = _start(_pool(10));
      s.next();
      s.next();
      expect(s.index, 2);
      s.goTo(99);
      expect(s.index, 2);
      s.previous();
      expect(s.index, 1);
      s.toggleFlag(3);
      expect(s.isFlagged(3), isTrue);
      expect(s.flaggedNumbers, [4]);
      s.toggleFlag(3);
      expect(s.isFlagged(3), isFalse);
      s.setAnswer(0, const ExamAnswer.choice({1}));
      s.setAnswer(1, const ExamAnswer.typed('  '));
      expect(s.isAnswered(0), isTrue);
      expect(s.isAnswered(1), isFalse);
      expect(s.unansweredNumbers, [2, 3, 4, 5, 6, 7, 8, 9, 10]);
      s.setAnswer(0, const ExamAnswer.choice({}));
      expect(s.isAnswered(0), isFalse);
    });

    test('scores multiple choice and numeric answers', () {
      final s = ExamSession(
        items: [_mcq('a1'), _mcq('a2'), _num('n1'), _num('n2')],
        subject: 'maths',
        limitSeconds: null,
        clock: _Clock().call,
      );
      s.setAnswer(0, const ExamAnswer.choice({1})); // right
      s.setAnswer(1, const ExamAnswer.choice({0})); // wrong
      s.setAnswer(2, const ExamAnswer.typed('12.0')); // right
      // question 4 left unanswered
      final r = s.submit();
      expect(r.correct, 2);
      expect(r.total, 4);
      expect(r.percent, 50);
      expect(r.unanswered, 1);
      expect(r.items[3].answered, isFalse);
      expect(r.topics.single.questions, 4);
      expect(r.weakest.single.correct, 2);
    });

    test('unanswered questions are not recorded as wrong', () {
      final s = ExamSession(
        items: [_mcq('a1'), _mcq('a2'), _mcq('a3')],
        subject: 'maths',
        limitSeconds: null,
        clock: _Clock().call,
      );
      s.setAnswer(0, const ExamAnswer.choice({1}));
      s.setAnswer(1, const ExamAnswer.choice({2}));
      s.submit();
      final p = s.applyTo(const ChildProgress(), day: 100);
      expect(p.items.keys.toSet(), {'a1', 'a2'});
      expect(p.items['a1']!.passed, isTrue);
      expect(p.items['a2']!.passes, 0);
      expect(p.mistakeIds, ['a2']);
      expect(p.topics['maths/5/a']!.answers, 2);
      expect(p.topics['maths/5/a']!.correct, 1);
      // no coins or stars
      expect(p.rewards.stars, 0);
      expect(p.rewards.weekCoins, isEmpty);
      expect(p.rewards.paid, isEmpty);
      // the activity log counts the answered questions
      final log = const ActivityLog().recordChange(
        100,
        const ChildProgress(),
        p,
      );
      expect(log.days[100]!.answers, 2);
    });

    test('submit is final and idempotent', () {
      final s = _start(_pool(10));
      s.setAnswer(0, const ExamAnswer.choice({1}));
      final a = s.submit();
      s.setAnswer(1, const ExamAnswer.choice({1}));
      s.toggleFlag(2);
      final b = s.submit();
      expect(identical(a, b), isTrue);
      expect(b.correct, a.correct);
      expect(s.isFlagged(2), isFalse);
    });

    test('applyTo needs a submitted exam', () {
      expect(
        () => _start(_pool(10)).applyTo(const ChildProgress(), day: 1),
        throwsStateError,
      );
    });
  });

  group('history', () {
    ExamRecord rec(int day, int correct) => ExamRecord(
      day: day,
      subject: 'maths',
      questions: 10,
      correct: correct,
      seconds: 300,
    );

    test('keeps the last 10, oldest dropped', () {
      var h = const ExamHistory();
      for (var i = 0; i < 13; i++) {
        h = h.add(rec(i, 5));
      }
      expect(h.records, hasLength(10));
      expect(h.records.first.day, 3);
      expect(h.records.last.day, 12);
    });

    test('round trips through JSON and trims on load', () {
      var h = const ExamHistory();
      for (var i = 0; i < 12; i++) {
        h = h.add(rec(i, i % 11));
      }
      final back = ExamHistory.fromJson(h.toJson());
      expect(back.records, hasLength(10));
      expect(back.records.last.correct, h.records.last.correct);
      expect(ExamHistory.fromJson('junk').records, isEmpty);
      expect(
        ExamHistory.fromJson([
          {'q': 0},
          5,
          rec(1, 4).toJson(),
        ]).records,
        hasLength(1),
      );
    });

    test('trend wording is calm and needs two exams', () {
      expect(const ExamHistory().trend, isNull);
      expect(ExamHistory([rec(1, 5)]).trend, isNull);
      expect(ExamHistory([rec(1, 5), rec(2, 9)]).trend, contains('up'));
      expect(ExamHistory([rec(1, 9), rec(2, 5)]).trend, contains('lower'));
      expect(ExamHistory([rec(1, 5), rec(2, 5)]).trend, contains('steady'));
    });

    test('a finished exam becomes a record', () {
      final s = _start(_pool(10));
      s.setAnswer(0, const ExamAnswer.choice({1}));
      s.submit();
      final r = s.toRecord(day: 42);
      expect(r.day, 42);
      expect(r.questions, 10);
      expect(r.percent, r.correct * 10);
    });
  });

  group('save version 9', () {
    test('a version 8 save migrates with no exams and no extra time', () {
      final d = SaveData.fromJson(
        SaveMigrator.migrate({
          'version': 8,
          'profiles': [
            {'id': 'p1', 'nickname': 'Mia'},
          ],
        }),
      );
      expect(SaveData.currentVersion, 9);
      expect(d.profiles.single.exams.records, isEmpty);
      expect(d.profiles.single.extraTime, ExtraTime.none);
    });
  });
}
