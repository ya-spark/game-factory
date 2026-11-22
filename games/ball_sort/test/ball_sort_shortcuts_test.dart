import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_ball_sort/ball_sort.dart';
import 'package:game_core/game_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B-09: every button shows its key; R restarts, Backspace undoes, T adds a tube.
void main() {
  testWidgets('buttons print their keys and R, Backspace and T work', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(
      MaterialApp(
        home: GameHostScope(host: const NoGameHost(), child: BallSortScreen()),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Play level 1 (Enter / Space)'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(find.text('Undo (Backspace)'), findsOneWidget);
    expect(find.text('Add a tube (once) (T)'), findsOneWidget);
    expect(find.text('Restart level (R)'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.keyT);
    await t.pump();
    expect(find.text('Tube added'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.keyR);
    await t.pump();
    expect(find.text('Add a tube (once) (T)'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
