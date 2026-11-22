import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_series_builder/series_builder.dart';

Map<String, dynamic> _series(int i) => {
  'id': 'se.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'series',
  'explanation': 'Series explained $i',
  'prompt': 'Put in order $i',
  'steps': ['one', 'two', 'three', 'four'],
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
      expect(find.byKey(SeriesBuilderIds.seriesTimer), findsNothing);
      // A wrong tile is greyed and the round goes on.
      final wrong = round.tiles.indexOf('two');
      await t.ensureVisible(find.byKey(SeriesBuilderIds.seriesTile(wrong)));
      await t.tap(find.byKey(SeriesBuilderIds.seriesTile(wrong)));
      await t.pump();
      expect(find.text('Not that one next. Have another go.'), findsOneWidget);
      for (final step in round.steps) {
        final i = round.tiles.indexOf(step);
        await t.ensureVisible(find.byKey(SeriesBuilderIds.seriesTile(i)));
        await t.tap(find.byKey(SeriesBuilderIds.seriesTile(i)));
        await t.pump();
      }
      expect(log.length, 1);
      expect(log.single.correct, isTrue);
      expect(find.byKey(SeriesBuilderIds.seriesFeedback), findsOneWidget);
      await t.ensureVisible(find.byKey(SeriesBuilderIds.seriesNext));
      await t.tap(find.byKey(SeriesBuilderIds.seriesNext));
      await t.pump();
      expect(find.byKey(SeriesBuilderIds.seriesSummary), findsOneWidget);
      expect(scores, [10]);
      await t.tap(find.byKey(SeriesBuilderIds.seriesNext));
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
    expect(find.byKey(SeriesBuilderIds.seriesTimer), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Space goes on after a result and leaves from the results', (
    t,
  ) async {
    final s = _session([_series(1), _series(2), _series(3)]);
    var exited = false;
    await t.pumpWidget(
      _wrap(
        SeriesBuilderScreen(
          session: s,
          mode: MiniGameMode.game,
          onExit: () => exited = true,
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
    for (final step in round.steps) {
      final i = round.tiles.indexOf(step);
      await t.ensureVisible(find.byKey(SeriesBuilderIds.seriesTile(i)));
      await t.tap(find.byKey(SeriesBuilderIds.seriesTile(i)));
      await t.pump();
    }
    expect(find.byKey(SeriesBuilderIds.seriesFeedback), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(find.byKey(SeriesBuilderIds.seriesSummary), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    expect(exited, isTrue);
  });
}
