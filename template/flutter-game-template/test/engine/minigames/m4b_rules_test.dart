import 'dart:math';

import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

ContentItem _numeric(int i, Object answer) => ContentItem({
  'id': 'n.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'numeric',
  'explanation': 'x',
  'prompt': 'What is it?',
  'answer': answer,
});

ContentItem _word(int i, String answer) => ContentItem({
  'id': 'w.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'word',
  'explanation': 'x',
  'answer': answer,
  'hint': 'Clue for $answer',
});

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
  group('Equation builder', () {
    test('evaluates with the usual order and rejects bad shapes', () {
      expect(evaluateTokens(['2', '+', '3', '×', '4']), 14);
      expect(evaluateTokens(['12', '÷', '4', '−', '1']), 2);
      expect(evaluateTokens(['5']), 5);
      expect(evaluateTokens(['5', '+']), isNull);
      expect(evaluateTokens(['+', '5', '3']), isNull);
      expect(evaluateTokens(['4', '÷', '0']), isNull);
      expect(evaluateTokens([]), isNull);
    });

    test('any valid equation that equals the target counts', () {
      expect(equationHitsTarget(['6', '+', '6'], 12), isTrue);
      expect(equationHitsTarget(['3', '×', '4'], 12), isTrue);
      expect(equationHitsTarget(['20', '−', '8'], 12), isTrue);
      expect(equationHitsTarget(['2', '×', '5'], 12), isFalse);
      expect(equationHitsTarget(['12', '+'], 12), isFalse);
    });

    test('the target comes from a whole-number numeric item only', () {
      expect(equationTarget(_numeric(1, 12)), 12);
      expect(equationTarget(_numeric(2, '1,000')), isNull);
      expect(equationTarget(_numeric(3, 2.5)), isNull);
      expect(equationTarget(_numeric(4, -3)), isNull);
      expect(equationTarget(_word(5, 'cat')), isNull);
    });

    test('every built puzzle can be solved with its own tiles', () {
      for (final level in [
        const MiniGameLevel.younger(),
        const MiniGameLevel.older(),
        const MiniGameLevel.older(harder: true),
      ]) {
        final s = EquationSettings.forLevel(level);
        for (var seed = 0; seed < 30; seed++) {
          for (final t in [0, 1, 2, 7, 12, 36, 100]) {
            final p = buildEquation(_numeric(1, t), s, Random(seed))!;
            expect(equationHitsTarget(p.solution, t), isTrue, reason: '$t');
            // The solution tiles are in the bank (each once).
            final bank = [...p.tiles];
            for (final tile in p.solution) {
              expect(bank.remove(tile), isTrue);
            }
            expect(p.tiles.length, greaterThanOrEqualTo(4));
          }
        }
      }
    });

    test('younger levels use only plus and minus and have no timer', () {
      final s = EquationSettings.forLevel(const MiniGameLevel.younger());
      expect(s.secondsPerQuestion, 0);
      for (var seed = 0; seed < 20; seed++) {
        final p = buildEquation(_numeric(1, 9), s, Random(seed))!;
        expect(p.tiles.where((t) => t == opMul || t == opDiv), isEmpty);
      }
      expect(
        EquationSettings.forLevel(const MiniGameLevel.older())
            .secondsPerQuestion,
        greaterThan(
          EquationSettings.forLevel(const MiniGameLevel.older(harder: true))
              .secondsPerQuestion,
        ),
      );
    });

    test('the same seed builds the same puzzle', () {
      final s = EquationSettings.forLevel(const MiniGameLevel.older());
      final a = buildEquation(_numeric(1, 24), s, Random(9))!;
      final b = buildEquation(_numeric(1, 24), s, Random(9))!;
      expect(a.tiles, b.tiles);
    });
  });

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

  group('Word grid', () {
    final words = [
      for (final (i, w) in [
        'PLANET',
        'ORBIT',
        'STAR',
        'MOON',
        'COMET',
        'SUN',
      ].indexed)
        gridWordFromItem(_word(i, w.toLowerCase()))!,
    ];

    test('only letter answers of 3 to 10 letters become grid words', () {
      expect(gridWordFromItem(_word(1, 'cat'))!.word, 'CAT');
      expect(gridWordFromItem(_word(2, 'at')), isNull);
      expect(gridWordFromItem(_word(3, 'ice cream')), isNull);
      expect(gridWordFromItem(_word(4, 'extraordinary')), isNull);
      expect(gridWordFromItem(_numeric(5, 3)), isNull);
      expect(
        leadingGridWords([_word(1, 'cat'), _word(2, 'a b'), _word(3, 'dog')])
            .map((w) => w.word),
        ['CAT'],
      );
    });

    test('word search hides every word, overlapping only on equal letters', () {
      for (var seed = 0; seed < 25; seed++) {
        for (final level in [
          const MiniGameLevel.younger(),
          const MiniGameLevel.older(),
          const MiniGameLevel.older(harder: true),
        ]) {
          final s = WordGridSettings.forLevel(level);
          final g = buildWordGrid(GridKind.wordSearch, words, s, Random(seed))!;
          expect(g.kind, GridKind.wordSearch);
          expect(g.placed.length, lessThanOrEqualTo(s.maxWords));
          expect(g.placed.length, greaterThanOrEqualTo(2));
          for (final p in g.placed) {
            final cells = p.cells;
            for (final (i, c) in cells.indexed) {
              expect(c.$1, inInclusiveRange(0, g.rows - 1));
              expect(c.$2, inInclusiveRange(0, g.cols - 1));
              expect(g.letters[c.$1][c.$2], p.word.word[i]);
            }
            expect(wordForSelection(g, cells.first, cells.last), p);
            expect(wordForSelection(g, cells.last, cells.first), p);
          }
          // No empty cells are left.
          expect(g.letters.every((r) => r.every((l) => l.isNotEmpty)), isTrue);
          // The placed words are the first of the round, in order.
          expect(
            {for (final p in g.placed) p.word.id},
            {for (final w in words.take(g.placed.length)) w.id},
          );
        }
      }
    });

    test('younger word search runs across and down only', () {
      final s = WordGridSettings.forLevel(const MiniGameLevel.younger());
      for (var seed = 0; seed < 20; seed++) {
        final g = buildWordGrid(GridKind.wordSearch, words, s, Random(seed))!;
        for (final p in g.placed) {
          expect(p.dRow >= 0 && p.dCol >= 0 && p.dRow + p.dCol == 1, isTrue);
        }
      }
    });

    test('the same seed gives the same grid', () {
      final s = WordGridSettings.forLevel(const MiniGameLevel.older());
      final a = buildWordGrid(GridKind.wordSearch, words, s, Random(5))!;
      final b = buildWordGrid(GridKind.wordSearch, words, s, Random(5))!;
      expect(a.letters, b.letters);
    });

    test('selections that are not a word or not a line match nothing', () {
      final s = WordGridSettings.forLevel(const MiniGameLevel.older());
      final g = buildWordGrid(GridKind.wordSearch, words, s, Random(2))!;
      expect(wordForSelection(g, (0, 0), (0, 0)), isNull);
      expect(lineBetween((0, 0), (1, 2)), isNull);
      expect(lineBetween((0, 0), (2, 2)), [(0, 0), (1, 1), (2, 2)]);
      expect(lineBetween((2, 0), (0, 0)), [(2, 0), (1, 0), (0, 0)]);
    });

    test(
      'crossword words cross, agree on letters and never run side by side',
      () {
        for (var seed = 0; seed < 25; seed++) {
          final s = WordGridSettings.forLevel(const MiniGameLevel.older());
          final g = buildWordGrid(GridKind.crossword, words, s, Random(seed))!;
          expect(g.placed.length, greaterThanOrEqualTo(2));
          // Rebuild the letters from the placed words: they must match the grid exactly.
          final seen = <(int, int), String>{};
          for (final p in g.placed) {
            for (final (i, c) in p.cells.indexed) {
              expect(seen[c] ?? p.word.word[i], p.word.word[i]);
              seen[c] = p.word.word[i];
              expect(g.letters[c.$1][c.$2], p.word.word[i]);
            }
          }
          for (var r = 0; r < g.rows; r++) {
            for (var c = 0; c < g.cols; c++) {
              expect(g.letters[r][c].isNotEmpty, seen.containsKey((r, c)));
            }
          }
          // Each word crosses at least one other word.
          for (final p in g.placed) {
            final crossing = p.cells.where(
              (c) => g.placed
                  .where((q) => q != p && q.cells.contains(c))
                  .isNotEmpty,
            );
            expect(crossing, isNotEmpty);
          }
          // Two words in the same direction never share a cell.
          for (final p in g.placed) {
            for (final q in g.placed) {
              if (p == q || p.across != q.across) continue;
              expect(p.cells.toSet().intersection(q.cells.toSet()), isEmpty);
            }
          }
          // Clues are numbered from 1.
          expect(g.placed.every((p) => p.number >= 1), isTrue);
        }
      },
    );

    test('crossword answers are matched exactly as listed, in any case', () {
      final s = WordGridSettings.forLevel(const MiniGameLevel.older());
      final g = buildWordGrid(GridKind.crossword, words, s, Random(1))!;
      final p = g.placed.first;
      expect(crosswordAnswerMatches(p, p.word.word.toLowerCase()), isTrue);
      expect(crosswordAnswerMatches(p, '${p.word.word}S'), isFalse);
    });

    test('fewer than two words give no grid', () {
      final s = WordGridSettings.forLevel(const MiniGameLevel.older());
      expect(
        buildWordGrid(
          GridKind.wordSearch,
          words.take(1).toList(),
          s,
          Random(1),
        ),
        isNull,
      );
    });
  });
}
