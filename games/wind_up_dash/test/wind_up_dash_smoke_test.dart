import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_wind_up_dash/wind_up_dash.dart';

/// The screen opens inside a container with no extras (the hub's own tests cover the integration).
void main() {
  testWidgets('Wind-up dash opens and closes cleanly', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: GameHostScope(
          host: const NoGameHost(),
          child: WindUpDashScreen(),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(WindUpDashScreen), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
