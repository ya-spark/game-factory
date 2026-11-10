/// Content model: pack manifest and items. Pure Dart, no Flutter.
library;

import 'package:yaml/yaml.dart';

/// The seven item types.
enum ItemType {
  mcq,
  series,
  pairs,
  word,
  category,
  numeric,
  cloze;

  static ItemType? parse(Object? name) {
    for (final t in ItemType.values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

const String contentLang = 'en-AU';
const String contentLicence = 'original';
const int minPackItems = 20;
const int maxPackItems = 50;

enum Severity { error, warning }

/// One finding from the validator. [code] is stable and used by tests.
class ContentIssue {
  const ContentIssue(this.severity, this.code, this.where, this.message);
  final Severity severity;
  final String code;
  final String where;
  final String message;

  bool get isError => severity == Severity.error;

  @override
  String toString() =>
      '${isError ? 'ERROR' : 'WARN '} [$code] $where: $message';
}

class ValidationResult {
  ValidationResult(this.issues);
  final List<ContentIssue> issues;

  List<ContentIssue> get errors => [
    for (final i in issues)
      if (i.isError) i,
  ];
  List<ContentIssue> get warnings => [
    for (final i in issues)
      if (!i.isError) i,
  ];
  bool get ok => errors.isEmpty;
  bool hasCode(String code) => issues.any((i) => i.code == code);
}

/// Allowed subjects, years and topics (from `content/topics.yaml`).
///
/// File shape: `subject: { year: { topic_id: Display name } }`, with year 0
/// meaning Foundation.
class Topics {
  Topics(this._byKey, this.subjects);

  final Map<String, Map<String, String>> _byKey;
  final Set<String> subjects;

  factory Topics.parse(String yamlText) {
    final doc = loadYaml(yamlText);
    if (doc is! YamlMap) {
      throw const FormatException('topics file must be a map of subjects');
    }
    final byKey = <String, Map<String, String>>{};
    final subjects = <String>{};
    for (final s in doc.entries) {
      final subject = '${s.key}';
      subjects.add(subject);
      final years = s.value;
      if (years is! YamlMap) {
        throw FormatException('subject $subject must map years to topics');
      }
      for (final y in years.entries) {
        final year = int.tryParse('${y.key}');
        if (year == null || year < 0 || year > 12) {
          throw FormatException('$subject: bad year "${y.key}"');
        }
        final topics = y.value;
        if (topics is! YamlMap) {
          throw FormatException('$subject year $year must map topic ids');
        }
        byKey['$subject/$year'] = {
          for (final t in topics.entries) '${t.key}': '${t.value}',
        };
      }
    }
    return Topics(byKey, subjects);
  }

  bool hasSubject(String subject) => subjects.contains(subject);

  /// Topic ids allowed for [subject] in [year] (empty when none).
  Set<String> topicsFor(String subject, int year) =>
      (_byKey['$subject/$year'] ?? const {}).keys.toSet();

  String? displayName(String subject, int year, String topic) =>
      _byKey['$subject/$year']?[topic];
}

/// A validated item, as a thin typed view over its JSON.
class ContentItem {
  ContentItem(this.json);
  final Map<String, dynamic> json;

  String get id => json['id'] as String;
  int get seq => json['seq'] as int;
  int get difficulty => json['difficulty'] as int;
  ItemType get type => ItemType.parse(json['type'])!;
  String get explanation => json['explanation'] as String;
  String? get image => json['image'] as String?;
  String? get imageAlt => json['image_alt'] as String?;
  String? get audio => json['audio'] as String?;
  String? topicOr(String packTopic) => json['topic'] as String? ?? packTopic;
}

/// A validated pack. Build it with [ContentPack.fromJson] after validation.
class ContentPack {
  ContentPack(this.json);
  final Map<String, dynamic> json;

  String get id => json['id'] as String;
  int get version => json['version'] as int;
  String get lang => json['lang'] as String;
  String get subject => json['subject'] as String;
  int get year => json['year'] as int;
  String get topic => json['topic'] as String;
  String get title => json['title'] as String;
  String? get productId => json['product_id'] as String?;
  bool get isExtra => productId != null;

  /// `draft` or `live`. A pack without a status is `draft` when it is an extra pack, else `live`.
  String get status =>
      json['status'] as String? ?? (isExtra ? 'draft' : 'live');
  String? get tier => json['tier'] as String?;
  Map<String, dynamic>? get preview => json['preview'] as Map<String, dynamic>?;

  List<ContentItem> get items => [
    for (final i in (json['items'] as List))
      ContentItem(i as Map<String, dynamic>),
  ];

  /// Preview item ids (empty when there is no preview).
  List<String> get previewItemIds => [
    for (final i in (preview?['item_ids'] as List? ?? const [])) i as String,
  ];
}
