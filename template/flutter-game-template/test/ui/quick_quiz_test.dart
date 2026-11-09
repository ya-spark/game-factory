import 'package:flutter/material.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/quick_quiz_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _mcq(int i, {Object correct = 1}) => {
  'id': 'q.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': 'Explained $i',
  'prompt': 'Question number $i with a fairly long prompt to wrap',
  'options': ['Alpha option', 'Beta option', 'Gamma option'],
  'correct': correct,
};

QuizSession _session({bool multi = false}) {
  final packs = [
    LoadedPack(
      ContentPack({
        'id': 'q',
        'version': 1,
        'lang': 'en-AU',
        'subject': 'maths',
        'year': 3,
        'topic': 't',
        'title': 'q',
        'items': [
          _mcq(1, correct: multi ? [0, 2] : 1),
          _mcq(2),
          _mcq(3),
          _mcq(4),
        ],
      }),
    ),
  ];
  return QuizSession(
    items: ReleaseEngine.ordered(packs, 'maths', 3),
    progress: const ChildProgress(),
    packs: packs,
    rewardsConfig: const RewardsConfig(),
    today: 100,
  );
}

Widget _app(
  QuizSession s,
  MiniGameMode mode, {
  double scale = 1,
  VoidCallback? onExit,
  List<AnswerResult>? log,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: QuickQuizScreen(
      session: s,
      mode: mode,
      onExit: onExit ?? () {},
      onAnswered: log == null ? null : (r, _) => log.add(r),
    ),
  ),
);

void main() {
  for (final mode in MiniGameMode.values) {
    testWidgets('Quick quiz plays a round in ${mode.name} mode', (t) async {
      final s = _session();
      final log = <AnswerResult>[];
      var exited = false;
      await t.pumpWidget(_app(s, mode, log: log, onExit: () => exited = true));
      expect(find.byKey(TestIds.quizPrompt), findsOneWidget);
      // First answer wrong, then the explanation shows.
      await t.tap(find.byKey(TestIds.quizOption(0)));
      await t.pump();
      expect(find.byKey(TestIds.quizExplanation), findsOneWidget);
      expect(find.text('Explained 1'), findsOneWidget);
      expect(find.text('Not quite.'), findsOneWidget);
      await t.tap(find.byKey(TestIds.quizNext));
      await t.pump();
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byKey(TestIds.quizOption(1)));
        await t.pump();
        expect(find.text('Correct!'), findsOneWidget);
        await t.tap(find.byKey(TestIds.quizNext));
        await t.pump();
      }
      expect(find.byKey(TestIds.quizSummary), findsOneWidget);
      expect(find.text('3 of 4 correct'), findsOneWidget);
      expect(log.length, 4);
      expect(s.progress.rewards.stars, 3);
      expect(s.progress.passedIds.length, 3);
      await t.tap(find.byKey(TestIds.quizNext));
      expect(exited, isTrue);
    });
  }

  testWidgets('Game mode shows earned stars, Study mode does not', (t) async {
    await t.pumpWidget(_app(_session(), MiniGameMode.game));
    await t.tap(find.byKey(TestIds.quizOption(1)));
    await t.pump();
    expect(find.text('+1 star'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_app(_session(), MiniGameMode.study));
    await t.tap(find.byKey(TestIds.quizOption(1)));
    await t.pump();
    expect(find.text('+1 star'), findsNothing);
  });

  testWidgets('several correct options use Check', (t) async {
    final s = _session(multi: true);
    await t.pumpWidget(_app(s, MiniGameMode.game));
    expect(find.byKey(TestIds.quizCheck), findsOneWidget);
    await t.tap(find.byKey(TestIds.quizOption(0)));
    await t.pump();
    await t.tap(find.byKey(TestIds.quizOption(2)));
    await t.pump();
    await t.tap(find.byKey(TestIds.quizCheck));
    await t.pump();
    expect(find.text('Correct!'), findsOneWidget);
  });

  testWidgets('no overflow at 150 percent text on a small screen', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = _session();
    await t.pumpWidget(_app(s, MiniGameMode.game, scale: 1.5));
    expect(t.takeException(), isNull);
    await t.tap(find.byKey(TestIds.quizOption(0)));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.byKey(TestIds.quizNext), findsOneWidget);
  });

  testWidgets('answer buttons are labelled for screen readers', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(_app(_session(), MiniGameMode.game));
    expect(find.bySemanticsLabel('Alpha option'), findsOneWidget);
    await t.tap(find.byKey(TestIds.quizOption(0)));
    await t.pump();
    expect(
      find.bySemanticsLabel('Beta option, correct answer'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Alpha option, your answer, not correct'),
      findsOneWidget,
    );
    h.dispose();
  });
}
