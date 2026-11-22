import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_sudoku/sudoku.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B-09: Play shows its number; Notes, Erase, Undo and Hint show their keys; N toggles the notes.
void main() {
  testWidgets('level and tool buttons print their keys', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1000, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: GameHostScope(host: const NoGameHost(), child: SudokuScreen()),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Play (1)'), findsOneWidget);
    expect(find.text('Play (4)'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.digit1);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Notes (N)'), findsOneWidget);
    expect(find.text('Erase (Backspace)'), findsOneWidget);
    expect(find.text('Undo (U)'), findsOneWidget);
    expect(find.textContaining('(H / Enter)'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.keyN);
    await t.pump();
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
