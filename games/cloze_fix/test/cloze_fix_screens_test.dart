import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_cloze_fix/cloze_fix.dart';

Map<String, dynamic> _cloze(int i, String word) => {
  'id': 'c.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'cloze',
  'explanation': 'Because $i',
  'text': 'Sentence $i has a {{1}} in it.',
  'gaps': {
    '1': [word],
  },
};

List<LoadedPack> _packs(List<Map<String, dynamic>> items, int year) => [
  LoadedPack(
    ContentPack({
      'id': 'q',
      'version': 1,
      'lang': 'en-AU',
      'subject': 'maths',
      'year': year,
      'topic': 't',
      'title': 'q',
      'items': items,
    }),
  ),
];

QuizSession _session(List<Map<String, dynamic>> items, {int year = 4}) {
  final packs = _packs(items, year);
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

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  group('Cloze and grammar fix', () {
    final items = [
      for (final (i, w) in ['cat', 'dog', 'bird', 'fish'].indexed)
        _cloze(i + 1, w),
    ];

    testWidgets('older: pick the word that fits the gap', (t) async {
      _phone(t);
      final log = <AnswerResult>[];
      await t.pumpWidget(
        _app(
          ClozeFixScreen(
            session: _session(items),
            level: const MiniGameLevel.older(),
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            random: Random(2),
          ),
          scale: 1.5,
        ),
      );
      await t.tap(find.byKey(GameIds.mgStart(clozeFixId)));
      await t.pump();
      expect(find.byKey(GameIds.mgTimer(clozeFixId)), findsOneWidget);
      expect(find.byKey(GameIds.mgBanner(clozeFixId)), findsNothing);
      for (var q = 1; q <= 4; q++) {
        final prompt =
            (t.widget(find.byKey(GameIds.mgPrompt(clozeFixId))) as Text).data!;
        expect(prompt, 'Sentence $q has a ____ in it.');
        final right = ['cat', 'dog', 'bird', 'fish'][q - 1];
        await t.tap(find.widgetWithText(InkWell, right));
        await t.pump();
        expect(log.last.correct, isTrue);
        await t.tap(find.byKey(GameIds.mgNext(clozeFixId)));
        await t.pump();
      }
      expect(find.byKey(GameIds.mgResults(clozeFixId)), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('study mode has no timer and a wrong pick is retried', (
      t,
    ) async {
      _phone(t);
      final log = <AnswerResult>[];
      await t.pumpWidget(
        _app(
          ClozeFixScreen(
            session: _session(items),
            level: const MiniGameLevel.older(),
            study: true,
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            random: Random(2),
          ),
        ),
      );
      await t.tap(find.byKey(GameIds.mgStart(clozeFixId)));
      await t.pump();
      expect(find.byKey(GameIds.mgTimer(clozeFixId)), findsNothing);
      await t.tap(find.widgetWithText(InkWell, 'dog'));
      await t.pump();
      expect(log, isEmpty);
      expect(find.text('Not that one. Try another!'), findsOneWidget);
      await t.tap(find.widgetWithText(InkWell, 'cat'));
      await t.pump();
      expect(log, hasLength(1));
    });

    testWidgets('grammar mcq: pick the corrected sentence', (t) async {
      _phone(t);
      final grammar = [
        for (var i = 1; i <= 4; i++)
          {
            'id': 'g.$i',
            'seq': i,
            'difficulty': 1,
            'type': 'mcq',
            'topic': 'grammar_verbs',
            'explanation': 'x',
            'prompt': 'Fix sentence $i',
            'options': ['Wrong $i', 'Right $i'],
            'correct': 1,
          },
      ];
      final log = <AnswerResult>[];
      await t.pumpWidget(
        _app(
          ClozeFixScreen(
            session: _session(grammar),
            level: const MiniGameLevel.older(),
            study: true,
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            random: Random(1),
          ),
        ),
      );
      await t.tap(find.byKey(GameIds.mgStart(clozeFixId)));
      await t.pump();
      await t.tap(find.widgetWithText(InkWell, 'Right 1'));
      await t.pump();
      expect(log.single.correct, isTrue);
    });
  });
}
