import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_blockfall/blockfall.dart';
import 'package:game_blockfall/testing.dart';
import 'package:game_core/kit/keys/keys.dart';
import 'package:game_core/kit/layout/frame_ids.dart';

/// Opens a game with the standard seven-piece rules and a few power-ups in stock.
Future<BlockfallGame> open(
  WidgetTester tester, {
  Size size = const Size(1000, 900),
}) async {
  final game = mk(stock: {for (final t in PowerUpType.values) t: 2});
  await pumpGame(tester, game, FakeBlockfallServices());
  tester.view.physicalSize = size;
  await tester.pump(const Duration(milliseconds: 100));
  return game;
}

void main() {
  testWidgets('arrows move and rotate the piece; held keys repeat', (
    tester,
  ) async {
    final game = await open(tester);
    final col = game.currentPiece!.col;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(game.currentPiece!.col, col - 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(game.currentPiece!.col, col);
    final rot = game.currentPiece!.rotation;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(game.currentPiece!.rotation, isNot(rot));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    expect(game.currentPiece!.col, lessThan(col));
  });

  testWidgets('the left hand plays too: A D W', (tester) async {
    final game = await open(tester);
    final col = game.currentPiece!.col;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(game.currentPiece!.col, col - 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    expect(game.currentPiece!.col, col);
  });

  testWidgets('Down soft-drops while held and stops on release', (
    tester,
  ) async {
    final game = await open(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(game.isSoftDropping, isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    // A quick tap still moves the piece (the drop holds for 0.15 s), then it stops.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.isSoftDropping, isFalse);
  });

  testWidgets('Enter drops the piece at once and scores it', (tester) async {
    final game = await open(tester);
    final before = game.score;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(game.score, greaterThan(before));
  });

  testWidgets('Q holds the piece, once per piece', (tester) async {
    final game = await open(tester);
    expect(game.holdPiece, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pump();
    expect(game.holdPiece, isNotNull);
    final held = game.holdPiece;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pump();
    expect(game.holdPiece, held);
  });

  testWidgets('Space pauses and the pause screen takes Space or Esc back', (
    tester,
  ) async {
    final game = await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(game.isPaused, isTrue);
    expect(find.byKey(TestIds.gamePauseResume), findsOneWidget);
    final col = game.currentPiece!.col;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(game.currentPiece!.col, col); // nothing moves while paused
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(game.isPaused, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(game.isPaused, isTrue);
  });

  testWidgets('a remapped key works and the old one does not', (tester) async {
    final keys = GameKeyMap()
      ..assign(const KeySlot(GameAction.up, 1), LogicalKeyboardKey.keyJ);
    final game = mk();
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GameKeysScope(
        keys: keys,
        child: BlockfallServicesScope(
          services: FakeBlockfallServices(),
          child: MaterialApp(home: GameScreen(game: game)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final rot = game.currentPiece!.rotation;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(game.currentPiece!.rotation, rot);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    expect(game.currentPiece!.rotation, isNot(rot));
  });

  testWidgets(
    'key hints on a wide window, none on a phone; the well is centered',
    (tester) async {
      await open(tester);
      expect(find.byKey(KeyIds.hints), findsOneWidget);
      expect(find.byKey(FrameIds.stage), findsOneWidget);
      expect(
        tester.getRect(find.byKey(FrameIds.stage)).center.dx,
        closeTo(500, 1),
      );
      await open(tester, size: const Size(390, 800));
      expect(find.byKey(KeyIds.hints), findsNothing);
    },
  );
}
