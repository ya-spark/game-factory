import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/minigames/shooter_screen.dart';
import 'package:flutter_game_template/ui/minigames/snake_series_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

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

Map<String, dynamic> _series(int i) => {
  'id': 's.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'series',
  'explanation': 'Explained $i',
  'prompt': 'Put the multiples of 3 in order.',
  'steps': ['3', '6', '9'],
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
    final f = find.byKey(TestIds.mgChoice(id, i));
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
        await t.tap(find.byKey(TestIds.mgStart('shooter')));
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
      await t.tap(find.byKey(TestIds.mgStart('shooter')));
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
      await t.tap(find.byKey(TestIds.mgStart('shooter')));
      await t.pump();
      expect(find.textContaining('Shoot the group for'), findsOneWidget);
      expect(find.text('Even'), findsOneWidget);
      expect(find.text('Odd'), findsOneWidget);
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

  group('Snake', () {
    testWidgets(
      'the board, status and steering buttons are there and a tap steers',
      (t) async {
        await t.pumpWidget(
          _app(
            SnakeSeriesScreen(
              session: _session([
                for (var i = 1; i <= 3; i++) _series(i),
              ], year: 1),
              level: const MiniGameLevel.younger(),
              onExit: () {},
              random: Random(1),
            ),
          ),
        );
        await t.tap(find.byKey(TestIds.mgStart('snake_series')));
        await t.pump();
        expect(find.byKey(const Key('snake.board')), findsOneWidget);
        expect(find.text('Eaten 0 of 3'), findsOneWidget);
        expect(find.text('Put the multiples of 3 in order.'), findsOneWidget);
        for (final d in ['left', 'up', 'down', 'right']) {
          expect(find.byKey(Key('snake.dir.$d')), findsOneWidget);
        }
        await t.tap(find.byKey(const Key('snake.dir.left')));
        await t.pump(const Duration(milliseconds: 800));
        await t.pumpWidget(const SizedBox());
      },
    );

    test('registry entry: series, word and numeric items it can build', () {
      PoolItem p(Map<String, dynamic> j) => PoolItem(
        item: ContentItem(j),
        packId: 'p',
        subject: 'maths',
        year: 3,
        topic: 't',
      );
      expect(snakeSeriesGame.canPlay(p(_series(1))), isTrue);
      expect(snakeSeriesGame.canPlay(p(_mcq(1))), isFalse);
      expect(
        snakeSeriesGame.canPlay(
          p({
            ..._series(1),
            'steps': ['a' * 9, 'b', 'c'],
          }),
        ),
        isFalse,
      );
    });
  });
}
