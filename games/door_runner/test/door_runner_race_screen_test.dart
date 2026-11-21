import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_door_runner/door_runner.dart';
import 'package:game_door_runner/src/ui/door_runner_extras.dart';

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

QuizSession _session({int n = 14, int year = 3}) {
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

const _p1 = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
];
const _p2 = [
  LogicalKeyboardKey.keyZ,
  LogicalKeyboardKey.keyX,
  LogicalKeyboardKey.keyC,
  LogicalKeyboardKey.keyV,
];

class Rig {
  Rig(this.t, this.session, this.exits);
  final WidgetTester t;
  final QuizSession session;
  final List<String> exits;

  String message() {
    final f = find.byKey(DoorRunnerIds.raceMessage);
    return f.evaluate().isEmpty ? '' : (t.widget<Text>(f)).data ?? '';
  }

  int doorOf(String label) {
    for (var i = 0; i < 4; i++) {
      final f = find.byKey(DoorRunnerIds.door(i));
      if (f.evaluate().isNotEmpty &&
          find
              .descendant(of: f, matching: find.text(label))
              .evaluate()
              .isNotEmpty) {
        return i;
      }
    }
    fail('no door shows $label');
  }

  int wrongDoor() {
    for (final l in ['Alpha', 'Gamma', 'Delta']) {
      for (var i = 0; i < 4; i++) {
        final f = find.byKey(DoorRunnerIds.door(i));
        if (f.evaluate().isNotEmpty &&
            find
                .descendant(of: f, matching: find.text(l))
                .evaluate()
                .isNotEmpty) {
          return i;
        }
      }
    }
    fail('no wrong door');
  }

  /// The door indexes of the wrong answers.
  List<int> wrongDoors() => [
    for (final l in ['Alpha', 'Gamma', 'Delta'])
      for (var i = 0; i < 4; i++)
        if (find.byKey(DoorRunnerIds.door(i)).evaluate().isNotEmpty &&
            find
                .descendant(
                  of: find.byKey(DoorRunnerIds.door(i)),
                  matching: find.text(l),
                )
                .evaluate()
                .isNotEmpty)
          i,
  ];

  Future<void> key(LogicalKeyboardKey k) async {
    await t.sendKeyEvent(k);
    await t.pump();
  }

  Future<void> start() => key(LogicalKeyboardKey.enter);
  Future<void> right(int p) => key((p == 1 ? _p1 : _p2)[doorOf('Beta')]);
  Future<void> wrong(int p) => key((p == 1 ? _p1 : _p2)[wrongDoor()]);
  Future<void> skip() => key(LogicalKeyboardKey.enter);

  String points(int p) =>
      (find
                  .descendant(
                    of: find.byKey(
                      p == 1 ? DoorRunnerIds.p1Score : DoorRunnerIds.p2Score,
                    ),
                    matching: find.byType(Text),
                  )
                  .evaluate()
                  .first
                  .widget
              as Text)
          .data!;
}

Future<Rig> open(
  WidgetTester t, {
  MiniGameLevel level = const MiniGameLevel.younger(),
  Size size = const Size(1000, 900),
  int n = 14,
  double scale = 1,
  Duration between = const Duration(milliseconds: 100),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final s = _session(n: n);
  final rig = Rig(t, s, []);
  await t.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: DoorRunnerRaceScreen(
          items: s.items,
          level: level,
          onExit: () => rig.exits.add('exit'),
          random: Random(5),
          betweenQuestions: between,
        ),
      ),
    ),
  );
  await t.pump();
  return rig;
}

