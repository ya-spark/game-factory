/// Skills: the rungs of the trail. Pure Dart.
///
/// A topic holds an ordered list of skills (rungs). An item belongs to one skill: either its own
/// `skill` field (an id) or, when absent, the rung whose `seq` range holds the item. Items are
/// written easiest first, so the first rung is the easiest.
///
/// `skills.yaml` shape (the content repo generates a first ladder; finer skills can replace it):
///
/// ```yaml
/// maths:
///   3:
///     times_tables:
///       - id: times_tables_1
///         name: Getting started
///         seq: [1, 6]
///       - id: times_tables_2
///         name: Building up
///         seq: [7, 13]
///         requires: [times_tables_1]   # optional; ids of the same subject and year
/// ```
///
/// Default prerequisites: a rung needs the rung before it in its topic; the first rung of a topic
/// needs the first rung of the topic before it (in `topics.yaml` order); the very first rung needs
/// nothing. An explicit `requires` replaces the default.
library;

import 'package:yaml/yaml.dart';

import 'models.dart';

/// Items a rung needs before its evidence can mean anything (the smallest window).
const int minSkillItems = 6;

/// One rung of the trail.
class Skill {
  const Skill({
    required this.id,
    required this.subject,
    required this.year,
    required this.topic,
    required this.name,
    required this.seqFrom,
    required this.seqTo,
    required this.requires,
    required this.order,
    required this.rung,
  });

  /// Unique within a subject and year.
  final String id;
  final String subject;
  final int year;
  final String topic;
  final String name;

  /// Items with `seq` from [seqFrom] to [seqTo] (both included) belong here by default.
  final int seqFrom;
  final int seqTo;

  /// Keys (see [key]) of the rungs that must be secure first. Empty for the very first rung.
  final List<String> requires;

  /// Position of the rung in the teaching order of its subject and year (0 first).
  final int order;

  /// Position inside its topic (0 first).
  final int rung;

  String get key => skillKey(subject, year, id);
  String get topicKey => '$subject/$year/$topic';
}

String skillKey(String subject, int year, String id) => '$subject/$year/$id';

/// All skills of an app, in teaching order.
class SkillMap {
  SkillMap._(this._bySubjectYear, this._byKey);

  final Map<String, List<Skill>> _bySubjectYear;
  final Map<String, Skill> _byKey;

  static final SkillMap empty = SkillMap._({}, {});

  bool get isEmpty => _byKey.isEmpty;
  int get length => _byKey.length;
  Iterable<Skill> get all => _byKey.values;

  /// Rungs of [subject] in [year] in teaching order (topic order, then rung).
  List<Skill> skillsFor(String subject, int year) =>
      _bySubjectYear['$subject/$year'] ?? const [];

  Skill? byKey(String key) => _byKey[key];

  /// Rungs of one topic, easiest first.
  List<Skill> forTopic(String subject, int year, String topic) => [
    for (final s in skillsFor(subject, year))
      if (s.topic == topic) s,
  ];

  bool hasTopic(String subject, int year, String topic) =>
      forTopic(subject, year, topic).isNotEmpty;

  /// The rung of an item of [subject], [year] and [topic]: its own `skill` id if it names a rung
  /// of that topic, else the rung whose `seq` range holds it, else null.
  Skill? skillOf(String subject, int year, String topic, ContentItem item) {
    final own = item.json['skill'];
    final rungs = forTopic(subject, year, topic);
    if (own is String) {
      for (final s in rungs) {
        if (s.id == own) return s;
      }
      return null;
    }
    final seq = item.json['seq'];
    if (seq is int) {
      for (final s in rungs) {
        if (seq >= s.seqFrom && seq <= s.seqTo) return s;
      }
    }
    return null;
  }

