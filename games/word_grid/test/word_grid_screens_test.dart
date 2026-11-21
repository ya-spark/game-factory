import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_word_grid/word_grid.dart';

Map<String, dynamic> _word(int i, String word) => {
  'id': 'w.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'word',
  'explanation': 'Because $i',
  'answer': word,
  'hint': 'Clue for $word',
};

List<LoadedPack> _packs(List<Map<String, dynamic>> items, int year) => [
  LoadedPack(
    ContentPack({
      'id': 'q',
      'version': 1,
      'lang': 'en-AU',
      'subject': 'maths',
      'year': year,
      'topic': 't',
      'title': 'q',
      'items': items,
    }),
  ),
];

QuizSession _session(List<Map<String, dynamic>> items, {int year = 4}) {
  final packs = _packs(items, year);
  return QuizSession(
    items: ReleaseEngine.ordered(packs, 'maths', year),
    progress: const ChildProgress(),
    packs: packs,
    rewardsConfig: const RewardsConfig(),
    today: 100,
  );
}

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      size: const Size(400, 900),
    ),
    child: child,
  ),
);

const _words = ['PLANET', 'ORBIT', 'STAR', 'MOON'];

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  group('Word grid', () {
    final items = [
      for (final (i, w) in _words.indexed) _word(i + 1, w.toLowerCase()),
    ];

    testWidgets('word search: tap first and last letter of each word', (
      t,
    ) async {
      _phone(t);
      final log = <AnswerResult>[];
      int? score;
      final session = _session(items, year: 1);
      final words = leadingGridWords([for (final p in session.items) p.item]);
      final expected = buildWordGrid(
        GridKind.wordSearch,
        words,
        WordGridSettings.forLevel(const MiniGameLevel.younger()),
        Random(7),
      )!;
      await t.pumpWidget(
        _app(
          WordGridScreen(
            session: session,
            level: const MiniGameLevel.younger(),
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            onScore: (v) => score = v,
            random: Random(7),
          ),
        ),
      );
      expect(find.byKey(GameIds.mgTimer(wordGridId)), findsNothing);
      await t.tap(find.byKey(GameIds.mgStart(wordGridId)));
      await t.pump();
      expect(find.byKey(GameIds.mgBanner(wordGridId)), findsNothing);
      expect(find.byKey(WordGridIds.mgGrid(wordGridId)), findsOneWidget);
      // A line that is not a word is told so, gently.
      await t.tap(find.byKey(WordGridIds.mgCell(wordGridId, 0, 0)));
      await t.pump();
      await t.tap(find.byKey(WordGridIds.mgCell(wordGridId, 0, 0)));
      await t.pump();
      for (final p in expected.placed) {
        final c = p.cells;
        await t.tap(
          find.byKey(WordGridIds.mgCell(wordGridId, c.first.$1, c.first.$2)),
        );
        await t.pump();
        await t.tap(
          find.byKey(WordGridIds.mgCell(wordGridId, c.last.$1, c.last.$2)),
        );
        await t.pump();
      }
      expect(find.byKey(GameIds.mgResults(wordGridId)), findsOneWidget);
      expect(log, hasLength(expected.placed.length));
      expect(log.every((r) => r.correct), isTrue);
      expect(score, 10 * expected.placed.length);
    });

    testWidgets(
      'word search: finishing early records unfound words as missed',
      (t) async {
        _phone(t);
        final log = <AnswerResult>[];
        await t.pumpWidget(
          _app(
            WordGridScreen(
              session: _session(items),
              level: const MiniGameLevel.older(),
              study: true,
              onExit: () {},
              onAnswered: (r, _) => log.add(r),
              random: Random(1),
            ),
          ),
        );
        await t.tap(find.byKey(GameIds.mgStart(wordGridId)));
        await t.pump();
        expect(find.byKey(GameIds.mgTimer(wordGridId)), findsNothing);
        await t.ensureVisible(find.byKey(WordGridIds.mgGiveUp(wordGridId)));
        await t.tap(find.byKey(WordGridIds.mgGiveUp(wordGridId)));
        await t.pump();
        expect(find.byKey(GameIds.mgResults(wordGridId)), findsOneWidget);
        expect(log, isNotEmpty);
        expect(log.every((r) => !r.correct), isTrue);
      },
    );

    testWidgets('crossword: tap a clue, tap its letters in order', (t) async {
      _phone(t);
      final log = <AnswerResult>[];
      await t.pumpWidget(
        _app(
          WordGridScreen(
            session: _session(items),
            level: const MiniGameLevel.older(),
            study: true,
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            random: Random(3),
          ),
          scale: 1.5,
        ),
      );
      await t.tap(find.byKey(WordGridIds.mgStartAlt(wordGridId)));
      await t.pump();
      expect(find.byKey(WordGridIds.mgClue(wordGridId, 0)), findsOneWidget);
      var i = 0;
      while (find
          .byKey(WordGridIds.mgClue(wordGridId, i))
          .evaluate()
          .isNotEmpty) {
        final clue = find.byKey(WordGridIds.mgClue(wordGridId, i));
        await t.ensureVisible(clue);
        final text = t.widget<Text>(
          find.descendant(of: clue, matching: find.byType(Text)),
        );
        final word = RegExp(r'Clue for (\w+)')
            .firstMatch(text.data!)!
            .group(1)!
            .toUpperCase();
        await t.tap(clue);
        await t.pump();
        final used = <int>{};
        for (final ch in word.split('')) {
          Finder? pick;
          for (var k = 0; k < word.length && pick == null; k++) {
            final f = find.byKey(WordGridIds.mgLetter(wordGridId, k));
            if (used.contains(k) || f.evaluate().isEmpty) continue;
            if (find
                .descendant(of: f, matching: find.text(ch))
                .evaluate()
                .isNotEmpty) {
              used.add(k);
              pick = f;
            }
          }
          await t.ensureVisible(pick!);
          await t.tap(pick);
          await t.pump();
        }
        i++;
      }
      expect(find.byKey(GameIds.mgResults(wordGridId)), findsOneWidget);
      expect(log.every((r) => r.correct), isTrue);
    });
  });
}
