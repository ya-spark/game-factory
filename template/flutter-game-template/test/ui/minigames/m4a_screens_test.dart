import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/minigames/flash_review_screen.dart';
import 'package:flutter_game_template/ui/minigames/true_false_screen.dart';
import 'package:flutter_game_template/ui/minigames/tug_of_war_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
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
    final f = find.byKey(TestIds.mgChoice(id, i));
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
    await t.tap(find.byKey(TestIds.mgStart('tug_of_war')));
    await t.pump();
    expect(find.byKey(TestIds.mgRope('tug_of_war')), findsOneWidget);
    expect(find.byKey(TestIds.mgTimer('tug_of_war')), findsNothing);
    expect(find.byKey(TestIds.mgBanner('tug_of_war')), findsNothing);
    expect(find.byKey(TestIds.mgChoice('tug_of_war', 1)), findsOneWidget);
    expect(find.byKey(TestIds.mgChoice('tug_of_war', 2)), findsNothing);
    for (var q = 0; q < 3; q++) {
      await _tapLabel(t, 'tug_of_war', 'Beta', 2);
      if (q < 2) {
        await t.tap(find.byKey(TestIds.mgNext('tug_of_war')));
        await t.pump();
      }
    }
    expect(find.textContaining('Round won!'), findsOneWidget);
    expect(log, hasLength(3));
    await t.tap(find.byKey(TestIds.mgNext('tug_of_war')));
    await t.pump();
    // The rope is back in the middle for the next round.
    expect(find.textContaining('Round won!'), findsNothing);
    await _tapLabel(t, 'tug_of_war', 'Beta', 2);
    await t.tap(find.byKey(TestIds.mgNext('tug_of_war')));
    await t.pump();
    expect(find.byKey(TestIds.mgResults('tug_of_war')), findsOneWidget);
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
    await t.tap(find.byKey(TestIds.mgStart('tug_of_war')));
    await t.pump();
    expect(find.byKey(TestIds.mgTimer('tug_of_war')), findsOneWidget);
    expect(find.byKey(TestIds.mgChoice('tug_of_war', 2)), findsOneWidget);
    await t.pump(const Duration(seconds: 21));
    expect(find.textContaining('Time is up'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('True or false: statement, True and False, streak score', (
    t,
  ) async {
    final log = <AnswerResult>[];
    int? score;
    await t.pumpWidget(
      _app(
        TrueFalseScreen(
          session: _session(),
          level: const MiniGameLevel.older(),
          onExit: () {},
          onAnswered: (r, _) => log.add(r),
          onScore: (v) => score = v,
          random: Random(4),
        ),
      ),
    );
    await t.tap(find.byKey(TestIds.mgStart('true_false')));
    await t.pump();
    expect(find.byKey(TestIds.mgTimer('true_false')), findsOneWidget);
    for (var q = 0; q < 4; q++) {
      final text =
          (t.widget(find.byKey(TestIds.mgPrompt('true_false'))) as Text).data!;
      expect(text, startsWith('Question number'));
      expect(text, contains('Answer: '));
      final stmtTrue = text.endsWith('Answer: Beta');
      await t.tap(find.byKey(TestIds.mgChoice('true_false', stmtTrue ? 0 : 1)));
      await t.pump();
      expect(log.last.correct, isTrue);
      await t.tap(find.byKey(TestIds.mgNext('true_false')));
      await t.pump();
    }
    expect(find.byKey(TestIds.mgResults('true_false')), findsOneWidget);
    expect(score, 10 + 12 + 14 + 16);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('True or false: younger level greys out a wrong try', (t) async {
    final log = <AnswerResult>[];
    await t.pumpWidget(
      _app(
        TrueFalseScreen(
          session: _session(year: 1),
          level: const MiniGameLevel.younger(),
          onExit: () {},
          onAnswered: (r, _) => log.add(r),
          random: Random(5),
        ),
        scale: 1.5,
      ),
    );
    await t.tap(find.byKey(TestIds.mgStart('true_false')));
    await t.pump();
    expect(find.byKey(TestIds.mgTimer('true_false')), findsNothing);
    final text =
        (t.widget(find.byKey(TestIds.mgPrompt('true_false'))) as Text).data!;
    final isTrue = text.endsWith('Answer: Beta');
    await t.tap(find.byKey(TestIds.mgChoice('true_false', isTrue ? 1 : 0)));
    await t.pump();
    expect(log, isEmpty);
    expect(find.text('Not that one. Try another!'), findsOneWidget);
    await t.tap(find.byKey(TestIds.mgChoice('true_false', isTrue ? 0 : 1)));
    await t.pump();
    expect(log, hasLength(1));
  });

  testWidgets('Flash review: flip, "Not yet" keeps it, "I knew it" passes', (
    t,
  ) async {
    final s = _session();
    final log = <AnswerResult>[];
    var exited = false;
    await t.pumpWidget(
      _app(
        FlashReviewScreen(
          session: s,
          onExit: () => exited = true,
          onAnswered: (r, _) => log.add(r),
        ),
        scale: 1.5,
      ),
    );
    expect(find.byKey(TestIds.mgTimer('flash_review')), findsNothing);
    await t.tap(find.byKey(TestIds.mgStart('flash_review')));
    await t.pump();
    expect(find.text('Question number 1'), findsOneWidget);
    expect(find.byKey(TestIds.mgKnew('flash_review')), findsNothing);
    await t.tap(find.byKey(TestIds.mgFlip('flash_review')));
    await t.pump();
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Explained 1'), findsOneWidget);
    await t.tap(find.byKey(TestIds.mgNotYet('flash_review')));
    await t.pump();
    expect(s.progress.mistakeIds, ['q.1']);
    for (var i = 1; i < 4; i++) {
      await t.tap(find.byKey(TestIds.mgFlip('flash_review')));
      await t.pump();
      await t.tap(find.byKey(TestIds.mgKnew('flash_review')));
      await t.pump();
    }
    expect(log, hasLength(4));
    expect(log.every((r) => r.coins == 0), isTrue);
    expect(find.byKey(TestIds.mgResults('flash_review')), findsOneWidget);
    expect(find.text('You knew 3 of 4'), findsOneWidget);
    await t.tap(find.byKey(TestIds.mgDone('flash_review')));
    expect(exited, isTrue);
  });
}
