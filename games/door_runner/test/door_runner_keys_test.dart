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
  testWidgets(
    'B-16: Enter starts a one-player game from the start screen; the Start button shows its keys',
    (t) async {
      await _size(t);
      await t.pumpWidget(
        _app(_screen(_session(year: 1), const MiniGameLevel.younger())),
      );
      expect(
        find.descendant(
          of: find.byKey(DoorRunnerIds.start),
          matching: find.text('Start (Enter / Space)'),
        ),
        findsOneWidget,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(find.byKey(DoorRunnerIds.intro), findsNothing);
      expect(find.byKey(DoorRunnerIds.door(1)), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Space starts too, and Esc or L leave from the start screen', (
    t,
  ) async {
    await _size(t);
    var left = 0;
    await t.pumpWidget(
      _app(
        _screen(
          _session(year: 1),
          const MiniGameLevel.younger(),
          onExit: () => left++,
        ),
      ),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.sendKeyEvent(LogicalKeyboardKey.keyL);
    expect(left, 2);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(find.byKey(DoorRunnerIds.intro), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'the question dialog: 1 to 4 answer, Esc goes back; its buttons show the keys',
    (t) async {
      await _size(t);
      final log = <AnswerResult>[];
      await _start(
        t,
        _screen(_session(), const MiniGameLevel.older(), log: log),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Back to the game (Esc'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(DoorRunnerIds.questionDialog), findsNothing);
      expect(log, isEmpty);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump(const Duration(milliseconds: 400));
      await t.sendKeyEvent(LogicalKeyboardKey.digit1);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(DoorRunnerIds.questionDialog), findsNothing);
      expect(log, hasLength(1));
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'the pause screen and the exit button show their keys; L leaves',
    (t) async {
      await _size(t);
      var left = 0;
      await _start(
        t,
        _screen(_session(), const MiniGameLevel.older(), onExit: () => left++),
      );
      expect(find.text('Esc'), findsWidgets);
      expect(find.text('L'), findsWidgets);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(find.text('Resume (Esc / Space)'), findsOneWidget);
      expect(find.text('Quit (L)'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.keyL);
      expect(left, 1);
      await t.pumpWidget(const SizedBox());
    },
  );
}
