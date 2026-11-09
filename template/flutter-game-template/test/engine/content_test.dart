import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

final Topics topics = Topics.parse(
  File('content/topics.yaml').readAsStringSync(),
);

Map<String, dynamic> samplePack() => jsonDecode(
  File('test/fixtures/sample_times_tables.json').readAsStringSync(),
) as Map<String, dynamic>;

List<Map<String, dynamic>> itemsOf(Map<String, dynamic> p) =>
    (p['items'] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> itemOfType(Map<String, dynamic> p, String type) =>
    itemsOf(p).firstWhere((i) => i['type'] == type);

ValidationResult check(Object? pack, {AssetChecker? assets}) =>
    validatePack(pack, topics: topics, assets: assets);

void expectCode(ValidationResult r, String code) {
  expect(r.errors.map((e) => e.code), contains(code), reason: '${r.issues}');
}

void main() {
  group('numeric answers', () {
    test('equivalent forms are the same number', () {
      for (final s in ['0.5', '.5', '0.50', '+0.5', '00.5', '0.5 ']) {
        expect(parseNumeric(s), 0.5, reason: s);
      }
      for (final s in ['1000', '1,000', '1 000', '1 000', '1000.0']) {
        expect(parseNumeric(s), 1000, reason: s);
      }
      expect(parseNumeric('-3'), -3);
      expect(parseNumeric('−3'), -3);
      expect(parseNumeric('-.5'), -0.5);
      expect(parseNumeric('12,345,678'), 12345678);
    });

    test('fractions and other text are not numbers', () {
      for (final s in [
        '1/2',
        '1,5',
        '1,00',
        '',
        ' ',
        'abc',
        '1e3',
        '.',
        '1 2',
        '5%',
      ]) {
        expect(parseNumeric(s), isNull, reason: s);
      }
    });

    test('checking typed answers and tolerance', () {
      expect(isNumericAnswerCorrect('.5', 0.5), isTrue);
      expect(isNumericAnswerCorrect('1,000', '1000'), isTrue);
      expect(isNumericAnswerCorrect('3.14', 3.1416, tolerance: 0.01), isTrue);
      expect(isNumericAnswerCorrect('3.2', 3.1416, tolerance: 0.01), isFalse);
      expect(isNumericAnswerCorrect('1/2', 0.5), isFalse);
    });
  });

  group('expressions', () {
    test('evaluates arithmetic', () {
      expect(evaluateExpression('2 + 3 * 4'), 14);
      expect(evaluateExpression('(2 + 3) * 4'), 20);
      expect(evaluateExpression('6 × 4'), 24);
      expect(evaluateExpression('20 ÷ 8'), 2.5);
      expect(evaluateExpression('2^3'), 8);
      expect(evaluateExpression('-3 + 5'), 2);
      expect(evaluateExpression('0.1 + 0.2'), closeTo(0.3, 1e-12));
    });

    test('rejects bad input', () {
      for (final s in ['', '2 +', '(2', '2 / 0', '2 & 3', 'abc']) {
        expect(
          () => evaluateExpression(s),
          throwsA(isA<ExpressionException>()),
          reason: s,
        );
      }
    });
  });

  group('spelling', () {
    test('finds US spellings, accepts Australian ones', () {
      expect(findUsSpellings('Pick a color'), isNotEmpty);
      expect(findUsSpellings('We organized the math lesson').length, 2);
      expect(findUsSpellings('colour organise maths centre'), isEmpty);
    });
  });

  group('topics file', () {
    test('covers maths and English, Foundation to Year 12', () {
      expect(topics.subjects, {'maths', 'english'});
      for (final s in topics.subjects) {
        for (var y = 0; y <= 12; y++) {
          expect(topics.topicsFor(s, y), isNotEmpty, reason: '$s year $y');
        }
      }
    });
  });

  group('good packs', () {
    test('sample pack is valid with one size warning', () {
      final r = check(samplePack());
      expect(r.errors, isEmpty);
      expect(r.warnings.map((w) => w.code), ['pack_size']);
    });

    test('every one of the seven types is in the sample', () {
      final types = itemsOf(samplePack()).map((i) => i['type']).toSet();
      expect(types, ItemType.values.map((t) => t.name).toSet());
    });

    test('built-in pack needs no preview', () {
      final p = samplePack()
        ..['product_id'] = null
        ..remove('preview');
      expect(check(p).errors, isEmpty);
    });

    test('multiple correct answers and numeric strings are fine', () {
      final p = samplePack();
      itemOfType(p, 'mcq')['correct'] = [0, 2];
      itemOfType(p, 'numeric')['answer'] = '1,000';
      itemOfType(p, 'numeric')['expression'] = '500*2';
      expect(check(p).errors, isEmpty, reason: '${check(p).issues}');
    });
  });

  group('errors', () {
    test('not an object / wrong top-level fields', () {
      expectCode(check([]), 'schema');
      final p = samplePack()
        ..['lang'] = 'en-US'
        ..['licence'] = 'x'
        ..['extra'] = 1
        ..['version'] = 0;
      final r = check(p);
      expect(
        r.errors.where((e) => e.code == 'schema').length,
        greaterThanOrEqualTo(4),
      );
    });

    test('unknown subject and unknown topic', () {
      expectCode(check(samplePack()..['subject'] = 'art'), 'unknown_subject');
      expectCode(check(samplePack()..['topic'] = 'made_up'), 'unknown_topic');
      expectCode(check(samplePack()..['year'] = 4), 'unknown_topic');
      final p = samplePack();
      itemsOf(p).first['topic'] = 'nope';
      expectCode(check(p), 'unknown_topic');
    });

    test('missing or empty explanation', () {
      final p = samplePack();
      itemsOf(p)[0].remove('explanation');
      expectCode(check(p), 'missing_explanation');
      final q = samplePack();
      itemsOf(q)[0]['explanation'] = '  ';
      expectCode(check(q), 'missing_explanation');
    });

    test('image needs alt text', () {
      final p = samplePack();
      itemsOf(p)[0]['image'] = 'assets/content/a.png';
      expectCode(check(p), 'missing_image_alt');
      itemsOf(p)[0]['image_alt'] = 'A picture';
      expect(check(p).hasCode('missing_image_alt'), isFalse);
    });

    test('ids and seq must be unique', () {
      final p = samplePack();
      itemsOf(p)[1]['id'] = itemsOf(p)[0]['id'];
      itemsOf(p)[3]['seq'] = itemsOf(p)[2]['seq'];
      final r = check(p);
      expectCode(r, 'duplicate_id');
      expectCode(r, 'duplicate_seq');
    });

    test('ids unique across packs', () {
      final a = samplePack();
      final b = samplePack()..['id'] = 'other_pack';
      final r = validatePacks([
        MapEntry('a.json', a),
        MapEntry('b.json', b),
      ], topics: topics);
      expectCode(r, 'duplicate_id');
      final c = samplePack();
      final r2 = validatePacks([
        MapEntry('a.json', a),
        MapEntry('c.json', c),
      ], topics: topics);
      expectCode(r2, 'duplicate_pack_id');
    });

    test('mcq correct answers', () {
      final p = samplePack();
      final m = itemOfType(p, 'mcq');
      for (final bad in [
        9,
        -1,
        [1, 1],
        <int>[],
        'a',
        [0, 'x'],
      ]) {
        m['correct'] = bad;
        expectCode(check(p), 'bad_correct');
      }
      m['correct'] = 0;
      m['options'] = ['only'];
      expect(check(p).errors, isNotEmpty);
    });

    test('expression must match the stated answer', () {
      final p = samplePack();
      itemOfType(p, 'numeric')['expression'] = '7*9';
      expectCode(check(p), 'expression');
      itemOfType(p, 'numeric')['expression'] = '7 *';
      expectCode(check(p), 'expression');
      final q = samplePack();
      final m = itemsOf(q).firstWhere((i) => i['expression'] != null);
      m['correct'] = 1; // option "20" is not 6*4
      expectCode(check(q), 'expression');
    });

    test('numeric answers that are not numbers', () {
      for (final bad in ['1/2', 'seven', '', null, true]) {
        final p = samplePack();
        final n = itemOfType(p, 'numeric')..remove('expression');
        n['answer'] = bad;
        expectCode(check(p), 'numeric_answer');
      }
      final p = samplePack();
      itemOfType(p, 'numeric')['tolerance'] = -1;
      expect(check(p).errors, isNotEmpty);
    });

    test('empty text', () {
      for (final type in ['mcq', 'series', 'word']) {
        final p = samplePack();
        final i = itemOfType(p, type);
        if (type == 'mcq') i['prompt'] = ' ';
        if (type == 'series') i['steps'] = ['a', ''];
        if (type == 'word') i['hint'] = '';
        expectCode(check(p), 'empty_text');
      }
    });

    test('series, pairs, word and category structure', () {
      final p = samplePack();
      itemOfType(p, 'series')['steps'] = ['one'];
      expect(check(p).errors, isNotEmpty);

      final q = samplePack();
      itemOfType(q, 'pairs')['pairs'] = [
        {'left': 'a'},
        {'left': 'b', 'right': 'c'},
      ];
      expectCode(check(q), 'schema');

      final w = samplePack();
      itemOfType(w, 'word')['letters'] = 'prod';
      expectCode(check(w), 'bad_letters');

      final c = samplePack();
      final cat = itemOfType(c, 'category');
      (cat['items'] as List).first['category'] = 'Prime';
      expectCode(check(c), 'bad_correct');
      final d = samplePack();
      itemOfType(d, 'category')['categories'] = ['Even', 'Odd', 'Unused'];
      expectCode(check(d), 'bad_correct');
    });

    test('cloze gaps must match the text', () {
      final p = samplePack();
      final cl = itemOfType(p, 'cloze');
      cl['gaps'] = {
        '1': ['4'],
      };
      expectCode(check(p), 'cloze_gap'); // gap 2 has no words
      cl['gaps'] = {
        '1': ['4'],
        '2': ['5'],
        '3': ['6'],
      };
      expectCode(check(p), 'cloze_gap'); // gap 3 not in text
      cl['gaps'] = {
        '1': ['4'],
        '2': <String>[],
      };
      expectCode(check(p), 'cloze_gap'); // empty list
      cl['text'] = 'No gaps here.';
      expectCode(check(p), 'cloze_gap');
    });

    test('preview ids belong to the pack', () {
      final p = samplePack();
      (p['preview'] as Map)['item_ids'] = ['missing.0001'];
      expectCode(check(p), 'preview_id');
      final q = samplePack()..remove('preview');
      expect(check(q).errors, isNotEmpty); // extra pack needs a preview
      final e = samplePack();
      (e['preview'] as Map)['item_ids'] = <String>[]; // empty is allowed
      expect(check(e).errors, isEmpty);
    });

    test('outline counts must match the full part', () {
      final p = samplePack();
      ((p['preview'] as Map)['outline'] as List).first['count'] = 3;
      expectCode(check(p), 'outline_count');
      final q = samplePack();
      ((q['preview'] as Map)['outline'] as List).add({
        'topic': 'money',
        'count': 1,
      });
      expect(check(q).hasCode('outline_count'), isTrue);
    });

    test('item topic shifts the outline', () {
      final p = samplePack();
      itemsOf(p)[0]['topic'] = 'money'; // not allowed for year 3 maths
      expectCode(check(p), 'unknown_topic');
      itemsOf(p)[0]['topic'] = 'time_calendars';
      final r = check(p);
      expectCode(r, 'outline_count');
      expect(r.hasCode('unknown_topic'), isFalse);
    });
  });

  group('assets', () {
    AssetChecker checker({bool exists = true, String lic = ''}) =>
        AssetChecker(exists: (_) => exists, licensesText: lic);

    Map<String, dynamic> withImage() {
      final p = samplePack();
      itemsOf(p)[0]
        ..['image'] = 'assets/content/cat.png'
        ..['image_alt'] = 'A cat';
      itemsOf(p)[1]['audio'] = 'assets/content/say.mp3';
      return p;
    }

    test('listed and present passes', () {
      final r = check(
        withImage(),
        assets: checker(
          lic: '| assets/content/cat.png | x | y |\n| assets/content/say.mp3 | x | y |',
        ),
      );
      expect(r.errors, isEmpty, reason: '${r.issues}');
    });

    test('missing file', () {
      final r = check(
        withImage(),
        assets: checker(
          exists: false,
          lic: 'assets/content/cat.png assets/content/say.mp3',
        ),
      );
      expectCode(r, 'asset_missing');
    });

    test('not in LICENSES.md', () {
      final r = check(
        withImage(),
        assets: checker(lic: 'assets/content/cat.png'),
      );
      expectCode(r, 'asset_license');
    });

    test('unsafe paths', () {
      final p = samplePack();
      itemsOf(p)[0]
        ..['image'] = '../secret.png'
        ..['image_alt'] = 'x';
      expectCode(check(p), 'asset_path');
    });
  });

  group('warnings', () {
    List<Map<String, dynamic>> manyItems(int n) {
      final base = itemsOf(samplePack()).first;
      return [
        for (var i = 1; i <= n; i++) {...base, 'id': 'p.$i', 'seq': i},
      ];
    }

    test('pack size outside 20 to 50 warns, inside does not', () {
      for (final n in [19, 51]) {
        final p = samplePack()
          ..['product_id'] = null
          ..remove('preview')
          ..['items'] = manyItems(n);
        final r = check(p);
        expect(r.errors, isEmpty);
        expect(r.warnings.map((w) => w.code), contains('pack_size'));
        expect(r.ok, isTrue);
      }
      for (final n in [20, 50]) {
        final p = samplePack()
          ..['product_id'] = null
          ..remove('preview')
          ..['items'] = manyItems(n);
        expect(check(p).issues, isEmpty);
      }
    });

    test('US spellings warn but do not fail', () {
      final p = samplePack();
      itemsOf(p)[0]['prompt'] = 'Which color is the math book?';
      final r = check(p);
      expect(r.ok, isTrue);
      expect(r.warnings.where((w) => w.code == 'us_spelling').length, 2);
    });
  });

  group('pool report', () {
    test('counts by type, subject, year and topic', () {
      final report = PoolReport.of([ContentPack(samplePack())]);
      expect(report.total, 10);
      expect(report.byType['mcq'], 3);
      expect(report.byType['cloze'], 1);
      expect(report.bySubject, {'maths': 10});
      expect(report.byYear, {'03': 10});
      expect(report.byTopic['maths/03/times_tables'], 10);
      expect(
        report.count(type: ItemType.numeric, subject: 'maths', year: 3),
        2,
      );
      expect(report.count(subject: 'english'), 0);
      expect(
        report.meetsMinimum(
          types: {ItemType.mcq, ItemType.series},
          minimum: 4,
          subject: 'maths',
          year: 3,
        ),
        isTrue,
      );
      expect(
        report.meetsMinimum(types: {ItemType.pairs}, minimum: 4, year: 3),
        isFalse,
      );
      expect(report.format(), contains('10 items'));
    });
  });

  group('CSV conversion', () {
    final csv = File('test/fixtures/sample_pack.csv').readAsStringSync();

    test('sample CSV matches the sample JSON and validates', () {
      final c = convertCsv(csv);
      expect(c.problems, isEmpty);
      expect(c.pack, samplePack());
      expect(check(c.pack).errors, isEmpty);
    });

    test('CSV parser handles quotes, CRLF and BOM', () {
      final rows = parseCsv('﻿a,"b,1","say ""hi"""\r\n"x\ny",,\r\n');
      expect(rows, [
        ['a', 'b,1', 'say "hi"'],
        ['x\ny', '', ''],
      ]);
      expect(() => parseCsv('"open'), throwsFormatException);
    });

    String ids(CsvConversion c) =>
        (c.pack['items'] as List).map((i) => i['id']).join(',');

    test('ids are stable across edits, reordering and deletion', () {
      final first = convertCsv(csv);
      final idsText = jsonEncode(first.idsJson);
      final original = {
        for (final i in itemsOf(first.pack))
          i['prompt'] ?? i['answer']: i['id'],
      };

      // Same CSV again: same ids.
      expect(ids(convertCsv(csv, previousIds: idsText)), ids(first));

      // Edit an answer (options and correct index) of row 1 and an explanation.
      final edited = csv
          .replaceAll('10|11|12|13,3', '10|11|12|14,3')
          .replaceAll('Six fours are twenty-four.', 'Six lots of four is 24.');
      final e = convertCsv(edited, previousIds: idsText);
      expect(ids(e), ids(first));

      // Edit a prompt in place (same row number keeps the id).
      final e2 = convertCsv(
        csv.replaceAll('What is 3 × 4?', 'What is 4 × 3?'),
        previousIds: idsText,
      );
      expect(ids(e2), ids(first));

      // Delete row 1: the others keep their ids; new row gets a new id
      // that is never one of the old ones.
      final lines = csv.split('\n');
      final i = lines.indexWhere(
        (l) => l.startsWith('mcq,1,times_tables,What is 3'),
      );
      final without = [...lines]..removeAt(i);
      final d = convertCsv(without.join('\n'), previousIds: idsText);
      expect(itemsOf(d.pack).first['id'], original['What is 6 × 4?']);
      expect(d.pack['items'], hasLength(9));
      final added = convertCsv(
        '${without.join('\n')}\nmcq,1,times_tables,New one?,Because.,,a|b,1,,,,,,,,,,,\n',
        previousIds: jsonEncode(d.idsJson),
      );
      final newId = itemsOf(added.pack).last['id'];
      expect(original.values, isNot(contains(newId)));
      expect(newId, 'sample_times_tables.0011');

      // Reordered rows keep their ids with the content.
      final head = lines.take(9).toList();
      final body = lines.skip(9).where((l) => l.isNotEmpty).toList();
      final swapped = convertCsv(
        [...head, body[1], body[0], ...body.skip(2)].join('\n'),
        previousIds: idsText,
      );
      final byPrompt = {
        for (final i in itemsOf(swapped.pack))
          i['prompt'] ?? i['answer']: i['id'],
      };
      expect(byPrompt, original);
    });

    test('CSV problems are reported', () {
      final bad = [
        '#meta,id,x',
        '#meta,colour,red',
        'type,difficulty,bogus',
        'mcq,1,zzz',
        'nope,1,',
        'numeric,1,,,,,,,,,,,,,,,,,,',
      ].join('\n');
      final c = convertCsv(bad);
      expect(c.ok, isFalse);
      expect(c.problems.join('\n'), contains('unknown #meta key'));
      expect(c.problems.join('\n'), contains('unknown column "bogus"'));
      expect(c.problems.join('\n'), contains('type must be one of'));
      expect(convertCsv('a,b').problems.join(), contains('header'));
    });

    test('a column from another type is rejected', () {
      final c = convertCsv('#meta,id,x\ntype,steps,options\nmcq,a|b,c|d\n');
      expect(c.problems.join(), contains('"steps" is not used by type mcq'));
    });

    test('escapes and numbers in cells', () {
      final c = convertCsv(
        [
          '#meta,id,esc',
          '#meta,subject,maths',
          '#meta,year,3',
          '#meta,topic,times_tables',
          '#meta,title,T',
          'type,difficulty,prompt,explanation,options,correct,pairs,answer',
          r'mcq,1,Pick,Why,a\|b|c,1|2,,',
          'pairs,1,,Why,,,a=b|c\\=d=e,',
          'numeric,1,Q,Why,,,,"1,000"',
        ].join('\n'),
      );
      final items = itemsOf(c.pack);
      expect(items[0]['options'], ['a|b', 'c']);
      expect(items[0]['correct'], [0, 1]);
      expect(items[1]['pairs'], [
        {'left': 'a', 'right': 'b'},
        {'left': 'c=d', 'right': 'e'},
      ]);
      expect(items[2]['answer'], 1000);
    });
  });

  group('index and signing', () {
    final keyText = File('test/fixtures/test_only_signing_key.txt')
        .readAsStringSync();

    Map<String, dynamic> index() => buildIndex(
      app: 'craft_lowteen',
      version: 3,
      packFiles: {
        'packs/sample_times_tables.json': Uint8List.fromList(
          File('test/fixtures/sample_times_tables.json').readAsBytesSync(),
        ),
      },
      readAsset: (_) => null,
    );

    test('index lists sha256 and size of each pack file', () {
      final idx = index();
      final bytes = File('test/fixtures/sample_times_tables.json')
          .readAsBytesSync();
      final pack = (idx['packs'] as List).single as Map;
      expect(pack['file'], {
        'path': 'packs/sample_times_tables.json',
        'sha256': sha256Hex(bytes),
        'size': bytes.length,
      });
      expect(pack['items'], 10);
      expect(idx['app'], 'craft_lowteen');
      expect(idx['format'], indexFormat);
      // known sha256 of "abc"
      expect(
        sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('index is deterministic and includes assets', () {
      expect(encodeIndex(index()), encodeIndex(index()));
      final p = samplePack();
      itemsOf(p)[0]
        ..['image'] = 'assets/content/cat.png'
        ..['image_alt'] = 'A cat';
      final idx = buildIndex(
        app: 'a',
        version: 1,
        packFiles: {
          'packs/p.json': Uint8List.fromList(utf8.encode(jsonEncode(p))),
        },
        readAsset: (path) => Uint8List.fromList([1, 2, 3]),
      );
      final assets = ((idx['packs'] as List).single as Map)['assets'] as List;
      expect(assets.single['path'], 'assets/content/cat.png');
      expect(assets.single['size'], 3);
      expect(
        () => buildIndex(
          app: 'a',
          version: 1,
          packFiles: {
            'packs/p.json': Uint8List.fromList(utf8.encode(jsonEncode(p))),
          },
          readAsset: (_) => null,
        ),
        throwsStateError,
      );
    });

    test('sign and verify round trip with the test key', () async {
      final seed = parseSigningKey(keyText);
      expect(seed, hasLength(32));
      final bytes = encodeIndex(index());
      final sig = await signIndex(bytes, seed);
      final pub = await publicKeyOf(seed);
      expect(await verifyIndex(bytes, sig, pub), isTrue);
      // Signing is deterministic for Ed25519.
      expect(await signIndex(bytes, seed), sig);
    });

    test('a changed index or wrong key fails verification', () async {
      final seed = parseSigningKey(keyText);
      final bytes = encodeIndex(index());
      final sig = await signIndex(bytes, seed);
      final pub = await publicKeyOf(seed);
      final tampered = Uint8List.fromList([...bytes, 32]);
      expect(await verifyIndex(tampered, sig, pub), isFalse);
      final other = await publicKeyOf(List.filled(32, 7));
      expect(await verifyIndex(bytes, sig, other), isFalse);
      expect(await verifyIndex(bytes, 'not base64!', pub), isFalse);
    });

    test('bad key files are rejected', () {
      expect(() => parseSigningKey(''), throwsFormatException);
      expect(() => parseSigningKey('# c\nAAAA'), throwsFormatException);
    });
  });
}
