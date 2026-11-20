/// Pool report: how many items exist per type, subject, year and topic, so a
/// minigame's minimum playable pool can be checked.
library;

import 'format_limits.dart';
import 'models.dart';
import 'skills.dart';

class PoolReport {
  PoolReport._(this.total, this._rows);

  final int total;
  final List<_Row> _rows;

  /// Counts every item of [packs] (built-in and extra alike).
  factory PoolReport.of(Iterable<ContentPack> packs, {SkillMap? skills}) {
    final rows = <_Row>[];
    for (final p in packs) {
      for (final i in p.items) {
        final topic = i.topicOr(p.topic)!;
        rows.add(
          _Row(
            i.type,
            p.subject,
            p.year,
            topic,
            i.sizeClass,
            skills?.skillOf(p.subject, p.year, topic, i)?.key,
          ),
        );
      }
    }
    return PoolReport._(rows.length, rows);
  }

  /// Items matching every given filter.
  int count({
    ItemType? type,
    String? subject,
    int? year,
    String? topic,
    SizeClass? sizeClass,
  }) {
    var n = 0;
    for (final r in _rows) {
      if (type != null && r.type != type) continue;
      if (subject != null && r.subject != subject) continue;
      if (year != null && r.year != year) continue;
      if (topic != null && r.topic != topic) continue;
      if (sizeClass != null && r.sizeClass != sizeClass) continue;
      n++;
    }
    return n;
  }

  /// True when at least [minimum] items of one of [types] exist for the
  /// subject and year (the minimum playable pool of a minigame).
  bool meetsMinimum({
    required Set<ItemType> types,
    required int minimum,
    String? subject,
    int? year,
  }) {
    var n = 0;
    for (final t in types) {
      n += count(type: t, subject: subject, year: year);
    }
    return n >= minimum;
  }

  Map<String, int> _group(String Function(_Row) key) {
    final m = <String, int>{};
    for (final r in _rows) {
      m.update(key(r), (v) => v + 1, ifAbsent: () => 1);
    }
    return Map.fromEntries(
      m.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  Map<String, int> get byType => _group((r) => r.type.name);
  Map<String, int> get bySubject => _group((r) => r.subject);
  Map<String, int> get byYear =>
      _group((r) => r.year.toString().padLeft(2, '0'));
  Map<String, int> get byTopic => _group(
    (r) => '${r.subject}/${r.year.toString().padLeft(2, '0')}/${r.topic}',
  );

  /// Items per type and size class (`short` or `long`).
  Map<String, int> get byTypeAndSize =>
      _group((r) => '${r.type.name}/${r.sizeClass.name}');

  /// Items per skill rung and format (only when a skill map was given).
  Map<String, int> get bySkillAndType => _group(
    (r) => r.skill == null
        ? '(no skill)/${r.type.name}'
        : '${r.skill}/${r.type.name}',
  );

  /// Items per topic and size class.
  Map<String, int> get byTopicAndSize => _group(
    (r) =>
        '${r.subject}/${r.year.toString().padLeft(2, '0')}/${r.topic}/${r.sizeClass.name}',
  );

  /// Subject, year and type together: the cut a minigame cares about.
  Map<String, int> get bySubjectYearType => _group(
    (r) => '${r.subject}/${r.year.toString().padLeft(2, '0')}/${r.type.name}',
  );

  String format() {
    final b = StringBuffer('Pool report: $total items\n');
    void section(String title, Map<String, int> m) {
      b.writeln('\n$title');
      for (final e in m.entries) {
        b.writeln('  ${e.key.padRight(48)} ${e.value}');
      }
    }

    section('By type', byType);
    section('By type and size class', byTypeAndSize);
    section('By subject', bySubject);
    section('By year (00 = Foundation)', byYear);
    section('By subject, year and type', bySubjectYearType);
    section('By topic', byTopic);
    section('By topic and size class', byTopicAndSize);
    if (_rows.any((r) => r.skill != null)) {
      section('By skill and type', bySkillAndType);
    }
    return b.toString();
  }
}

class _Row {
  _Row(
    this.type,
    this.subject,
    this.year,
    this.topic,
    this.sizeClass,
    this.skill,
  );
  final ItemType type;
  final String subject;
  final int year;
  final String topic;
  final SizeClass sizeClass;
  final String? skill;
}
