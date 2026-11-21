import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_runner/runner.dart';

/// The screen opens inside a container with no extras (the hub's own tests cover the integration).
void main() {
  testWidgets('Runner opens and closes cleanly', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: GameHostScope(host: const NoGameHost(), child: RunnerScreen()),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(RunnerScreen), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
