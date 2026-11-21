import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_sort_bins/sort_bins.dart';

Map<String, dynamic> _cat(int i) => {
  'id': 's.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'category',
  'explanation': 'Sorted $i',
  'prompt': 'Sort them $i',
  'categories': ['Alpha', 'Beta'],
  'items': [
    {'text': 'a1', 'category': 'Alpha'},
    {'text': 'a2', 'category': 'Alpha'},
    {'text': 'b1', 'category': 'Beta'},
    {'text': 'b2', 'category': 'Beta'},
  ],
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

QuizSession _session(List<Map<String, dynamic>> items, {int take = 3}) {
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
    testWidgets('Sort into bins plays a round in ${mode.name} mode', (t) async {
      final s = _session([_cat(1), _cat(2), _cat(3)], take: 1);
      final log = <AnswerResult>[];
      var exited = false;
      await t.pumpWidget(
        _wrap(
          SortBinsScreen(
            session: s,
            mode: mode,
            onExit: () => exited = true,
            onAnswered: (r, _) => log.add(r),
            level: SortLevel.younger,
            random: Random(2),
          ),
          scale: 1.5,
        ),
      );
      final round = SortRound.fromItem(
        s.items.first.item,
        SortLevel.younger,
        Random(2),
      );
      expect(find.byKey(SortBinsIds.sortBin(0)), findsOneWidget);
      expect(find.byKey(SortBinsIds.sortBin(1)), findsOneWidget);
      expect(find.byKey(SortBinsIds.sortBin(2)), findsNothing);
      // One wrong tap is allowed and does not end the round.
      final first = round.current!.bin;
      await t.tap(find.byKey(SortBinsIds.sortBin(1 - first)));
      await t.pump();
      expect(find.text('Not that bin. Have another go.'), findsOneWidget);
      while (!round.complete) {
        final bin = round.current!.bin;
        round.drop(bin);
        await t.ensureVisible(find.byKey(SortBinsIds.sortBin(bin)));
        await t.tap(find.byKey(SortBinsIds.sortBin(bin)));
        await t.pump();
      }
      expect(log.length, 1);
      expect(log.single.correct, isTrue);
      expect(find.byKey(SortBinsIds.sortFeedback), findsOneWidget);
      await t.ensureVisible(find.byKey(SortBinsIds.sortNext));
      await t.tap(find.byKey(SortBinsIds.sortNext));
      await t.pump();
      expect(find.byKey(SortBinsIds.sortSummary), findsOneWidget);
      await t.tap(find.byKey(SortBinsIds.sortNext));
      expect(exited, isTrue);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('Sort into bins older level shows 3 bins and a timer', (t) async {
    final item = _cat(1);
    item['categories'] = ['Alpha', 'Beta', 'Gamma'];
    (item['items'] as List).add({'text': 'g1', 'category': 'Gamma'});
    final s = _session([item, _cat(2), _cat(3)], take: 1);
    await t.pumpWidget(
      _wrap(
        SortBinsScreen(
          session: s,
          mode: MiniGameMode.game,
          onExit: () {},
          level: SortLevel.older,
          random: Random(3),
        ),
      ),
    );
    expect(find.byKey(SortBinsIds.sortBin(2)), findsOneWidget);
    expect(find.byKey(SortBinsIds.sortTimer), findsOneWidget);
  });
}
