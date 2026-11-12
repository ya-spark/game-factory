import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayTimeLog', () {
    test('adds to a day and sums the last seven days only', () {
      var log = const PlayTimeLog();
      log = log.add(100, 600).add(100, 60).add(95, 300).add(93, 1000);
      expect(log.secondsByDay[100], 660);
      // 94..100 count; 95 is in, 93 is out.
      expect(log.weekSeconds(100), 660 + 300);
      // The next week the old days no longer count.
      expect(log.weekSeconds(107), 0);
    });

    test('ignores zero and negative amounts and caps one stretch', () {
      const log = PlayTimeLog();
      expect(log.add(5, 0).secondsByDay, isEmpty);
      expect(log.add(5, -30).secondsByDay, isEmpty);
      expect(log.add(5, 999999).secondsByDay[5], PlayTimeLog.maxStretchSeconds);
    });

    test('drops days older than two weeks', () {
      final log = const PlayTimeLog().add(1, 60).add(40, 60);
      expect(log.secondsByDay.containsKey(1), isFalse);
      expect(log.secondsByDay.containsKey(40), isTrue);
    });

    test('round-trips through JSON and survives junk', () {
      final log = const PlayTimeLog().add(7, 120).add(8, 30);
      final back = PlayTimeLog.fromJson(log.toJson());
      expect(back.secondsByDay, {7: 120, 8: 30});
      expect(PlayTimeLog.fromJson(null).secondsByDay, isEmpty);
      expect(PlayTimeLog.fromJson({'x': 5, '3': -1}).secondsByDay, isEmpty);
    });

    test('describes time in plain words', () {
      expect(PlayTimeLog.describe(20), 'Less than a minute');
      expect(PlayTimeLog.describe(60), '1 minute');
      expect(PlayTimeLog.describe(12 * 60), '12 minutes');
      expect(PlayTimeLog.describe(3600), '1 hour');
      expect(PlayTimeLog.describe(3600 + 5 * 60), '1 hour 5 minutes');
      expect(PlayTimeLog.describe(2 * 3600 + 60), '2 hours 1 minute');
    });
  });

  group('TextSizeChoice', () {
    test('scales and parses with a safe default', () {
      expect(TextSizeChoice.small.scale, lessThan(1));
      expect(TextSizeChoice.normal.scale, 1);
      expect(TextSizeChoice.large.scale, greaterThan(1));
      expect(TextSizeChoice.parse('large'), TextSizeChoice.large);
      expect(TextSizeChoice.parse('huge'), TextSizeChoice.normal);
      expect(TextSizeChoice.parse(null), TextSizeChoice.normal);
    });
  });

  group('ProgressReport', () {
    test('lists answered topics with accuracy, most answers first', () {
      const p = ChildProgress(
        topics: {
          'maths/4/fractions': TopicResult(
            attempted: 5,
            passed: 3,
            answers: 8,
            correct: 6,
          ),
          'english/4/spelling_words': TopicResult(
            attempted: 2,
            passed: 2,
            answers: 2,
            correct: 2,
          ),
          'maths/4/untouched': TopicResult(),
        },
      );
      final lines = ProgressReport.topics(p);
      expect(lines.map((l) => l.name), ['Fractions', 'Spelling words']);
      expect(lines.first.accuracyPercent, 75);
      expect(lines.last.accuracyPercent, 100);
    });

    test('no answers: no lines', () {
      expect(ProgressReport.topics(const ChildProgress()), isEmpty);
    });
  });
}
