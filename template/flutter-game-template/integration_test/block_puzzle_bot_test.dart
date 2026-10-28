import 'package:flutter/material.dart';
import 'package:flutter_game_template/main.dart' as app;
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/puzzle_bot.dart';

/// Runs the real app on a device/emulator and plays the first moves of the block puzzle
/// with real pointer gestures. Run: `flutter test integration_test -d <device>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bot plays the first moves of the block puzzle', (tester) async {
    app.main();
    // Wait for the home screen (bootstrap is async). No pumpAndSettle: ads/game animate forever.
    for (
      var i = 0;
      i < 100 && find.byKey(TestIds.homePlay).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(TestIds.homePlay), findsOneWidget);

    await tester.tap(find.byKey(TestIds.homePlay));
    await tester.pump(const Duration(milliseconds: 500));

    final bot = PuzzleBot(tester);
    await bot.waitForGame();
    expect(bot.game.state.score, 0);

    final made = await bot.playMoves(5);
    expect(
      made,
      greaterThanOrEqualTo(3),
      reason: 'bot should place at least 3 pieces',
    );
    expect(bot.game.state.score, greaterThan(0));
    expect(
      tester.widget<Text>(find.byKey(TestIds.gameScore)).data,
      '${bot.game.state.score}',
    );

    // Back to the menu.
    await tester.tap(find.byKey(TestIds.gameBack));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
  });
}