void main() {
  group('choosing the mode', () {
    Widget screen({bool offer = true}) => MaterialApp(
      home: DoorRunnerScreen(
        session: _session(),
        onExit: () {},
        level: const MiniGameLevel.older(),
        random: Random(1),
        offerTwoPlayers: offer,
      ),
    );

    testWidgets('a wide start screen offers 2 players and opens the race', (
      t,
    ) async {
      t.view.physicalSize = const Size(1000, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(screen());
      expect(find.byKey(DoorRunnerIds.start), findsOneWidget);
      await t.tap(find.byKey(DoorRunnerIds.modeTwo));
      await t.pump();
      expect(find.byKey(DoorRunnerIds.raceScreen), findsOneWidget);
    });

    testWidgets('not on a phone and not when the container does not offer it', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(screen());
      expect(find.byKey(DoorRunnerIds.modeTwo), findsNothing);
      t.view.physicalSize = const Size(1000, 900);
      await t.pumpWidget(screen(offer: false));
      expect(find.byKey(DoorRunnerIds.modeTwo), findsNothing);
    });
  });

  group('the race', () {
    testWidgets('the intro shows both players\' keys and Enter starts', (
      t,
    ) async {
      final r = await open(t);
      expect(find.byKey(DoorRunnerIds.start), findsOneWidget);
      expect(find.textContaining('Player 1: ← → ↑'), findsOneWidget);
      expect(find.textContaining('Player 2: A D W'), findsOneWidget);
      await r.start();
      expect(find.byKey(DoorRunnerIds.runner1), findsOneWidget);
      expect(find.byKey(DoorRunnerIds.runner2), findsOneWidget);
    });

    testWidgets('each player steers their own runner', (t) async {
      final r = await open(t);
      await r.start();
      expect(
        find.bySemanticsLabel(RegExp('Player 1 in lane 2 of 2')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Player 2 in lane 1 of 2')),
        findsOneWidget,
      );
      await r.key(LogicalKeyboardKey.arrowLeft); // player 1 to lane 1
      expect(
        find.bySemanticsLabel(RegExp('Player 1 in lane 1 of 2')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Player 2 in lane 1 of 2')),
        findsOneWidget,
      );
      await r.key(LogicalKeyboardKey.keyD); // player 2 to lane 2
      expect(
        find.bySemanticsLabel(RegExp('Player 2 in lane 2 of 2')),
        findsOneWidget,
      );
    });

    testWidgets('two runners can stand in one lane, side by side', (t) async {
      final r = await open(t);
      await r.start();
      await r.key(
        LogicalKeyboardKey.arrowLeft,
      ); // player 1 joins player 2 in lane 1
      await t.pump(const Duration(milliseconds: 400)); // the runners glide over
      final a = t.getRect(find.byKey(DoorRunnerIds.runner1));
      final b = t.getRect(find.byKey(DoorRunnerIds.runner2));
      expect(a.center.dx, isNot(b.center.dx));
      expect((a.center.dx - b.center.dx).abs(), lessThan(a.width));
      expect(t.takeException(), isNull);
    });

    testWidgets('the first right pick scores and the other is too late', (
      t,
    ) async {
      final r = await open(t);
      await r.start();
      await r.right(1);
      expect(r.message(), 'Player 1 got it!');
      expect(r.points(1), '1 / 5');
      await r.right(2);
      expect(r.points(2), '0 / 5');
    });

    testWidgets(
      'a wrong pick locks only that player; the other can still score',
      (t) async {
        final r = await open(t);
        await r.start();
        await r.wrong(1);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        await r.right(1); // locked out
        expect(r.points(1), '0 / 5');
        await r.right(2);
        expect(r.message(), 'Player 2 got it!');
      },
    );

    testWidgets('both locked out: no one gets it and the answer is named', (
      t,
    ) async {
      // three doors (older level): each player picks a different wrong door
      final r = await open(t, level: const MiniGameLevel.older());
      await r.start();
      final w = r.wrongDoors();
      await r.key(_p1[w[0]]);
      expect(r.message(), contains('Player 1 is out'));
      await r.key(_p2[w[1]]);
      expect(r.message(), contains('No one got it'));
      expect(r.message(), contains('Beta'));
    });

    testWidgets('the next question follows by itself', (t) async {
      final r = await open(t);
      await r.start();
      await r.right(1);
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));
      expect(r.message(), isEmpty);
    });

    testWidgets('older: the doors reaching the line pick for both runners', (
      t,
    ) async {
      final r = await open(t, level: const MiniGameLevel.older());
      await r.start();
      for (var i = 0; i < 140; i++) {
        await t.pump(const Duration(milliseconds: 100));
        if (r.message().isNotEmpty) break;
      }
      expect(
        r.message(),
        anyOf(
          contains('got it'),
          contains('No one got it'),
          contains('photo finish'),
        ),
      );
    });

    testWidgets('five points win the race, Play again restarts, Leave leaves', (
      t,
    ) async {
      final r = await open(t);
      await r.start();
      for (var i = 0; i < 5; i++) {
        await r.right(2);
        await r.skip();
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(
        (t.widget(find.byKey(DoorRunnerIds.winner)) as Text).data,
        'Player 2 wins!',
      );
      await t.tap(find.byKey(DoorRunnerIds.again));
      await t.pump();
      expect(r.points(2), '0 / 5');
      // finish again and leave
      for (var i = 0; i < 5; i++) {
        await r.right(1);
        await r.skip();
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(
        (t.widget(find.byKey(DoorRunnerIds.winner)) as Text).data,
        'Player 1 wins!',
      );
      await t.tap(find.byKey(DoorRunnerIds.raceLeave));
      expect(r.exits, ['exit']);
    });

    testWidgets('when the questions run out the points decide', (t) async {
      final r = await open(t, n: 3);
      await r.start();
      await r.right(1);
      await r.skip();
      await t.pump(const Duration(milliseconds: 200));
      await r.right(1);
      await r.skip();
      await t.pump(const Duration(milliseconds: 200));
      await r.right(2);
      await r.skip();
      await t.pump(const Duration(milliseconds: 200));
      expect(
        (t.widget(find.byKey(DoorRunnerIds.winner)) as Text).data,
        'Player 1 wins!',
      );
    });

    testWidgets('a race records nothing', (t) async {
      final r = await open(t);
      await r.start();
      await r.right(1);
      expect(r.session.index, 0);
      expect(r.session.report.answered, 0);
    });
  });

  group('pause, keys and layout', () {
    testWidgets('Space pauses: nothing scores; Resume goes on', (t) async {
      final r = await open(t);
      await r.start();
      await r.key(LogicalKeyboardKey.space);
      expect(find.byType(DoorRunnerPauseOverlay), findsOneWidget);
      await r.right(1);
      expect(r.points(1), '0 / 5');
      await r.key(LogicalKeyboardKey.space);
      expect(find.byType(DoorRunnerPauseOverlay), findsNothing);
      await r.right(1);
      expect(r.points(1), '1 / 5');
    });

    testWidgets('Esc leaves from the intro and pauses in a race', (t) async {
      final r = await open(t);
      await r.key(LogicalKeyboardKey.escape);
      expect(r.exits, ['exit']);
      final r2 = await open(t);
      await r2.start();
      await r2.key(LogicalKeyboardKey.escape);
      expect(find.byType(DoorRunnerPauseOverlay), findsOneWidget);
    });

    testWidgets('the slow key and the question key do nothing in the race', (
      t,
    ) async {
      final r = await open(t, level: const MiniGameLevel.older());
      await r.start();
      await r.key(LogicalKeyboardKey.arrowDown);
      await r.key(LogicalKeyboardKey.keyQ);
      expect(find.byType(DoorRunnerPauseOverlay), findsNothing);
      expect(r.message(), isEmpty);
      expect(t.takeException(), isNull);
    });

    testWidgets(
      'both players\' hints, a read-only question, no ad space in play',
      (t) async {
        final r = await open(t);
        await r.start();
        expect(find.byKey(KeyIds.hints), findsNWidgets(2));
        expect(find.byKey(DoorRunnerIds.question), findsOneWidget);
        expect(find.text('Tap to see the answers'), findsNothing);
        expect(find.byType(AppBar), findsNothing);
      },
    );

    testWidgets('holds at 200 percent text on a medium window', (t) async {
      final r = await open(t, size: const Size(700, 900), scale: 2);
      await r.start();
      await r.wrong(1);
      await r.right(2);
      expect(t.takeException(), isNull);
    });

    testWidgets('the points chips are read out', (t) async {
      final r = await open(t);
      await r.start();
      expect(
        find.bySemanticsLabel(RegExp('Player 1, 0 of 5 points')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Player 2, 0 of 5 points')),
        findsOneWidget,
      );
      expect(r.message(), isEmpty);
    });
  });
}
