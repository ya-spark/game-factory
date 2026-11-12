/// What a grown-up sees about one player: topics practised and accuracy per topic.
/// Pure Dart, built from the stored progress.
library;

import '../content/progress.dart';

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
}
