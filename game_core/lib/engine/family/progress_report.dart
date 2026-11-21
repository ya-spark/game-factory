/// What a grown-up sees about one player: topics practised and accuracy per topic.
/// Pure Dart, built from the stored progress.
library;

import '../content/progress.dart';
import 'activity_log.dart';
import 'play_time.dart';

class TopicLine {
  const TopicLine({
    required this.key,
    required this.name,
    required this.answers,
    required this.accuracyPercent,
    required this.passed,
    required this.attempted,
  });

  /// `subject/year/topic`.
  final String key;

  /// Readable: "Fractions" from `maths/4/fractions`.
  final String name;
  final int answers;

  /// Whole percent of answers that were right; null before the first answer.
  final int? accuracyPercent;
  final int passed;
  final int attempted;
}

abstract final class ProgressReport {
  /// Topics with at least one answer, most answers first (ties by name).
  static List<TopicLine> topics(ChildProgress p) {
    final out = <TopicLine>[
      for (final e in p.topics.entries)
        if (e.value.answers > 0)
          TopicLine(
            key: e.key,
            name: topicName(e.key),
            answers: e.value.answers,
            accuracyPercent: e.value.accuracy == null
                ? null
                : (e.value.accuracy! * 100).round(),
            passed: e.value.passed,
            attempted: e.value.attempted,
          ),
    ];
    out.sort((a, b) {
      final c = b.answers.compareTo(a.answers);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return out;
  }

  /// The last part of a topic key, with underscores and dashes turned into spaces and the first
  /// letter capitalised.
  static String topicName(String key) {
    final last = key.split('/').last.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (last.isEmpty) return key;
    return last[0].toUpperCase() + last.substring(1);
  }

  /// Topic key to the number of items in it, over every loaded pack (the base of mastery).
  static Map<String, int> topicSizes(Iterable<LoadedPack> packs) {
    final m = <String, int>{};
    for (final lp in packs) {
      final p = lp.pack;
      for (final it in p.items) {
        final k = topicKey(p.subject, p.year, it.topicOr(p.topic) ?? p.topic);
        m[k] = (m[k] ?? 0) + 1;
      }
    }
    return m;
  }

  /// Item id to topic key, over every loaded pack.
  static Map<String, String> itemTopics(Iterable<LoadedPack> packs) {
    final m = <String, String>{};
    for (final lp in packs) {
      final p = lp.pack;
      for (final it in p.items) {
        m[it.id] = topicKey(p.subject, p.year, it.topicOr(p.topic) ?? p.topic);
      }
    }
    return m;
  }

  /// Topics that are Mastered by [masteryOf], by name.
  static List<TopicLine> strongest(ChildProgress p, Map<String, int> sizes) => [
    for (final t in topics(p))
      if (masteryOf(
            passed: p.topics[t.key]!.passed,
            total: sizes[t.key] ?? 0,
            answers: p.topics[t.key]!.answers,
            correct: p.topics[t.key]!.correct,
          ) ==
          Mastery.mastered)
        t,
  ]..sort((a, b) => a.name.compareTo(b.name));

  /// How many topics "Needs attention" lists.
  static const int needsAttentionCount = 3;

  /// Up to [limit] topics with the most items in the mistakes notebook (ties by name), with the
  /// count of such items. [itemTopic] maps item ids to topic keys.
  static List<({TopicLine topic, int mistakes})> needsAttention(
    ChildProgress p,
    Map<String, String> itemTopic, {
    int limit = needsAttentionCount,
  }) {
    final count = <String, int>{};
    for (final id in p.mistakeIds) {
      final k = itemTopic[id];
      if (k != null) count[k] = (count[k] ?? 0) + 1;
    }
    final lines = {for (final t in topics(p)) t.key: t};
    final out = <({TopicLine topic, int mistakes})>[
      for (final e in count.entries)
        (
          topic:
              lines[e.key] ??
              TopicLine(
                key: e.key,
                name: topicName(e.key),
                answers: 0,
                accuracyPercent: null,
                passed: 0,
                attempted: 0,
              ),
          mistakes: e.value,
        ),
    ];
    out.sort((a, b) {
      final c = b.mistakes.compareTo(a.mistakes);
      return c != 0 ? c : a.topic.name.compareTo(b.topic.name);
    });
    return out.take(limit).toList();
  }

  /// This week or last week in numbers.
  static WeekFigures week(
    ActivityLog log,
    PlayTimeLog playTime,
    int today, {
    int weeksAgo = 0,
  }) {
    final a = log.week(today, weeksAgo: weeksAgo);
    final end = today - 7 * weeksAgo;
    var secs = 0;
    for (final e in playTime.secondsByDay.entries) {
      if (e.key > end - 7 && e.key <= end) secs += e.value;
    }
    return WeekFigures(
      firstDay: end - 6,
      lastDay: end,
      playSeconds: secs,
      answers: a.answers,
      correct: a.correct,
      newlyPassed: a.newlyPassed,
      daysPlayed: log.daysPlayed(today, weeksAgo: weeksAgo),
      longestRun: log.longestRun(today, weeksAgo: weeksAgo),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  /// "14 Nov" for a day number.
  static String dayLabel(int day) {
    final d = DateTime.utc(1970, 1, 1).add(Duration(days: day));
    return '${d.day} ${_months[d.month - 1]}';
  }

  /// The plain text a parent can share: the week's dates, the numbers, strongest topics and
  /// topics needing attention. [nickname] is included only when not null. No coins, no
  /// ranking, no comparison with other children.
  static String shareText({
    required String gameName,
    required WeekFigures thisWeek,
    required WeekFigures lastWeek,
    required List<TopicLine> strongest,
    required List<({TopicLine topic, int mistakes})> attention,
    String? nickname,
  }) {
    final b = StringBuffer()
      ..writeln(
        nickname == null || nickname.isEmpty
            ? 'Learning summary, $gameName'
            : '$nickname: learning summary, $gameName',
      )
      ..writeln(
        'Week of ${dayLabel(thisWeek.firstDay)} to ${dayLabel(thisWeek.lastDay)}',
      )
      ..writeln('Time played: ${PlayTimeLog.describe(thisWeek.playSeconds)}')
      ..writeln(
        'Answers: ${thisWeek.answers}'
        '${thisWeek.accuracyPercent == null ? '' : ' (${thisWeek.accuracyPercent}% right)'}',
      )
      ..writeln('Newly passed: ${thisWeek.newlyPassed}')
      ..writeln(
        'Days played: ${thisWeek.daysPlayed} of 7 (${thisWeek.longestRun} in a row)',
      )
      ..writeln(
        'Last week: ${lastWeek.answers} answers, '
        '${lastWeek.newlyPassed} newly passed, '
        '${PlayTimeLog.describe(lastWeek.playSeconds)}',
      )
      ..writeln(
        'Strongest topics: '
        '${strongest.isEmpty ? 'none yet' : strongest.map((t) => t.name).join(', ')}',
      )
      ..write(
        'Needs attention: '
        '${attention.isEmpty ? 'nothing right now' : attention.map((a) => a.topic.name).join(', ')}',
      );
    return b.toString();
  }
}

/// One week of activity for the report.
class WeekFigures {
  const WeekFigures({
    required this.firstDay,
    required this.lastDay,
    required this.playSeconds,
    required this.answers,
    required this.correct,
    required this.newlyPassed,
    required this.daysPlayed,
    required this.longestRun,
  });

  final int firstDay;
  final int lastDay;
  final int playSeconds;
  final int answers;
  final int correct;
  final int newlyPassed;
  final int daysPlayed;
  final int longestRun;

  /// Whole percent of answers that were right; null with no answers.
  int? get accuracyPercent =>
      answers == 0 ? null : (correct * 100 / answers).round();
}
