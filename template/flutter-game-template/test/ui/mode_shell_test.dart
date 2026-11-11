import 'package:flutter/material.dart';
import 'package:flutter_game_template/app.dart';
import 'package:flutter_game_template/core/profile/child_profile.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_game_template/ui/theme/app_theme.dart';
import 'package:flutter_game_template/ui/theme/design_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import 'kit/kit_test.dart' show FileDesignBundle, appIds, loadDesign;

/// Apps with a Game and a Study look (not the Mind apps). A generated game has only its own.
final _modeApps = [
  for (final id in appIds)
    if (loadDesign(id).app.modes.length > 1) id,
];

Future<Services> _pump(
  WidgetTester tester,
  String id, {
  int year = 3,
  LearnMode? lock,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await buildFakeServices(contentEnabled: true);
  final kid = (await s.profile.addChild('Mia', year: year))!;
  if (lock != null) await s.profile.setChildLockedMode(kid.id, lock);
  s.profile.selectChild(kid.id);
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
  return s;
}

Finder _tab(String id) => find.byKey(TestIds.dsTab(TestIds.shellBottomBar, id));

void main() {
  test('the interface level follows the year level', () {
    for (final id in appIds) {
      final app = loadDesign(id).app;
      if (app.levels.isEmpty) {
        expect(app.levelForYear(3), isNull, reason: id);
      } else if (id == 'craft_lowteen') {
        expect(app.levelForYear(0), InterfaceLevel.younger);
        expect(app.levelForYear(2), InterfaceLevel.younger);
        expect(app.levelForYear(3), InterfaceLevel.older);
        expect(app.levelForYear(6), InterfaceLevel.older);
      } else if (id == 'craft_preteen') {
        expect(app.levelForYear(7), InterfaceLevel.younger);
        expect(app.levelForYear(8), InterfaceLevel.younger);
        expect(app.levelForYear(9), InterfaceLevel.older);
        expect(app.levelForYear(10), InterfaceLevel.older);
      }
    }
  });

  for (final id in _modeApps) {
    testWidgets('$id: mode is remembered per child and sets the tabs', (
      tester,
    ) async {
      final s = await _pump(tester, id);
      final mia = s.profile.activeChild!;
      expect(mia.mode, LearnMode.game); // Game on first launch
      expect(_tab('play'), findsOneWidget);
      expect(_tab('challenges'), findsOneWidget);
      expect(_tab('shop'), findsOneWidget);
      await tester.tap(find.byKey(TestIds.modeStudy));
      await tester.pump();
      expect(_tab('learn'), findsOneWidget);
      expect(_tab('progress'), findsOneWidget);
      expect(_tab('revise'), findsOneWidget);
      expect(_tab('play'), findsNothing);
      // Saved on the child: a second child still starts in Game mode.
      expect(s.profile.activeChild!.mode, LearnMode.study);
      final bo = (await s.profile.addChild('Bo', year: 4))!;
      expect(
        s.profile.children.firstWhere((c) => c.id == bo.id).mode,
        LearnMode.game,
      );
      final back = ChildProfile.fromJson(s.profile.activeChild!.toJson());
      expect(back.mode, LearnMode.study);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$id: a locked child cannot switch and sees the lock icon', (
      tester,
    ) async {
      final s = await _pump(tester, id, lock: LearnMode.study);
      expect(find.byKey(TestIds.modeLock), findsOneWidget);
      expect(_tab('learn'), findsOneWidget);
      expect(find.byKey(TestIds.modeGame), findsNothing);
      await tester.tap(find.byKey(TestIds.modeStudy));
      await tester.pump();
      expect(_tab('learn'), findsOneWidget);
      final id0 = s.profile.activeChild!.id;
      expect(await s.profile.setChildMode(id0, LearnMode.game), isFalse);
      expect(s.profile.activeChild!.effectiveMode, LearnMode.study);
      // Lifting the lock brings the toggle back and the lock icon goes.
      await s.profile.setChildLockedMode(id0, null);
      await tester.pump();
      expect(find.byKey(TestIds.modeLock), findsNothing);
      expect(find.byKey(TestIds.modeGame), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final id in appIds.where((i) => loadDesign(i).app.levels.isNotEmpty)) {
    testWidgets('$id: the theme level changes with the year level', (
      tester,
    ) async {
      final design = loadDesign(id);
      final s = await _pump(tester, id, year: 3);
      final first = design.app.levelForYear(3)!;
      double touch() =>
          ThemeTokens.of(tester.element(find.byKey(TestIds.shell))).minTouch;
      expect(touch(), design.app.levels[first]!.minTouch);
      final low = id == 'craft_preteen' ? 7 : 0;
      await s.profile.setChildYear(s.profile.activeChild!.id, low);
      await tester.pump();
      final second = design.app.levelForYear(low)!;
      expect(touch(), design.app.levels[second]!.minTouch);
    });
  }
}
