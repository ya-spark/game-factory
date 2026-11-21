import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
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

QuizSession _session({int n = 12, int year = 3}) {
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

const _p1 = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
];
const _p2 = [
  LogicalKeyboardKey.keyZ,
  LogicalKeyboardKey.keyX,
  LogicalKeyboardKey.keyC,
  LogicalKeyboardKey.keyV,
];

class Rig {
  Rig(this.t, this.session, this.exits);
  final WidgetTester t;
  final QuizSession session;
  final List<String> exits;

  Text _text(Key k) => t.widget<Text>(find.byKey(k));
  String message() => _text(TugIds.message).data ?? '';

  /// The index of the option that shows [label].
  int indexOf(String label) {
    for (var i = 0; i < 4; i++) {
      final f = find.byKey(TugIds.option(i));
      if (f.evaluate().isNotEmpty &&
          find
              .descendant(of: f, matching: find.text(label))
              .evaluate()
              .isNotEmpty) {
        return i;
      }
    }
    fail('no option shows $label');
  }

  int get wrongIndex =>
      indexOf('Alpha') >= 0 &&
          find.byKey(TugIds.option(indexOf('Alpha'))).evaluate().isNotEmpty
      ? indexOf('Alpha')
      : indexOf('Gamma');

  Future<void> start() async {
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
  }

  /// Player [p] presses the right answer.
  Future<void> right(int p) async {
    await t.sendKeyEvent((p == 1 ? _p1 : _p2)[indexOf('Beta')]);
    await t.pump();
  }

  /// Player [p] presses a wrong answer.
  Future<void> wrong(int p) async {
    final wrong = ['Alpha', 'Gamma', 'Delta']
        .where(
          (l) => find
              .descendant(of: find.byType(Container), matching: find.text(l))
              .evaluate()
              .isNotEmpty,
        )
        .first;
    await t.sendKeyEvent((p == 1 ? _p1 : _p2)[indexOf(wrong)]);
    await t.pump();
  }

  /// Skips the between-questions pause with Enter.
  Future<void> skip() async {
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
  }
}

Future<Rig> open(
  WidgetTester t, {
  MiniGameLevel level = const MiniGameLevel.older(),
  Size size = const Size(1000, 900),
  int n = 12,
  double scale = 1,
  Duration between = const Duration(milliseconds: 80),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final s = _session(n: n);
  final rig = Rig(t, s, []);
  await t.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: TugOfWarHeadToHeadScreen(
          items: s.items,
          level: level,
          onExit: () => rig.exits.add('exit'),
          random: Random(3),
          betweenQuestions: between,
        ),
      ),
    ),
  );
  await t.pump();
  return rig;
}

