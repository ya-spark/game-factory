import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_balloon_pop/balloon_pop.dart';

Map<String, dynamic> _item(int i, {bool numeric = false}) => {
  'id': 'q.$i',
  'seq': i,
  'difficulty': 1,
  'type': numeric ? 'numeric' : 'mcq',
  'explanation': 'Explained $i',
  'prompt': 'Question number $i',
  if (numeric)
    'answer': 5 + i
  else ...{
    'options': ['Alpha', 'Beta', 'Gamma', 'Delta'],
    'correct': 1,
  },
};

QuizSession _session({int year = 3, bool numeric = false}) {
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
        'items': [for (var i = 1; i <= 4; i++) _item(i, numeric: numeric)],
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

Widget _app(Widget child, {double scale = 1, bool reduce = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduce,
          size: const Size(400, 900),
        ),
        child: child,
      ),
    );

/// Taps the right option: the one whose label is [label], found through its choice key.
Future<void> _tapRight(WidgetTester t, String id, String label, int n) async {
  for (var i = 0; i < n; i++) {
    final f = find.byKey(GameIds.mgChoice(id, i));
    if (f.evaluate().isEmpty) continue;
    if (find
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
  testWidgets('Balloon pop: numeric items become number balloons', (t) async {
    final s = _session(numeric: true);
    final log = <AnswerResult>[];
    await t.pumpWidget(
      _app(
        BalloonPopScreen(
          session: s,
          level: const MiniGameLevel.older(),
          onExit: () {},
          onAnswered: (r, _) => log.add(r),
          random: Random(3),
        ),
      ),
    );
    await t.tap(find.byKey(GameIds.mgStart('balloon_pop')));
    await t.pump();
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(GameIds.mgChoice('balloon_pop', i)), findsOneWidget);
    }
    await _tapRight(t, 'balloon_pop', '6', 5);
    expect(log.single.correct, isTrue);
    expect(log.single.stars, 1);
    expect(find.text('Correct!'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Balloon pop: younger level has large balloons and no timer', (
    t,
  ) async {
    final s = _session(year: 2);
    await t.pumpWidget(
      _app(
        BalloonPopScreen(
          session: s,
          level: const MiniGameLevel.younger(),
          onExit: () {},
          random: Random(4),
        ),
      ),
    );
    await t.tap(find.byKey(GameIds.mgStart('balloon_pop')));
    await t.pump();
    expect(find.byKey(GameIds.mgTimer('balloon_pop')), findsNothing);
    expect(find.byKey(GameIds.mgChoice('balloon_pop', 2)), findsOneWidget);
    expect(find.byKey(GameIds.mgChoice('balloon_pop', 3)), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  for (final reduce in [false, true]) {
    testWidgets('Balloon pop holds at 150% text (reduce motion: $reduce)', (
      t,
    ) async {
      {
        final s = _session();
        final id = 'balloon_pop';
        final screen = BalloonPopScreen(
          session: s,
          level: const MiniGameLevel.older(harder: true),
          onExit: () {},
        );
        await t.pumpWidget(_app(screen, scale: 1.5, reduce: reduce));
        await t.tap(find.byKey(GameIds.mgStart(id)));
        await t.pump();
        await t.pump(const Duration(milliseconds: 500));
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(GameIds.mgChoice(id, 0)));
        await t.pump();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
    });
  }
}
