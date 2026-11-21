import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_equation_builder/equation_builder.dart';

Map<String, dynamic> _numeric(int i, int answer) => {
  'id': 'n.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'numeric',
  'explanation': 'Because $i',
  'prompt': 'Question $i',
  'answer': answer,
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
  group('Equation builder', () {
    final items = [for (var i = 1; i <= 4; i++) _numeric(i, 5 + i)];

    Future<List<String>> tileTexts(WidgetTester t, int n) async => [
      for (var i = 0; i < n; i++)
        (t.widget<Text>(
          find.descendant(
            of: find.byKey(EquationBuilderIds.mgTile(equationBuilderId, i)),
            matching: find.byType(Text),
          ),
        )).data!,
    ];

    /// Taps tiles for any equation of the bank that makes [target].
    Future<void> build(WidgetTester t, int target) async {
      final texts = await tileTexts(t, 4);
      for (var a = 0; a < texts.length; a++) {
        for (var b = 0; b < texts.length; b++) {
          for (var c = 0; c < texts.length; c++) {
            if ({a, b, c}.length < 3) continue;
            if (equationHitsTarget([texts[a], texts[b], texts[c]], target)) {
              for (final i in [a, b, c]) {
                final tile = find.byKey(
                  EquationBuilderIds.mgTile(equationBuilderId, i),
                );
                await t.ensureVisible(tile);
                await t.tap(tile);
                await t.pump();
              }
              return;
            }
          }
        }
      }
      fail('no equation in $texts makes $target');
    }

    testWidgets('younger: any right equation passes; a wrong check retries', (
      t,
    ) async {
      _phone(t);
      final log = <AnswerResult>[];
      int? score;
      await t.pumpWidget(
        _app(
          EquationBuilderScreen(
            session: _session(items, year: 1),
            level: const MiniGameLevel.younger(),
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            onScore: (v) => score = v,
            random: Random(3),
          ),
        ),
      );
      await t.tap(find.byKey(GameIds.mgStart(equationBuilderId)));
      await t.pump();
      expect(find.byKey(GameIds.mgTimer(equationBuilderId)), findsNothing);
      expect(find.byKey(GameIds.mgBanner(equationBuilderId)), findsNothing);
      expect(find.textContaining('Make 6'), findsOneWidget);
      // One tile alone is wrong: the game says so and lets the child try again.
      await t.tap(find.byKey(EquationBuilderIds.mgTile(equationBuilderId, 0)));
      await t.pump();
      await t.tap(find.byKey(EquationBuilderIds.mgCheck(equationBuilderId)));
      await t.pump();
      expect(log, isEmpty);
      expect(find.text('Not that one. Try another!'), findsOneWidget);
      await t.tap(find.byKey(EquationBuilderIds.mgClear(equationBuilderId)));
      await t.pump();
      await build(t, 6);
      await t.tap(find.byKey(EquationBuilderIds.mgCheck(equationBuilderId)));
      await t.pump();
      expect(log, hasLength(1));
      // The first try was wrong, so it does not count as a first pass.
      expect(log.single.correct, isFalse);
      for (var q = 2; q <= 4; q++) {
        await t.tap(find.byKey(GameIds.mgNext(equationBuilderId)));
        await t.pump();
        await build(t, 5 + q);
        await t.tap(find.byKey(EquationBuilderIds.mgCheck(equationBuilderId)));
        await t.pump();
      }
      expect(log.skip(1).every((r) => r.correct), isTrue);
      await t.tap(find.byKey(GameIds.mgNext(equationBuilderId)));
      await t.pump();
      expect(find.byKey(GameIds.mgResults(equationBuilderId)), findsOneWidget);
      expect(score, 40);
    });

    testWidgets('older: timed, wrong check shows a working equation', (
      t,
    ) async {
      _phone(t);
      final log = <AnswerResult>[];
      await t.pumpWidget(
        _app(
          EquationBuilderScreen(
            session: _session(items),
            level: const MiniGameLevel.older(),
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            random: Random(4),
          ),
          scale: 1.5,
        ),
      );
      await t.tap(find.byKey(GameIds.mgStart(equationBuilderId)));
      await t.pump();
      expect(find.byKey(GameIds.mgTimer(equationBuilderId)), findsOneWidget);
      await t.tap(find.byKey(EquationBuilderIds.mgTile(equationBuilderId, 0)));
      await t.pump();
      await t.tap(find.byKey(EquationBuilderIds.mgCheck(equationBuilderId)));
      await t.pump();
      expect(log.single.correct, isFalse);
      expect(find.textContaining('The answer was'), findsOneWidget);
      expect(find.textContaining('= 6'), findsWidgets);
      await t.pumpWidget(const SizedBox());
    });
  });
}
