import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_word_grid/word_grid.dart';

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

void main() {
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
