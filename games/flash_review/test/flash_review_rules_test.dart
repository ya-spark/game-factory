import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_flash_review/flash_review.dart';

ContentItem mcq({
  Object correct = 1,
  List<String> options = const ['a', 'b', 'c', 'd'],
}) => ContentItem({
  'id': 'a.1',
  'seq': 1,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': 'e',
  'prompt': 'Pick',
  'options': options,
  'correct': correct,
});

ContentItem other(Map<String, dynamic> j) => ContentItem({
  'id': 'o.1',
  'seq': 1,
  'difficulty': 1,
  'explanation': 'e',
  ...j,
});

void main() {
  group('Flash review rules', () {
    test('every item type has a front and a back', () {
      final cases = <ContentItem, (String, String)>{
        mcq(): ('Pick', 'b'),
        other({'type': 'numeric', 'prompt': 'q', 'answer': 4.0, 'unit': 'cm'}):
            ('q', '4 cm'),
        other({
          'type': 'series',
          'prompt': 'Order',
          'steps': ['one', 'two'],
        }): (
          'Order',
          'one, then two',
        ),
        other({
          'type': 'pairs',
          'pairs': [
            {'left': 'cat', 'right': 'meow'},
            {'left': 'dog', 'right': 'woof'},
          ],
        }): (
          'Match each pair\ncat, dog',
          'cat goes with meow\ndog goes with woof',
        ),
        other({'type': 'word', 'answer': 'cat', 'hint': 'pet'}): (
          'Spell the word. Hint: pet',
          'cat',
        ),
        other({
          'type': 'category',
          'prompt': 'Sort',
          'categories': ['A', 'B'],
          'items': [
            {'text': 'x', 'category': 'A'},
            {'text': 'y', 'category': 'B'},
          ],
        }): (
          'Sort\nA, B',
          'x: A\ny: B',
        ),
        other({
          'type': 'cloze',
          'text': 'The {{1}} sat.',
          'gaps': {
            '1': ['cat', 'kitten'],
          },
        }): (
          'The ___ sat.',
          'The cat sat.',
        ),
      };
      cases.forEach((item, want) {
        expect(flashPrompt(item), want.$1, reason: item.type.name);
        expect(flashAnswer(item), want.$2, reason: item.type.name);
      });
    });

    test('the run counts known and not yet', () {
      final r = FlashReviewRun()
        ..mark(knew: true)
        ..mark(knew: false)
        ..mark(knew: true);
      expect((r.known, r.notYet, r.total), (2, 1, 3));
    });
  });
}
