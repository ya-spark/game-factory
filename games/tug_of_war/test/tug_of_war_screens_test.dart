import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_tug_of_war/tug_of_war.dart';

Map<String, dynamic> _item(int i) => {
  'id': 'q.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': 'Explained $i',
  'prompt': 'Question number $i',
  'options': ['Alpha', 'Beta', 'Gamma', 'Delta'],
  'correct': 1,
};

QuizSession _session({int year = 3, int n = 4}) {
  final packs = [
    LoadedPack(
      ContentPack({
        'id': 'q',
        'version': 1,
        'lang': 'en-AU',
        'subject': 'maths',
        'year': year,
        'topic': 't',
        'title': 'q',
        'items': [for (var i = 1; i <= n; i++) _item(i)],
      }),
    ),
  ];
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

Future<void> _tapLabel(WidgetTester t, String id, String label, int n) async {
  for (var i = 0; i < n; i++) {
    final f = find.byKey(GameIds.mgChoice(id, i));
    if (f.evaluate().isNotEmpty &&
        find
            .descendant(of: f, matching: find.text(label))
            .evaluate()
            .isNotEmpty) {
      await t.tap(f);
      await t.pump();
      return;
    }
  }
  fail('no choice shows $label');
}

void main() {
  testWidgets('Tug of war: right answers pull the rope and win a round', (
    t,
  ) async {
    final log = <AnswerResult>[];
    int? score;
    await t.pumpWidget(
      _app(
        TugOfWarScreen(
          session: _session(year: 1),
          level: const MiniGameLevel.younger(),
          onExit: () {},
          onAnswered: (r, _) => log.add(r),
          onScore: (v) => score = v,
          random: Random(1),
        ),
      ),
    );
    await t.tap(find.byKey(GameIds.mgStart('tug_of_war')));
    await t.pump();
    expect(find.byKey(GameIds.mgRope('tug_of_war')), findsOneWidget);
    expect(find.byKey(GameIds.mgTimer('tug_of_war')), findsNothing);
    expect(find.byKey(GameIds.mgBanner('tug_of_war')), findsNothing);
    expect(find.byKey(GameIds.mgChoice('tug_of_war', 1)), findsOneWidget);
    expect(find.byKey(GameIds.mgChoice('tug_of_war', 2)), findsNothing);
    for (var q = 0; q < 3; q++) {
      await _tapLabel(t, 'tug_of_war', 'Beta', 2);
      if (q < 2) {
        await t.tap(find.byKey(GameIds.mgNext('tug_of_war')));
        await t.pump();
      }
    }
    expect(find.textContaining('Round won!'), findsOneWidget);
    expect(log, hasLength(3));
    await t.tap(find.byKey(GameIds.mgNext('tug_of_war')));
    await t.pump();
    // The rope is back in the middle for the next round.
    expect(find.textContaining('Round won!'), findsNothing);
    await _tapLabel(t, 'tug_of_war', 'Beta', 2);
    await t.tap(find.byKey(GameIds.mgNext('tug_of_war')));
    await t.pump();
    expect(find.byKey(GameIds.mgResults('tug_of_war')), findsOneWidget);
    expect(score, 40);
  });

  testWidgets('Tug of war: older level is timed and a slow answer pulls back', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        TugOfWarScreen(
          session: _session(),
          level: const MiniGameLevel.older(),
          onExit: () {},
          random: Random(2),
        ),
        scale: 1.5,
      ),
    );
    await t.tap(find.byKey(GameIds.mgStart('tug_of_war')));
    await t.pump();
    expect(find.byKey(GameIds.mgTimer('tug_of_war')), findsOneWidget);
    expect(find.byKey(GameIds.mgChoice('tug_of_war', 2)), findsOneWidget);
    await t.pump(const Duration(seconds: 21));
    expect(find.textContaining('Time is up'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
