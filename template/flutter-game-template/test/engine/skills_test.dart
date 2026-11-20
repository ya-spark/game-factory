import 'dart:convert';
import 'dart:io';

import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

final Topics topics = Topics.parse(
  File('content/topics.yaml').readAsStringSync(),
);

const String yamlOk = '''
maths:
  3:
    times_tables:
      - {id: tt_1, name: Getting started, seq: [1, 6]}
      - {id: tt_2, name: Building up, seq: [7, 13]}
      - {id: tt_3, name: Stretch, seq: [14, 20]}
''';

Map<String, dynamic> samplePack() => jsonDecode(
  File('test/fixtures/sample_times_tables.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  group('SkillMap.parse', () {
    test('rungs in order with default prerequisites', () {
      final m = SkillMap.parse(yamlOk, topics);
      final r = m.skillsFor('maths', 3);
      expect(r.map((s) => s.id), ['tt_1', 'tt_2', 'tt_3']);
      expect(r[0].requires, isEmpty);
      expect(r[1].requires, ['maths/3/tt_1']);
      expect(r[2].requires, ['maths/3/tt_2']);
      expect(m.ancestorsOf(r[2]), {'maths/3/tt_1', 'maths/3/tt_2'});
      expect(m.length, 3);
    });

    test(
      'the first rung of a topic needs the first rung of the topic before',
      () {
        final order = topics.orderFor('maths', 3);
        final a = order[0];
        final b = order[1];
        final m = SkillMap.parse('''
maths:
  3:
    $a:
      - {id: a_1, name: A, seq: [1, 10]}
      - {id: a_2, name: A2, seq: [11, 20]}
    $b:
      - {id: b_1, name: B, seq: [1, 20]}
''', topics);
        expect(m.byKey('maths/3/b_1')!.requires, ['maths/3/a_1']);
        expect(m.byKey('maths/3/b_1')!.order, 2);
      },
    );

    test('explicit requires replace the default', () {
      final m = SkillMap.parse('''
maths:
  3:
    times_tables:
      - {id: tt_1, name: A, seq: [1, 10]}
      - {id: tt_2, name: B, seq: [11, 20], requires: []}
''', topics);
      expect(m.byKey('maths/3/tt_2')!.requires, isEmpty);
    });

    void bad(String yaml, String part) {
      expect(
        () => SkillMap.parse(yaml, topics),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(part),
          ),
        ),
      );
    }

    test('rejects unknown subject, topic, overlap, duplicates, cycles', () {
      bad(
        'science:\n  3:\n    x:\n      - {id: a, name: A, seq: [1, 2]}',
        'subject',
      );
      bad(
        'maths:\n  3:\n    nope:\n      - {id: a, name: A, seq: [1, 2]}',
        'topics file',
      );
      bad(
        'maths:\n  3:\n    times_tables:\n      - {id: a, name: A, seq: [1, 10]}\n      - {id: b, name: B, seq: [10, 20]}',
        'overlap',
      );
      bad(
        'maths:\n  3:\n    times_tables:\n      - {id: a, name: A, seq: [1, 10]}\n      - {id: a, name: B, seq: [11, 20]}',
        'used twice',
      );
      bad(
        'maths:\n  3:\n    times_tables:\n      - {id: a, name: A, seq: [1, 10], requires: [b]}\n      - {id: b, name: B, seq: [11, 20]}',
        'cycle',
      );
      bad(
        'maths:\n  3:\n    times_tables:\n      - {id: a, name: A, seq: [1, 10], requires: [zzz]}',
        'does not exist',
      );
    });
  });

  group('skillOf', () {
    final m = SkillMap.parse(yamlOk, topics);
    ContentItem item(int seq, {String? skill}) => ContentItem({
      'id': 'x.$seq',
      'seq': seq,
      'difficulty': 1,
      'type': 'mcq',
      'explanation': 'e',
      'skill': ?skill,
    });
    test('by seq range, by own field, unknown own field', () {
      expect(m.skillOf('maths', 3, 'times_tables', item(1))!.id, 'tt_1');
      expect(m.skillOf('maths', 3, 'times_tables', item(7))!.id, 'tt_2');
      expect(m.skillOf('maths', 3, 'times_tables', item(20))!.id, 'tt_3');
      expect(
        m.skillOf('maths', 3, 'times_tables', item(1, skill: 'tt_3'))!.id,
        'tt_3',
      );
      expect(
        m.skillOf('maths', 3, 'times_tables', item(1, skill: 'zzz')),
        isNull,
      );
      expect(m.skillOf('maths', 3, 'other', item(1)), isNull);
    });
  });

  group('coverage', () {
    final m = SkillMap.parse(yamlOk, topics);
    List<MapEntry<String, Object?>> packs(Map<String, dynamic> p) => [
      MapEntry('p', p),
    ];

    Map<String, dynamic> pack20() {
      final p = samplePack();
      final base = (p['items'] as List).cast<Map<String, dynamic>>();
      p['items'] = [
        for (var i = 1; i <= 20; i++)
          {...base[(i - 1) % base.length], 'id': 'p.$i', 'seq': i},
      ];
      return p;
    }

    test('a full pack with two formats per rung is clean', () {
      final issues = validateSkillCoverage(packs(pack20()), m);
      expect(issues.where((i) => i.isError), isEmpty, reason: '$issues');
    });

    test('a short rung and an item in no rung are errors', () {
      final p = pack20();
      (p['items'] as List).removeRange(12, 20); // rung 3 loses items
      final issues = validateSkillCoverage(packs(p), m);
      expect(issues.map((i) => i.code), contains('skill_pool'));
      final p2 = pack20();
      (p2['items'] as List).last['seq'] = 25;
      expect(
        validateSkillCoverage(packs(p2), m).map((i) => i.code),
        contains('item_no_skill'),
      );
    });

    test('an unknown skill field is an error and a known one is not', () {
      final p = pack20();
      (p['items'] as List).first['skill'] = 'zzz';
      expect(
        validateSkillCoverage(packs(p), m).map((i) => i.code),
        contains('unknown_skill'),
      );
    });

    test('the validator accepts a skill field and rejects an empty one', () {
      final p = samplePack();
      (p['items'] as List).first['skill'] = 'tt_1';
      expect(validatePack(p, topics: topics).errors, isEmpty);
      (p['items'] as List).first['skill'] = '';
      expect(validatePack(p, topics: topics).errors, isNotEmpty);
    });

    test('the pool report groups by skill', () {
      final r = PoolReport.of([ContentPack(pack20())], skills: m);
      expect(
        r.bySkillAndType.keys.any((k) => k.startsWith('maths/3/tt_1/')),
        isTrue,
      );
      expect(r.format(), contains('By skill and type'));
    });
  });
}
