import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_brick_breaker/brick_breaker.dart';

/// The screen opens inside a container with no extras (the hub's own tests cover the integration).
void main() {
  testWidgets('BrickBreaker opens and closes cleanly', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: GameHostScope(
          host: const NoGameHost(),
          child: BrickBreakerScreen(),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(BrickBreakerScreen), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
