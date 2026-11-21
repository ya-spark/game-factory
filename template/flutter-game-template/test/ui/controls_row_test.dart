import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/ui/settings_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/kit/keys/keys.dart';

import '../helpers/fake_services.dart';

void main() {
  testWidgets('Settings has a Controls row that opens the key screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await buildFakeServices();
    await tester.pumpWidget(
      GameKeysScope(
        keys: GameKeyMap(),
        child: MaterialApp(
          home: ServicesScope(services: s, child: const SettingsScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(TestIds.settingsControls));
    await tester.pumpAndSettle();
    expect(find.byKey(KeyIds.controlsScreen), findsOneWidget);
    expect(
      find.byKey(KeyIds.chip(const KeySlot(GameAction.left, 2))),
      findsOneWidget,
    );
  });
}
