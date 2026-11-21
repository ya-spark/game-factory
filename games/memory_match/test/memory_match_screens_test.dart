import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_memory_match/memory_match.dart';

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
      expect(find.byKey(MemoryMatchIds.matchPrompt), findsOneWidget);
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
        await t.tap(find.byKey(MemoryMatchIds.matchCard(idx[0])));
        await t.pump();
        await t.tap(find.byKey(MemoryMatchIds.matchCard(idx[1])));
        await t.pump();
      }
      expect(log.length, 1);
      expect(log.single.correct, isTrue);
      expect(find.byKey(MemoryMatchIds.matchFeedback), findsOneWidget);
      expect(find.text('Pairs explained 1'), findsOneWidget);
      expect(find.byKey(MemoryMatchIds.matchTimer), findsNothing);
      await t.tap(find.byKey(MemoryMatchIds.matchNext));
      await t.pump();
      expect(find.byKey(MemoryMatchIds.matchSummary), findsOneWidget);
      await t.tap(find.byKey(MemoryMatchIds.matchNext));
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
    expect(find.byKey(MemoryMatchIds.matchTimer), findsOneWidget);
    final b = MemoryMatchBoard.fromItem(
      s.items.first.item,
      MatchLevel.older,
      Random(1),
    );
    final other = b.cards.indexWhere(
      (c) => c.pairIndex != b.cards[0].pairIndex,
    );
    await t.tap(find.byKey(MemoryMatchIds.matchCard(0)));
    await t.pump();
    await t.tap(find.byKey(MemoryMatchIds.matchCard(other)));
    await t.pump();
    expect(find.text(b.cards[0].text), findsOneWidget);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text(b.cards[0].text), findsNothing);
    expect(t.takeException(), isNull);
  });
}
