/// Pack validator. Pure Dart: file access is injected through [AssetChecker].
library;

import 'expression.dart';
import 'models.dart';
import 'numeric.dart';
import 'spelling.dart';

/// Answers "does this asset exist" and "is it listed in assets/LICENSES.md".
class AssetChecker {
  const AssetChecker({required this.exists, required this.licensesText});
  final bool Function(String path) exists;
  final String licensesText;

  bool isListed(String path) => licensesText.contains(path);
}

final RegExp _idForm = RegExp(r'^[a-z0-9][a-z0-9_.-]*$');
final RegExp _gapForm = RegExp(r'\{\{(\d+)\}\}');

const _commonKeys = {
  'id',
  'seq',
  'difficulty',
  'type',
  'topic',
  'explanation',
  'image',
  'image_alt',
  'audio',
  'expression',
};
const Map<ItemType, Set<String>> _typeKeys = {
  ItemType.mcq: {'prompt', 'options', 'correct'},
  ItemType.series: {'prompt', 'steps'},
  ItemType.pairs: {'prompt', 'pairs'},
  ItemType.word: {'answer', 'hint', 'letters'},
  ItemType.category: {'prompt', 'categories', 'items'},
  ItemType.numeric: {'prompt', 'answer', 'tolerance', 'unit'},
  ItemType.cloze: {'text', 'gaps'},
};
const _packKeys = {
  'id',
  'version',
  'lang',
  'subject',
  'year',
  'topic',
  'title',
  'product_id',
  'tier',
  'status',
  'licence',
  'preview',
  'items',
};
const _previewKeys = {'description', 'outline', 'item_ids'};

/// Validates one pack (decoded JSON). Pass [assets] to check image and audio
/// files. [fileLabel] only names the pack in messages.
ValidationResult validatePack(
  Object? json, {
  required Topics topics,
  AssetChecker? assets,
  String? fileLabel,
}) {
  final v = _PackValidator(topics, assets, fileLabel);
  v.run(json);
  return ValidationResult(v.issues);
}

/// Validates many packs and adds the cross-pack checks (unique pack ids and
/// item ids across all packs).
ValidationResult validatePacks(
  List<MapEntry<String, Object?>> packs, {
  required Topics topics,
  AssetChecker? assets,
}) {
  final issues = <ContentIssue>[];
  final packIds = <String, String>{};
  final itemIds = <String, String>{};
  for (final p in packs) {
    issues.addAll(
      validatePack(
        p.value,
        topics: topics,
        assets: assets,
        fileLabel: p.key,
      ).issues,
    );
    final j = p.value;
    if (j is! Map) continue;
    final pid = j['id'];
    if (pid is String) {
      final prev = packIds[pid];
      if (prev != null) {
        issues.add(
          ContentIssue(
            Severity.error,
            'duplicate_pack_id',
            p.key,
            'pack id "$pid" is also used by $prev',
          ),
        );
      }
      packIds[pid] = p.key;
    }
    final items = j['items'];
    if (items is List) {
      for (final it in items) {
        final id = it is Map ? it['id'] : null;
        if (id is! String) continue;
        final prev = itemIds[id];
        if (prev != null && prev != p.key) {
          issues.add(
            ContentIssue(
              Severity.error,
              'duplicate_id',
              p.key,
              'item id "$id" is also used in $prev',
            ),
          );
        }
        itemIds[id] = p.key;
      }
    }
  }
  return ValidationResult(issues);
}

class _PackValidator {
  _PackValidator(this.topics, this.assets, String? label) : label = label ?? '';
  final Topics topics;
  final AssetChecker? assets;
  final String label;
  final List<ContentIssue> issues = [];

  String _packWhere = '';

  void _err(String code, String where, String msg) =>
      issues.add(ContentIssue(Severity.error, code, where, msg));
  void _warn(String code, String where, String msg) =>
      issues.add(ContentIssue(Severity.warning, code, where, msg));

