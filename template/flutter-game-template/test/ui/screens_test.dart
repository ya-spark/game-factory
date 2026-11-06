import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_game_template/app.dart';
import 'package:flutter_game_template/core/ads/ad_service.dart';
import 'package:flutter_game_template/core/purchase/parent_gate_guard.dart';
import 'package:flutter_game_template/core/purchase/purchase_service.dart';
import 'package:flutter_game_template/core/retention/daily_reward.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/game/flame/block_puzzle_game.dart';
import 'package:flutter_game_template/game/rules/board.dart';
import 'package:flutter_game_template/game/rules/game_state.dart';
import 'package:flutter_game_template/game/rules/piece.dart';
import 'package:flutter_game_template/game/rules/piece_generator.dart';
import 'package:flutter_game_template/ui/game_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_game_template/ui/widgets.dart';
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
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Types the correct answer into the open parent gate and submits.
Future<void> answerGate(WidgetTester tester, Services s) async {
  await tester.enterText(
    find.byKey(TestIds.gateAnswer),
    '${s.parentGate.a * s.parentGate.b}',
  );
  await tester.tap(find.byKey(TestIds.gateSubmit));
  await tester.pumpAndSettle();
}

/// Opens a game on a board where the first placement ends the game; the game over panel is up.
Future<BlockPuzzleGame> pumpGameOver(WidgetTester tester, Services s) async {
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
  return game;
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
    await tester.ensureVisible(find.byKey(TestIds.homeDailyReward));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(TestIds.shopBuy('remove_ads_all')));
    await tester.pumpAndSettle();
    await answerGate(tester, s);
    expect(s.profile.data.adsRemoved, isTrue);
    expect(s.ads.adsEnabled, isFalse);
    expect(find.byKey(TestIds.shopBuy('remove_ads_all')), findsNothing);
    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    await answerGate(tester, s);
    expect(s.profile.data.coins, 500);
  });

  testWidgets('coin icon replaces the old icon on home and in the shop', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    expect(find.byType(CoinIcon), findsOneWidget);
    expect(find.byIcon(Icons.monetization_on), findsNothing);
    await tester.tap(find.byKey(TestIds.homeShop));
    await tester.pumpAndSettle();
    expect(find.byType(CoinIcon), findsNWidgets(3)); // the three coin packs
    expect(find.byIcon(Icons.monetization_on), findsNothing);
  });

  testWidgets('shop lists all four products, Remove Ads first', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await tester.pumpAndSettle();
    final ids = ['remove_ads_all', 'coins_500', 'coins_1500', 'coins_4000'];
    final ys = [
      for (final id in ids)
        tester.getTopLeft(find.byKey(TestIds.shopBuy(id))).dy,
    ];
    expect(ys, [...ys]..sort());
  });

  testWidgets('parent gate: cancel buys nothing; wrong answers lock for 60 s', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1, 12);
    final s = await buildFakeServices(
      parentGate: ParentGateGuard(clock: () => now, random: Random(3)),
    );
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.gateDialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gateCancel));
    await tester.pumpAndSettle();
    expect(s.profile.data.coins, 0);

    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(TestIds.gateDialog), findsOneWidget);
      await tester.enterText(find.byKey(TestIds.gateAnswer), '1');
      await tester.tap(find.byKey(TestIds.gateSubmit));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(TestIds.gateDialog), findsNothing);
    expect(s.profile.data.coins, 0);
    expect(s.parentGate.isLocked, isTrue);

    // Still locked 30 s later: the dialog opens but cannot be answered.
    now = now.add(const Duration(seconds: 30));
    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.gateAnswer), findsNothing);
    await tester.tap(find.byKey(TestIds.gateCancel));
    await tester.pumpAndSettle();
    expect(s.profile.data.coins, 0);

    // After the 60 s the gate works again.
    now = now.add(const Duration(seconds: 31));
    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    await answerGate(tester, s);
    expect(s.profile.data.coins, 500);
  });

  test('parent gate guard: factors 6 to 9, wrong then correct', () {
    final g = ParentGateGuard(random: Random(5));
    for (var i = 0; i < 50; i++) {
      g.newQuestion();
      expect(g.a, inInclusiveRange(6, 9));
      expect(g.b, inInclusiveRange(6, 9));
    }
    expect(g.submit('abc'), GateAnswer.wrong);
    expect(g.submit('${g.a * g.b}'), GateAnswer.correct);
  });

  test('parent gate guard: 3 wrong answers lock 60 s, then it unlocks', () {
    var now = DateTime(2026, 1, 1);
    final g = ParentGateGuard(clock: () => now, random: Random(1));
    expect(g.submit('0'), GateAnswer.wrong);
    expect(g.submit('0'), GateAnswer.wrong);
    expect(g.submit('0'), GateAnswer.locked);
    expect(g.isLocked, isTrue);
    expect(g.lockSecondsLeft, 60);
    expect(
      g.submit('${g.a * g.b}'),
      GateAnswer.locked,
    ); // right answer, still locked
    now = now.add(const Duration(seconds: 59));
    expect(g.isLocked, isTrue);
    now = now.add(const Duration(seconds: 2));
    expect(g.isLocked, isFalse);
    expect(g.submit('${g.a * g.b}'), GateAnswer.correct);
  });

  testWidgets('remove ads: continue is granted at once without an ad', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    await s.profile.addCoins(200);
    await s.profile.deliverPurchase(
      const PurchaseUpdate('remove_ads_all', PurchaseStatus.purchased),
      s.catalog,
    );
    final game = await pumpGameOver(tester, s);
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await settle(tester);
    expect(ads.rewardedShown, 0);
    expect(s.profile.data.coins, 200);
    expect(game.state.isGameOver, isFalse);
    expect(game.state.revivesUsed, 1);
  });

  testWidgets('legacy remove_ads entitlement also continues without an ad', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    await s.profile.deliverPurchase(
      const PurchaseUpdate('remove_ads', PurchaseStatus.restored),
      s.catalog,
    );
    expect(s.profile.data.adsRemoved, isTrue);
    final game = await pumpGameOver(tester, s);
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await settle(tester);
    expect(ads.rewardedShown, 0);
    expect(game.state.revivesUsed, 1);
  });

  testWidgets('1000 coins: continue calls the ad directly, no coins spent', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    await s.profile.addCoins(1000);
    final game = await pumpGameOver(tester, s);
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(ads.rewardedShown, 1);
    expect(game.state.revivesUsed, 1);
    expect(game.state.isGameOver, isFalse);
    expect(s.profile.data.coins, 1000);
  });

  testWidgets('ad not earned: no continue, panel open, coins unchanged', (
    tester,
  ) async {
    final ads = FakeAdService(rewardResult: false);
    final s = await buildFakeServices(ads: ads);
    await s.profile.addCoins(1000);
    final game = await pumpGameOver(tester, s);
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await settle(tester);
    expect(ads.rewardedShown, 1);
    expect(game.state.revivesUsed, 0);
    expect(game.state.isGameOver, isTrue);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.textContaining('No ad available right now'), findsOneWidget);
    expect(s.profile.data.coins, 1000);
  });

  testWidgets('ad continues count against the 3 per run limit', (tester) async {
    final s = await buildFakeServices();
    final game = await pumpGameOver(tester, s);
    game.state.revivesUsed = GameState.maxRevives - 1;
    await tester.tap(find.byKey(TestIds.gameOverRevive));
    await settle(tester);
    expect(game.state.revivesUsed, GameState.maxRevives);
    expect(game.state.canRevive, isFalse);
  });

  testWidgets('settings toggles persist to the profile', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsSound));
    await tester.pumpAndSettle();
    expect(s.profile.data.soundOn, isFalse);
    // Play Games is off in the template config, so its row is hidden.
    expect(find.byKey(TestIds.settingsPlayGames), findsNothing);
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
    expect(game.state.revivesRemaining, 2);
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
