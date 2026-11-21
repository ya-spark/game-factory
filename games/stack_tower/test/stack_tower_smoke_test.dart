import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_stack_tower/stack_tower.dart';

/// The screen opens inside a container with no extras (the hub's own tests cover the integration).
void main() {
  testWidgets('StackTower opens and closes cleanly', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: GameHostScope(
          host: const NoGameHost(),
          child: StackTowerScreen(),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(StackTowerScreen), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