  bool _text(Object? v) => v is String && v.trim().isNotEmpty;

  /// Requires a non-empty string field.
  String? _reqText(Map m, String key, String where, {String? code}) {
    final v = m[key];
    if (v == null || (v is String && v.trim().isEmpty)) {
      _err(
        code ?? (v == null ? 'schema' : 'empty_text'),
        where,
        '"$key" is ${v == null ? 'missing' : 'empty'}',
      );
      return null;
    }
    if (v is! String) {
      _err('schema', where, '"$key" must be text');
      return null;
    }
    return v;
  }

  List<String>? _textList(Map m, String key, String where, {int min = 1}) {
    final v = m[key];
    if (v is! List) {
      _err('schema', where, '"$key" must be a list');
      return null;
    }
    if (v.length < min) {
      _err('schema', where, '"$key" needs at least $min entries');
    }
    final out = <String>[];
    for (var i = 0; i < v.length; i++) {
      if (!_text(v[i])) {
        _err('empty_text', where, '"$key" entry ${i + 1} is empty or not text');
      } else {
        out.add(v[i] as String);
      }
    }
    return out;
  }

  void _unknownKeys(Map m, Set<String> allowed, String where) {
    for (final k in m.keys) {
      if (!allowed.contains(k)) _err('schema', where, 'unknown field "$k"');
    }
  }

  void run(Object? json) {
    final tag = label.isEmpty ? 'pack' : label;
    if (json is! Map) {
      _err('schema', tag, 'pack must be a JSON object');
      return;
    }
    final pack = json;
    _packWhere = pack['id'] is String ? '$tag(${pack['id']})' : tag;
    final w = _packWhere;
    _unknownKeys(pack, _packKeys, w);

    final id = _reqText(pack, 'id', w);
    if (id != null && !_idForm.hasMatch(id)) {
      _err('schema', w, 'id "$id" must be lowercase letters, digits, _ . -');
    }
    final version = pack['version'];
    if (version is! int || version < 1) {
      _err('schema', w, '"version" must be a whole number, 1 or more');
    }
    if (pack['lang'] != contentLang) {
      _err('schema', w, '"lang" must be "$contentLang"');
    }
    if (pack['licence'] != contentLicence) {
      _err('schema', w, '"licence" must be "$contentLicence"');
    }
    _reqText(pack, 'title', w);

    final subject = pack['subject'];
    final year = pack['year'];
    final topic = pack['topic'];
    var subjectOk = false;
    if (subject is! String || !topics.hasSubject(subject)) {
      _err(
        'unknown_subject',
        w,
        'subject "$subject" is not in the topics file',
      );
    } else {
      subjectOk = true;
    }
    var yearOk = false;
    if (year is! int || year < 0 || year > 12) {
      _err('schema', w, '"year" must be 0 (Foundation) to 12');
    } else {
      yearOk = true;
    }
    var allowed = <String>{};
    if (subjectOk && yearOk) {
      allowed = topics.topicsFor(subject as String, year as int);
    }
    if (!_text(topic)) {
      _err('schema', w, '"topic" is missing');
    } else if (subjectOk && yearOk && !allowed.contains(topic)) {
      _err(
        'unknown_topic',
        w,
        'topic "$topic" is not in the topics file for $subject year $year',
      );
    }

    final productId = pack['product_id'];
    if (productId != null && !_text(productId)) {
      _err('schema', w, '"product_id" must be null or a product id');
    }
    final isExtra = _text(productId);
    final status = pack['status'];
    if (status != null && status != 'draft' && status != 'live') {
      _err('schema', w, '"status" must be draft or live');
    }
    final tier = pack['tier'];
    if (tier != null && !_text(tier)) {
      _err('schema', w, '"tier" must be a price tier id');
    }

    final itemsRaw = pack['items'];
    final itemIds = <String>{};
    final topicCounts = <String, int>{};
    var itemCount = 0;
    if (itemsRaw is! List || itemsRaw.isEmpty) {
      _err('schema', w, '"items" must be a non-empty list');
    } else {
      itemCount = itemsRaw.length;
      final seqs = <int>{};
      for (var i = 0; i < itemsRaw.length; i++) {
        final it = itemsRaw[i];
        final where = '$w item ${i + 1}';
        if (it is! Map) {
          _err('schema', where, 'item must be a JSON object');
          continue;
        }
        _item(
          it,
          where,
          itemIds,
          seqs,
          allowed: allowed,
          topicsKnown: subjectOk && yearOk,
          packTopic: topic is String ? topic : null,
          topicCounts: topicCounts,
        );
      }
      if (itemCount < minPackItems) {
        _warn(
          'pack_size',
          w,
          'pack has $itemCount items; aim for $minPackItems to $maxPackItems',
        );
      } else if (itemCount > maxPackItems) {
        _warn(
          'pack_size',
          w,
          'pack has $itemCount items; aim for $minPackItems to $maxPackItems',
        );
      }
    }

    _preview(
      pack,
      w,
      isExtra,
      itemIds,
      topicCounts,
      allowed,
      topicsKnown: subjectOk && yearOk,
    );
  }

