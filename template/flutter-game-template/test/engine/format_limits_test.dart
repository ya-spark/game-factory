import 'dart:convert';
import 'dart:io';

import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

final Topics topics = Topics.parse(
  File('content/topics.yaml').readAsStringSync(),
);

Map<String, dynamic> samplePack() => jsonDecode(
  File('test/fixtures/sample_times_tables.json').readAsStringSync(),
) as Map<String, dynamic>;

Map<String, dynamic> item(Map<String, dynamic> p, String type) =>
    (p['items'] as List).cast<Map<String, dynamic>>().firstWhere(
      (i) => i['type'] == type,
    );

String chars(int n) => List.filled(n, 'a').join();

/// Validates the sample pack after [change] edits the item of [type].
ValidationResult run(
  String type,
  void Function(Map<String, dynamic> item) change, {
  AssetChecker? assets,
}) {
  final p = samplePack();
  change(item(p, type));
  return validatePack(p, topics: topics, assets: assets);
}

bool limited(ValidationResult r) =>
    r.errors.any((e) => e.code == 'format_limit');

void main() {
  test('the unchanged sample pack is inside the envelope', () {
    expect(validatePack(samplePack(), topics: topics).errors, isEmpty);
  });

  group('common', () {
    test('prompt: 300 passes, 301 fails', () {
      expect(limited(run('mcq', (i) => i['prompt'] = chars(300))), isFalse);
      expect(limited(run('mcq', (i) => i['prompt'] = chars(301))), isTrue);
    });
    test('explanation: 250 passes, 251 fails', () {
      expect(
        limited(run('mcq', (i) => i['explanation'] = chars(250))),
        isFalse,
      );
      expect(limited(run('mcq', (i) => i['explanation'] = chars(251))), isTrue);
    });
    test('markup and edge spaces fail; emoji, symbols and < are fine', () {
      expect(
        limited(run('mcq', (i) => i['prompt'] = 'A <b>bold</b> one')),
        isTrue,
      );
      expect(
        limited(run('mcq', (i) => i['prompt'] = 'Count the \u{1F34E}')),
        isFalse,
      );
      expect(limited(run('mcq', (i) => i['prompt'] = ' leading')), isTrue);
      expect(limited(run('mcq', (i) => i['prompt'] = 'Is 3 < 5?')), isFalse);
      expect(
        limited(run('mcq', (i) => i['prompt'] = 'What is 3 × 4?')),
        isFalse,
      );
    });
    test('image_alt: 120 passes, 121 fails', () {
      final assets = AssetChecker(
        exists: (_) => true,
        licensesText: 'assets/content/cat.png',
      );
      ValidationResult alt(int n) => run('mcq', (i) {
        i['image'] = 'assets/content/cat.png';
        i['image_alt'] = chars(n);
      }, assets: assets);
      expect(limited(alt(120)), isFalse);
      expect(limited(alt(121)), isTrue);
    });
  });

  group('mcq', () {
    test('2 to 4 options', () {
      expect(
        limited(
          run('mcq', (i) {
            i['options'] = ['10', '11', '12', '13', '14'];
          }),
        ),
        isTrue,
      );
      expect(
        limited(
          run('mcq', (i) {
            i['options'] = ['11', '12'];
            i['correct'] = 1;
          }),
        ),
        isFalse,
      );
    });
    test('option text: 150 passes, 151 fails', () {
      ValidationResult opt(int n) => run('mcq', (i) {
        i['options'] = ['10', '11', chars(n), '13'];
        i['correct'] = 2;
        i.remove('expression');
      });
      expect(limited(opt(150)), isFalse);
      expect(limited(opt(151)), isTrue);
    });
    test('exactly one correct', () {
      expect(limited(run('mcq', (i) => i['correct'] = [0, 2])), isTrue);
      expect(limited(run('mcq', (i) => i['correct'] = [2])), isFalse);
    });
  });

  group('series', () {
    ValidationResult steps(List<String> s) =>
        run('series', (i) => i['steps'] = s);
    test('3 to 8 distinct steps', () {
      expect(limited(steps(['1', '2'])), isTrue);
      expect(limited(steps(['1', '2', '3'])), isFalse);
      expect(limited(steps(['1', '2', '3', '4', '5', '6', '7', '8'])), isFalse);
      expect(
        limited(steps(['1', '2', '3', '4', '5', '6', '7', '8', '9'])),
        isTrue,
      );
      expect(limited(steps(['1', '2', '2'])), isTrue);
    });
    test('step text: 80 passes, 81 fails', () {
      expect(limited(steps(['1', '2', chars(80)])), isFalse);
      expect(limited(steps(['1', '2', chars(81)])), isTrue);
    });
  });

  group('pairs', () {
    List<Map<String, String>> pairs(int n, {String Function(int)? right}) => [
      for (var k = 0; k < n; k++)
        {'left': 'L$k', 'right': right == null ? 'R$k' : right(k)},
    ];
    ValidationResult with_(List<Map<String, String>> p) =>
        run('pairs', (i) => i['pairs'] = p);
    test('3 to 6 pairs', () {
      expect(limited(with_(pairs(2))), isTrue);
      expect(limited(with_(pairs(3))), isFalse);
      expect(limited(with_(pairs(6))), isFalse);
      expect(limited(with_(pairs(7))), isTrue);
    });
    test('every right side is different', () {
      expect(limited(with_(pairs(3, right: (_) => 'same'))), isTrue);
    });
    test('side text: 60 passes, 61 fails', () {
      expect(
        limited(with_(pairs(3, right: (k) => k == 0 ? chars(60) : 'R$k'))),
        isFalse,
      );
      expect(
        limited(with_(pairs(3, right: (k) => k == 0 ? chars(61) : 'R$k'))),
        isTrue,
      );
    });
  });

  group('category', () {
    Map<String, String> e(String t, String c) => {'text': t, 'category': c};
    ValidationResult with_(
      List<String> cats,
      List<Map<String, String>> items,
    ) => run('category', (i) {
      i['categories'] = cats;
      i['items'] = items;
    });
    test('3 to 12 items, 2 to 4 categories', () {
      expect(limited(with_(['A', 'B'], [e('1', 'A'), e('2', 'B')])), isTrue);
      expect(
        limited(with_(['A', 'B'], [e('1', 'A'), e('2', 'A'), e('3', 'B')])),
        isFalse,
      );
      expect(
        limited(
          with_(
            ['A', 'B'],
            [for (var k = 0; k < 13; k++) e('$k', k.isEven ? 'A' : 'B')],
          ),
        ),
        isTrue,
      );
      expect(
        limited(
          with_(
            ['A', 'B', 'C', 'D', 'E'],
            [for (var k = 0; k < 10; k++) e('$k', 'ABCDE'[k % 5])],
          ),
        ),
        isTrue,
      );
      expect(
        limited(
          with_(
            ['A', 'B'],
            [for (var k = 0; k < 12; k++) e('$k', k.isEven ? 'A' : 'B')],
          ),
        ),
        isFalse,
      );
    });
    test('a category with a single item is allowed, an empty one is not', () {
      expect(
        limited(
          with_(
            ['A', 'B'],
            [e('1', 'A'), e('2', 'A'), e('3', 'A'), e('4', 'B')],
          ),
        ),
        isFalse,
      );
      final r = with_(
        ['A', 'B'],
        [e('1', 'A'), e('2', 'A'), e('3', 'A'), e('4', 'A')],
      );
      expect(r.errors.map((x) => x.code), contains('bad_correct'));
    });
    test(
      'item text: 80 passes, 81 fails; category name 30 passes, 31 fails',
      () {
        ValidationResult item_(int n) => with_(
          ['A', 'B'],
          [e(chars(n), 'A'), e('2', 'A'), e('3', 'B'), e('4', 'B')],
        );
        expect(limited(item_(80)), isFalse);
        expect(limited(item_(81)), isTrue);
        ValidationResult cat(int n) => with_(
          [chars(n), 'B'],
          [e('1', chars(n)), e('2', chars(n)), e('3', 'B'), e('4', 'B')],
        );
        expect(limited(cat(30)), isFalse);
        expect(limited(cat(31)), isTrue);
      },
    );
  });

  group('word', () {
    ValidationResult answer(String a) => run('word', (i) {
      i['answer'] = a;
      i.remove('letters');
    });
    test('3 to 14 letters, one word, letters only', () {
      expect(limited(answer('ab')), isTrue);
      expect(limited(answer('abc')), isFalse);
      expect(limited(answer(chars(14))), isFalse);
      expect(limited(answer(chars(15))), isTrue);
      expect(limited(answer('two words')), isTrue);
      expect(limited(answer('ab-cd')), isTrue);
    });
    test('hint: 100 passes, 101 fails', () {
      expect(limited(run('word', (i) => i['hint'] = chars(100))), isFalse);
      expect(limited(run('word', (i) => i['hint'] = chars(101))), isTrue);
    });
    test('letters pool: 20 passes, 21 fails', () {
      ValidationResult pool(int n) => run('word', (i) {
        i['answer'] = 'product';
        i['letters'] = 'product${chars(n - 7)}';
      });
      expect(limited(pool(20)), isFalse);
      expect(limited(pool(21)), isTrue);
    });
  });

  group('numeric', () {
    ValidationResult ans(Object a, {String? expression}) => run('numeric', (i) {
      i['answer'] = a;
      if (expression == null) {
        i.remove('expression');
      } else {
        i['expression'] = expression;
      }
    });
    test('8 digits and 3 decimals at most', () {
      expect(limited(ans(12345678, expression: '12345678')), isFalse);
      expect(limited(ans(123456789, expression: '123456789')), isTrue);
      expect(limited(ans(1.234, expression: '1.234')), isFalse);
      expect(limited(ans(1.2345, expression: '1.2345')), isTrue);
    });
    test('unit: 20 passes, 21 fails', () {
      expect(limited(run('numeric', (i) => i['unit'] = chars(20))), isFalse);
      expect(limited(run('numeric', (i) => i['unit'] = chars(21))), isTrue);
    });
    test('an expression is optional, also for maths', () {
      final r = run('numeric', (i) => i.remove('expression'));
      expect(r.errors, isEmpty);
    });
    test('a wrong expression is still an error', () {
      final r = run('numeric', (i) => i['expression'] = '7*7');
      expect(r.errors.map((e) => e.code), contains('expression'));
    });
  });

  group('cloze', () {
    test('1 to 3 gaps', () {
      ValidationResult gaps(int n) => run('cloze', (i) {
        i['text'] = [for (var k = 1; k <= n; k++) '{{$k}}'].join(' + ');
        i['gaps'] = {
          for (var k = 1; k <= n; k++) '$k': ['x'],
        };
      });
      expect(limited(gaps(3)), isFalse);
      expect(limited(gaps(4)), isTrue);
    });
    test('1 to 6 forms of at most 20 characters', () {
      ValidationResult forms(List<String> f) => run('cloze', (i) {
        i['text'] = '{{1}} + 1';
        i['gaps'] = {'1': f};
      });
      expect(limited(forms(['a', 'b', 'c', 'd', 'e', 'f'])), isFalse);
      expect(limited(forms(['a', 'b', 'c', 'd', 'e', 'f', 'g'])), isTrue);
      expect(limited(forms([chars(20)])), isFalse);
      expect(limited(forms([chars(21)])), isTrue);
    });
    test('text: 200 passes, 201 fails', () {
      ValidationResult text(int n) => run('cloze', (i) {
        i['text'] = '{{1}}${chars(n - 5)}';
        i['gaps'] = {
          '1': ['x'],
        };
      });
      expect(limited(text(200)), isFalse);
      expect(limited(text(201)), isTrue);
    });
  });

  group('size class', () {
    Map<String, dynamic> mcq({String? prompt, List<String>? options}) => {
      'id': 'x.1',
      'seq': 1,
      'difficulty': 1,
      'type': 'mcq',
      'explanation': 'e',
      'prompt': prompt ?? 'p',
      'options': options ?? ['a', 'b'],
      'correct': 0,
    };
    test('prompt at 150 is short, 151 long', () {
      expect(ContentItem(mcq(prompt: chars(150))).sizeClass, SizeClass.short);
      expect(ContentItem(mcq(prompt: chars(151))).sizeClass, SizeClass.long);
    });
    test('mcq option at 30 is short, 31 long', () {
      expect(
        ContentItem(mcq(options: [chars(30), 'b'])).sizeClass,
        SizeClass.short,
      );
      expect(
        ContentItem(mcq(options: [chars(31), 'b'])).sizeClass,
        SizeClass.long,
      );
    });
    test('series step at 24 is short, 25 long', () {
      Map<String, dynamic> s(int n) => {
        'type': 'series',
        'prompt': 'p',
        'steps': ['1', '2', chars(n)],
      };
      expect(sizeClassOfJson(s(24)), SizeClass.short);
      expect(sizeClassOfJson(s(25)), SizeClass.long);
    });
    test('pair side at 24 is short, 25 long', () {
      Map<String, dynamic> p(int n) => {
        'type': 'pairs',
        'pairs': [
          {'left': chars(n), 'right': 'r'},
        ],
      };
      expect(sizeClassOfJson(p(24)), SizeClass.short);
      expect(sizeClassOfJson(p(25)), SizeClass.long);
    });
    test('category item at 24 is short, 25 long', () {
      Map<String, dynamic> c(int n) => {
        'type': 'category',
        'items': [
          {'text': chars(n), 'category': 'A'},
        ],
      };
      expect(sizeClassOfJson(c(24)), SizeClass.short);
      expect(sizeClassOfJson(c(25)), SizeClass.long);
    });
    test('word, numeric and cloze are short unless the text is long', () {
      expect(
        sizeClassOfJson({'type': 'word', 'answer': 'cat', 'hint': 'h'}),
        SizeClass.short,
      );
      expect(
        sizeClassOfJson({'type': 'cloze', 'text': chars(151)}),
        SizeClass.long,
      );
    });
    test('the pool report counts by size class', () {
      final report = PoolReport.of([ContentPack(samplePack())]);
      expect(report.count(sizeClass: SizeClass.short), report.total);
      expect(report.byTypeAndSize['mcq/short'], 3);
      expect(report.format(), contains('By type and size class'));
    });
  });
}
