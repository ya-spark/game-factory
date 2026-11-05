import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/core/share/share_service.dart';
import 'package:flutter_game_template/game/flame/block_puzzle_game.dart';
import 'package:flutter_game_template/game/rules/board.dart';
import 'package:flutter_game_template/game/rules/game_state.dart';
import 'package:flutter_game_template/game/rules/piece.dart';
import 'package:flutter_game_template/game/rules/piece_generator.dart';
import 'package:flutter_game_template/ui/game_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import '../helpers/puzzle_bot.dart';

/// Checkerboard: every empty cell is isolated, so after the dot nothing fits.
GameState deadEndState() => GameState(
  generator: PieceGenerator(Random(1)),
  board: Board.fromRows(
    List.generate(8, (r) => r.isEven ? '.#.#.#.#' : '#.#.#.#.'),
  ),
  tray: [
    PieceCatalog.dot,
    PieceCatalog.byId('bar2_0'),
    PieceCatalog.byId('square2_0'),
  ],
);

Future<void> endRun(WidgetTester tester, Services s) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final game = BlockPuzzleGame(initialState: deadEndState());
  await tester.pumpWidget(
    ServicesScope(
      services: s,
      child: MaterialApp(home: GameScreen(game: game)),
    ),
  );
  await PuzzleBot(tester).waitForGame();
  expect(await PuzzleBot(tester).drag(0, 0, 0), isTrue);
}

bool retryTappable(WidgetTester tester) =>
    find.byKey(TestIds.gameOverRetry).hitTestable().evaluate().isNotEmpty;

double panelOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byKey(TestIds.gameOverPanel),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

void main() {
  testWidgets('game over share button shares the score text', (tester) async {
    final share = FakeShareService(link: 'https://example.com/test');
    final s = await buildFakeServices(share: share);
    await endRun(tester, s);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(TestIds.gameOverShare));
    await tester.runAsync(() async {
      for (var i = 0; i < 20 && share.sent.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(share.sent, hasLength(1));
    expect(share.sent.single.text, endsWith('\nhttps://example.com/test'));
  });

  testWidgets('game over panel: layout order and the eye button', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await endRun(tester, s);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(TestIds.gameOverPanel), findsOneWidget);

    // Share top left, Play again and Home side by side, Continue last.
    final panel = tester.getRect(find.byKey(TestIds.gameOverPanel));
    final share = tester.getRect(find.byKey(TestIds.gameOverShare));
    final again = tester.getRect(find.byKey(TestIds.gameOverRetry));
    final home = tester.getRect(find.byKey(TestIds.gameOverHome));
    final cont = tester.getRect(find.byKey(TestIds.gameOverRevive));
    expect(share.left - panel.left, lessThan(30));
    expect(share.bottom, lessThanOrEqualTo(again.top));
    expect((again.center.dy - home.center.dy).abs(), lessThan(2));
    expect(again.right, lessThan(home.left));
    expect(cont.top, greaterThanOrEqualTo(again.bottom));

    // Eye button fades the panel out in 0.2 s; a tap anywhere brings it back.
    await tester.tap(find.byKey(TestIds.gameOverView));
    await tester.pump(const Duration(milliseconds: 250));
    expect(panelOpacity(tester), 0);
    expect(find.byKey(TestIds.gameOverView), findsOneWidget);
    await tester.tapAt(const Offset(200, 600));
    await tester.pump(const Duration(milliseconds: 250));
    expect(panelOpacity(tester), 1);
  });

  testWidgets('game over eases in: buttons tappable only after 1 s', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await endRun(tester, s);
    await tester.pump(); // first frame of the overlay
    expect(find.byKey(TestIds.gameOverPanel), findsOneWidget);
    expect(retryTappable(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(retryTappable(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 650));
    expect(retryTappable(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(retryTappable(tester), isTrue);
  });

  testWidgets('game over with reduce motion is a single 0.2 s fade', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final s = await buildFakeServices();
    await endRun(tester, s);
    await tester.pump();
    expect(retryTappable(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 250));
    expect(retryTappable(tester), isTrue);
  });
}