  void _preview(
    Map pack,
    String w,
    bool isExtra,
    Set<String> itemIds,
    Map<String, int> topicCounts,
    Set<String> allowed, {
    required bool topicsKnown,
  }) {
    final p = pack['preview'];
    if (p == null) {
      if (isExtra) _err('schema', w, 'an extra pack needs a "preview"');
      return;
    }
    final pw = '$w preview';
    if (p is! Map) {
      _err('schema', pw, 'preview must be an object');
      return;
    }
    _unknownKeys(p, _previewKeys, pw);
    _reqText(p, 'description', pw);

    final ids = p['item_ids'];
    if (ids is! List) {
      _err('schema', pw, '"item_ids" must be a list (may be empty)');
    } else {
      final seen = <String>{};
      for (final id in ids) {
        if (id is! String || !itemIds.contains(id)) {
          _err(
            'preview_id',
            pw,
            'preview id "$id" is not an item in this pack',
          );
        } else if (!seen.add(id)) {
          _err('preview_id', pw, 'preview id "$id" is listed twice');
        }
      }
    }

    final outline = p['outline'];
    if (outline is! List || outline.isEmpty) {
      _err('schema', pw, '"outline" must list topic names and item counts');
      return;
    }
    final declared = <String, int>{};
    for (var i = 0; i < outline.length; i++) {
      final o = outline[i];
      final ow = '$pw outline ${i + 1}';
      if (o is! Map) {
        _err('schema', ow, 'outline entry must be an object');
        continue;
      }
      _unknownKeys(o, {'topic', 'count'}, ow);
      final t = _reqText(o, 'topic', ow);
      final c = o['count'];
      if (c is! int || c < 0) {
        _err('schema', ow, '"count" must be a whole number');
        continue;
      }
      if (t == null) continue;
      if (topicsKnown && !allowed.contains(t)) {
        _err('unknown_topic', ow, 'topic "$t" is not in the topics file');
      }
      if (declared.containsKey(t)) {
        _err('outline_count', ow, 'topic "$t" is listed twice');
      }
      declared[t] = c;
    }
    final keys = {...declared.keys, ...topicCounts.keys};
    for (final t in keys) {
      if ((declared[t] ?? 0) != (topicCounts[t] ?? 0)) {
        _err(
          'outline_count',
          pw,
          'topic "$t": outline says ${declared[t] ?? 0}, the pack has ${topicCounts[t] ?? 0}',
        );
      }
    }
  }

