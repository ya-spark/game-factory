import 'package:flutter/material.dart';
import 'package:flutter_game_template/app.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import 'kit/kit_test.dart' show FileDesignBundle, appIds, loadDesign;

/// The existing screens (home, shop, challenges, settings) on every app's design theme, with the
/// phone's text at 150 percent: no layout overflow, behaviour unchanged (same test ids).
void main() {
  for (final id in appIds) {
    testWidgets('$id: existing screens build and do not overflow at 150%', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await buildFakeServices();
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FileDesignBundle(),
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 900),
              textScaler: TextScaler.linear(1.5),
            ),
            child: GameApp(services: s, design: loadDesign(id)),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(TestIds.homeShop), findsOneWidget);
      expect(find.byKey(TestIds.homeChallenges), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final key in [
        TestIds.homeShop,
        TestIds.homeChallenges,
        TestIds.homeSettings,
      ]) {
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$id $key');
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  }
}
