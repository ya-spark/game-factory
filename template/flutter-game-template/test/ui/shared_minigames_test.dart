import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/game_registry.dart';
import 'package:flutter_game_template/ui/minigames/balloon_pop_screen.dart';
import 'package:flutter_game_template/ui/minigames/door_runner_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final f = find.byKey(TestIds.mgChoice(id, i));
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
  testWidgets('Door runner: younger level has no timer and retries', (t) async {
    final s = _session(year: 1);
    final log = <AnswerResult>[];
    int? score;
    var exited = false;
    await t.pumpWidget(
      _app(
        DoorRunnerScreen(
          session: s,
          level: const MiniGameLevel.younger(),
          onExit: () => exited = true,
          onAnswered: (r, _) => log.add(r),
          onScore: (v) => score = v,
          random: Random(1),
        ),
      ),
    );
    expect(find.byKey(TestIds.mgIntro('door_runner')), findsOneWidget);
    await t.tap(find.byKey(TestIds.mgStart('door_runner')));
    await t.pump();
    expect(find.byKey(TestIds.mgTimer('door_runner')), findsNothing);
    expect(find.byKey(TestIds.mgChoice('door_runner', 1)), findsOneWidget);
    expect(find.byKey(TestIds.mgChoice('door_runner', 2)), findsNothing);
    // A wrong door is greyed out, the round goes on, nothing is answered yet.
    for (var i = 0; i < 2; i++) {
      final f = find.byKey(TestIds.mgChoice('door_runner', i));
      if (find
          .descendant(of: f, matching: find.text('Beta'))
          .evaluate()
          .isEmpty) {
        await t.tap(f);
        await t.pump();
      }
    }
    expect(log, isEmpty);
    expect(find.text('Not that one. Try another!'), findsOneWidget);
    await _tapRight(t, 'door_runner', 'Beta', 2);
    expect(log, hasLength(1));
    // Finished only after a wrong try: no first-pass star.
    expect(log.first.stars, 0);
    expect(find.byKey(TestIds.mgFeedback('door_runner')), findsOneWidget);
    for (var q = 1; q < 4; q++) {
      await t.tap(find.byKey(TestIds.mgNext('door_runner')));
      await t.pump();
      await _tapRight(t, 'door_runner', 'Beta', 2);
    }
    expect(log, hasLength(4));
    await t.tap(find.byKey(TestIds.mgNext('door_runner')));
    await t.pump();
    expect(find.byKey(TestIds.mgResults('door_runner')), findsOneWidget);
    expect(score, 40);
    await t.tap(find.byKey(TestIds.mgDone('door_runner')));
    expect(exited, isTrue);
  });

  testWidgets(
    'Door runner: older level shows the timer, a miss shows the answer',
    (t) async {
      final s = _session();
      await t.pumpWidget(
        _app(
          DoorRunnerScreen(
            session: s,
            level: const MiniGameLevel.older(),
            onExit: () {},
            random: Random(2),
          ),
        ),
      );
      await t.tap(find.byKey(TestIds.mgStart('door_runner')));
      await t.pump();
      expect(find.byKey(TestIds.mgTimer('door_runner')), findsOneWidget);
      expect(find.byKey(TestIds.mgChoice('door_runner', 2)), findsOneWidget);
      // Run out the clock: counts as a miss, shows the answer, never ends the round.
      await t.pump(const Duration(seconds: 21));
      expect(
        find.textContaining('Time is up. The answer was Beta.'),
        findsOneWidget,
      );
      expect(find.text('Explained 1'), findsOneWidget);
      await t.tap(find.byKey(TestIds.mgNext('door_runner')));
      await t.pump();
      expect(find.text('Question 2 of 4'), findsOneWidget);
      // Dispose with the timer running: no pending timers.
      await t.pumpWidget(const SizedBox());
    },
  );

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
    await t.tap(find.byKey(TestIds.mgStart('balloon_pop')));
    await t.pump();
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(TestIds.mgChoice('balloon_pop', i)), findsOneWidget);
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
    await t.tap(find.byKey(TestIds.mgStart('balloon_pop')));
    await t.pump();
    expect(find.byKey(TestIds.mgTimer('balloon_pop')), findsNothing);
    expect(find.byKey(TestIds.mgChoice('balloon_pop', 2)), findsOneWidget);
    expect(find.byKey(TestIds.mgChoice('balloon_pop', 3)), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  for (final reduce in [false, true]) {
    testWidgets('both games hold at 150% text (reduce motion: $reduce)', (
      t,
    ) async {
      for (final game in ['door', 'balloon']) {
        final s = _session();
        final id = game == 'door' ? 'door_runner' : 'balloon_pop';
        final screen = game == 'door'
            ? DoorRunnerScreen(
                session: s,
                level: const MiniGameLevel.older(harder: true),
                onExit: () {},
              )
            : BalloonPopScreen(
                session: s,
                level: const MiniGameLevel.older(harder: true),
                onExit: () {},
              );
        await t.pumpWidget(_app(screen, scale: 1.5, reduce: reduce));
        await t.tap(find.byKey(TestIds.mgStart(id)));
        await t.pump();
        await t.pump(const Duration(milliseconds: 500));
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(TestIds.mgChoice(id, 0)));
        await t.pump();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
    });
  }

  test('registry: the games appear only when enough items are open', () {
    final reg = MiniGameRegistry([
      RegistryEntry(doorRunnerGame),
      RegistryEntry(balloonPopGame),
    ]);
    PoolItem p(int i) => PoolItem(
      packId: 'q',
      subject: 'maths',
      year: 3,
      topic: 't',
      item: ContentItem(_item(i)),
    );
    List<String> ids(int n) => [
      for (final o in reg.offers(
        open: [for (var i = 0; i < n; i++) p(i)],
        subject: 'maths',
        year: 3,
        mode: MiniGameMode.game,
        unlocked: {},
      ))
        o.game.id,
    ];
    expect(ids(3), isEmpty);
    expect(ids(4), ['door_runner', 'balloon_pop']);
    expect(doorRunnerGame.modes, {MiniGameMode.game});
    expect(doorRunnerGame.access, GameAccess.freeWithAds);
    expect(
      appGames.entries.map((e) => e.game.id),
      containsAll(['quick_quiz', 'door_runner', 'balloon_pop']),
    );
  });
}
