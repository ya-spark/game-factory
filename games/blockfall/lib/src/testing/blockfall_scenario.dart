import '../host/services.dart';
import '../game/rules/blockfall_game.dart';
import '../ui/test_ids.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'blockfall_bot.dart';

/// The bot's script, shared by the emulator integration test
/// (`integration_test/blockfall_bot_test.dart`) and the VM widget test
/// (`test/ui/e2e_bot_test.dart`), so both exercise exactly the same moves.
///
/// Preconditions: the game screen is showing with the Buttons control scheme and
/// `tester.ensureSemantics()` is active. [rules] is optional: widget tests can pass the
/// injected game to also assert on the falling piece itself; the emulator cannot.
/// All readouts otherwise come from Semantics values, like a real player-facing bot.
abstract final class BlockfallScenario {
  /// Opening moves: readouts, movement, soft drop, Hold, hard drop, a power-up, pause and
  /// resume. Leaves the game running and not over.
  static Future<void> openingMoves(
    WidgetTester tester,
    BlockfallBot bot, {
    BlockfallGame? rules,
  }) async {
    // Fresh game readouts.
    expect(bot.score, 0);
    expect(bot.level, 1);
    expect(bot.goal, 10);
    expect(bot.combo, 0);
    expect(bot.holdPiece, 'empty');
    expect(find.byKey(TestIds.gameBanner), findsNothing);
    for (final k in [
      TestIds.gameCtlLeft,
      TestIds.gameCtlRight,
      TestIds.gameCtlRotate,
      TestIds.gameCtlSoftDrop,
      TestIds.gameCtlHardDrop,
    ]) {
      expect(find.byKey(k), findsOneWidget, reason: '$k');
    }

    // The piece moves: left, right and rotate change its place and orientation.
    final startCol = rules?.currentPiece?.col;
    await bot.left(2);
    if (rules != null) expect(rules.currentPiece!.col, startCol! - 2);
    await bot.right(3);
    if (rules != null) expect(rules.currentPiece!.col, startCol! + 1);
    await bot.rotate();
    if (rules != null) expect(rules.currentPiece!.rotation, 1);

    // Soft drop pays 1 point per row.
    await bot.softDrop();
    await bot.pumpFor(const Duration(milliseconds: 400));
    final afterSoft = bot.score;
    expect(afterSoft, greaterThan(0), reason: 'soft drop scored');

    // Hold stores the piece and brings in the next one; a second Hold is ignored.
    final queued = bot.nextPiece(1);
    await bot.hold();
    expect(bot.holdPiece, isNot('empty'));
    final held = bot.holdPiece;
    expect(bot.nextPiece(0), queued, reason: 'queue advanced on Hold');
    await bot.hold();
    expect(bot.holdPiece, held, reason: 'Hold once per piece');
    expect(bot.nextPiece(0), queued, reason: 'second Hold changed nothing');

    // Hard drop locks the piece, the queue advances and the score grows (2 per row).
    final n1 = bot.nextPiece(1);
    final beforeDrop = bot.score;
    await bot.hardDrop();
    expect(bot.score, greaterThan(beforeDrop), reason: 'hard drop scored');
    expect(bot.nextPiece(0), n1, reason: 'next piece became current');
    if (rules != null) expect(rules.piecesPlaced, 1);

    // A power-up button: Slow costs one from stock (or opens the refill sheet at 0).
    final slowBefore = bot.powerUpCount(TestIds.gamePowerUpSlowCount);
    await tester.tap(find.byKey(TestIds.gamePowerUpSlow));
    await bot.pumpFor(const Duration(milliseconds: 300));
    if (slowBefore > 0) {
      expect(bot.powerUpCount(TestIds.gamePowerUpSlowCount), slowBefore - 1);
    } else {
      expect(find.byKey(TestIds.gameRefillCoins), findsOneWidget);
      await tester.tapAt(const Offset(5, 5)); // dismiss the sheet
      await bot.pumpFor(const Duration(milliseconds: 500));
    }

    // Pause stops the game; resume continues it.
    await bot.tap(TestIds.gamePause);
    expect(find.byKey(TestIds.gamePauseResume), findsOneWidget);
    final pausedScore = bot.score;
    await bot.pumpFor(const Duration(seconds: 2));
    expect(bot.score, pausedScore, reason: 'nothing happens while paused');
    await bot.tap(TestIds.gamePauseResume);
    expect(find.byKey(TestIds.gamePauseResume), findsNothing);
    expect(bot.isGameOver, isFalse);
  }

