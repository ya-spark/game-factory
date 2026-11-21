import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/kit/keys/keys.dart';

Future<List<GameInput>> pump(
  WidgetTester tester, {
  bool twoPlayer = false,
  bool enabled = true,
  GameKeyMap? keys,
  List<GameInput>? released,
}) async {
  final got = <GameInput>[];
  Widget app = MaterialApp(
    home: Scaffold(
      body: GameKeyboard(
        twoPlayer: twoPlayer,
        enabled: enabled,
        onInput: got.add,
        onRelease: released?.add,
        child: Center(
          child: ElevatedButton(onPressed: () {}, child: const Text('Tap me')),
        ),
      ),
    ),
  );
  if (keys != null) app = GameKeysScope(keys: keys, child: app);
  await tester.pumpWidget(app);
  await tester.pump();
  return got;
}

void main() {
  testWidgets('keys reach the game as actions', (tester) async {
    final got = await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM); // not mapped
    expect(got.map((i) => i.action), [
      GameAction.left,
      GameAction.pause,
      GameAction.pick2,
    ]);
  });

  testWidgets('two players: WASD is player 2, arrows are player 1', (
    tester,
  ) async {
    final got = await pump(tester, twoPlayer: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(got.map((i) => (i.action, i.player)), [
      (GameAction.left, 2),
      (GameAction.right, 1),
      (GameAction.pause, 1),
    ]);
  });

  testWidgets('one player: the left hand works too and counts as player 1', (
    tester,
  ) async {
    final got = await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    expect(got.single.player, 1);
    expect(got.single.action, GameAction.right);
  });

  testWidgets('a remapped key works and the old one does not', (tester) async {
    final keys = GameKeyMap()
      ..assign(const KeySlot(GameAction.left, 1), LogicalKeyboardKey.keyJ);
    final got = await pump(tester, keys: keys);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(got.map((i) => i.action), [GameAction.left]);
  });

  testWidgets('held keys repeat and a release is reported', (tester) async {
    final released = <GameInput>[];
    final got = await pump(tester, released: released);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    expect(got.map((i) => i.repeat), [false, true]);
    expect(released.single.action, GameAction.right);
  });

  testWidgets('disabled: the keys are left alone', (tester) async {
    final got = await pump(tester, enabled: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(got, isEmpty);
  });

  testWidgets('the keys keep working after a tap moved the focus to a button', (
    tester,
  ) async {
    final got = await pump(tester);
    await tester.tap(find.text('Tap me'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(got.map((i) => i.action), contains(GameAction.up));
  });

  testWidgets('key hints show the real keys, also after a remap', (
    tester,
  ) async {
    final keys = GameKeyMap();
    await tester.pumpWidget(
      GameKeysScope(
        keys: keys,
        child: const MaterialApp(
          home: Scaffold(
            body: KeyHints(
              actions: [
                GameAction.left,
                GameAction.right,
                GameAction.up,
                GameAction.pick1,
                GameAction.pick2,
                GameAction.pick3,
                GameAction.pick4,
                GameAction.pause,
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('← →'), findsOneWidget);
    expect(find.text('1-4'), findsOneWidget);
    expect(find.text('Space'), findsOneWidget);
    keys.assign(const KeySlot(GameAction.pause, 0), LogicalKeyboardKey.keyP);
    await tester.pump();
    expect(find.text('P'), findsOneWidget);
    expect(find.text('Space'), findsNothing);
  });

  testWidgets('hints for player 2 show the left-hand keys', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KeyHints(
            player: 2,
            actions: [GameAction.left, GameAction.right, GameAction.action],
          ),
        ),
      ),
    );
    expect(find.text('A D'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
  });
}