  /// Parses `skills.yaml` against the topics file. Throws [FormatException] with a plain message.
  factory SkillMap.parse(String yamlText, Topics topics) {
    final doc = loadYaml(yamlText);
    if (doc is! YamlMap) {
      throw const FormatException('skills file must be a map of subjects');
    }
    final bySY = <String, List<Skill>>{};
    final byKey = <String, Skill>{};
    for (final s in doc.entries) {
      final subject = '${s.key}';
      if (!topics.hasSubject(subject)) {
        throw FormatException(
          'skills: subject "$subject" is not in the topics file',
        );
      }
      final years = s.value;
      if (years is! YamlMap) {
        throw FormatException('skills: $subject must map years to topics');
      }
      for (final y in years.entries) {
        final year = int.tryParse('${y.key}');
        if (year == null || year < 0 || year > 12) {
          throw FormatException('skills: $subject has a bad year "${y.key}"');
        }
        final topicMap = y.value;
        if (topicMap is! YamlMap) {
          throw FormatException(
            'skills: $subject year $year must map topics to rungs',
          );
        }
        final order = topics.orderFor(subject, year);
        for (final t in topicMap.keys) {
          if (!order.contains('$t')) {
            throw FormatException(
              'skills: topic "$t" is not in the topics file for $subject year $year',
            );
          }
        }
        // Teaching order: topics.yaml order, then rung order.
        final list = <Skill>[];
        final ids = <String>{};
        String? previousTopicFirst;
        var n = 0;
        for (final topic in order) {
          final rungs = topicMap[topic];
          if (rungs == null) continue;
          if (rungs is! YamlList || rungs.isEmpty) {
            throw FormatException(
              'skills: $subject $year $topic must be a non-empty list of rungs',
            );
          }
          final topicSkills = <Skill>[];
          var lastTo = 0;
          String? previousId;
          for (var i = 0; i < rungs.length; i++) {
            final r = rungs[i];
            final where = 'skills: $subject $year $topic rung ${i + 1}';
            if (r is! YamlMap) throw FormatException('$where must be a map');
            final id = r['id'];
            final name = r['name'];
            if (id is! String ||
                !RegExp(r'^[a-z0-9][a-z0-9_]*$').hasMatch(id)) {
              throw FormatException(
                '$where needs an id of lowercase letters, digits, _',
              );
            }
            if (!ids.add(id)) {
              throw FormatException('$where: id "$id" is used twice');
            }
            if (name is! String || name.trim().isEmpty) {
              throw FormatException('$where needs a name');
            }
            final seq = r['seq'];
            if (seq is! YamlList ||
                seq.length != 2 ||
                seq[0] is! int ||
                seq[1] is! int ||
                (seq[0] as int) < 1 ||
                (seq[1] as int) < (seq[0] as int)) {
              throw FormatException(
                '$where needs seq: [from, to] with from <= to',
              );
            }
            final from = seq[0] as int;
            final to = seq[1] as int;
            if (from <= lastTo) {
              throw FormatException(
                '$where: seq ranges overlap or are out of order',
              );
            }
            lastTo = to;
            List<String> requires;
            final explicit = r['requires'];
            if (explicit != null) {
              if (explicit is! YamlList) {
                throw FormatException('$where: requires must be a list of ids');
              }
              requires = [
                for (final e in explicit) skillKey(subject, year, '$e'),
              ];
            } else if (previousId != null) {
              requires = [skillKey(subject, year, previousId)];
            } else if (previousTopicFirst != null) {
              requires = [previousTopicFirst];
            } else {
              requires = const [];
            }
            final skill = Skill(
              id: id,
              subject: subject,
              year: year,
              topic: topic,
              name: name,
              seqFrom: from,
              seqTo: to,
              requires: requires,
              order: n++,
              rung: i,
            );
            topicSkills.add(skill);
            previousId = id;
          }
          previousTopicFirst = topicSkills.first.key;
          list.addAll(topicSkills);
        }
        for (final s in list) {
          byKey[s.key] = s;
        }
        bySY['$subject/$year'] = list;
      }
    }
    // Every required rung exists, and the graph has no cycle.
    for (final s in byKey.values) {
      for (final r in s.requires) {
        if (!byKey.containsKey(r)) {
          throw FormatException(
            'skills: ${s.key} requires "$r", which does not exist',
          );
        }
      }
    }
    final state = <String, int>{};
    void visit(Skill s, List<String> path) {
      final st = state[s.key] ?? 0;
      if (st == 2) return;
      if (st == 1) {
        throw FormatException(
          'skills: prerequisites form a cycle: ${[...path, s.key].join(' -> ')}',
        );
      }
      state[s.key] = 1;
      for (final r in s.requires) {
        visit(byKey[r]!, [...path, s.key]);
      }
      state[s.key] = 2;
    }

    for (final s in byKey.values) {
      visit(s, const []);
    }
    return SkillMap._(bySY, byKey);
  }

  /// All rungs that must be secure, directly or through other rungs, before [skill].
  Set<String> ancestorsOf(Skill skill) {
    final out = <String>{};
    void walk(Skill s) {
      for (final r in s.requires) {
        if (out.add(r)) walk(_byKey[r]!);
      }
    }

    walk(skill);
    return out;
  }
}

/// Coverage checks over decoded packs (as in [validatePacks]): every item of a topic that has
/// skills belongs to a rung, a `skill` field names a rung of the item's topic, and every rung has
/// at least [minSkillItems] items. Single-format rungs only warn.
List<ContentIssue> validateSkillCoverage(
  List<MapEntry<String, Object?>> packs,
  SkillMap skills,
) {
  final issues = <ContentIssue>[];
  if (skills.isEmpty) return issues;
  final count = <String, int>{};
  final formats = <String, Set<String>>{};
  for (final p in packs) {
    final j = p.value;
    if (j is! Map) continue;
    final subject = j['subject'];
    final year = j['year'];
    final packTopic = j['topic'];
    final items = j['items'];
    if (subject is! String || year is! int || items is! List) continue;
    for (final it in items) {
      if (it is! Map<String, dynamic>) continue;
      final topic = it['topic'] is String ? it['topic'] as String : packTopic;
      if (topic is! String || !skills.hasTopic(subject, year, topic)) continue;
      final where = '${p.key} (${it['id']})';
      final item = ContentItem(it);
      final own = it['skill'];
      final s = skills.skillOf(subject, year, topic, item);
      if (s == null) {
        issues.add(
          ContentIssue(
            Severity.error,
            own is String ? 'unknown_skill' : 'item_no_skill',
            where,
            own is String
                ? 'skill "$own" is not a rung of topic $topic'
                : 'seq ${it['seq']} is in no rung of topic $topic',
          ),
        );
        continue;
      }
      count[s.key] = (count[s.key] ?? 0) + 1;
      (formats[s.key] ??= {}).add('${it['type']}');
    }
  }
  for (final s in skills.all) {
    final n = count[s.key] ?? 0;
    if (n < minSkillItems) {
      issues.add(
        ContentIssue(
          Severity.error,
          'skill_pool',
          s.key,
          'rung "${s.name}" has $n items; it needs at least $minSkillItems',
        ),
      );
    } else if ((formats[s.key] ?? const {}).length < 2) {
      issues.add(
        ContentIssue(
          Severity.warning,
          'skill_one_format',
          s.key,
          'rung "${s.name}" has only one format; a second format is needed to reach mastered',
        ),
      );
    }
  }
  return issues;
}
