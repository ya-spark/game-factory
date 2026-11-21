import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_shooter/shooter.dart';

Map<String, dynamic> _mcq(int i) => {
  'id': 'q.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': 'Explained $i',
  'prompt': 'Question number $i',
  'options': ['Alpha', 'Beta', 'Gamma', 'Delta'],
  'correct': 1,
};

Map<String, dynamic> _category(int i) => {
  'id': 'c.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'category',
  'explanation': 'Explained $i',
  'prompt': 'Sort the numbers.',
  'categories': ['Even', 'Odd'],
  'items': [
    {'text': '2', 'category': 'Even'},
    {'text': '7', 'category': 'Odd'},
    {'text': '10', 'category': 'Even'},
    {'text': '13', 'category': 'Odd'},
  ],
};

QuizSession _session(List<Map<String, dynamic>> items, {int year = 3}) {
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
        'items': items,
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

Widget _app(Widget child) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(size: Size(400, 900)),
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
      await t.pump(); // the shot starts on the first frame
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      return;
    }
  }
  fail('no target shows $label');
}

void main() {
  group('Shooter', () {
    testWidgets(
      'a wrong shot is greyed out and a right shot answers (younger level)',
      (t) async {
        final log = <AnswerResult>[];
        await t.pumpWidget(
          _app(
            ShooterScreen(
              session: _session([
                for (var i = 1; i <= 4; i++) _mcq(i),
              ], year: 1),
              level: const MiniGameLevel.younger(),
              onExit: () {},
              onAnswered: (r, _) => log.add(r),
              random: Random(1),
            ),
          ),
        );
        await t.tap(find.byKey(GameIds.mgStart('shooter')));
        await t.pump();
        expect(find.byKey(const Key('shooter.cannon')), findsOneWidget);
        expect(find.text('Question number 1'), findsOneWidget);
        // three of the four options are shown; shoot any wrong one
        for (final wrong in ['Alpha', 'Gamma', 'Delta']) {
          if (find.text(wrong).evaluate().isNotEmpty) {
            await _tapLabel(t, 'shooter', wrong, 3);
            break;
          }
        }
        expect(log, isEmpty, reason: 'a wrong shot does not end the question');
        await _tapLabel(t, 'shooter', 'Beta', 3);
        expect(log.length, 1);
        expect(
          log.single.correct,
          isFalse,
          reason: 'a retry means it was not first try',
        );
      },
    );

    testWidgets('a right first shot is a correct answer', (t) async {
      final log = <AnswerResult>[];
      await t.pumpWidget(
        _app(
          ShooterScreen(
            session: _session([for (var i = 1; i <= 4; i++) _mcq(i)], year: 1),
            level: const MiniGameLevel.younger(),
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            random: Random(1),
          ),
        ),
      );
      await t.tap(find.byKey(GameIds.mgStart('shooter')));
      await t.pump();
      await _tapLabel(t, 'shooter', 'Beta', 3);
      expect(log.single.correct, isTrue);
    });

    testWidgets('a category item asks which group an entry belongs to', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          ShooterScreen(
            session: _session([
              for (var i = 1; i <= 4; i++) _category(i),
            ], year: 1),
            level: const MiniGameLevel.younger(),
            onExit: () {},
            random: Random(1),
          ),
        ),
      );
      await t.tap(find.byKey(GameIds.mgStart('shooter')));
      await t.pump();
      expect(find.textContaining('Shoot the group for'), findsOneWidget);
      expect(find.text('Even'), findsOneWidget);
      expect(find.text('Odd'), findsOneWidget);
    });

    testWidgets(
      'keyboard: number keys shoot the targets, Enter shoots a focused one',
      (t) async {
        final log = <AnswerResult>[];
        await t.pumpWidget(
          _app(
            ShooterScreen(
              session: _session([
                for (var i = 1; i <= 4; i++) _mcq(i),
              ], year: 1),
              level: const MiniGameLevel.younger(),
              onExit: () {},
              onAnswered: (r, _) => log.add(r),
              random: Random(1),
            ),
          ),
        );
        await t.tap(find.byKey(GameIds.mgStart('shooter')));
        await t.pump();
        // every target shows its key number
        expect(find.byKey(const Key('shooter.key.0')), findsOneWidget);
        expect(find.byKey(const Key('shooter.key.1')), findsOneWidget);
        // find which key number the right answer ("Beta") has
        var right = -1;
        for (var i = 0; i < 3; i++) {
          final box = find.byKey(GameIds.mgChoice('shooter', i));
          if (find
              .descendant(of: box, matching: find.text('Beta'))
              .evaluate()
              .isNotEmpty) {
            right = i;
          }
        }
        expect(right, isNonNegative);
        final keys = [
          LogicalKeyboardKey.digit1,
          LogicalKeyboardKey.digit2,
          LogicalKeyboardKey.digit3,
        ];
        await t.sendKeyEvent(keys[right]);
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.pump();
        expect(log.length, 1);
        expect(log.single.correct, isTrue);
      },
    );

    testWidgets('keyboard: a key with no target does nothing', (t) async {
      final log = <AnswerResult>[];
      await t.pumpWidget(
        _app(
          ShooterScreen(
            session: _session([for (var i = 1; i <= 4; i++) _mcq(i)], year: 1),
            level: const MiniGameLevel.younger(),
            onExit: () {},
            onAnswered: (r, _) => log.add(r),
            random: Random(1),
          ),
        ),
      );
      await t.tap(find.byKey(GameIds.mgStart('shooter')));
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.digit9);
      await t.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await t.pump(const Duration(milliseconds: 400));
      expect(log, isEmpty);
    });

    test('registry entry: short mcq and category items only', () {
      final long = PoolItem(
        item: ContentItem({
          ..._mcq(1),
          'options': ['x' * 31, 'b', 'c'],
        }),
        packId: 'p',
        subject: 'maths',
        year: 3,
        topic: 't',
      );
      final short = PoolItem(
        item: ContentItem(_mcq(1)),
        packId: 'p',
        subject: 'maths',
        year: 3,
        topic: 't',
      );
      expect(shooterGame.canPlay(short), isTrue);
      expect(shooterGame.canPlay(long), isFalse);
      expect(shooterGame.modes, {MiniGameMode.game});
    });
  });
}
