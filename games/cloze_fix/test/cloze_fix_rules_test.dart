import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_cloze_fix/cloze_fix.dart';

PoolItem _pool(ContentItem it, {String topic = 't', int year = 4}) => PoolItem(
  item: it,
  packId: 'p',
  subject: 'english',
  year: year,
  topic: topic,
);

ContentItem _cloze(int i, String first, List<String> accepted) => ContentItem({
  'id': 'c.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'cloze',
  'explanation': 'x',
  'text': 'The {{1}} sat on the mat.',
  'gaps': {
    '1': [first, ...accepted],
  },
});

void main() {
  group('Cloze and grammar fix', () {
    test('a cloze question has the answer and borrowed wrong words', () {
      final items = [
        _pool(_cloze(1, 'cat', ['kitten'])),
        _pool(_cloze(2, 'dog', [])),
        _pool(_cloze(3, 'bird', [])),
        _pool(_cloze(4, 'fish', [])),
      ];
      final s = ClozeFixSettings.forLevel(const MiniGameLevel.older());
      final q = buildCloze(items.first, items, s, Random(3))!;
      expect(q.text, 'The ____ sat on the mat.');
      expect(q.options, hasLength(4));
      expect(q.options.toSet(), {'cat', 'dog', 'bird', 'fish'});
      expect(q.answer, 'cat');
      // A wrong option never matches an accepted word.
      expect(q.options.where((o) => o == 'kitten'), isEmpty);
    });

    test('grammar mcq items are picked by topic, other mcq are not', () {
      final mcq = ContentItem({
        'id': 'g.1',
        'seq': 1,
        'difficulty': 1,
        'type': 'mcq',
        'explanation': 'x',
        'prompt': 'Which sentence is right?',
        'options': ['She go home.', 'She goes home.'],
        'correct': 1,
      });
      final g = _pool(mcq, topic: 'grammar_verbs');
      final plain = _pool(mcq, topic: 'fractions');
      expect(isGrammarItem(g), isTrue);
      expect(isGrammarItem(plain), isFalse);
      expect(clozeFixPlays(plain), isFalse);
      final s = ClozeFixSettings.forLevel(const MiniGameLevel.younger());
      final q = buildCloze(g, [g], s, Random(1))!;
      expect(q.options, ['She go home.', 'She goes home.']);
      expect(q.correct, {1});
      expect(buildCloze(plain, [plain], s, Random(1)), isNull);
    });

    test('a cloze item with no wrong words to borrow is skipped', () {
      final one = _pool(_cloze(1, 'cat', []));
      final s = ClozeFixSettings.forLevel(const MiniGameLevel.older());
      expect(buildCloze(one, [one], s, Random(1)), isNull);
    });
  });
}
