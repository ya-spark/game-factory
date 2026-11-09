/// Converts one pack's CSV (exported from Excel or Google Sheets) into pack
/// JSON, and keeps item ids stable across edits through an "ids" file.
///
/// Layout (see docs/CONTENT_FORMAT.md):
///  * `#meta,<key>,<value>` rows set pack fields (id, version, subject, year,
///    topic, title, product_id, preview_description).
///  * One header row starting with `type`, then one row per item.
///  * Multi-value cells: `|` separates entries, `=` separates a pair, `/`
///    separates accepted alternatives; `\|`, `\=` and `\/` write the symbol.
library;

import 'dart:convert';

import 'csv.dart';
import 'models.dart';
import 'numeric.dart';

const List<String> csvColumns = [
  'type',
  'seq',
  'difficulty',
  'topic',
  'prompt',
  'explanation',
  'image',
  'image_alt',
  'audio',
  'preview',
  'options',
  'correct',
  'steps',
  'pairs',
  'answer',
  'hint',
  'letters',
  'categories',
  'items',
  'tolerance',
  'unit',
  'expression',
  'gaps',
];

const Set<String> _metaKeys = {
  'id',
  'version',
  'subject',
  'year',
  'topic',
  'title',
  'product_id',
  'preview_description',
};

/// Columns that each type may fill (besides the common ones).
const Map<ItemType, Set<String>> _typeColumns = {
  ItemType.mcq: {'prompt', 'options', 'correct', 'expression'},
  ItemType.series: {'prompt', 'steps'},
  ItemType.pairs: {'prompt', 'pairs'},
  ItemType.word: {'answer', 'hint', 'letters'},
  ItemType.category: {'prompt', 'categories', 'items'},
  ItemType.numeric: {'prompt', 'answer', 'tolerance', 'unit', 'expression'},
  ItemType.cloze: {'prompt', 'gaps'},
};
const Set<String> _commonColumns = {
  'type',
  'seq',
  'difficulty',
  'topic',
  'explanation',
  'image',
  'image_alt',
  'audio',
  'preview',
};

class CsvConversion {
  CsvConversion(this.pack, this.idsJson, this.problems);

  /// Pack JSON (may still fail validation; run the validator on it).
  final Map<String, dynamic> pack;

  /// New contents of the ids file.
  final Map<String, dynamic> idsJson;

  /// Problems with the CSV itself (unknown column, bad row ...).
  final List<String> problems;

  bool get ok => problems.isEmpty;
}

/// Splits [s] on unescaped [sep]; `\` escapes the next character.
List<String> splitEscaped(String s, String sep) {
  final out = <String>[];
  final cur = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == r'\' && i + 1 < s.length && '|=/\\'.contains(s[i + 1])) {
      // Swap the escaped symbol for a control character until [_unprotect].
      cur.write(String.fromCharCode(_escapes.indexOf(s[i + 1]) + 1));
      i++;
    } else if (c == sep) {
      out.add(cur.toString());
      cur.clear();
    } else {
      cur.write(c);
    }
  }
  out.add(cur.toString());
  return out;
}

const String _escapes = r'|=/\';

String _unprotect(String s) => s.replaceAllMapped(
  RegExp('[\x01-\x04]'),
  (m) => _escapes[m.group(0)!.codeUnitAt(0) - 1],
);

/// Entries of a `|` cell, escapes still protected (see [_unprotect]).
List<String> _list(String cell) => [
  for (final p in splitEscaped(cell, '|'))
    if (p.trim().isNotEmpty) p.trim(),
];

List<String> _plain(String cell) => [
  for (final p in _list(cell)) _unprotect(p),
];

/// Splits `a=b` into a key and value; null when there is no unescaped `=`.
MapEntry<String, String>? _kv(String entry) {
  final parts = splitEscaped(entry, '=');
  if (parts.length < 2) return null;
  return MapEntry(
    _unprotect(parts.first).trim(),
    parts.sublist(1).join('=').trim(), // still protected
  );
}