  void _item(
    Map it,
    String where,
    Set<String> ids,
    Set<int> seqs, {
    required Set<String> allowed,
    required bool topicsKnown,
    required String? packTopic,
    required Map<String, int> topicCounts,
  }) {
    final id = it['id'];
    var w = where;
    if (_text(id)) {
      w = '$where (${it['id']})';
      if (!_idForm.hasMatch(id as String)) {
        _err('schema', w, 'id "$id" must be lowercase letters, digits, _ . -');
      }
      if (!ids.add(id)) _err('duplicate_id', w, 'id "$id" is used twice');
    } else {
      _err('schema', w, '"id" is missing');
    }

    final seq = it['seq'];
    if (seq is! int || seq < 1) {
      _err('schema', w, '"seq" must be a whole number, 1 or more');
    } else if (!seqs.add(seq)) {
      _err('duplicate_seq', w, 'seq $seq is used twice in this pack');
    }
    final d = it['difficulty'];
    if (d is! int || d < 1 || d > 5) {
      _err('schema', w, '"difficulty" must be 1 to 5');
    }

    final itemTopic = it.containsKey('topic') ? it['topic'] : packTopic;
    if (it.containsKey('topic') && !_text(itemTopic)) {
      _err('schema', w, '"topic" is empty');
    } else if (itemTopic is String) {
      if (topicsKnown && !allowed.contains(itemTopic)) {
        _err(
          'unknown_topic',
          w,
          'topic "$itemTopic" is not in the topics file',
        );
      }
      topicCounts[itemTopic] = (topicCounts[itemTopic] ?? 0) + 1;
    }

    if (!it.containsKey('explanation') || it['explanation'] == null) {
      _err('missing_explanation', w, 'every item needs an "explanation"');
    } else if (!_text(it['explanation'])) {
      _err('missing_explanation', w, '"explanation" is empty');
    }

    final type = ItemType.parse(it['type']);
    if (type == null) {
      _err(
        'schema',
        w,
        '"type" must be one of ${ItemType.values.map((t) => t.name).join(', ')}',
      );
      return;
    }
    _unknownKeys(it, {..._commonKeys, ..._typeKeys[type]!}, w);
    _assets(it, w);

    switch (type) {
      case ItemType.mcq:
        _mcq(it, w);
      case ItemType.series:
        _reqText(it, 'prompt', w);
        _textList(it, 'steps', w, min: 2);
      case ItemType.pairs:
        _pairs(it, w);
      case ItemType.word:
        _word(it, w);
      case ItemType.category:
        _category(it, w);
      case ItemType.numeric:
        _numeric(it, w);
      case ItemType.cloze:
        _cloze(it, w);
    }
    _spelling(it, w);
  }

  void _assets(Map it, String w) {
    final image = it['image'];
    if (it.containsKey('image')) {
      if (!_text(image)) {
        _err('schema', w, '"image" is empty');
      } else {
        _asset(image as String, w);
        if (!_text(it['image_alt'])) {
          _err('missing_image_alt', w, 'an image needs "image_alt" text');
        }
      }
    } else if (it.containsKey('image_alt') && !_text(it['image_alt'])) {
      _err('empty_text', w, '"image_alt" is empty');
    }
    if (it.containsKey('audio')) {
      if (!_text(it['audio'])) {
        _err('schema', w, '"audio" is empty');
      } else {
        _asset(it['audio'] as String, w);
      }
    }
  }

  void _asset(String path, String w) {
    final a = assets;
    if (path.startsWith('/') || path.split('/').contains('..')) {
      _err('asset_path', w, 'asset path "$path" must be relative, no ".."');
      return;
    }
    if (a == null) return;
    if (!a.exists(path)) {
      _err('asset_missing', w, 'asset file "$path" does not exist');
    }
    if (!a.isListed(path)) {
      _err(
        'asset_license',
        w,
        'asset "$path" is not listed in assets/LICENSES.md',
      );
    }
  }

