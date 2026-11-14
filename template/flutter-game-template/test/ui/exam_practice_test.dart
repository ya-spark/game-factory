import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/profile/child_profile.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/app_shell.dart';
import 'package:flutter_game_template/ui/exam_practice.dart';
import 'package:flutter_game_template/ui/parent_area_screen.dart';
import 'package:flutter_game_template/ui/tabs/tab_data.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_game_template/ui/theme/app_theme.dart';
import 'package:flutter_game_template/ui/theme/design_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import 'kit/kit_test.dart' show FileDesignBundle, loadDesign;

PoolItem _mcq(int i, String topic) => PoolItem(
  item: ContentItem({
    'id': 'm$i',
    'type': 'mcq',
    'seq': 1,
    'difficulty': 1,
    'explanation': 'Because $i',
    'prompt': 'Question m$i',
    'options': ['wrong', 'right'],
    'correct': 1,
  }),
  packId: 'pk_$topic',
  subject: 'maths',
  year: 7,
  topic: topic,
);

PoolItem _num(int i, String topic) => PoolItem(
  item: ContentItem({
    'id': 'n$i',
    'type': 'numeric',
    'seq': 1,
    'difficulty': 1,
    'explanation': 'Sum $i',
    'prompt': 'Number n$i',
    'answer': 12,
    'tolerance': 0,
    'unit': '',
  }),
  packId: 'pk_$topic',
  subject: 'maths',
  year: 7,
  topic: topic,
);

List<PoolItem> _items(int n) => [
  for (var i = 0; i < n; i++)
    i.isEven ? _mcq(i, i % 4 == 0 ? 'algebra' : 'ratio') : _num(i, 'algebra'),
];

MiniGame _game() => MiniGame(
  id: 'g',
  title: 'Game g',
  itemTypes: const {ItemType.mcq},
  build: (_) => const SizedBox(),
);

class _Clock {
  DateTime t = DateTime.utc(2026, 11, 14, 9);
  DateTime call() => t;
}

