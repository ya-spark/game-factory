import 'dart:math';

import 'package:game_core/engine/engine.dart';
import 'package:game_door_runner/door_runner.dart';
import 'package:game_door_runner/src/ui/door_runner_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

QuizSession _session({int year = 3}) {
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
        'items': [for (var i = 1; i <= 4; i++) _item(i)],
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
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduce,
          size: const Size(420, 900),
        ),
        child: child,
      ),
    );

/// Runs the clock [seconds] in 50 ms frames (the screen caps one frame at 0.1 s).
Future<void> _run(WidgetTester t, double seconds) async {
  for (var i = 0; i < (seconds * 20).round(); i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _size(WidgetTester t, [double w = 420, double h = 900]) async {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

/// Index of the door showing [label].
int _doorWith(WidgetTester t, String label, int n) {
  for (var i = 0; i < n; i++) {
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

Future<void> _start(
  WidgetTester t,
  Widget screen, {
  bool reduce = false,
}) async {
  await t.pumpWidget(_app(screen, reduce: reduce));
  await t.tap(find.byKey(DoorRunnerIds.start));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

DoorRunnerScreen _screen(
  QuizSession s,
  MiniGameLevel l, {
  List<AnswerResult>? log,
  void Function(int)? onScore,
  VoidCallback? onExit,
  int seed = 1,
}) => DoorRunnerScreen(
  session: s,
  level: l,
  onExit: onExit ?? () {},
  onAnswered: log == null ? null : (r, _) => log.add(r),
  onScore: onScore,
  random: Random(seed),
);

void main() {
  testWidgets('intro, then 2 doors, no hearts, no streak (younger)', (t) async {
    await _size(t);
    await t.pumpWidget(
      _app(_screen(_session(year: 1), const MiniGameLevel.younger())),
    );
    expect(find.byKey(DoorRunnerIds.intro), findsOneWidget);
    await t.tap(find.byKey(DoorRunnerIds.start));
    await t.pump();
    expect(find.byKey(DoorRunnerIds.door(1)), findsOneWidget);
    expect(find.byKey(DoorRunnerIds.door(2)), findsNothing);
    expect(find.byKey(DoorRunnerIds.hearts), findsNothing);
    expect(find.byKey(DoorRunnerIds.streak), findsNothing);
    expect(find.text('Question number 1'), findsWidgets);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'younger: a wrong door greys out and nothing is answered; a full round ends with the score',
    (t) async {
      await _size(t);
      final log = <AnswerResult>[];
      int? score;
      var exited = false;
      await _start(
        t,
        _screen(
          _session(year: 1),
          const MiniGameLevel.younger(),
          log: log,
          onScore: (v) => score = v,
          onExit: () => exited = true,
        ),
      );
      // Doors wait: a long time passes and nothing is picked.
      await _run(t, 12);
      expect(log, isEmpty);
      final wrong = _doorWith(t, 'Beta', 2) == 0 ? 1 : 0;
      await t.tap(find.byKey(DoorRunnerIds.door(wrong)));
      await t.pump();
      expect(log, isEmpty);
      // Right door: answered, but with a wrong try first: no first-pass star.
      await t.tap(find.byKey(DoorRunnerIds.door(_doorWith(t, 'Beta', 2))));
      await t.pump();
      expect(log, hasLength(1));
      expect(log.first.stars, 0);
      for (var q = 1; q < 4; q++) {
        await _run(t, 1); // right answers move on by themselves
        await t.tap(find.byKey(DoorRunnerIds.door(_doorWith(t, 'Beta', 2))));
        await t.pump();
      }
      expect(log, hasLength(4));
      await _run(t, 1);
      expect(find.byKey(DoorRunnerIds.results), findsOneWidget);
      expect(score, 40);
      await t.tap(find.byKey(DoorRunnerIds.done));
      expect(exited, isTrue);
    },
  );

  testWidgets(
    'older: 3 hearts and 3 doors; a wrong zap costs a heart and shows the answer',
    (t) async {
      await _size(t);
      final log = <AnswerResult>[];
      await _start(
        t,
        _screen(_session(), const MiniGameLevel.older(), log: log),
      );
      expect(find.byKey(DoorRunnerIds.door(2)), findsOneWidget);
      expect(find.byKey(DoorRunnerIds.hearts), findsOneWidget);
      final wrong = _doorWith(t, 'Beta', 3) == 0 ? 1 : 0;
      await t.tap(find.byKey(DoorRunnerIds.door(wrong)));
      await t.pump();
      expect(log.single.correct, isFalse);
      expect(find.text('Not quite. The answer was Beta.'), findsOneWidget);
      expect(find.text('Explained 1'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNWidgets(2));
      await t.tap(find.byKey(DoorRunnerIds.next));
      await t.pump();
      expect(find.text('Question number 2'), findsWidgets);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'older: a door reaching the runner is picked (the round never stalls)',
    (t) async {
      await _size(t);
      final log = <AnswerResult>[];
      await _start(
        t,
        _screen(_session(), const MiniGameLevel.older(), log: log),
      );
      await _run(t, 13);
      expect(log, hasLength(1));
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('older: three wrong zaps end the round kindly', (t) async {
    await _size(t);
    int? score;
    await _start(
      t,
      _screen(
        _session(),
        const MiniGameLevel.older(),
        onScore: (v) => score = v,
      ),
    );
    for (var q = 0; q < 3; q++) {
      final wrong = _doorWith(t, 'Beta', 3) == 0 ? 1 : 0;
      await t.tap(find.byKey(DoorRunnerIds.door(wrong)));
      await t.pump();
      await t.tap(find.byKey(DoorRunnerIds.next));
      await t.pump();
    }
    expect(find.byKey(DoorRunnerIds.results), findsOneWidget);
    expect(find.text('Good run!'), findsOneWidget);
    expect(score, 0);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'keys: Up zaps the lane door, digits zap a door, Left and Right steer',
    (t) async {
      await _size(t);
      final log = <AnswerResult>[];
      await _start(
        t,
        _screen(_session(), const MiniGameLevel.older(), log: log),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pump(const Duration(milliseconds: 300));
      await _run(t, 0.5);
      final runner = t.getCenter(find.byKey(DoorRunnerIds.runner));
      final lane0 = t.getRect(find.byKey(DoorRunnerIds.lane(0)));
      expect(lane0.contains(Offset(runner.dx, lane0.center.dy)), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.pump();
      expect(log, hasLength(1));
      await _run(t, 1);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Space pauses: doors stop; Resume gives a 3-2-1 count-in at the older level',
    (t) async {
      await _size(t);
      await _start(t, _screen(_session(), const MiniGameLevel.older()));
      await _run(t, 2);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(find.byKey(DoorRunnerIds.resume), findsOneWidget);
      final y = t.getTopLeft(find.byKey(DoorRunnerIds.door(0))).dy;
      await _run(t, 5);
      expect(t.getTopLeft(find.byKey(DoorRunnerIds.door(0))).dy, y);
      await t.tap(find.byKey(DoorRunnerIds.resume));
      await t.pump();
      expect(find.byType(DoorRunnerCountdown), findsOneWidget);
      await _run(t, 3.2);
      expect(find.byKey(DoorRunnerIds.resume), findsNothing);
      expect(find.byType(DoorRunnerCountdown), findsNothing);
      await _run(t, 1);
      expect(
        t.getTopLeft(find.byKey(DoorRunnerIds.door(0))).dy,
        greaterThan(y),
      );
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the question dialog pauses; choosing an answer zaps that door', (
    t,
  ) async {
    await _size(t);
    final log = <AnswerResult>[];
    await _start(t, _screen(_session(), const MiniGameLevel.older(), log: log));
    await t.tap(find.byKey(DoorRunnerIds.question));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(DoorRunnerIds.questionDialog), findsOneWidget);
    final y = t.getTopLeft(find.byKey(DoorRunnerIds.door(0))).dy;
    await _run(t, 3);
    expect(
      t.getTopLeft(find.byKey(DoorRunnerIds.door(0))).dy,
      y,
      reason: 'paused behind the dialog',
    );
    await t.tap(find.byKey(DoorRunnerIds.answer(0)));
    await t.pump(const Duration(milliseconds: 400));
    expect(log, hasLength(1));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Back to the game resumes without a pick', (t) async {
    await _size(t);
    final log = <AnswerResult>[];
    await _start(t, _screen(_session(), const MiniGameLevel.older(), log: log));
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(DoorRunnerIds.questionDialog), findsOneWidget);
    await t.tap(find.byKey(DoorRunnerIds.questionBack));
    await t.pump(const Duration(milliseconds: 400));
    expect(log, isEmpty);
    expect(find.byKey(DoorRunnerIds.questionDialog), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion: doors at the line and they wait for the child', (
    t,
  ) async {
    await _size(t);
    final log = <AnswerResult>[];
    await _start(
      t,
      _screen(_session(), const MiniGameLevel.older(), log: log),
      reduce: true,
    );
    await _run(t, 30);
    expect(log, isEmpty, reason: 'no door arrives by itself');
    final door = t.getRect(find.byKey(DoorRunnerIds.door(0)));
    final runner = t.getRect(find.byKey(DoorRunnerIds.runner));
    expect(runner.top - door.bottom, lessThan(60));
    await t.pumpWidget(const SizedBox());
  });

  for (final older in [false, true]) {
    for (final reduce in [false, true]) {
      testWidgets(
        'holds at 150% text on a phone (older: $older, reduce motion: $reduce)',
        (t) async {
          await _size(t, 390, 780);
          await t.pumpWidget(
            _app(
              _screen(
                _session(year: older ? 3 : 1),
                older
                    ? const MiniGameLevel.older(harder: true)
                    : const MiniGameLevel.younger(),
              ),
              scale: 1.5,
              reduce: reduce,
            ),
          );
          await t.tap(find.byKey(DoorRunnerIds.start));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          expect(t.takeException(), isNull);
          await t.tap(find.byKey(DoorRunnerIds.door(0)));
          await t.pump();
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
