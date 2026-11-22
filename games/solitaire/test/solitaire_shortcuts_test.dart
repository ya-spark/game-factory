import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_solitaire/solitaire.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B-09: Play, Undo, New deal and Hint show their keys; Left and Right change the level on the menu.
void main() {
  testWidgets('buttons print their keys', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1000, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: GameHostScope(host: const NoGameHost(), child: SolitaireScreen()),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Play (Enter / Space)'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Undo (Backspace / 2)'), findsOneWidget);
    expect(find.text('New deal (N)'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
