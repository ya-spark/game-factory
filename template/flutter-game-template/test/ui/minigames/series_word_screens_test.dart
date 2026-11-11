import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/minigames/series_builder_screen.dart';
import 'package:flutter_game_template/ui/minigames/word_builder_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _series(int i) => {
  'id': 'se.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'series',
  'explanation': 'Series explained $i',
  'prompt': 'Put in order $i',
  'steps': ['one', 'two', 'three', 'four'],
};

Map<String, dynamic> _word(int i, String answer) => {
  'id': 'w.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'word',
  'explanation': 'Word explained $i',
  'answer': answer,
  'hint': 'Hint $i',
};

Map<String, dynamic> _cloze(int i) => {
  'id': 'c.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'cloze',
  'explanation': 'Cloze explained $i',
  'text': 'The {{1}} is big.',
  'gaps': {
    '1': ['cat'],
  },
};

List<LoadedPack> _packs(List<Map<String, dynamic>> items) => [
  LoadedPack(
    ContentPack({
      'id': 'p',
      'version': 1,
      'lang': 'en-AU',
      'subject': 'maths',
      'year': 3,
      'topic': 't',
      'title': 'p',
      'items': items,
    }),
  ),
];

QuizSession _session(List<Map<String, dynamic>> items, {int take = 1}) {
  final packs = _packs(items);
  return QuizSession(
    items: ReleaseEngine.ordered(packs, 'maths', 3).take(take).toList(),
    progress: const ChildProgress(),
    packs: packs,
    rewardsConfig: const RewardsConfig(),
    today: 100,
  );
}

Widget _wrap(Widget child, {double scale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 900),
      textScaler: TextScaler.linear(scale),
    ),
    child: child,
  ),
);

