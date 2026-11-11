import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/minigames/memory_match_screen.dart';
import 'package:flutter_game_template/ui/minigames/sort_bins_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _pairs(int i) => {
  'id': 'm.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'pairs',
  'explanation': 'Pairs explained $i',
  'prompt': 'Match the pairs $i',
  'pairs': [
    for (var k = 0; k < 3; k++) {'left': 'L$i$k', 'right': 'R$i$k'},
  ],
};

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
  group('registry', () {
    final reg = MiniGameRegistry([
      RegistryEntry(memoryMatchGame),
      RegistryEntry(sortBinsGame),
    ]);
    List<PoolItem> pool(List<Map<String, dynamic>> items) =>
        ReleaseEngine.ordered(_packs(items), 'maths', 3);

    test('each game appears only with enough open items of its type', () {
      List<String> ids(List<Map<String, dynamic>> items) => [
        for (final o in reg.offers(
          open: pool(items),
          subject: 'maths',
          year: 3,
          mode: MiniGameMode.game,
          unlocked: {},
        ))
          o.game.id,
      ];
      expect(ids([_pairs(1), _pairs(2)]), isEmpty);
      expect(ids([_pairs(1), _pairs(2), _pairs(3)]), [memoryMatchId]);
      expect(ids([_cat(1), _cat(2), _cat(3)]), [sortBinsId]);
      expect(
        ids([
          for (var i = 1; i <= 3; i++) _pairs(i),
          for (var i = 4; i <= 6; i++) _cat(i),
        ]),
        [memoryMatchId, sortBinsId],
      );
    });

    test('both games work in Game and Study mode', () {
      expect(memoryMatchGame.modes, MiniGameMode.values.toSet());
      expect(sortBinsGame.modes, MiniGameMode.values.toSet());
    });
  });

  for (final mode in MiniGameMode.values) {
    testWidgets('Memory match plays a board in ${mode.name} mode', (t) async {
      final s = _session([_pairs(1), _pairs(2), _pairs(3)], take: 1);
      final log = <AnswerResult>[];
      var exited = false;
      late MemoryMatchScreen screen;
      screen = MemoryMatchScreen(
        session: s,
        mode: mode,
        onExit: () => exited = true,
        onAnswered: (r, _) => log.add(r),
        level: MatchLevel.younger,
        random: Random(1),
        mismatchDelay: const Duration(milliseconds: 10),
      );
      await t.pumpWidget(_wrap(screen));
      expect(find.byKey(TestIds.matchPrompt), findsOneWidget);
      // Cards are face down: no card text is visible yet.
      expect(find.text('L10'), findsNothing);
      // Flip all cards of one pair by reading their order from the rules.
      final b = MemoryMatchBoard.fromItem(
        s.items.first.item,
        MatchLevel.younger,
        Random(1),
      );
      for (var p = 0; p < b.pairCount; p++) {
        final idx = [
          for (var i = 0; i < b.cards.length; i++)
            if (b.cards[i].pairIndex == p) i,
        ];
        await t.tap(find.byKey(TestIds.matchCard(idx[0])));
        await t.pump();
        await t.tap(find.byKey(TestIds.matchCard(idx[1])));
        await t.pump();
      }
      expect(log.length, 1);
      expect(log.single.correct, isTrue);
      expect(find.byKey(TestIds.matchFeedback), findsOneWidget);
      expect(find.text('Pairs explained 1'), findsOneWidget);
      expect(find.byKey(TestIds.matchTimer), findsNothing);
      await t.tap(find.byKey(TestIds.matchNext));
      await t.pump();
      expect(find.byKey(TestIds.matchSummary), findsOneWidget);
      await t.tap(find.byKey(TestIds.matchNext));
      expect(exited, isTrue);
    });
  }

  testWidgets('Memory match mismatch hides again; older shows a timer', (
    t,
  ) async {
    final s = _session([_pairs(1), _pairs(2), _pairs(3)], take: 1);
    await t.pumpWidget(
      _wrap(
        MemoryMatchScreen(
          session: s,
          mode: MiniGameMode.game,
          onExit: () {},
          level: MatchLevel.older,
          random: Random(1),
          mismatchDelay: const Duration(milliseconds: 50),
        ),
        scale: 1.5,
      ),
    );
    expect(find.byKey(TestIds.matchTimer), findsOneWidget);
    final b = MemoryMatchBoard.fromItem(
      s.items.first.item,
      MatchLevel.older,
      Random(1),
    );
    final other = b.cards.indexWhere(
      (c) => c.pairIndex != b.cards[0].pairIndex,
    );
    await t.tap(find.byKey(TestIds.matchCard(0)));
    await t.pump();
    await t.tap(find.byKey(TestIds.matchCard(other)));
    await t.pump();
    expect(find.text(b.cards[0].text), findsOneWidget);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text(b.cards[0].text), findsNothing);
    expect(t.takeException(), isNull);
  });

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
      expect(find.byKey(TestIds.sortBin(0)), findsOneWidget);
      expect(find.byKey(TestIds.sortBin(1)), findsOneWidget);
      expect(find.byKey(TestIds.sortBin(2)), findsNothing);
      // One wrong tap is allowed and does not end the round.
      final first = round.current!.bin;
      await t.tap(find.byKey(TestIds.sortBin(1 - first)));
      await t.pump();
      expect(find.text('Not that bin. Have another go.'), findsOneWidget);
      while (!round.complete) {
        final bin = round.current!.bin;
        round.drop(bin);
        await t.ensureVisible(find.byKey(TestIds.sortBin(bin)));
        await t.tap(find.byKey(TestIds.sortBin(bin)));
        await t.pump();
      }
      expect(log.length, 1);
      expect(log.single.correct, isTrue);
      expect(find.byKey(TestIds.sortFeedback), findsOneWidget);
      await t.ensureVisible(find.byKey(TestIds.sortNext));
      await t.tap(find.byKey(TestIds.sortNext));
      await t.pump();
      expect(find.byKey(TestIds.sortSummary), findsOneWidget);
      await t.tap(find.byKey(TestIds.sortNext));
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
    expect(find.byKey(TestIds.sortBin(2)), findsOneWidget);
    expect(find.byKey(TestIds.sortTimer), findsOneWidget);
  });
}
