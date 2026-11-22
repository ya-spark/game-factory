import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keyboard play in the shared arcade frame (docs/KEYBOARD.md): Enter starts, Space and Esc pause,
/// other keys reach the game, Esc on the menu leaves.
void main() {
  Future<List<GameInput>> open(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({});
    final got = <GameInput>[];
    await t.pumpWidget(
      MaterialApp(
        home: GameHostScope(
          host: const NoGameHost(),
          child: ArcadeFrame(
            id: 'demo',
            title: 'Demo',
            howTo: 'How',
            starScores: const [1, 2, 3],
            coinsPerPoints: 10,
            hintActions: const [GameAction.left, GameAction.right],
            buildPlay: (context, run, round) {
              run.onInput = got.add;
              return const SizedBox(key: Key('demo.field'));
            },
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    return got;
  }

  testWidgets(
    'Enter starts, keys reach the game, Space pauses and Esc resumes',
    (t) async {
      final got = await open(t);
      expect(find.byKey(const Key('demo.field')), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(find.byKey(const Key('demo.field')), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(got.map((i) => i.action), [GameAction.left]);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(find.text('Paused'), findsOneWidget);
      await t.sendKeyEvent(
        LogicalKeyboardKey.arrowRight,
      ); // ignored while paused
      expect(got.length, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(find.text('Paused'), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(got.length, 2);
    },
  );

  testWidgets('Esc pauses a round and Leave goes back to the menu', (t) async {
    await open(t);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.text('Paused'), findsOneWidget);
    await t.tap(find.byKey(MindIds.arcade('demo', 'leave')));
    await t.pump();
    expect(find.byKey(MindIds.arcade('demo', 'play')), findsOneWidget);
  });
}
