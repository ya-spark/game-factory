import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_ball_sort/ball_sort.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The screen opens inside a container with no extras (the hub's own tests cover the integration).
void main() {
  testWidgets('BallSort opens and closes cleanly', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(
      MaterialApp(
        home: GameHostScope(host: const NoGameHost(), child: BallSortScreen()),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(BallSortScreen), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
