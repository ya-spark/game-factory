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
      // A content-enabled (Craft) game starts at the player setup: make a player, pick a year.
      if (find.byKey(TestIds.pickerNickname).evaluate().isNotEmpty) {
        await tester.enterText(find.byKey(TestIds.pickerNickname), 'Mia');
        await tester.tap(find.byKey(TestIds.pickerYear(3)));
        await tester.pump();
        await tester.tap(find.byKey(TestIds.pickerSave));
        await tester.pump();
        await tester.pump();
      }
      if (find.byKey(TestIds.shell).evaluate().isNotEmpty) {
        // A learning game opens the app shell: visit every tab of every mode.
        expect(tester.takeException(), isNull);
        for (final m in [TestIds.modeGame, TestIds.modeStudy]) {
          if (find.byKey(m).evaluate().isEmpty) continue;
          await tester.tap(find.byKey(m));
          await tester.pump();
          for (final tab in [
            'play',
            'challenges',
            'shop',
            'learn',
            'progress',
            'revise',
          ]) {
            final f = find.byKey(TestIds.dsTab(TestIds.shellBottomBar, tab));
            if (f.evaluate().isEmpty) continue;
            await tester.tap(f);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$id $tab');
          }
        }
        return;
      }
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