Object _intOrText(String s) => int.tryParse(s.trim()) ?? s.trim();

/// Converts [csvText]. [previousIds] is the ids file from the last run (or
/// null the first time).
CsvConversion convertCsv(String csvText, {String? previousIds}) {
  final problems = <String>[];
  final List<List<String>> rows;
  try {
    rows = parseCsv(csvText);
  } on FormatException catch (e) {
    return CsvConversion({}, {}, ['CSV: ${e.message}']);
  }

  final meta = <String, String>{};
  List<String>? header;
  final itemRows = <MapEntry<int, Map<String, String>>>[]; // sheet row, cells
  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    final line = r + 1;
    if (row.every((c) => c.trim().isEmpty)) continue;
    final first = row.first.trim();
    if (first == '#meta') {
      final k = row.length > 1 ? row[1].trim() : '';
      final v = row.length > 2 ? row[2].trim() : '';
      if (!_metaKeys.contains(k)) {
        problems.add('row $line: unknown #meta key "$k"');
      } else {
        meta[k] = v;
      }
      continue;
    }
    if (first.startsWith('#')) continue; // comment row
    if (header == null) {
      if (first != 'type') {
        problems.add('row $line: expected the header row starting with "type"');
        continue;
      }
      header = [for (final h in row) h.trim()];
      for (final h in header) {
        if (h.isNotEmpty && !csvColumns.contains(h)) {
          problems.add('row $line: unknown column "$h"');
        }
      }
      continue;
    }
    final cells = <String, String>{};
    for (var c = 0; c < header.length && c < row.length; c++) {
      if (header[c].isNotEmpty && row[c].trim().isNotEmpty) {
        cells[header[c]] = row[c].trim();
      }
    }
    for (var c = header.length; c < row.length; c++) {
      if (row[c].trim().isNotEmpty) {
        problems.add('row $line: text in a column without a header');
      }
    }
    itemRows.add(MapEntry(line, cells));
  }
  if (header == null) problems.add('no header row (first cell "type") found');

  // Pack fields.
  final packId = meta['id'] ?? '';
  if (packId.isEmpty) problems.add('#meta id is missing');
  final productId =
      (meta['product_id'] ?? '').isEmpty || meta['product_id'] == 'null'
      ? null
      : meta['product_id'];

  // Items.
  final items = <Map<String, dynamic>>[];
  final previewFlags = <bool>[];
  final primaryKeys = <String>[];
  for (var n = 0; n < itemRows.length; n++) {
    final line = itemRows[n].key;
    final cells = itemRows[n].value;
    final type = ItemType.parse(cells['type']);
    if (type == null) {
      problems.add(
        'row $line: type must be one of '
        '${ItemType.values.map((t) => t.name).join(', ')}',
      );
      continue;
    }
    final allowed = {..._commonColumns, ..._typeColumns[type]!};
    for (final k in cells.keys) {
      if (!allowed.contains(k)) {
        problems.add('row $line: column "$k" is not used by type ${type.name}');
      }
    }
    final item = <String, dynamic>{};
    item['seq'] = cells.containsKey('seq') ? _intOrText(cells['seq']!) : n + 1;
    if (cells.containsKey('difficulty')) {
      item['difficulty'] = _intOrText(cells['difficulty']!);
    }
    item['type'] = type.name;
    if (cells.containsKey('topic')) item['topic'] = cells['topic'];
    if (cells.containsKey('explanation')) {
      item['explanation'] = cells['explanation'];
    }
    for (final k in ['image', 'image_alt', 'audio']) {
      if (cells.containsKey(k)) item[k] = cells[k];
    }
    _typeFields(type, cells, item, line, problems);
    if (cells.containsKey('expression') &&
        (type == ItemType.mcq || type == ItemType.numeric)) {
      item['expression'] = cells['expression'];
    }
    final flag = (cells['preview'] ?? '').toLowerCase();
    if (flag.isNotEmpty &&
        !const {
          'yes',
          'y',
          'true',
          '1',
          'no',
          'n',
          'false',
          '0',
        }.contains(flag)) {
      problems.add('row $line: preview must be yes or no');
    }
    previewFlags.add(const {'yes', 'y', 'true', '1'}.contains(flag));
    primaryKeys.add(
      '${type.name}:${(cells['prompt'] ?? cells['answer'] ?? '').toLowerCase()}',
    );
    items.add(item);
  }

  // Stable ids.
  final ids = _IdBook.parse(previousIds, packId);
  final assigned = ids.assign(items, primaryKeys);
  final newBook = ids.toJson();
  for (var i = 0; i < items.length; i++) {
    items[i] = {'id': assigned[i], ...items[i]};
  }

  // Preview block.
  Map<String, dynamic>? preview;
  final wantsPreview =
      productId != null ||
      (meta['preview_description'] ?? '').isNotEmpty ||
      previewFlags.any((f) => f);
  if (wantsPreview) {
    final counts = <String, int>{};
    for (final it in items) {
      final t = (it['topic'] ?? meta['topic'] ?? '') as String;
      counts[t] = (counts[t] ?? 0) + 1;
    }
    preview = {
      'description': meta['preview_description'] ?? '',
      'outline': [
        for (final e in counts.entries) {'topic': e.key, 'count': e.value},
      ],
      'item_ids': [
        for (var i = 0; i < items.length; i++)
          if (previewFlags[i]) items[i]['id'],
      ],
    };
  }

  final pack = <String, dynamic>{
    'id': packId,
    'version': meta.containsKey('version') ? _intOrText(meta['version']!) : 1,
    'lang': contentLang,
    'subject': meta['subject'] ?? '',
    'year': _intOrText(meta['year'] ?? ''),
    'topic': meta['topic'] ?? '',
    'title': meta['title'] ?? '',
    'product_id': productId,
    'licence': contentLicence,
    'preview': ?preview,
    'items': items,
  };
  return CsvConversion(pack, newBook, problems);
}

