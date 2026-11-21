import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/kit/keys/keys.dart';

Future<GameKeyMap> open(
  WidgetTester tester, {
  GameKeyMap? keys,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final map = keys ?? GameKeyMap();
  await tester.pumpWidget(
    GameKeysScope(
      keys: map,
      child: MaterialApp(
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: w!,
        ),
        home: const ControlsScreen(),
      ),
    ),
  );
  await tester.pump();
  return map;
}

void main() {
  const left1 = KeySlot(GameAction.left, 1);
  const left2 = KeySlot(GameAction.left, 2);

  testWidgets('lists every action with both players and no Exit row', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(KeyIds.controlsScreen), findsOneWidget);
    for (final a in GameAction.values.where((a) => a != GameAction.exit)) {
      expect(
        find.byKey(KeyIds.row(KeySlot(a, a.shared ? 0 : 1))),
        findsOneWidget,
        reason: a.name,
      );
    }
    expect(
      find.byKey(KeyIds.row(const KeySlot(GameAction.exit, 0))),
      findsNothing,
    );
    expect(find.byKey(KeyIds.chip(left2)), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
  });

  testWidgets('tap a chip, press a key: it is assigned', (tester) async {
    final map = await open(tester);
    await tester.tap(find.byKey(KeyIds.chip(left1)));
    await tester.pump();
    expect(find.byKey(KeyIds.listening), findsOneWidget);
    expect(find.textContaining('Press a key for Move left'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pump();
    expect(map.primaryOf(left1), LogicalKeyboardKey.keyJ);
    expect(find.byKey(KeyIds.listening), findsNothing);
    expect(find.text('J'), findsOneWidget);
    expect(find.textContaining('now J'), findsOneWidget);
  });

  testWidgets('a key another action uses is swapped and said so', (
    tester,
  ) async {
    final map = await open(tester);
    await tester.tap(find.byKey(KeyIds.chip(left1)));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(map.primaryOf(left1), LogicalKeyboardKey.keyA);
    expect(map.primaryOf(left2), LogicalKeyboardKey.arrowLeft);
    expect(find.textContaining('took Left arrow'), findsOneWidget);
  });

  testWidgets('Escape cancels and a system key is refused', (tester) async {
    final map = await open(tester);
    await tester.tap(find.byKey(KeyIds.chip(left1)));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byKey(KeyIds.listening), findsOneWidget);
    expect(find.textContaining('kept for the system'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(KeyIds.listening), findsNothing);
    expect(map.allDefault, isTrue);
    expect(find.textContaining('Cancelled'), findsOneWidget);
  });

  testWidgets(
    'works from the keyboard alone: focus a chip, Enter, press a key',
    (tester) async {
      final map = await open(tester);
      Focus.of(tester.element(find.byKey(KeyIds.chip(left1)))); // exists
      // Tab to the first chip (the first focusable thing), then Enter starts listening.
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus;
        if (focused?.debugLabel == 'chip p1.left') break;
      }
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'chip p1.left');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byKey(KeyIds.listening), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pump();
      expect(map.primaryOf(left1), LogicalKeyboardKey.keyK);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'chip p1.left');
    },
  );

  testWidgets(
    'Reset to defaults is off until something changed, then restores',
    (tester) async {
      final map = await open(tester);
      expect(
        tester.widget<FilledButton>(find.byKey(KeyIds.reset)).onPressed,
        isNull,
      );
      map.assign(left1, LogicalKeyboardKey.keyJ);
      await tester.pump();
      await tester.tap(find.byKey(KeyIds.reset));
      await tester.pump();
      expect(map.allDefault, isTrue);
      expect(find.textContaining('back to its start'), findsOneWidget);
    },
  );

  testWidgets('chips have a spoken label', (tester) async {
    await open(tester);
    expect(
      find.bySemanticsLabel('Move left (player 1), key Left arrow'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Move left (player 2), key A'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Pause, key Space')), findsOneWidget);
  });

  testWidgets('fits at 200 percent text, down to the buttons', (tester) async {
    await open(tester, textScale: 2);
    await tester.scrollUntilVisible(
      find.byKey(KeyIds.done),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(KeyIds.done), findsOneWidget);
  });

  testWidgets('Done closes the screen', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.of(c).push(
              MaterialPageRoute<void>(
                builder: (_) => ControlsScreen(keys: GameKeyMap()),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(KeyIds.controlsScreen), findsOneWidget);
    await tester.tap(find.byKey(KeyIds.done));
    await tester.pumpAndSettle();
    expect(find.byKey(KeyIds.controlsScreen), findsNothing);
  });
}
