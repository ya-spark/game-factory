import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('keyboard', () {
    Future<List<AnswerResult>> start(
      WidgetTester t, {
      Size size = const Size(1000, 800),
      VoidCallback? onExit,
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final log = <AnswerResult>[];
      await t.pumpWidget(
        MaterialApp(
          home: TugOfWarScreen(
            session: _session(year: 3),
            level: const MiniGameLevel.older(),
            onExit: onExit ?? () {},
            onAnswered: (r, _) => log.add(r),
            random: Random(1),
          ),
        ),
      );
      return log;
    }

    testWidgets('Enter starts, 2 picks the answer, Enter goes on', (t) async {
      final log = await start(t);
      expect(find.byKey(GameIds.mgIntro('tug_of_war')), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(find.byKey(GameIds.mgRope('tug_of_war')), findsOneWidget);
      // Every option is on the screen; press the key of the one that is right (Beta).
      for (var n = 1; n <= 4; n++) {
        final f = find.byKey(GameIds.mgChoice('tug_of_war', n - 1));
        if (find
            .descendant(of: f, matching: find.text('Beta'))
            .evaluate()
            .isNotEmpty) {
          await t.sendKeyEvent(
            [
              LogicalKeyboardKey.digit1,
              LogicalKeyboardKey.digit2,
              LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4,
            ][n - 1],
          );
          break;
        }
      }
      await t.pump();
      expect(log.single.correct, isTrue);
      expect(find.byKey(GameIds.mgFeedback('tug_of_war')), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(find.byKey(GameIds.mgFeedback('tug_of_war')), findsNothing);
    });

    testWidgets('Space starts, goes on after a result, never pauses then', (
      t,
    ) async {
      final log = await start(t);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(find.byKey(GameIds.mgRope('tug_of_war')), findsOneWidget);
      for (var n = 1; n <= 4; n++) {
        final f = find.byKey(GameIds.mgChoice('tug_of_war', n - 1));
        if (find
            .descendant(of: f, matching: find.text('Beta'))
            .evaluate()
            .isNotEmpty) {
          await t.sendKeyEvent(
            [
              LogicalKeyboardKey.digit1,
              LogicalKeyboardKey.digit2,
              LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4,
            ][n - 1],
          );
          break;
        }
      }
      await t.pump();
      expect(log.single.correct, isTrue);
      expect(find.byKey(GameIds.mgFeedback('tug_of_war')), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(find.byKey(GameIds.mgFeedback('tug_of_war')), findsNothing);
      expect(find.byKey(GameIds.mgPaused('tug_of_war')), findsNothing);
    });

    testWidgets('Esc leaves from the start screen, pauses in a round', (
      t,
    ) async {
      var left = false;
      await start(t, onExit: () => left = true);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(left, isTrue);
      left = false;
      await start(t, onExit: () => left = true);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(left, isFalse);
      expect(find.byKey(GameIds.mgPaused('tug_of_war')), findsOneWidget);
      await t.tap(find.byKey(GameIds.mgLeave('tug_of_war')));
      expect(left, isTrue);
    });

    testWidgets('Space pauses: no answer is taken, Space or Resume goes on', (
      t,
    ) async {
      final log = await start(t);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(find.byKey(GameIds.mgPaused('tug_of_war')), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.digit1);
      await t.pump();
      expect(log, isEmpty);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(find.byKey(GameIds.mgPaused('tug_of_war')), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      await t.tap(find.byKey(GameIds.mgResume('tug_of_war')));
      await t.pump();
      expect(find.byKey(GameIds.mgPaused('tug_of_war')), findsNothing);
    });

    testWidgets('the pause button works too', (t) async {
      await start(t);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      await t.tap(find.byKey(GameIds.mgPause('tug_of_war')));
      await t.pump();
      expect(find.byKey(GameIds.mgPaused('tug_of_war')), findsOneWidget);
    });

    testWidgets('a wide window shows the key hints, a phone does not', (
      t,
    ) async {
      await start(t);
      expect(find.byKey(KeyIds.hints), findsOneWidget);
      await start(t, size: const Size(390, 800));
      expect(find.byKey(KeyIds.hints), findsNothing);
    });

    testWidgets('no title bar: the game name sits in the overlay row', (
      t,
    ) async {
      await start(t);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(GameIds.mgExit('tug_of_war')), findsOneWidget);
    });
  });
}