void _typeFields(
  ItemType type,
  Map<String, String> c,
  Map<String, dynamic> item,
  int line,
  List<String> problems,
) {
  switch (type) {
    case ItemType.mcq:
      if (c.containsKey('prompt')) item['prompt'] = c['prompt'];
      item['options'] = _plain(c['options'] ?? '');
      final correct = [
        for (final p in _plain(c['correct'] ?? ''))
          (int.tryParse(p) ?? -999999) - 1,
      ];
      if (correct.any((x) => x < -1000)) {
        problems.add(
          'row $line: "correct" must be option numbers like 2 or 1|3',
        );
      }
      item['correct'] = correct.length == 1 ? correct.single : correct;
    case ItemType.series:
      if (c.containsKey('prompt')) item['prompt'] = c['prompt'];
      item['steps'] = _plain(c['steps'] ?? '');
    case ItemType.pairs:
      if (c.containsKey('prompt')) item['prompt'] = c['prompt'];
      final pairs = <Map<String, String>>[];
      for (final e in _list(c['pairs'] ?? '')) {
        final kv = _kv(e);
        if (kv == null) {
          problems.add('row $line: pair "$e" needs left=right');
        } else {
          pairs.add({'left': kv.key, 'right': _unprotect(kv.value)});
        }
      }
      item['pairs'] = pairs;
    case ItemType.word:
      if (c.containsKey('answer')) item['answer'] = c['answer'];
      if (c.containsKey('hint')) item['hint'] = c['hint'];
      if (c.containsKey('letters')) item['letters'] = c['letters'];
    case ItemType.category:
      if (c.containsKey('prompt')) item['prompt'] = c['prompt'];
      item['categories'] = _plain(c['categories'] ?? '');
      final entries = <Map<String, String>>[];
      for (final e in _list(c['items'] ?? '')) {
        final kv = _kv(e);
        if (kv == null) {
          problems.add('row $line: item "$e" needs text=category');
        } else {
          entries.add({'text': kv.key, 'category': _unprotect(kv.value)});
        }
      }
      item['items'] = entries;
    case ItemType.numeric:
      if (c.containsKey('prompt')) item['prompt'] = c['prompt'];
      if (c.containsKey('answer')) {
        final a = c['answer']!;
        // Keep a clean number when it is one; otherwise keep the text so the
        // validator reports it.
        final n = parseNumeric(a);
        item['answer'] = n == null
            ? a
            : (n == n.roundToDouble() && n.abs() < 1e15 ? n.toInt() : n);
      }
      if (c.containsKey('tolerance')) {
        item['tolerance'] = parseNumeric(c['tolerance']!) ?? c['tolerance'];
      }
      if (c.containsKey('unit')) item['unit'] = c['unit'];
    case ItemType.cloze:
      if (c.containsKey('prompt')) item['text'] = c['prompt'];
      final gaps = <String, List<String>>{};
      for (final e in _list(c['gaps'] ?? '')) {
        final kv = _kv(e);
        if (kv == null) {
          problems.add('row $line: gap "$e" needs number=word/word');
        } else {
          gaps[kv.key] = [
            for (final w in splitEscaped(kv.value, '/'))
              if (_unprotect(w).trim().isNotEmpty) _unprotect(w).trim(),
          ];
        }
      }
      item['gaps'] = gaps;
  }
}

