import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_word_builder/word_builder.dart';

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
      expect(find.byKey(WordBuilderIds.wordBuilderCheck), findsNothing);
      final tiles = round.current!.tiles;
      await t.tap(
        find.byKey(WordBuilderIds.wordBuilderTile(tiles.indexOf('g'))),
      );
      await t.pump();
      expect(find.text('Not that letter. Have another go.'), findsOneWidget);
      for (final ch in ['d', 'o', 'g']) {
        await t.tap(
          find.byKey(WordBuilderIds.wordBuilderTile(tiles.indexOf(ch))),
        );
        await t.pump();
      }
      expect(log.single.correct, isTrue);
      expect(find.byKey(WordBuilderIds.wordBuilderFeedback), findsOneWidget);
      // After a miss the correct spelling is shown.
      expect(find.text('The spelling is: dog'), findsOneWidget);
      await t.ensureVisible(find.byKey(WordBuilderIds.wordBuilderNext));
      await t.tap(find.byKey(WordBuilderIds.wordBuilderNext));
      await t.pump();
      expect(find.byKey(WordBuilderIds.wordBuilderSummary), findsOneWidget);
      await t.tap(find.byKey(WordBuilderIds.wordBuilderNext));
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
    expect(find.byKey(WordBuilderIds.wordBuilderTimer), findsOneWidget);
    expect(find.text('The ____ is big.'), findsOneWidget);
    // Wrong order first, then Check.
    for (final ch in ['a', 'c', 't']) {
      await t.tap(
        find.byKey(WordBuilderIds.wordBuilderTile(tiles.indexOf(ch))),
      );
      await t.pump();
    }
    await t.ensureVisible(find.byKey(WordBuilderIds.wordBuilderCheck));
    await t.tap(find.byKey(WordBuilderIds.wordBuilderCheck));
    await t.pump();
    expect(find.text('Not quite. Have another go.'), findsOneWidget);
    expect(find.text('The spelling is: cat'), findsOneWidget);
    for (final ch in ['c', 'a', 't']) {
      await t.tap(
        find.byKey(WordBuilderIds.wordBuilderTile(tiles.indexOf(ch))),
      );
      await t.pump();
    }
    await t.ensureVisible(find.byKey(WordBuilderIds.wordBuilderCheck));
    await t.tap(find.byKey(WordBuilderIds.wordBuilderCheck));
    await t.pump();
    expect(log.length, 1);
    expect(find.byKey(WordBuilderIds.wordBuilderFeedback), findsOneWidget);
    await t.ensureVisible(find.byKey(WordBuilderIds.wordBuilderNext));
    await t.tap(find.byKey(WordBuilderIds.wordBuilderNext));
    await t.pump();
    expect(scores.length, 1);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
