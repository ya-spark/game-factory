import 'package:flutter/material.dart';
import 'package:flutter_game_template/app.dart';
import 'package:flutter_game_template/core/links/external_link_service.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/ui/settings_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

Future<Services> _open(
  WidgetTester tester, {
  required bool web,
  String url = '',
  bool learning = true,
}) async {
  tester.view.physicalSize = const Size(600, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await buildFakeServices(
    contentEnabled: learning,
    webShell: web,
    webPlayStoreUrl: url,
  );
  if (learning) {
    final kid = (await s.profile.addChild('Mia', year: 3))!;
    s.profile.selectChild(kid.id);
  }
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
  await tester.tap(find.byKey(TestIds.homeSettings));
  await tester.pumpAndSettle();
  return s;
}

void main() {
  testWidgets('web Settings: save note shown, no Android link when empty', (
    tester,
  ) async {
    await _open(tester, web: true);
    expect(find.byKey(TestIds.settingsWebSaveNote), findsOneWidget);
    expect(find.text(webSaveNote), findsOneWidget);
    expect(find.byKey(TestIds.settingsGetAndroidApp), findsNothing);
  });

  testWidgets('web Settings: Android link shown and opened when set', (
    tester,
  ) async {
    final s = await _open(
      tester,
      web: true,
      url: 'https://play.google.com/store/apps/details?id=x',
    );
    final link = find.byKey(TestIds.settingsGetAndroidApp);
    await tester.scrollUntilVisible(link, 200);
    await tester.tap(link);
    await tester.pump();
    expect((s.links as FakeExternalLinkService).openedUrls, [
      'https://play.google.com/store/apps/details?id=x',
    ]);
  });

  testWidgets('Android Settings: no web note and no Android link', (
    tester,
  ) async {
    await _open(tester, web: false, url: 'https://example.com/a');
    expect(find.byKey(TestIds.settingsWebSaveNote), findsNothing);
    expect(find.byKey(TestIds.settingsGetAndroidApp), findsNothing);
  });

  testWidgets('web: the Shop button and the Grown-ups purchases are gone', (
    tester,
  ) async {
    await _open(tester, web: true, learning: false);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.homeShop), findsNothing);
  });

  testWidgets('Android: the Shop button is still there', (tester) async {
    await _open(tester, web: false, learning: false);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.homeShop), findsOneWidget);
  });
}
