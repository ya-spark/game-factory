import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_game_template/app.dart';
import 'package:flutter_game_template/core/ads/ad_service.dart';
import 'package:flutter_game_template/core/retention/daily_reward.dart';
import 'package:flutter_game_template/core/services.dart';
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

Future<void> pumpApp(WidgetTester tester, Services s) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
}

/// pumpAndSettle never returns while the Flame game loop is running.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('home shows the main menu', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    for (final k in [
      TestIds.homePlay,
      TestIds.homeDailyReward,
      TestIds.homeChallenges,
      TestIds.homeShop,
      TestIds.homeSettings,
      TestIds.homeCoins,
      TestIds.homeBestScore,
    ]) {
      expect(find.byKey(k), findsOneWidget, reason: '$k');
    }
  });

  testWidgets('daily reward screen: claim adds coins and disables the button', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeDailyReward));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.dailyDay(6)), findsOneWidget);
    await tester.tap(find.byKey(TestIds.dailyClaim));
    await tester.pumpAndSettle();
    expect(s.profile.data.coins, DailyRewardEngine.coinsByDay[0]);
    final btn = tester.widget<FilledButton>(find.byKey(TestIds.dailyClaim));
    expect(btn.onPressed, isNull);
  });

  testWidgets(
    'challenges screen lists three daily challenges and achievements',
    (tester) async {
      final s = await buildFakeServices();
      await pumpApp(tester, s);
      await tester.tap(find.byKey(TestIds.homeChallenges));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(TestIds.challengeTile(i)), findsOneWidget);
      }
      expect(find.byKey(TestIds.achievementTile('first_game')), findsOneWidget);
    },
  );

  testWidgets('shop: buying remove ads marks it owned and disables ads', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.shopBuy('remove_ads')));
    await tester.pumpAndSettle();
    expect(s.profile.data.adsRemoved, isTrue);
    expect(s.ads.adsEnabled, isFalse);
    expect(find.byKey(TestIds.shopBuy('remove_ads')), findsNothing);
    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    expect(s.profile.data.coins, 500);
  });

  testWidgets('settings toggles persist to the profile', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsSound));
    await tester.pumpAndSettle();
    expect(s.profile.data.soundOn, isFalse);
    expect(find.byKey(TestIds.settingsPlayGames), findsOneWidget);
  });

  testWidgets('game: dragging a tray piece onto the board places it', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homePlay));
    await tester.pump();
    final bot = PuzzleBot(tester);
    await bot.waitForGame();
    expect(bot.game.state.score, 0);
    final made = await bot.playMoves(3);
    expect(made, 3);
    expect(bot.game.state.piecesPlaced, 3);
    expect(bot.game.state.score, greaterThan(0));
    expect(
      tester.widget<Text>(find.byKey(TestIds.gameScore)).data,
      '${bot.game.state.score}',
    );
  });

  testWidgets('game: dropping outside the board does not place the piece', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homePlay));
    await tester.pump();
    final bot = PuzzleBot(tester);
    await bot.waitForGame();
    final origin = tester.getTopLeft(find.byKey(TestIds.gameWidget));
    final (sx, sy) = bot.game.layout.trayCenter(0);
    await tester.dragFrom(origin + Offset(sx, sy), const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 50));
    expect(bot.game.state.piecesPlaced, 0);
  });

  testWidgets('game over offers a rewarded-ad revive that continues the game', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Checkerboard: every empty cell is isolated, so after the dot nothing fits.
    final rows = List.generate(8, (r) => r.isEven ? '.#.#.#.#' : '#.#.#.#.');
    final game = BlockPuzzleGame(
      initialState: GameState(
        generator: PieceGenerator(Random(1)),
        board: Board.fromRows(rows),
        tray: [
          PieceCatalog.dot,
          PieceCatalog.byId('bar2_0'),
          PieceCatalog.byId('square2_0'),
        ],
      ),
    );
    await tester.pumpWidget(
      ServicesScope(
        services: s,
        child: MaterialApp(home: GameScreen(game: game)),
      ),
    );
    final bot = PuzzleBot(tester);
    await bot.waitForGame();
    expect(await bot.drag(0, 0, 0), isTrue);
    await settle(tester);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.byKey(TestIds.gameOverRevive), findsOneWidget);

    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await settle(tester);
    expect(ads.rewardedShown, 1);
    expect(game.state.isGameOver, isFalse);
    expect(game.state.revivesUsed, 1);
    expect(find.byKey(TestIds.gameOverDialog), findsNothing);
  });

  testWidgets(
    'game over: declined revive ad keeps the dialog and plays again',
    (tester) async {
      final ads = FakeAdService(rewardResult: false);
      final s = await buildFakeServices(ads: ads);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rows = List.generate(8, (r) => r.isEven ? '.#.#.#.#' : '#.#.#.#.');
      final game = BlockPuzzleGame(
        initialState: GameState(
          generator: PieceGenerator(Random(1)),
          board: Board.fromRows(rows),
          tray: [
            PieceCatalog.dot,
            PieceCatalog.byId('bar2_0'),
            PieceCatalog.byId('square2_0'),
          ],
        ),
      );
      await tester.pumpWidget(
        ServicesScope(
          services: s,
          child: MaterialApp(home: GameScreen(game: game)),
        ),
      );
      final bot = PuzzleBot(tester);
      await bot.waitForGame();
      await bot.drag(0, 0, 0);
      await settle(tester);
      await tester.tap(find.byKey(TestIds.gameOverRevive));
      await settle(tester);
      // Ad failed: dialog is shown again.
      expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
      await tester.tap(find.byKey(TestIds.gameOverRetry));
      await settle(tester);
      expect(game.state.piecesPlaced, 0);
      expect(game.state.isGameOver, isFalse);
      expect(s.profile.data.stats.gamesPlayed, 1);
      expect(ads.rewardedShown, 1);
      expect(AdPlacement.values, contains(AdPlacement.revive));
    },
  );
}