  void _mcq(Map it, String w) {
    _reqText(it, 'prompt', w);
    final options = _textList(it, 'options', w, min: 2);
    final correct = it['correct'];
    final idx = <int>[];
    if (correct is int) {
      idx.add(correct);
    } else if (correct is List && correct.isNotEmpty) {
      for (final c in correct) {
        if (c is int) {
          idx.add(c);
        } else {
          _err('bad_correct', w, '"correct" must hold option indexes');
        }
      }
    } else {
      _err('bad_correct', w, '"correct" must be an index or a list of indexes');
    }
    if (options == null) return;
    var good = true;
    for (final c in idx) {
      if (c < 0 || c >= (it['options'] as List).length) {
        _err('bad_correct', w, 'correct index $c is outside the options');
        good = false;
      }
    }
    if (idx.toSet().length != idx.length) {
      _err('bad_correct', w, '"correct" lists an index twice');
      good = false;
    }
    if (options.toSet().length != options.length) {
      _err('schema', w, 'two options have the same text');
    }
    if (it.containsKey('expression') && good && idx.length == 1) {
      final opt = (it['options'] as List)[idx.single];
      _expression(it, w, numericFromJson(opt));
    } else if (it.containsKey('expression') && idx.length != 1) {
      _err('expression', w, 'an expression needs exactly one correct option');
    }
  }

  void _pairs(Map it, String w) {
    if (it.containsKey('prompt')) _reqText(it, 'prompt', w);
    final pairs = it['pairs'];
    if (pairs is! List || pairs.length < 2) {
      _err('schema', w, '"pairs" needs at least 2 pairs');
      return;
    }
    final lefts = <String>{};
    for (var i = 0; i < pairs.length; i++) {
      final p = pairs[i];
      if (p is! Map) {
        _err('schema', w, 'pair ${i + 1} must have "left" and "right"');
        continue;
      }
      _unknownKeys(p, {'left', 'right'}, '$w pair ${i + 1}');
      final l = _reqText(p, 'left', '$w pair ${i + 1}');
      _reqText(p, 'right', '$w pair ${i + 1}');
      if (l != null && !lefts.add(l)) {
        _err('schema', w, 'left "$l" appears twice');
      }
    }
  }

  void _word(Map it, String w) {
    final answer = _reqText(it, 'answer', w);
    _reqText(it, 'hint', w);
    if (it.containsKey('letters')) {
      final l = it['letters'];
      final letters = l is String
          ? l.split('')
          : (l is List && l.every((e) => e is String)
                ? l.cast<String>()
                : null);
      if (letters == null || letters.isEmpty) {
        _err('schema', w, '"letters" must be text or a list of letters');
      } else if (answer != null) {
        final pool = [...letters.expand((e) => e.toLowerCase().split(''))];
        for (final ch in answer.toLowerCase().split('')) {
          if (!pool.remove(ch)) {
            _err(
              'bad_letters',
              w,
              '"letters" is missing "$ch" needed to spell the answer',
            );
            break;
          }
        }
      }
    }
  }

  void _category(Map it, String w) {
    if (it.containsKey('prompt')) _reqText(it, 'prompt', w);
    final cats = _textList(it, 'categories', w, min: 2);
    final items = it['items'];
    if (items is! List || items.isEmpty) {
      _err('schema', w, '"items" needs entries with "text" and "category"');
      return;
    }
    final used = <String>{};
    for (var i = 0; i < items.length; i++) {
      final x = items[i];
      if (x is! Map) {
        _err('schema', w, 'item ${i + 1} must have "text" and "category"');
        continue;
      }
      _unknownKeys(x, {'text', 'category'}, '$w entry ${i + 1}');
      _reqText(x, 'text', '$w entry ${i + 1}');
      final c = _reqText(x, 'category', '$w entry ${i + 1}');
      if (c != null && cats != null) {
        if (!cats.contains(c)) {
          _err(
            'bad_correct',
            w,
            'entry ${i + 1}: "$c" is not one of the categories',
          );
        } else {
          used.add(c);
        }
      }
    }
    if (cats != null && used.length < cats.length) {
      _err('bad_correct', w, 'every category needs at least one item');
    }
  }

