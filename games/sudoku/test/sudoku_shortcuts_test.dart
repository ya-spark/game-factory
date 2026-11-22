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

  testWidgets(
    'B-17: the digit bar and the tool row sit above the key hints at 1280x720 and 844x390',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      for (final size in const [
        Size(1280, 720),
        Size(844, 390),
        Size(390, 844),
      ]) {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        await t.pumpWidget(
          MaterialApp(
            home: GameHostScope(
              host: const NoGameHost(),
              child: SudokuScreen(),
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 200));
        await t.sendKeyEvent(LogicalKeyboardKey.digit1);
        await t.pump(const Duration(seconds: 1));
        final nine = t.getRect(find.byKey(SudokuIds.sudokuDigit(9)));
        expect(nine.bottom, lessThanOrEqualTo(size.height), reason: '$size');
        if (size.width >= 600 && size.height >= 600) {
          final hints = find.byKey(KeyIds.hints);
          expect(hints, findsOneWidget);
          expect(
            nine.bottom,
            lessThanOrEqualTo(t.getRect(hints).top),
            reason: 'digit bar clear of the key hints at $size',
          );
          final undo = t.getRect(
            find.byKey(MindIds.calmControl('sudoku', 'undo')),
          );
          expect(undo.bottom, lessThanOrEqualTo(t.getRect(hints).top));
        }
        await t.pumpWidget(const SizedBox());
      }
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
    },
  );
}
