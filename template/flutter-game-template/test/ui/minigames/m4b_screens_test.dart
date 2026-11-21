import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/game_registry.dart';
import 'package:flutter_game_template/ui/minigames/cloze_fix_screen.dart';
import 'package:flutter_game_template/ui/minigames/equation_builder_screen.dart';
import 'package:flutter_game_template/ui/minigames/word_grid_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _numeric(int i, int answer) => {
  'id': 'n.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'numeric',
  'explanation': 'Because $i',
  'prompt': 'Question $i',
  'answer': answer,
};

Map<String, dynamic> _cloze(int i, String word) => {
  'id': 'c.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'cloze',
  'explanation': 'Because $i',
  'text': 'Sentence $i has a {{1}} in it.',
  'gaps': {
    '1': [word],
  },
};

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
  group('Equation builder', () {
    final items = [for (var i = 1; i <= 4; i++) _numeric(i, 5 + i)];

    Future<List<String>> tileTexts(WidgetTester t, int n) async => [
      for (var i = 0; i < n; i++)
        (t.widget<Text>(
          find.descendant(
            of: find.byKey(TestIds.mgTile(equationBuilderId, i)),
            matching: find.byType(Text),
          ),
        )).data!,
    ];

    /// Taps tiles for any equation of the bank that makes [target].
    Future<void> build(WidgetTester t, int target) async {
      final texts = await tileTexts(t, 4);
      for (var a = 0; a < texts.length; a++) {
        for (var b = 0; b < texts.length; b++) {
          for (var c = 0; c < texts.length; c++) {
            if ({a, b, c}.length < 3) continue;
            if (equationHitsTarget([texts[a], texts[b], texts[c]], target)) {
              for (final i in [a, b, c]) {
                final tile = find.byKey(TestIds.mgTile(equationBuilderId, i));
                await t.ensureVisible(tile);
                await t.tap(tile);
                await t.pump();
              }
              return;
            }
          }
        }
      }
      fail('no equation in $texts makes $target');
    }

    testWidgets('younger: any right equation passes; a wrong check retries', (
      t,
    ) async {
      _phone(t);
      final log = <AnswerResult>[];
      int? score;
      await t.pumpWidget(
        _app(
          EquationBuilderScreen(
            session: _session(items, year: 1),
            level: const MiniGameLevel.younger(),
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            onScore: (v) => score = v,
            random: Random(3),
          ),
        ),
      );
      await t.tap(find.byKey(TestIds.mgStart(equationBuilderId)));
      await t.pump();
      expect(find.byKey(TestIds.mgTimer(equationBuilderId)), findsNothing);
      expect(find.byKey(TestIds.mgBanner(equationBuilderId)), findsNothing);
      expect(find.textContaining('Make 6'), findsOneWidget);
      // One tile alone is wrong: the game says so and lets the child try again.
      await t.tap(find.byKey(TestIds.mgTile(equationBuilderId, 0)));
      await t.pump();
      await t.tap(find.byKey(TestIds.mgCheck(equationBuilderId)));
      await t.pump();
      expect(log, isEmpty);
      expect(find.text('Not that one. Try another!'), findsOneWidget);
      await t.tap(find.byKey(TestIds.mgClear(equationBuilderId)));
      await t.pump();
      await build(t, 6);
      await t.tap(find.byKey(TestIds.mgCheck(equationBuilderId)));
      await t.pump();
      expect(log, hasLength(1));
      // The first try was wrong, so it does not count as a first pass.
      expect(log.single.correct, isFalse);
      for (var q = 2; q <= 4; q++) {
        await t.tap(find.byKey(TestIds.mgNext(equationBuilderId)));
        await t.pump();
        await build(t, 5 + q);
        await t.tap(find.byKey(TestIds.mgCheck(equationBuilderId)));
        await t.pump();
      }
      expect(log.skip(1).every((r) => r.correct), isTrue);
      await t.tap(find.byKey(TestIds.mgNext(equationBuilderId)));
      await t.pump();
      expect(find.byKey(TestIds.mgResults(equationBuilderId)), findsOneWidget);
      expect(score, 40);
    });

    testWidgets('older: timed, wrong check shows a working equation', (
      t,
    ) async {
      _phone(t);
      final log = <AnswerResult>[];
      await t.pumpWidget(
        _app(
          EquationBuilderScreen(
            session: _session(items),
            level: const MiniGameLevel.older(),
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            random: Random(4),
          ),
          scale: 1.5,
        ),
      );
      await t.tap(find.byKey(TestIds.mgStart(equationBuilderId)));
      await t.pump();
      expect(find.byKey(TestIds.mgTimer(equationBuilderId)), findsOneWidget);
      await t.tap(find.byKey(TestIds.mgTile(equationBuilderId, 0)));
      await t.pump();
      await t.tap(find.byKey(TestIds.mgCheck(equationBuilderId)));
      await t.pump();
      expect(log.single.correct, isFalse);
      expect(find.textContaining('The answer was'), findsOneWidget);
      expect(find.textContaining('= 6'), findsWidgets);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('Cloze and grammar fix', () {
    final items = [
      for (final (i, w) in ['cat', 'dog', 'bird', 'fish'].indexed)
        _cloze(i + 1, w),
    ];

    testWidgets('older: pick the word that fits the gap', (t) async {
      _phone(t);
      final log = <AnswerResult>[];
      await t.pumpWidget(
        _app(
          ClozeFixScreen(
            session: _session(items),
            level: const MiniGameLevel.older(),
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            random: Random(2),
          ),
          scale: 1.5,
        ),
      );
      await t.tap(find.byKey(TestIds.mgStart(clozeFixId)));
      await t.pump();
      expect(find.byKey(TestIds.mgTimer(clozeFixId)), findsOneWidget);
      expect(find.byKey(TestIds.mgBanner(clozeFixId)), findsNothing);
      for (var q = 1; q <= 4; q++) {
        final prompt =
            (t.widget(find.byKey(TestIds.mgPrompt(clozeFixId))) as Text).data!;
        expect(prompt, 'Sentence $q has a ____ in it.');
        final right = ['cat', 'dog', 'bird', 'fish'][q - 1];
        await t.tap(find.widgetWithText(InkWell, right));
        await t.pump();
        expect(log.last.correct, isTrue);
        await t.tap(find.byKey(TestIds.mgNext(clozeFixId)));
        await t.pump();
      }
      expect(find.byKey(TestIds.mgResults(clozeFixId)), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('study mode has no timer and a wrong pick is retried', (
      t,
    ) async {
      _phone(t);
      final log = <AnswerResult>[];
      await t.pumpWidget(
        _app(
          ClozeFixScreen(
            session: _session(items),
            level: const MiniGameLevel.older(),
            study: true,
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            random: Random(2),
          ),
        ),
      );
      await t.tap(find.byKey(TestIds.mgStart(clozeFixId)));
      await t.pump();
      expect(find.byKey(TestIds.mgTimer(clozeFixId)), findsNothing);
      await t.tap(find.widgetWithText(InkWell, 'dog'));
      await t.pump();
      expect(log, isEmpty);
      expect(find.text('Not that one. Try another!'), findsOneWidget);
      await t.tap(find.widgetWithText(InkWell, 'cat'));
      await t.pump();
      expect(log, hasLength(1));
    });

    testWidgets('grammar mcq: pick the corrected sentence', (t) async {
      _phone(t);
      final grammar = [
        for (var i = 1; i <= 4; i++)
          {
            'id': 'g.$i',
            'seq': i,
            'difficulty': 1,
            'type': 'mcq',
            'topic': 'grammar_verbs',
            'explanation': 'x',
            'prompt': 'Fix sentence $i',
            'options': ['Wrong $i', 'Right $i'],
            'correct': 1,
          },
      ];
      final log = <AnswerResult>[];
      await t.pumpWidget(
        _app(
          ClozeFixScreen(
            session: _session(grammar),
            level: const MiniGameLevel.older(),
            study: true,
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            random: Random(1),
          ),
        ),
      );
      await t.tap(find.byKey(TestIds.mgStart(clozeFixId)));
      await t.pump();
      await t.tap(find.widgetWithText(InkWell, 'Right 1'));
      await t.pump();
      expect(log.single.correct, isTrue);
    });
  });

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
      expect(find.byKey(TestIds.mgTimer(wordGridId)), findsNothing);
      await t.tap(find.byKey(TestIds.mgStart(wordGridId)));
      await t.pump();
      expect(find.byKey(TestIds.mgBanner(wordGridId)), findsNothing);
      expect(find.byKey(TestIds.mgGrid(wordGridId)), findsOneWidget);
      // A line that is not a word is told so, gently.
      await t.tap(find.byKey(TestIds.mgCell(wordGridId, 0, 0)));
      await t.pump();
      await t.tap(find.byKey(TestIds.mgCell(wordGridId, 0, 0)));
      await t.pump();
      for (final p in expected.placed) {
        final c = p.cells;
        await t.tap(
          find.byKey(TestIds.mgCell(wordGridId, c.first.$1, c.first.$2)),
        );
        await t.pump();
        await t.tap(
          find.byKey(TestIds.mgCell(wordGridId, c.last.$1, c.last.$2)),
        );
        await t.pump();
      }
      expect(find.byKey(TestIds.mgResults(wordGridId)), findsOneWidget);
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
        await t.tap(find.byKey(TestIds.mgStart(wordGridId)));
        await t.pump();
        expect(find.byKey(TestIds.mgTimer(wordGridId)), findsNothing);
        await t.ensureVisible(find.byKey(TestIds.mgGiveUp(wordGridId)));
        await t.tap(find.byKey(TestIds.mgGiveUp(wordGridId)));
        await t.pump();
        expect(find.byKey(TestIds.mgResults(wordGridId)), findsOneWidget);
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
      await t.tap(find.byKey(TestIds.mgStartAlt(wordGridId)));
      await t.pump();
      expect(find.byKey(TestIds.mgClue(wordGridId, 0)), findsOneWidget);
      var i = 0;
      while (find.byKey(TestIds.mgClue(wordGridId, i)).evaluate().isNotEmpty) {
        final clue = find.byKey(TestIds.mgClue(wordGridId, i));
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
            final f = find.byKey(TestIds.mgLetter(wordGridId, k));
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
      expect(find.byKey(TestIds.mgResults(wordGridId)), findsOneWidget);
      expect(log.every((r) => r.correct), isTrue);
    });
  });

  group('Registry', () {
    PoolItem pool(Map<String, dynamic> j, {String topic = 't'}) => PoolItem(
      item: ContentItem(j),
      packId: 'p',
      subject: 'maths',
      year: 4,
      topic: topic,
    );

    Set<String> ids(List<PoolItem> open) => {
      for (final o in appGames.offers(
        open: open,
        subject: 'maths',
        year: 4,
        mode: MiniGameMode.game,
        unlocked: const {},
      ))
        o.game.id,
    };

    test('each game appears only when enough items of its types are open', () {
      expect(
        ids([for (var i = 0; i < 3; i++) pool(_numeric(i, 5))]),
        isNot(contains(equationBuilderId)),
      );
      expect(
        ids([for (var i = 0; i < 4; i++) pool(_numeric(i, 5))]),
        contains(equationBuilderId),
      );
      expect(ids([for (var i = 0; i < 4; i++) pool(_cloze(i, 'a$i'))]), {
        clozeFixId,
      });
      expect(
        ids([for (var i = 0; i < 3; i++) pool(_word(i, 'cats'))]),
        isEmpty,
      );
      expect(ids([for (var i = 0; i < 4; i++) pool(_word(i, 'cats'))]), {
        wordGridId,
      });
    });

    test('all three are free and play in Game and Study mode', () {
      for (final id in [equationBuilderId, clozeFixId, wordGridId]) {
        final g = appGames.byId(id)!;
        expect(g.access, GameAccess.freeWithAds);
        expect(g.modes, {MiniGameMode.game, MiniGameMode.study});
      }
    });

    test('the harder builders give a Champion version', () {
      expect(equationBuilderGameFor(harder: true).id, equationBuilderId);
      expect(clozeFixGameFor(harder: true).id, clozeFixId);
      expect(wordGridGameFor(harder: true).id, wordGridId);
    });
  });
}
