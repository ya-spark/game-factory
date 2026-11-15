import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/ads/ad_service.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/ui/settings_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import 'screens_test.dart' show pumpGameOver, settle;

/// Counts how often Google's consent dialog was asked to open.
class _ConsentAds extends FakeAdService {
  _ConsentAds({required this.present});
  final bool present;
  int shown = 0;
  @override
  bool get privacyOptionsRequired => present;
  @override
  Future<void> showPrivacyOptions() async => shown++;
}

Future<void> openSettings(
  WidgetTester tester, {
  required bool web,
  required bool adsense,
  FakeAdService? ads,
}) async {
  tester.view.physicalSize = const Size(600, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await buildFakeServices(
    contentEnabled: false,
    webShell: web,
    adsenseEnabled: adsense,
    ads: ads,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: ServicesScope(services: s, child: const SettingsScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('ads are only built at the three placements, none during play', (
    tester,
  ) async {
    final ads = FakeAdService();
    final s = await buildFakeServices(ads: ads);
    await pumpGameOver(tester, s);
    await settle(tester);
    // Play is over: only the post_game banner was ever asked for, never in play.
    expect(ads.bannersBuilt.toSet(), {AdPlacement.postGame});
    expect(ads.bannersBuilt.every(AdPlacement.values.contains), isTrue);
  });

  testWidgets('web Settings with AdSense on shows Ad privacy choices', (
    tester,
  ) async {
    final ads = _ConsentAds(present: true);
    await openSettings(tester, web: true, adsense: true, ads: ads);
    final row = find.byKey(TestIds.settingsAdChoices);
    await tester.scrollUntilVisible(row, 200);
    await tester.tap(row);
    await tester.pump();
    expect(ads.shown, 1);
    // One privacy row on web, not two.
    expect(find.byKey(TestIds.settingsPrivacy), findsNothing);
  });

  testWidgets('no consent dialog: a calm message, nothing opens', (
    tester,
  ) async {
    final ads = _ConsentAds(present: false);
    await openSettings(tester, web: true, adsense: true, ads: ads);
    final row = find.byKey(TestIds.settingsAdChoices);
    await tester.scrollUntilVisible(row, 200);
    await tester.tap(row);
    await tester.pump();
    expect(ads.shown, 0);
    expect(
      find.text('There are no ad choices to change right now.'),
      findsOneWidget,
    );
  });

  testWidgets('the row is absent off web and with AdSense off', (tester) async {
    await openSettings(tester, web: false, adsense: true);
    expect(find.byKey(TestIds.settingsAdChoices), findsNothing);
    await openSettings(tester, web: true, adsense: false);
    expect(find.byKey(TestIds.settingsAdChoices), findsNothing);
  });
}
