import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_ball_sort/ball_sort.dart';
import 'package:game_core/game_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keyboard play (docs/SPEC.md, Keyboard): Enter starts a level, 1 to 9 pick a tube, Esc goes back.
void main() {
  testWidgets('Enter starts, a number lifts a tube, Esc returns to the menu', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(
      MaterialApp(
        home: GameHostScope(host: const NoGameHost(), child: BallSortScreen()),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byKey(BallSortIds.ballSortTube(0)), findsNothing);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(find.byKey(BallSortIds.ballSortTube(0)), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.digit1);
    await t.pump();
    final lifted = t.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(BallSortIds.ballSortTube(0)),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(lifted.properties.selected, isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.byKey(BallSortIds.ballSortTube(0)), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