/// The "ids" file: remembers which id each row got.
///
/// Matching a row to an earlier id, in order: (1) identical content, (2) same
/// type and prompt (an edited answer or option), (3) same row number (an
/// edited prompt). Ids of deleted rows are never reused.
class _IdBook {
  _IdBook(this.packId, this.next, this.entries);
  final String packId;
  int next;
  final List<_IdEntry> entries;

  factory _IdBook.parse(String? text, String packId) {
    if (text == null || text.trim().isEmpty) return _IdBook(packId, 1, []);
    final j = jsonDecode(text) as Map<String, dynamic>;
    return _IdBook(packId, j['next'] as int, [
      for (final e in j['rows'] as List)
        _IdEntry(
          e['id'] as String,
          e['hash'] as String,
          e['key'] as String,
          e['row'] as int,
        ),
    ]);
  }

  List<String> assign(List<Map<String, dynamic>> items, List<String> keys) {
    final old = [...entries];
    final result = List<String?>.filled(items.length, null);
    final hashes = [
      for (final it in items) jsonEncode({...it}..remove('seq')),
    ];
    final taken = <_IdEntry>{};

    void pass(bool Function(int i, _IdEntry e) match) {
      for (var i = 0; i < items.length; i++) {
        if (result[i] != null) continue;
        for (final e in old) {
          if (taken.contains(e) || !match(i, e)) continue;
          result[i] = e.id;
          taken.add(e);
          break;
        }
      }
    }

    pass((i, e) => e.hash == hashes[i]);
    pass((i, e) => e.key == keys[i] && keys[i].split(':').last.isNotEmpty);
    pass((i, e) => e.row == i);
    for (var i = 0; i < items.length; i++) {
      result[i] ??= '$packId.${(next++).toString().padLeft(4, '0')}';
    }
    entries
      ..clear()
      ..addAll([
        for (var i = 0; i < items.length; i++)
          _IdEntry(result[i]!, hashes[i], keys[i], i),
      ]);
    return result.cast<String>();
  }

  Map<String, dynamic> toJson() => {
    'pack': packId,
    'next': next,
    'rows': [
      for (final e in entries)
        {'id': e.id, 'hash': e.hash, 'key': e.key, 'row': e.row},
    ],
  };
}

class _IdEntry {
  _IdEntry(this.id, this.hash, this.key, this.row);
  final String id;
  final String hash;
  final String key;
  final int row;
}