  void _numeric(Map it, String w) {
    _reqText(it, 'prompt', w);
    final raw = it['answer'];
    double? answer;
    if (raw == null) {
      _err('numeric_answer', w, '"answer" is missing');
    } else {
      answer = numericFromJson(raw);
      if (answer == null) {
        _err(
          'numeric_answer',
          w,
          'answer "$raw" is not a number (integers and decimals only; use mcq for fractions)',
        );
      }
    }
    if (it.containsKey('tolerance')) {
      final t = it['tolerance'];
      if (t is! num || t < 0 || !t.isFinite) {
        _err('schema', w, '"tolerance" must be a number, 0 or more');
      }
    }
    if (it.containsKey('unit') && !_text(it['unit'])) {
      _err('empty_text', w, '"unit" is empty');
    }
    if (it.containsKey('expression')) _expression(it, w, answer);
  }

  void _expression(Map it, String w, double? stated) {
    final e = it['expression'];
    if (!_text(e)) {
      _err('empty_text', w, '"expression" is empty');
      return;
    }
    try {
      final value = evaluateExpression(e as String);
      if (stated == null) {
        _err(
          'expression',
          w,
          'expression "$e" has no numeric answer to compare',
        );
      } else if (!numbersMatch(value, stated)) {
        _err(
          'expression',
          w,
          'expression "$e" evaluates to ${_fmt(value)}, the item states ${_fmt(stated)}',
        );
      }
    } on ExpressionException catch (x) {
      _err(
        'expression',
        w,
        'expression "$e" cannot be evaluated: ${x.message}',
      );
    }
  }

  String _fmt(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  void _cloze(Map it, String w) {
    final text = _reqText(it, 'text', w);
    final gaps = it['gaps'];
    final inText = <String>{};
    if (text != null) {
      for (final m in _gapForm.allMatches(text)) {
        if (!inText.add(m.group(1)!)) {
          _err(
            'cloze_gap',
            w,
            'gap {{${m.group(1)}}} appears twice in the text',
          );
        }
      }
      if (inText.isEmpty) {
        _err('cloze_gap', w, 'the text needs at least one gap like {{1}}');
      }
    }
    if (gaps is! Map || gaps.isEmpty) {
      _err('cloze_gap', w, '"gaps" must map each gap number to accepted words');
      return;
    }
    final declared = gaps.keys.map((k) => '$k').toSet();
    if (text != null) {
      for (final g in inText.difference(declared)) {
        _err('cloze_gap', w, 'gap {{$g}} has no accepted words');
      }
      for (final g in declared.difference(inText)) {
        _err('cloze_gap', w, 'gaps lists "$g" but the text has no {{$g}}');
      }
    }
    for (final e in gaps.entries) {
      final v = e.value;
      if (v is! List || v.isEmpty || v.any((x) => !_text(x))) {
        _err(
          'cloze_gap',
          w,
          'gap ${e.key} needs a non-empty list of accepted words',
        );
      }
    }
  }

  void _spelling(Map it, String w) {
    final seen = <String>{};
    void scan(Object? v) {
      if (v is String) {
        for (final h in findUsSpellings(v)) {
          if (seen.add(h.found.toLowerCase())) {
            _warn(
              'us_spelling',
              w,
              'US spelling "${h.found}"; Australian is "${h.suggest}"',
            );
          }
        }
      } else if (v is List) {
        v.forEach(scan);
      } else if (v is Map) {
        for (final e in v.entries) {
          if (e.key == 'id' || e.key == 'image' || e.key == 'audio') continue;
          scan(e.value);
        }
      }
    }

    scan(it);
  }
}