Future<Services> _shell(
  WidgetTester tester,
  String id,
  List<PoolItem> open, {
  required bool exam,
}) async {
  tester.view.physicalSize = const Size(500, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await buildFakeServices(contentEnabled: true, examPractice: exam);
  final kid = (await s.profile.addChild('Mia', year: 7))!;
  await s.profile.setChildMode(kid.id, LearnMode.study);
  s.profile.selectChild(kid.id);
  final design = loadDesign(id);
  final mode = design.app.modes.keys.first;
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: FileDesignBundle(),
      child: ServicesScope(
        services: s,
        child: MaterialApp(
          theme: buildDesignTheme(
            app: design.app,
            shared: design.shared,
            mode: mode,
            level: design.app.levelForYear(7),
          ),
          builder: (context, child) => DesignScope(
            design: design,
            mode: mode,
            level: design.app.levelForYear(7),
            child: child!,
          ),
          home: AppShell(
            registry: MiniGameRegistry([RegistryEntry(_game())]),
            loaders: TabLoaders(
              openItems: (_) async => open,
              packs: () async => const [],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return s;
}

/// The exam screen on its own, with a fake clock.
Future<({ExamSession session, List<ExamResult> saved, _Clock clock})> _exam(
  WidgetTester tester, {
  int count = 10,
  int? minutes = 10,
}) async {
  tester.view.physicalSize = const Size(500, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final clock = _Clock();
  final session = ExamSession.start(
    open: _items(12),
    subject: 'maths',
    year: 7,
    count: count,
    minutes: minutes,
    random: Random(3),
    clock: clock.call,
  )!;
  final saved = <ExamResult>[];
  await tester.pumpWidget(
    MaterialApp(
      home: ExamScreen(
        session: session,
        packs: const [],
        onSubmitted: (r) async => saved.add(r),
        onPractise: (_, _, _) {},
        onDone: () {},
      ),
    ),
  );
  return (session: session, saved: saved, clock: clock);
}

/// Picks the right answer for the shown question (option 1, or 12 typed).
Future<void> _answerShown(WidgetTester tester, ExamSession s) async {
  if (s.current.item.type == ItemType.numeric) {
    await tester.enterText(find.byKey(TestIds.examNumericField), '12');
  } else {
    await tester.tap(find.byKey(TestIds.examOption(1)));
  }
  await tester.pump();
}

void main() {
  testWidgets('Champion: the Exam practice card opens the setup screen', (
    tester,
  ) async {
    await _shell(tester, 'craft_highteen', _items(14), exam: true);
    expect(find.byKey(TestIds.examEntry), findsOneWidget);
    await tester.tap(find.byKey(TestIds.examEntry));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.examSetupScreen), findsOneWidget);
    expect(find.byKey(TestIds.examSubject('maths')), findsOneWidget);
    expect(find.byKey(TestIds.examTopic), findsOneWidget);
    // 14 open questions: only 10 can be chosen
    expect(find.byKey(TestIds.examCount(10)), findsOneWidget);
    expect(find.byKey(TestIds.examCount(20)), findsNothing);
    for (final m in [10, 20, 30, null]) {
      expect(find.byKey(TestIds.examMinutes(m)), findsOneWidget);
    }
    await tester.tap(find.byKey(TestIds.examMinutes(null)));
    await tester.tap(find.byKey(TestIds.examStart));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.examScreen), findsOneWidget);
    expect(find.byKey(TestIds.examTimer), findsNothing); // no timer
    expect(find.text('Question 1 of 10'), findsOneWidget);
  });

  for (final id in ['craft_lowteen', 'craft_preteen']) {
    testWidgets('$id: the card is absent with the flag off', (tester) async {
      await _shell(tester, id, _items(14), exam: false);
      expect(find.byKey(TestIds.learnTab), findsOneWidget);
      expect(find.byKey(TestIds.examEntry), findsNothing);
    });
  }

  testWidgets('fewer than 10 open: a calm line and a link to practice', (
    tester,
  ) async {
    await _shell(tester, 'craft_highteen', _items(6), exam: true);
    await tester.tap(find.byKey(TestIds.examEntry));
    await tester.pumpAndSettle();
    expect(find.text('Open a few more questions first'), findsOneWidget);
    expect(find.byKey(TestIds.examStart), findsNothing);
    expect(find.byKey(TestIds.examPractiseLink), findsOneWidget);
  });

  testWidgets('the exam gives no feedback while answering', (tester) async {
    final e = await _exam(tester);
    await _answerShown(tester, e.session);
    expect(find.textContaining('Correct'), findsNothing);
    expect(find.textContaining('Not quite'), findsNothing);
    expect(find.textContaining('Because'), findsNothing);
    expect(e.session.isAnswered(0), isTrue);
  });

  testWidgets('navigation, flag and the question grid', (tester) async {
    final e = await _exam(tester);
    expect(
      tester.widget<OutlinedButton>(find.byKey(TestIds.examPrev)).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(TestIds.examNext));
    await tester.pump();
    expect(find.text('Question 2 of 10'), findsOneWidget);
    await tester.tap(find.byKey(TestIds.examFlag));
    await tester.pump();
    expect(e.session.isFlagged(1), isTrue);
    expect(
      find.bySemanticsLabel('Question 2, not answered, flagged'),
      findsOneWidget,
    );
    await _answerShown(tester, e.session);
    expect(
      find.bySemanticsLabel('Question 2, answered, flagged'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(TestIds.examGridCell(6)));
    await tester.pump();
    expect(find.text('Question 7 of 10'), findsOneWidget);
    await tester.tap(find.byKey(TestIds.examPrev));
    await tester.pump();
    expect(find.text('Question 6 of 10'), findsOneWidget);
  });

  testWidgets('submit asks first and lists the unanswered questions', (
    tester,
  ) async {
    final e = await _exam(tester);
    await _answerShown(tester, e.session);
    await tester.ensureVisible(find.byKey(TestIds.examSubmit));
    await tester.tap(find.byKey(TestIds.examSubmit));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not answered yet: 2, 3, 4'), findsOneWidget);
    await tester.tap(find.byKey(TestIds.examSubmitKeep));
    await tester.pumpAndSettle();
    expect(e.session.submitted, isFalse);
    await tester.tap(find.byKey(TestIds.examSubmit));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.examSubmitConfirm));
    await tester.pumpAndSettle();
    expect(e.session.submitted, isTrue);
    expect(e.saved, hasLength(1));
    expect(find.byKey(TestIds.examResults), findsOneWidget);
  });

  testWidgets('results: score, time, topics, review and practise links', (
    tester,
  ) async {
    final e = await _exam(tester);
    for (var i = 0; i < 4; i++) {
      e.session.goTo(i);
      e.session.setAnswer(
        i,
        e.session.items[i].item.type == ItemType.numeric
            ? const ExamAnswer.typed('12')
            : const ExamAnswer.choice({1}),
      );
    }
    e.session.setAnswer(
      4,
      e.session.items[4].item.type == ItemType.numeric
          ? const ExamAnswer.typed('7')
          : const ExamAnswer.choice({0}),
    );
    e.clock.t = e.clock.t.add(const Duration(seconds: 125));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(TestIds.examSubmit));
    await tester.tap(find.byKey(TestIds.examSubmit));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.examSubmitConfirm));
    await tester.pumpAndSettle();
    expect(find.text('4 of 10 correct (40%)'), findsOneWidget);
    expect(find.text('Time used: 2:05'), findsOneWidget);
    expect(find.textContaining('5 not answered'), findsOneWidget);
    expect(find.text('Practise these topics'), findsOneWidget);
    expect(find.byKey(TestIds.examReviewItem(0)), findsOneWidget);
    await tester.ensureVisible(find.byKey(TestIds.examReviewItem(4)));
    expect(
      tester.widget<Text>(find.byKey(TestIds.examReviewYours(4))).data,
      startsWith('Your answer:'),
    );
    expect(find.byKey(TestIds.examReviewCorrect(4)), findsOneWidget);
    expect(find.byKey(TestIds.examReviewExplanation(4)), findsOneWidget);
    expect(find.byKey(TestIds.examDone), findsOneWidget);
  });

  testWidgets('auto-submit when the time runs out', (tester) async {
    final e = await _exam(tester, minutes: 10);
    expect(find.byKey(TestIds.examTimer), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    await _answerShown(tester, e.session);
    e.clock.t = e.clock.t.add(const Duration(seconds: 601));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(e.session.submitted, isTrue);
    expect(e.saved.single.timedOut, isTrue);
    expect(find.byKey(TestIds.examTimedOut), findsOneWidget);
  });

  testWidgets('the countdown pauses while the app is in the background', (
    tester,
  ) async {
    final e = await _exam(tester);
    e.clock.t = e.clock.t.add(const Duration(seconds: 60));
    for (final st in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    e.clock.t = e.clock.t.add(const Duration(hours: 2));
    for (final st in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(e.session.submitted, isFalse);
    expect(e.session.remainingSeconds, 540);
  });

  testWidgets('submitting saves progress and history, no coins or stars', (
    tester,
  ) async {
    final s = await _shell(tester, 'craft_highteen', _items(12), exam: true);
    final kid = s.profile.children.single;
    await tester.tap(find.byKey(TestIds.examEntry));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.examMinutes(null)));
    await tester.tap(find.byKey(TestIds.examStart));
    await tester.pumpAndSettle();
    // answer two questions, leave the rest
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(TestIds.examGridCell(i)));
      await tester.pump();
      if (find.byKey(TestIds.examNumericField).evaluate().isNotEmpty) {
        await tester.enterText(find.byKey(TestIds.examNumericField), '12');
      } else {
        await tester.tap(find.byKey(TestIds.examOption(1)));
      }
      await tester.pump();
    }
    await tester.ensureVisible(find.byKey(TestIds.examSubmit));
    await tester.tap(find.byKey(TestIds.examSubmit));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.examSubmitConfirm));
    await tester.pumpAndSettle();
    final after = s.profile.children.firstWhere((c) => c.id == kid.id);
    expect(after.exams.records, hasLength(1));
    expect(after.exams.records.single.questions, 10);
    expect(after.exams.records.single.correct, 2);
    expect(after.progress.items, hasLength(2)); // unanswered are not recorded
    expect(after.progress.mistakeIds, isEmpty);
    expect(after.progress.rewards.stars, 0);
    expect(after.activity.days.values.single.answers, 2);
  });

  testWidgets('Parent area: extra time is saved per child', (tester) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await buildFakeServices(
      contentEnabled: true,
      goalsParentArea: true,
      examPractice: true,
    );
    await s.profile.addChild('Mia');
    await tester.pumpWidget(
      ServicesScope(
        services: s,
        child: const MaterialApp(home: ParentAreaScreen()),
      ),
    );
    await tester.pump();
    expect(find.byKey(TestIds.parentExtraTime), findsOneWidget);
    await tester.tap(find.byKey(TestIds.parentExtraTimeOption('half')));
    await tester.pump();
    expect(s.profile.children.single.extraTime, ExtraTime.half);
  });

  testWidgets('Parent area: no extra-time row with the flag off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await buildFakeServices(
      contentEnabled: true,
      goalsParentArea: true,
    );
    await s.profile.addChild('Mia');
    await tester.pumpWidget(
      ServicesScope(
        services: s,
        child: const MaterialApp(home: ParentAreaScreen()),
      ),
    );
    await tester.pump();
    expect(find.byKey(TestIds.parentExtraTime), findsNothing);
  });

  testWidgets('Progress page shows the history and a calm trend', (
    tester,
  ) async {
    final s = await _shell(tester, 'craft_highteen', _items(12), exam: true);
    final id = s.profile.children.single.id;
    final p = s.profile.children.single.progress;
    await s.profile.recordExam(
      id,
      p,
      const ExamRecord(
        day: 20000,
        subject: 'maths',
        questions: 10,
        correct: 5,
        seconds: 300,
      ),
    );
    await s.profile.recordExam(
      id,
      p,
      const ExamRecord(
        day: 20001,
        subject: 'maths',
        questions: 10,
        correct: 9,
        seconds: 280,
      ),
    );
    await tester.tap(
      find.byKey(TestIds.dsTab(TestIds.shellBottomBar, 'progress')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.examHistory), findsOneWidget);
    expect(find.byKey(TestIds.examHistoryTrend), findsOneWidget);
    expect(find.byKey(TestIds.examHistoryRow(0)), findsOneWidget);
    expect(find.byKey(TestIds.examHistoryRow(1)), findsOneWidget);
  });
}