void main() {
  group('choosing the mode', () {
    Widget screen({bool offer = true, double width = 1000}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: TugOfWarScreen(
          session: _session(),
          level: const MiniGameLevel.older(),
          onExit: () {},
          random: Random(1),
          offerHeadToHead: offer,
        ),
      ),
    );

    testWidgets('the start screen has a Head to head button on a wide window', (
      t,
    ) async {
      t.view.physicalSize = const Size(1000, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(screen());
      expect(find.byKey(TugIds.modeHeadToHead), findsOneWidget);
      await t.tap(find.byKey(TugIds.modeHeadToHead));
      await t.pump();
      expect(find.byKey(TugIds.h2hScreen), findsOneWidget);
    });

    testWidgets(
      'not on a phone, and not when the container does not offer it',
      (t) async {
        t.view.physicalSize = const Size(390, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(screen(width: 390));
        expect(find.byKey(TugIds.modeHeadToHead), findsNothing);
        t.view.physicalSize = const Size(1000, 900);
        await t.pumpWidget(screen(offer: false));
        expect(find.byKey(TugIds.modeHeadToHead), findsNothing);
      },
    );

    testWidgets('the sibling button of the container stays beside it', (
      t,
    ) async {
      t.view.physicalSize = const Size(1000, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1000, 900)),
            child: TugOfWarScreen(
              session: _session(),
              level: const MiniGameLevel.older(),
              onExit: () {},
              offerHeadToHead: true,
              introExtra: (c) => const Text('sibling', key: Key('sibling')),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('sibling')), findsOneWidget);
      expect(find.byKey(TugIds.modeHeadToHead), findsOneWidget);
    });
  });

  group('playing', () {
    testWidgets('the intro shows both players\' keys and Enter starts', (
      t,
    ) async {
      final r = await open(t);
      expect(find.byKey(TugIds.start), findsOneWidget);
      expect(find.text('1 2 3'), findsOneWidget);
      expect(find.text('Z X C'), findsOneWidget);
      await r.start();
      expect(find.byKey(TugIds.question), findsOneWidget);
    });

    testWidgets('the first right answer pulls the rope toward that player', (
      t,
    ) async {
      final r = await open(t);
      await r.start();
      await r.right(1);
      expect(r.message(), contains('Player 1 got it first'));
      expect(t.takeException(), isNull);
      await r.skip();
      await r.right(2);
      expect(r.message(), contains('Player 2 got it first'));
    });

    testWidgets(
      'a wrong answer locks only that player, the other can still answer',
      (t) async {
        final r = await open(t);
        await r.start();
        await r.wrong(1);
        expect(find.byKey(TugIds.p1Locked), findsOneWidget);
        expect(find.byKey(TugIds.p2Locked), findsNothing);
        expect(r.message(), contains('Player 1 is out'));
        await r.right(1); // locked: ignored
        expect(r.message(), contains('Player 1 is out'));
        await r.right(2);
        expect(r.message(), contains('Player 2 got it first'));
      },
    );

    testWidgets('both locked out: no one gets it and the answer is shown', (
      t,
    ) async {
      final r = await open(t, level: const MiniGameLevel.younger());
      await r.start();
      await r.wrong(1);
      await r.wrong(2);
      expect(r.message(), contains('No one got it'));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('the next question comes by itself after a pause', (t) async {
      final r = await open(t);
      await r.start();
      expect(find.text('Question 1'), findsOneWidget);
      await r.right(1);
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Question 2'), findsOneWidget);
    });

    testWidgets(
      'winning two rounds ends the game with the winner and Play again restarts',
      (t) async {
        final r = await open(t, level: const MiniGameLevel.younger(), n: 12);
        await r.start();
        // reach 3 per round, 2 rounds: six right answers by player 2
        for (var i = 0; i < 6; i++) {
          await r.right(2);
          await r.skip();
        }
        expect(find.byKey(TugIds.winner), findsOneWidget);
        expect(
          (t.widget(find.byKey(TugIds.winner)) as Text).data,
          'Player 2 wins!',
        );
        await t.tap(find.byKey(TugIds.again));
        await t.pump();
        expect(find.text('Question 1'), findsOneWidget);
      },
    );

    testWidgets('when the questions run out the rounds decide', (t) async {
      final r = await open(t, level: const MiniGameLevel.younger(), n: 4);
      await r.start();
      for (var i = 0; i < 4; i++) {
        await r.right(1); // four steps: one round (reach 3) and one step
        await r.skip();
      }
      expect(
        (t.widget(find.byKey(TugIds.winner)) as Text).data,
        'Player 1 wins!',
      );
    });

    testWidgets('older: the timer ends the question with no pull', (t) async {
      final r = await open(t);
      await r.start();
      expect(find.byKey(TugIds.timer), findsOneWidget);
      await t.pump(const Duration(seconds: 21));
      expect(r.message(), contains('Time is up'));
    });

    testWidgets('a head-to-head round records nothing', (t) async {
      final r = await open(t, level: const MiniGameLevel.younger());
      await r.start();
      await r.right(1);
      await r.skip();
      expect(r.session.index, 0);
      expect(r.session.report.answered, 0);
    });
  });

  group('pause, keys and layout', () {
    testWidgets(
      'Space pauses: no answer counts and the question stays; Resume goes on',
      (t) async {
        final r = await open(t);
        await r.start();
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(find.byKey(TugIds.paused), findsOneWidget);
        await t.sendKeyEvent(_p1[r.indexOf('Beta')]);
        await t.pump();
        expect(r.message(), isEmpty);
        await t.tap(find.byKey(TugIds.resume));
        await t.pump();
        await r.right(1);
        expect(r.message(), contains('Player 1 got it first'));
      },
    );

    testWidgets(
      'Esc pauses in a round, and Leave leaves; Esc on the intro leaves',
      (t) async {
        final r = await open(t);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(r.exits, ['exit']);
        final r2 = await open(t);
        await r2.start();
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(find.byKey(TugIds.paused), findsOneWidget);
        await t.tap(find.byKey(TugIds.leave));
        expect(r2.exits, ['exit']);
      },
    );

    testWidgets('both players\' hints on a wide window; no title bar', (
      t,
    ) async {
      final r = await open(t);
      await r.start();
      expect(find.byKey(KeyIds.hints), findsNWidgets(2));
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('holds at 200 percent text on a tablet-sized window', (
      t,
    ) async {
      final r = await open(t, size: const Size(640, 900), scale: 2);
      await r.start();
      await r.wrong(1);
      await r.right(2);
      expect(t.takeException(), isNull);
    });

    testWidgets('the chips and the answers are read out', (t) async {
      final r = await open(t);
      await r.start();
      expect(
        find.bySemanticsLabel(RegExp('Player 1, 0 rounds')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'Beta\. Player 1 key \d, player 2 key [ZXCV]'),
        ),
        findsOneWidget,
      );
      expect(r.message(), isEmpty);
    });
  });
}
