import 'dart:math';

import 'package:flutter/material.dart';
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
      size: const Size(400, 900),
    ),
    child: child,
  ),
);

void main() {
  testWidgets('True or false: statement, True and False, streak score', (
    t,
  ) async {
    final log = <AnswerResult>[];
    int? score;
    await t.pumpWidget(
      _app(
        JudgeBotScreen(
          session: _session(),
          level: const MiniGameLevel.older(),
          onExit: () {},
          onAnswered: (r, _) => log.add(r),
          onScore: (v) => score = v,
          random: Random(4),
        ),
      ),
    );
    await t.tap(find.byKey(GameIds.mgStart('judge_bot')));
    await t.pump();
    expect(find.byKey(GameIds.mgTimer('judge_bot')), findsOneWidget);
    for (var q = 0; q < 4; q++) {
      final text =
          (t.widget(find.byKey(GameIds.mgPrompt('judge_bot'))) as Text).data!;
      expect(text, startsWith('Question number'));
      expect(text, contains('Answer: '));
      final stmtTrue = text.endsWith('Answer: Beta');
      await t.tap(find.byKey(GameIds.mgChoice('judge_bot', stmtTrue ? 0 : 1)));
      await t.pump();
      expect(log.last.correct, isTrue);
      await t.tap(find.byKey(GameIds.mgNext('judge_bot')));
      await t.pump();
    }
    expect(find.byKey(GameIds.mgResults('judge_bot')), findsOneWidget);
    expect(score, 10 + 12 + 14 + 16);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('True or false: younger level greys out a wrong try', (t) async {
    final log = <AnswerResult>[];
    await t.pumpWidget(
      _app(
        JudgeBotScreen(
          session: _session(year: 1),
          level: const MiniGameLevel.younger(),
          onExit: () {},
          onAnswered: (r, _) => log.add(r),
          random: Random(5),
        ),
        scale: 1.5,
      ),
    );
    await t.tap(find.byKey(GameIds.mgStart('judge_bot')));
    await t.pump();
    expect(find.byKey(GameIds.mgTimer('judge_bot')), findsNothing);
    final text =
        (t.widget(find.byKey(GameIds.mgPrompt('judge_bot'))) as Text).data!;
    final isTrue = text.endsWith('Answer: Beta');
    await t.tap(find.byKey(GameIds.mgChoice('judge_bot', isTrue ? 1 : 0)));
    await t.pump();
    expect(log, isEmpty);
    expect(find.text('Not that one. Try another!'), findsOneWidget);
    await t.tap(find.byKey(GameIds.mgChoice('judge_bot', isTrue ? 0 : 1)));
    await t.pump();
    expect(log, hasLength(1));
  });
}
