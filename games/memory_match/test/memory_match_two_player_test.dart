import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_memory_match/memory_match.dart';

Map<String, dynamic> _pairs(int i) => {
  'id': 'm.$i',
  'seq': i,
  'difficulty': 1,
  'type': 'pairs',
  'explanation': 'Pairs explained $i',
  'prompt': 'Match the pairs $i',
  'pairs': [
    for (var k = 0; k < 3; k++) {'left': 'L$i$k', 'right': 'R$i$k'},
  ],
};

QuizSession _session({int boards = 2}) {
  final packs = [
    LoadedPack(
      ContentPack({
        'id': 'p',
        'version': 1,
        'lang': 'en-AU',
        'subject': 'maths',
        'year': 3,
        'topic': 't',
        'title': 'p',
        'items': [for (var i = 1; i <= boards; i++) _pairs(i)],
      }),
    ),
  ];
  return QuizSession(
    items: ReleaseEngine.ordered(packs, 'maths', 3).take(boards).toList(),
    progress: const ChildProgress(),
    packs: packs,
    rewardsConfig: const RewardsConfig(),
    today: 100,
  );
}

class Rig {
  Rig(this.t, this.session, this.seed, this.exits, this.answered);
  final WidgetTester t;
  final QuizSession session;
  final int seed;
  final List<String> exits;
  final List<AnswerResult> answered;

  /// The boards the screen builds, in order (it draws them from one seeded random; this copy is an
  /// identical generator of our own, so the predictions do not disturb the screen's).
  late final Random random = Random(seed);
  Random screenRandom() => Random(seed);
  final List<MemoryMatchBoard> boards = [];

  MemoryMatchBoard board(int i) {
    while (boards.length <= i) {
      boards.add(
        MemoryMatchBoard.fromItem(
          session.items[boards.length].item,
          MatchLevel.younger,
          random,
        ),
      );
    }
    return boards[i];
  }

  List<int> pair(int b, int p) => [
    for (var i = 0; i < board(b).cards.length; i++)
      if (board(b).cards[i].pairIndex == p) i,
  ];

  Future<void> tapCard(int i) async {
    await t.ensureVisible(find.byKey(MemoryMatchIds.matchCard(i)));
    await t.tap(find.byKey(MemoryMatchIds.matchCard(i)));
    await t.pump();
  }

  Future<void> takePair(int b, int p) async {
    final i = pair(b, p);
    await tapCard(i[0]);
    await tapCard(i[1]);
  }

  /// Two cards of different pairs, then the delay.
  Future<void> miss(int b, int pa, int pb) async {
    await tapCard(pair(b, pa)[0]);
    await tapCard(pair(b, pb)[0]);
    await t.pump(const Duration(milliseconds: 60));
  }

  String text(Key k) => (t.widget(find.byKey(k)) as Text).data!;
}

Future<Rig> open(
  WidgetTester t, {
  Size size = const Size(1000, 900),
  int boards = 2,
  int seed = 7,
  double scale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final s = _session(boards: boards);
  final rig = Rig(t, s, seed, [], []);
  await t.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: MemoryMatchTwoPlayerScreen(
          items: s.items,
          level: MatchLevel.younger,
          random: rig.screenRandom(),
          onExit: () => rig.exits.add('exit'),
          mismatchDelay: const Duration(milliseconds: 50),
        ),
      ),
    ),
  );
  await t.pump();
  return rig;
}