void main() {
  group('registry', () {
    final reg = MiniGameRegistry([
      RegistryEntry(seriesBuilderGame),
      RegistryEntry(wordBuilderGame),
    ]);
    List<String> ids(List<Map<String, dynamic>> items) => [
      for (final o in reg.offers(
        open: ReleaseEngine.ordered(_packs(items), 'maths', 3),
        subject: 'maths',
        year: 3,
        mode: MiniGameMode.game,
        unlocked: {},
      ))
        o.game.id,
    ];

    test('each game appears only with enough open items of its types', () {
      expect(ids([_series(1), _series(2)]), isEmpty);
      expect(ids([_series(1), _series(2), _series(3)]), [seriesBuilderId]);
      expect(ids([_word(1, 'dog'), _word(2, 'cat'), _cloze(3)]), [
        wordBuilderId,
      ]);
      expect(ids([_word(1, 'dog'), _word(2, 'cat')]), isEmpty);
      expect(
        ids([
          for (var i = 1; i <= 3; i++) _series(i),
          for (var i = 4; i <= 6; i++) _word(i, 'dog'),
        ]),
        [seriesBuilderId, wordBuilderId],
      );
    });

    test('both games work in Game and Study mode', () {
      expect(seriesBuilderGame.modes, MiniGameMode.values.toSet());
      expect(wordBuilderGame.modes, MiniGameMode.values.toSet());
    });
  });

  for (final mode in MiniGameMode.values) {
    testWidgets('Series builder plays a round in ${mode.name} mode', (t) async {
      final s = _session([_series(1), _series(2), _series(3)]);
      final log = <AnswerResult>[];
      final scores = <int>[];
      var exited = false;
      await t.pumpWidget(
        _wrap(
          SeriesBuilderScreen(
            session: s,
            mode: mode,
            onExit: () => exited = true,
            onAnswered: (r, _) => log.add(r),
            onScore: scores.add,
            level: SeriesLevel.younger,
            random: Random(1),
          ),
          scale: 1.5,
        ),
      );
      final round = SeriesRound.fromItem(
        s.items.first.item,
        SeriesLevel.younger,
        Random(1),
      );
      expect(find.byKey(TestIds.seriesTimer), findsNothing);
      // A wrong tile is greyed and the round goes on.
      final wrong = round.tiles.indexOf('two');
      await t.ensureVisible(find.byKey(TestIds.seriesTile(wrong)));
      await t.tap(find.byKey(TestIds.seriesTile(wrong)));
      await t.pump();
      expect(find.text('Not that one next. Have another go.'), findsOneWidget);
      for (final step in round.steps) {
        final i = round.tiles.indexOf(step);
        await t.ensureVisible(find.byKey(TestIds.seriesTile(i)));
        await t.tap(find.byKey(TestIds.seriesTile(i)));
        await t.pump();
      }
      expect(log.length, 1);
      expect(log.single.correct, isTrue);
      expect(find.byKey(TestIds.seriesFeedback), findsOneWidget);
      await t.ensureVisible(find.byKey(TestIds.seriesNext));
      await t.tap(find.byKey(TestIds.seriesNext));
      await t.pump();
      expect(find.byKey(TestIds.seriesSummary), findsOneWidget);
      expect(scores, [10]);
      await t.tap(find.byKey(TestIds.seriesNext));
      expect(exited, isTrue);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('Series builder older level shows a timer', (t) async {
    final s = _session([_series(1), _series(2), _series(3)]);
    await t.pumpWidget(
      _wrap(
        SeriesBuilderScreen(
          session: s,
          mode: MiniGameMode.game,
          onExit: () {},
          level: SeriesLevel.older,
          random: Random(1),
        ),
      ),
    );
    expect(find.byKey(TestIds.seriesTimer), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  for (final mode in MiniGameMode.values) {
    testWidgets('Word builder (younger) builds a word in ${mode.name} mode', (
      t,
    ) async {
      final s = _session([_word(1, 'dog'), _word(2, 'cat'), _word(3, 'pig')]);
      final log = <AnswerResult>[];
      var exited = false;
      await t.pumpWidget(
        _wrap(
          WordBuilderScreen(
            session: s,
            mode: mode,
            onExit: () => exited = true,
            onAnswered: (r, _) => log.add(r),
            level: WordLevel.younger,
            random: Random(1),
          ),
          scale: 1.5,
        ),
      );
      final round = WordRound.fromItem(
        s.items.first.item,
        WordLevel.younger,
        Random(1),
      );
      expect(find.text('Hint 1'), findsOneWidget);
      expect(find.byKey(TestIds.wordBuilderCheck), findsNothing);
      final tiles = round.current!.tiles;
      await t.tap(find.byKey(TestIds.wordBuilderTile(tiles.indexOf('g'))));
      await t.pump();
      expect(find.text('Not that letter. Have another go.'), findsOneWidget);
      for (final ch in ['d', 'o', 'g']) {
        await t.tap(find.byKey(TestIds.wordBuilderTile(tiles.indexOf(ch))));
        await t.pump();
      }
      expect(log.single.correct, isTrue);
      expect(find.byKey(TestIds.wordBuilderFeedback), findsOneWidget);
      // After a miss the correct spelling is shown.
      expect(find.text('The spelling is: dog'), findsOneWidget);
      await t.ensureVisible(find.byKey(TestIds.wordBuilderNext));
      await t.tap(find.byKey(TestIds.wordBuilderNext));
      await t.pump();
      expect(find.byKey(TestIds.wordBuilderSummary), findsOneWidget);
      await t.tap(find.byKey(TestIds.wordBuilderNext));
      expect(exited, isTrue);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('Word builder (older) uses Check and shows the spelling', (
    t,
  ) async {
    final s = _session([_cloze(1), _cloze(2), _cloze(3)]);
    final log = <AnswerResult>[];
    final scores = <int>[];
    await t.pumpWidget(
      _wrap(
        WordBuilderScreen(
          session: s,
          mode: MiniGameMode.game,
          onExit: () {},
          onAnswered: (r, _) => log.add(r),
          onScore: scores.add,
          level: WordLevel.older,
          random: Random(1),
        ),
        scale: 1.5,
      ),
    );
    final round = WordRound.fromItem(
      s.items.first.item,
      WordLevel.older,
      Random(1),
    );
    final tiles = round.current!.tiles;
    expect(find.byKey(TestIds.wordBuilderTimer), findsOneWidget);
    expect(find.text('The ____ is big.'), findsOneWidget);
    // Wrong order first, then Check.
    for (final ch in ['a', 'c', 't']) {
      await t.tap(find.byKey(TestIds.wordBuilderTile(tiles.indexOf(ch))));
      await t.pump();
    }
    await t.ensureVisible(find.byKey(TestIds.wordBuilderCheck));
    await t.tap(find.byKey(TestIds.wordBuilderCheck));
    await t.pump();
    expect(find.text('Not quite. Have another go.'), findsOneWidget);
    expect(find.text('The spelling is: cat'), findsOneWidget);
    for (final ch in ['c', 'a', 't']) {
      await t.tap(find.byKey(TestIds.wordBuilderTile(tiles.indexOf(ch))));
      await t.pump();
    }
    await t.ensureVisible(find.byKey(TestIds.wordBuilderCheck));
    await t.tap(find.byKey(TestIds.wordBuilderCheck));
    await t.pump();
    expect(log.length, 1);
    expect(find.byKey(TestIds.wordBuilderFeedback), findsOneWidget);
    await t.ensureVisible(find.byKey(TestIds.wordBuilderNext));
    await t.tap(find.byKey(TestIds.wordBuilderNext));
    await t.pump();
    expect(scores.length, 1);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
