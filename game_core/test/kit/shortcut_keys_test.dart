import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B-09: every button shows its key and the key presses it (docs/KEYBOARD.md).
void main() {
  testWidgets(
    'keyedLabel prints the real keys, Enter and Space, or a remapped key',
    (t) async {
      late BuildContext ctx;
      final keys = GameKeyMap()
        ..assign(const KeySlot(GameAction.action, 1), LogicalKeyboardKey.keyJ);
      await t.pumpWidget(
        GameKeysScope(
          keys: keys,
          child: MaterialApp(
            home: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(keyedLabel(ctx, 'Start', GameAction.action), 'Start (J)');
      expect(
        keyedLabel(ctx, 'Start', GameAction.action, alsoSpace: true),
        'Start (J / Space)',
      );
      expect(keyedLabel(ctx, 'Leave', GameAction.exit), 'Leave (Esc)');
      expect(withKey('Undo', 'Backspace'), 'Undo (Backspace)');
    },
  );

  testWidgets('GameKeyboard.shortcuts fire once per press, before the map', (
    t,
  ) async {
    final got = <GameInput>[];
    var l = 0, bs = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameKeyboard(
            onInput: got.add,
            shortcuts: {
              LogicalKeyboardKey.keyL: () => l++,
              LogicalKeyboardKey.backspace: () => bs++,
              // D is "right" for the left hand; a shortcut wins.
              LogicalKeyboardKey.keyD: () => l += 10,
            },
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.keyL);
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.sendKeyEvent(LogicalKeyboardKey.keyD);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(l, 11);
    expect(bs, 1);
    expect(got.map((i) => i.action), [GameAction.right]);
  });

  testWidgets('KeyHints prints extra chips after the actions', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KeyHints(
            actions: [GameAction.action],
            extra: [('H', 'hint'), ('Backspace', 'undo')],
          ),
        ),
      ),
    );
    expect(find.text('H'), findsOneWidget);
    expect(find.text('hint'), findsOneWidget);
    expect(find.text('Backspace'), findsOneWidget);
  });

  testWidgets(
    'the top bar and the pause screen print the keys of their buttons',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: Stack(
                children: [
                  GameTopBar(
                    title: 'Demo',
                    onExit: () {},
                    exitKey: const Key('exit'),
                    onPause: () {},
                    pauseKey: const Key('pause'),
                  ),
                  PauseOverlay(onResume: () {}, onLeave: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('L'), findsOneWidget);
      expect(find.text('Esc'), findsOneWidget);
      expect(find.text('Resume (Esc / Space)'), findsOneWidget);
      expect(find.text('Leave game (L)'), findsOneWidget);
    },
  );

  testWidgets('the calm results screen prints Enter / Space and Esc', (
    t,
  ) async {
    await t.pumpWidget(
      GameHostScope(
        host: const NoGameHost(),
        child: MaterialApp(
          home: Scaffold(
            body: CalmResults(
              game: 'demo',
              title: 'Done',
              score: 1,
              thresholds: const [1, 2, 3],
              onAgain: () {},
              onDone: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Play again (Enter / Space)'), findsOneWidget);
    expect(find.text('Done (Esc)'), findsOneWidget);
  });

  testWidgets(
    'the arcade frame prints keys on Play, Play again, Done and Continue (C)',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      ArcadeRun? run;
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
              hasContinue: true,
              buildPlay: (context, r, round) {
                run = r;
                return const SizedBox(key: Key('demo.field'));
              },
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Play (Enter / Space)'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      run!.end(5, canContinue: true);
      await t.pump();
      expect(find.text('Play again (Enter / Space)'), findsOneWidget);
      expect(find.text('Done (Esc)'), findsOneWidget);
      expect(find.text('Continue (C)'), findsOneWidget);
      // Esc is Done: back to the menu.
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(find.byKey(MindIds.arcade('demo', 'play')), findsOneWidget);
    },
  );
}