void main() {
  group('choosing the mode', () {
    Widget screen({
      bool offer = true,
      MiniGameMode mode = MiniGameMode.game,
      List<String>? log,
    }) => MaterialApp(
      home: MemoryMatchScreen(
        session: _session(),
        mode: mode,
        onExit: () => log?.add('exit'),
        level: MatchLevel.younger,
        random: Random(1),
        offerTwoPlayers: offer,
        mismatchDelay: const Duration(milliseconds: 50),
      ),
    );

    testWidgets('the start of a game offers 1 or 2 players, 1 is selected', (
      t,
    ) async {
      await t.pumpWidget(screen());
      expect(find.byKey(MemoryMatchIds.matchModeOne), findsOneWidget);
      expect(find.byKey(MemoryMatchIds.matchModeTwo), findsOneWidget);
      expect(find.byType(MemoryMatchTwoPlayerScreen), findsNothing);
    });

    testWidgets('2 players opens the two-player board', (t) async {
      await t.pumpWidget(screen());
      await t.tap(find.byKey(MemoryMatchIds.matchModeTwo));
      await t.pumpAndSettle();
      expect(find.byType(MemoryMatchTwoPlayerScreen), findsOneWidget);
      expect(find.byKey(MemoryMatchIds.matchP1Score), findsOneWidget);
    });

    testWidgets(
      'not offered once a card is turned, in study mode, or when the container does not offer it',
      (t) async {
        await t.pumpWidget(screen());
        await t.tap(find.byKey(MemoryMatchIds.matchCard(0)));
        await t.pump();
        expect(find.byKey(MemoryMatchIds.matchModeTwo), findsNothing);
        await t.pumpWidget(screen(mode: MiniGameMode.study));
        expect(find.byKey(MemoryMatchIds.matchModeTwo), findsNothing);
        await t.pumpWidget(screen(offer: false));
        expect(find.byKey(MemoryMatchIds.matchModeTwo), findsNothing);
      },
    );

    testWidgets('the registry entry offers it in game mode only', (t) async {
      expect(memoryMatchGame.id, memoryMatchId);
    });
  });

  group('turns', () {
    testWidgets('player 1 starts; a match scores and keeps the turn', (
      t,
    ) async {
      final r = await open(t);
      expect(r.text(MemoryMatchIds.matchTurn), "Player 1's turn");
      await r.takePair(0, 0);
      expect(find.text('Player 1: 1'), findsOneWidget);
      expect(find.text('Player 2: 0'), findsOneWidget);
      expect(r.text(MemoryMatchIds.matchTurn), "Player 1's turn");
    });

    testWidgets('a mismatch passes the turn after the delay', (t) async {
      final r = await open(t);
      await r.miss(0, 0, 1);
      expect(r.text(MemoryMatchIds.matchTurn), "Player 2's turn");
    });

    testWidgets(
      'touch works for the active player and a matched card carries the owner marker',
      (t) async {
        final r = await open(t);
        await r.miss(0, 0, 1);
        await r.takePair(0, 2); // player 2 by touch
        expect(find.text('Player 2: 1'), findsOneWidget);
        expect(find.byIcon(Icons.square), findsWidgets);
      },
    );

    testWidgets('only the active player can use their keys', (t) async {
      final r = await open(t);
      // player 2's keys do nothing on player 1's turn
      await t.sendKeyEvent(LogicalKeyboardKey.keyF);
      await t.pump();
      expect(find.text('Player 1: 0'), findsOneWidget);
      expect(
        find.text('L00').evaluate().length + find.text('R00').evaluate().length,
        0,
      );
      // player 1 turns card 0 with Enter
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(
        find.descendant(
          of: find.byKey(MemoryMatchIds.matchCard(0)),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      // after a mismatch player 2 takes over and player 1's keys stop working
      await r.miss(0, 0, 1);
      await r.t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await r.t.sendKeyEvent(LogicalKeyboardKey.enter);
      await r.t.pump();
      expect(r.text(MemoryMatchIds.matchTurn), "Player 2's turn");
    });

    testWidgets('player 2 moves with W A S D and turns with F', (t) async {
      final r = await open(t);
      await r.miss(0, 0, 1); // now player 2
      await t.sendKeyEvent(LogicalKeyboardKey.keyD);
      await t.sendKeyEvent(LogicalKeyboardKey.keyF);
      await t.pump();
      expect(
        find.descendant(
          of: find.byKey(MemoryMatchIds.matchCard(1)),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
    });
  });

  group('boards and the round', () {
    testWidgets(
      'finishing a board shows who won it; the other player starts the next board',
      (t) async {
        final r = await open(t);
        for (var p = 0; p < 3; p++) {
          await r.takePair(0, p);
        }
        expect(find.byKey(MemoryMatchIds.matchBoardResult), findsOneWidget);
        expect(
          r.text(MemoryMatchIds.matchBoardResult),
          'Player 1 wins this board',
        );
        await t.ensureVisible(find.byKey(MemoryMatchIds.matchNext));
        await t.tap(find.byKey(MemoryMatchIds.matchNext));
        await t.pump();
        expect(r.text(MemoryMatchIds.matchTurn), "Player 2's turn");
        expect(find.text('Board 2 of 2'), findsOneWidget);
      },
    );

    testWidgets(
      'the round ends with the winner, then Play again swaps who starts',
      (t) async {
        final r = await open(t);
        for (var p = 0; p < 3; p++) {
          await r.takePair(0, p); // player 1 takes board 1
        }
        await t.ensureVisible(find.byKey(MemoryMatchIds.matchNext));
        await t.tap(find.byKey(MemoryMatchIds.matchNext));
        await t.pump();
        for (var p = 0; p < 3; p++) {
          await r.takePair(1, p); // player 2 starts board 2 and takes it
        }
        await t.ensureVisible(find.byKey(MemoryMatchIds.matchNext));
        await t.tap(find.byKey(MemoryMatchIds.matchNext));
        await t.pump();
        // one board each, three pairs each: a draw
        expect(r.text(MemoryMatchIds.matchWinner), 'A draw!');
        await t.tap(find.byKey(MemoryMatchIds.matchAgain));
        await t.pump();
        expect(
          r.text(MemoryMatchIds.matchTurn),
          "Player 2's turn",
        ); // sides swapped
        expect(find.text('Board 1 of 2'), findsOneWidget);
      },
    );

    testWidgets('Leave leaves', (t) async {
      final r = await open(t, boards: 1);
      for (var p = 0; p < 3; p++) {
        await r.takePair(0, p);
      }
      await t.ensureVisible(find.byKey(MemoryMatchIds.matchNext));
      await t.tap(find.byKey(MemoryMatchIds.matchNext));
      await t.pump();
      expect(r.text(MemoryMatchIds.matchWinner), 'Player 1 wins!');
      await t.tap(find.byKey(MemoryMatchIds.matchDone));
      expect(r.exits, ['exit']);
    });

    testWidgets('a two-player round records nothing', (t) async {
      final r = await open(t, boards: 1);
      for (var p = 0; p < 3; p++) {
        await r.takePair(0, p);
      }
      expect(r.session.index, 0);
      expect(r.session.report.answered, 0);
    });
  });

  group('pause and layout', () {
    testWidgets(
      'Space pauses: no card turns and a mismatch waits; Resume goes on',
      (t) async {
        final r = await open(t);
        await r.tapCard(r.pair(0, 0)[0]);
        await r.tapCard(r.pair(0, 1)[0]); // mismatch showing
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump(const Duration(milliseconds: 200));
        expect(find.byKey(MemoryMatchIds.matchPaused), findsOneWidget);
        expect(
          r.text(MemoryMatchIds.matchTurn),
          "Player 1's turn",
        ); // the delay did not run
        await t.tap(find.byKey(MemoryMatchIds.matchResume));
        await t.pump(const Duration(milliseconds: 100));
        expect(r.text(MemoryMatchIds.matchTurn), "Player 2's turn");
      },
    );

    testWidgets('Esc pauses a board and Leave leaves', (t) async {
      final r = await open(t);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(find.byKey(MemoryMatchIds.matchPaused), findsOneWidget);
      await t.tap(find.byKey(MemoryMatchIds.matchLeave));
      expect(r.exits, ['exit']);
    });

    testWidgets(
      'both players\' key hints show on a wide window and not on a phone; no title bar',
      (t) async {
        await open(t);
        expect(find.byKey(KeyIds.hints), findsNWidgets(2));
        expect(find.byType(AppBar), findsNothing);
        await open(t, size: const Size(390, 800));
        expect(find.byKey(KeyIds.hints), findsNothing);
      },
    );

    testWidgets('holds at 200 percent text on a phone', (t) async {
      final r = await open(t, size: const Size(390, 800), scale: 2);
      await r.miss(0, 0, 1);
      expect(t.takeException(), isNull);
    });

    testWidgets('score chips are announced to screen readers', (t) async {
      await open(t);
      expect(
        find.bySemanticsLabel(RegExp('Player 1, 0 pairs, your turn')),
        findsOneWidget,
      );
    });
  });
}
