/// The mastery map: one node per topic of a subject and year, in the teaching order. Pure Dart;
/// the day clock is passed in. Nothing is locked: the state only says where the child is.
library;

import 'models.dart';
import 'progress.dart';

/// Where a topic node stands.
enum MapNodeState { notOpen, learning, gettingThere, mastered }

/// One topic on the path.
class MapNode {
  const MapNode({
    required this.subject,
    required this.year,
    required this.topic,
    required this.name,
    required this.state,
    required this.passed,
    required this.total,
    required this.toRevise,
    required this.accuracyPercent,
    required this.reviseItems,
    required this.openItems,
  });
  final String subject;
  final int year;
  final String topic;
  final String name;
  final MapNodeState state;

  /// Passed of open items (0 of 0 while not open yet).
  final int passed;
  final int total;

  /// Open items of the topic in the mistakes notebook or due for spaced review.
  final int toRevise;

  /// Correct answers over answers, in whole percent; null before the first answer.
  final int? accuracyPercent;

  /// The items behind [toRevise], most pressing first, and every open item of the topic.
  final List<PoolItem> reviseItems;
  final List<PoolItem> openItems;

  String get key => topicKey(subject, year, topic);
  bool get isOpen => state != MapNodeState.notOpen;

  /// Filled pips: 0 not open, 1 Learning, 2 Getting there, 3 Mastered.
  int get pips => switch (state) {
    MapNodeState.notOpen => 0,
    MapNodeState.learning => 1,
    MapNodeState.gettingThere => 2,
    MapNodeState.mastered => 3,
  };

  String get stateLabel => switch (state) {
    MapNodeState.notOpen => 'Opens as you go',
    MapNodeState.learning => 'Learning',
    MapNodeState.gettingThere => 'Getting there',
    MapNodeState.mastered => 'Mastered',
  };
}

abstract final class TopicMap {
  /// Years that have built-in content, lowest first.
  static List<int> years(Iterable<LoadedPack> packs) => {
    for (final lp in packs)
      if (!lp.pack.isExtra) lp.pack.year,
  }.toList()..sort();

  /// Subjects with built-in content in [year]: maths, then english, then the rest by name.
  static List<String> subjects(Iterable<LoadedPack> packs, int year) {
    final all = {
      for (final lp in packs)
        if (!lp.pack.isExtra && lp.pack.year == year) lp.pack.subject,
    };
    int rank(String s) => s == 'maths' ? 0 : (s == 'english' ? 1 : 2);
    return all.toList()..sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : a.compareTo(b);
    });
  }

  /// The path for [subject] and [year]. Topics come from the built-in packs of the app (a topic
  /// no pack covers is not shown), in the order of [topics] (`topics.yaml`, the teaching order);
  /// topics the file does not list follow, by id. [open] are the child's open items.
  static List<MapNode> build({
    required String subject,
    required int year,
    required Iterable<LoadedPack> packs,
    required List<PoolItem> open,
    required ChildProgress progress,
    required int today,
    Topics? topics,
    bool spaced = true,
  }) {
    final names = <String, String>{};
    for (final lp in packs) {
      final p = lp.pack;
      if (p.isExtra || p.subject != subject || p.year != year) continue;
      final t = p.title.trim();
      names.putIfAbsent(p.topic, () => t);
      for (final it in p.items) {
        final other = it.topicOr(p.topic);
        if (other != null) names.putIfAbsent(other, () => '');
      }
    }
    final order = topics?.orderFor(subject, year) ?? const <String>[];
    final ids = <String>[
      for (final t in order)
        if (names.containsKey(t)) t,
      ...(names.keys.where((t) => !order.contains(t)).toList()..sort()),
    ];
    final review = progress.reviewItems(open, today: today, spaced: spaced);
    return [
      for (final t in ids)
        _node(
          subject,
          year,
          t,
          topics?.displayName(subject, year, t) ??
              (names[t]!.isNotEmpty ? names[t]! : _tidy(t)),
          [
            for (final p in open)
              if (p.subject == subject && p.year == year && p.topic == t) p,
          ],
          [
            for (final p in review)
              if (p.subject == subject && p.year == year && p.topic == t) p,
          ],
          progress,
        ),
    ];
  }

  static MapNode _node(
    String subject,
    int year,
    String topic,
    String name,
    List<PoolItem> open,
    List<PoolItem> revise,
    ChildProgress progress,
  ) {
    final r =
        progress.topics[topicKey(subject, year, topic)] ?? const TopicResult();
    final total = open.length;
    final passed = r.passed < total ? r.passed : total;
    final state = total == 0
        ? MapNodeState.notOpen
        : switch (masteryOf(
            passed: passed,
            total: total,
            answers: r.answers,
            correct: r.correct,
          )) {
            Mastery.learning => MapNodeState.learning,
            Mastery.gettingThere => MapNodeState.gettingThere,
            Mastery.mastered => MapNodeState.mastered,
          };
    return MapNode(
      subject: subject,
      year: year,
      topic: topic,
      name: name,
      state: state,
      passed: total == 0 ? 0 : passed,
      total: total,
      toRevise: total == 0 ? 0 : revise.length,
      accuracyPercent: r.accuracy == null ? null : (r.accuracy! * 100).round(),
      reviseItems: total == 0 ? const [] : revise,
      openItems: open,
    );
  }

  static String _tidy(String id) {
    final s = id.replaceAll('_', ' ').trim();
    return s.isEmpty ? id : s[0].toUpperCase() + s.substring(1);
  }
}