  /// Plays random drops, then stacks straight down until the well tops out. Returns the
  /// number of pieces dropped. Ends with the game over dialog showing.
  static Future<int> playToGameOver(
    WidgetTester tester,
    BlockfallBot bot, {
    int randomPieces = 150,
    int maxStackDrops = 80,
  }) async {
    var n = await bot.playRandom(randomPieces);
    var stack = 0;
    while (!bot.isGameOver && stack < maxStackDrops) {
      await bot.hardDrop();
      stack++;
    }
    expect(bot.isGameOver, isTrue, reason: 'the game ends in game over');
    return n + stack;
  }

  // ---- whole-app flow (from Home) ------------------------------------------

  /// Opens Settings from Home, sets the controls switch and returns to Home.
  static Future<void> setControls(
    WidgetTester tester,
    BlockfallBot bot, {
    required bool buttons,
  }) async {
    await bot.tap(TestIds.homeSettings);
    await bot.pumpFor(const Duration(milliseconds: 800));
    final on = tester
        .widget<SwitchListTile>(find.byKey(TestIds.settingsControls))
        .value;
    if (on != buttons) {
      await bot.tap(TestIds.settingsControls);
      await bot.pumpFor(const Duration(milliseconds: 300));
    }
    await tester.pageBack();
    await bot.pumpFor(const Duration(milliseconds: 800));
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
  }

  static Future<void> _play(WidgetTester tester, BlockfallBot bot) async {
    await bot.tap(TestIds.homePlay);
    await bot.pumpFor(const Duration(milliseconds: 800));
    expect(find.byKey(TestIds.gameWidget), findsOneWidget);
    // No ad widget on the game screen, ever.
    expect(find.byKey(TestIds.gameBanner), findsNothing);
  }

  /// Touch scheme: tap, drag and fling on `game.well`. Only the fling is visible through
  /// Semantics (score and queue); tap and drag must at least run without errors.
  static Future<void> gesturePhase(
    WidgetTester tester,
    BlockfallBot bot,
  ) async {
    for (final k in [
      TestIds.gameCtlLeft,
      TestIds.gameCtlRight,
      TestIds.gameCtlRotate,
      TestIds.gameCtlSoftDrop,
      TestIds.gameCtlHardDrop,
    ]) {
      expect(find.byKey(k), findsNothing, reason: '$k absent with Touch');
    }
    await bot.tapWell();
    await bot.dragColumns(2);
    await bot.dragColumns(-2);
    final n1 = bot.nextPiece(1);
    final before = bot.score;
    await bot.flingDown();
    expect(bot.score, greaterThan(before), reason: 'fling hard-dropped');
    expect(bot.nextPiece(0), n1, reason: 'next piece became current');
  }

  /// Home to Home: touch gestures, then the Buttons opening moves, a played game to game
  /// over, and back to Home. Needs `tester.ensureSemantics()` and the Home screen showing.
  static Future<void> fullAppRun(WidgetTester tester, {int botSeed = 1}) async {
    final bot = BlockfallBot(tester, seed: botSeed);
    expect(find.byKey(TestIds.homePlay), findsOneWidget);

    await setControls(tester, bot, buttons: false);
    await _play(tester, bot);
    await gesturePhase(tester, bot);
    await bot.tap(
      TestIds.gameBack,
    ); // Back pauses; Exit saves the game and leaves
    await bot.pumpFor(const Duration(milliseconds: 300));
    await bot.tap(TestIds.gamePauseQuit);
    await bot.pumpFor(const Duration(milliseconds: 800));
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
    // Leaving keeps the unfinished game (autosave); drop it so the next Play is a new game.
    final home = tester.element(find.byKey(TestIds.homePlay));
    await BlockfallServicesScope.of(home).profile.saveGame(null);

    await setControls(tester, bot, buttons: true);
    await _play(tester, bot);
    await openingMoves(tester, bot);
    await playToGameOver(tester, bot);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    await bot.pumpFor(const Duration(milliseconds: 1100));
    expect(int.parse(bot.value(TestIds.gameOverScore)), greaterThan(0));
    await bot.tap(TestIds.gameOverHome);
    await bot.pumpFor(const Duration(seconds: 1));
    expect(
      find.byKey(TestIds.homePlay),
      findsOneWidget,
      reason: 'back at Home',
    );
  }
}
