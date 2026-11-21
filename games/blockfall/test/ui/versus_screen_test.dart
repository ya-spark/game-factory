import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_blockfall/blockfall.dart';
import 'package:game_core/kit/keys/keys.dart';

class Rig {
  Rig(this.t, this.exits, this.games);
  final WidgetTester t;
  final List<String> exits;
  final List<BlockfallVersus> games;
  BlockfallVersus get v => games.last;

  Future<void> key(LogicalKeyboardKey k) async {
    await t.sendKeyEvent(k);
    await t.pump();
  }

  Future<void> start() => key(LogicalKeyboardKey.enter);
}

Future<Rig> open(
  WidgetTester t, {
  Size size = const Size(1200, 900),
  double scale = 1,
  PieceBag Function()? bag,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final rig = Rig(t, [], []);
  await t.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: BlockfallVersusScreen(
          onExit: () => rig.exits.add('exit'),
          newGame: () {
            final v = BlockfallVersus(seed: 9, bagFor: bag);
            rig.games.add(v);
            return v;
          },
        ),
      ),
    ),
  );
  await t.pump();
  return rig;
}

void main() {
  testWidgets(
    'the intro lists both players\' keys; Enter starts and shows two wells',
    (t) async {
      final r = await open(t);
      expect(find.byKey(TestIds.versusStart), findsOneWidget);
      expect(find.textContaining('Player 1: ← → ↑ ↓ Enter 1'), findsOneWidget);
      expect(find.textContaining('Player 2: A D W S F Z'), findsOneWidget);
      await r.start();
      expect(find.byKey(TestIds.versusP1Well), findsOneWidget);
      expect(find.byKey(TestIds.versusP2Well), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('player 2 is on the left, player 1 on the right', (t) async {
    final r = await open(t);
    await r.start();
    final left = t.getRect(find.byKey(TestIds.versusP2Well));
    final right = t.getRect(find.byKey(TestIds.versusP1Well));
    expect(left.right, lessThan(right.left));
    expect(find.byKey(TestIds.versusScreen), findsOneWidget);
  });

  testWidgets('each player\'s keys move only their own well', (t) async {
    final r = await open(t);
    await r.start();
    final c1 = r.v.game(1).currentPiece!.col,
        c2 = r.v.game(2).currentPiece!.col;
    await r.key(LogicalKeyboardKey.arrowLeft);
    expect(r.v.game(1).currentPiece!.col, c1 - 1);
    expect(r.v.game(2).currentPiece!.col, c2);
    await r.key(LogicalKeyboardKey.keyD);
    expect(r.v.game(2).currentPiece!.col, c2 + 1);
    expect(r.v.game(1).currentPiece!.col, c1 - 1);
  });

  testWidgets('up rotates, down soft-drops while held, Enter and F hard-drop', (
    t,
  ) async {
    final r = await open(t);
    await r.start();
    final rot = r.v.game(1).currentPiece!.rotation;
    await r.key(LogicalKeyboardKey.arrowUp);
    expect(r.v.game(1).currentPiece!.rotation, isNot(rot));
    await t.sendKeyDownEvent(LogicalKeyboardKey.keyS);
    await t.pump();
    expect(r.v.game(2).isSoftDropping, isTrue);
    expect(r.v.game(1).isSoftDropping, isFalse);
    await t.sendKeyUpEvent(LogicalKeyboardKey.keyS);
    await t.pump();
    expect(r.v.game(2).isSoftDropping, isFalse);
    await r.key(LogicalKeyboardKey.enter);
    expect(r.v.game(1).piecesPlaced, 1);
    expect(r.v.game(2).piecesPlaced, 0);
    await r.key(LogicalKeyboardKey.keyF);
    expect(r.v.game(2).piecesPlaced, 1);
  });

  testWidgets('1 holds for player 1 and Z for player 2, once per piece', (
    t,
  ) async {
    final r = await open(t);
    await r.start();
    await r.key(LogicalKeyboardKey.digit1);
    expect(r.v.game(1).holdPiece, isNotNull);
    expect(r.v.game(2).holdPiece, isNull);
    await r.key(LogicalKeyboardKey.keyZ);
    expect(r.v.game(2).holdPiece, isNotNull);
  });

  testWidgets('a clear sends garbage and the bar shows it', (t) async {
    final r = await open(t, bag: () => PieceBag.sequence([PieceType.cube]));
    await r.start();
    final g = r.v.game(1);
    final gap = {for (final c in g.currentPiece!.cells) c.col};
    for (var row = Well.totalRows - 2; row < Well.totalRows; row++) {
      for (var c = 0; c < Well.cols; c++) {
        g.well.set(row, c, gap.contains(c) ? 0 : 1);
      }
    }
    await r.key(LogicalKeyboardKey.enter);
    expect(r.v.pendingFor(2), 1);
    expect(
      find.bySemanticsLabel(RegExp('Player 2: 1 garbage row coming')),
      findsOneWidget,
    );
    final bar = t.getRect(
      find.descendant(
        of: find.byKey(TestIds.versusP2Garbage),
        matching: find.byType(Container),
      ),
    );
    expect(bar.height, greaterThan(0));
  });

  testWidgets('Space pauses both wells and Resume goes on', (t) async {
    final r = await open(t);
    await r.start();
    await t.pump(const Duration(milliseconds: 100));
    await r.key(LogicalKeyboardKey.space);
    expect(find.byKey(TestIds.versusPaused), findsOneWidget);
    final e = r.v.elapsed;
    await t.pump(const Duration(seconds: 1));
    expect(r.v.elapsed, e);
    final c = r.v.game(1).currentPiece!.col;
    await r.key(LogicalKeyboardKey.arrowLeft);
    expect(r.v.game(1).currentPiece!.col, c);
    await t.tap(find.byKey(TestIds.versusResume));
    await t.pump(); // the first frame after resuming only restarts the clock
    await t.pump(const Duration(milliseconds: 200));
    expect(r.v.elapsed, greaterThan(e));
  });

  testWidgets('Esc leaves from the intro, pauses in a game, and Leave leaves', (
    t,
  ) async {
    final r = await open(t);
    await r.key(LogicalKeyboardKey.escape);
    expect(r.exits, ['exit']);
    final r2 = await open(t);
    await r2.start();
    await r2.key(LogicalKeyboardKey.escape);
    expect(find.byKey(TestIds.versusPaused), findsOneWidget);
    await t.tap(find.byKey(TestIds.versusLeave));
    expect(r2.exits, ['exit']);
  });

  testWidgets(
    'topping out ends the game: the other wins, Play again starts a new one',
    (t) async {
      final r = await open(t);
      await r.start();
      for (
        var i = 0;
        i < 60 && find.byKey(TestIds.versusWinner).evaluate().isEmpty;
        i++
      ) {
        await r.key(LogicalKeyboardKey.enter); // player 1 only
      }
      expect(
        (t.widget(find.byKey(TestIds.versusWinner)) as Text).data,
        'Player 2 wins!',
      );
      final games = r.games.length;
      await t.tap(find.byKey(TestIds.versusAgain));
      await t.pump();
      expect(r.games.length, games + 1);
      expect(find.byKey(TestIds.versusP1Well), findsOneWidget);
    },
  );

  testWidgets('both players\' key hints on a wide window; no title bar', (
    t,
  ) async {
    final r = await open(t);
    await r.start();
    expect(find.byKey(KeyIds.hints), findsNWidgets(2));
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('holds at 200 percent text on a 900 wide window', (t) async {
    final r = await open(t, size: const Size(900, 800), scale: 2);
    await r.start();
    await r.key(LogicalKeyboardKey.arrowLeft);
    expect(t.takeException(), isNull);
  });

  testWidgets('a versus game records nothing: no profile is needed', (t) async {
    final r = await open(t);
    await r.start();
    expect(find.byType(BlockfallServicesScope), findsNothing);
  });
}
