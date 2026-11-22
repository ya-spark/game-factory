import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_judge_bot/judge_bot.dart';

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
      size: const Size(1000, 700),
    ),
    child: child,
  ),
);

void main() {
  Future<int> open(WidgetTester t, {VoidCallback? onExit}) async {
    t.view.physicalSize = const Size(1000, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      _app(
        JudgeBotScreen(
          session: _session(),
          level: const MiniGameLevel.younger(),
          onExit: onExit ?? () {},
          random: Random(4),
        ),
      ),
    );
    return 0;
  }

  testWidgets('B-09: the kit buttons show their keys and the keys work', (
    t,
  ) async {
    var left = 0;
    await open(t, onExit: () => left++);
    expect(find.text('Start (Enter / Space)'), findsOneWidget);
    // The exit and pause controls print their keys beside the icon.
    expect(find.text('L'), findsWidgets);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    // Every answer shows its number.
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    await t.sendKeyEvent(LogicalKeyboardKey.digit1);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.digit2);
    await t.pump();
    expect(find.textContaining('Next (Enter / Space)'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    // L leaves from play; so does Esc from the start screen (checked above in the kit tests).
    await t.sendKeyEvent(LogicalKeyboardKey.keyL);
    expect(left, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'the pause screen shows Resume (Esc / Space) and Leave game (L)',
    (t) async {
      var left = 0;
      await open(t, onExit: () => left++);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(find.text('Resume (Esc / Space)'), findsOneWidget);
      expect(find.text('Leave game (L)'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(find.text('Resume (Esc / Space)'), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.keyL);
      expect(left, 1);
      await t.pumpWidget(const SizedBox());
    },
  );
}
