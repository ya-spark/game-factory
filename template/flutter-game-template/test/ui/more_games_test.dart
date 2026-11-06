import 'package:flutter/material.dart';
import 'package:flutter_game_template/app.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/links/external_link_service.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

const _base = '''
app:
  id: me
  display_name: Me
  package_name: com.x.me
admob:
  debug:
    app_id: ca-app-pub-3940256099942544~1
    banner: ca-app-pub-3940256099942544/1
    interstitial: ca-app-pub-3940256099942544/2
    rewarded: ca-app-pub-3940256099942544/3
  release:
    app_id: PLACEHOLDER_A
    banner: PLACEHOLDER_B
    interstitial: PLACEHOLDER_C
    rewarded: PLACEHOLDER_D
''';

const _list = '''
more_games:
  - id: me
    package_name: com.x.me
    name: "Me"
    tagline: "self"
    status: live
  - id: a
    package_name: com.x.a
    name: "A"
    tagline: "live one"
    status: live
  - id: b
    package_name: com.x.b
    name: "B"
    tagline: "soon"
    status: coming_soon
  - id: c
    package_name: com.x.c
    name: "C"
    tagline: "hidden"
    status: hidden
''';

Future<Services> _services(
  FakeExternalLinkService links, {
  String more = _list,
}) async {
  final base = await buildFakeServices();
  return Services(
    config: AppConfig.fromYamlString('$_base$more'),
    catalog: base.catalog,
    identity: base.identity,
    saves: base.saves,
    leaderboard: base.leaderboard,
    ads: base.ads,
    purchases: base.purchases,
    notifications: base.notifications,
    analytics: base.analytics,
    remoteConfig: base.remoteConfig,
    profile: base.profile,
    share: base.share,
    audio: base.audio,
    links: links,
  );
}

Future<void> _pump(WidgetTester tester, Services s) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
}

void main() {
  test('config: parses, skips self, hides hidden, empty list', () {
    final c = AppConfig.fromYamlString('$_base$_list');
    expect(c.moreGames.length, 4);
    expect(c.visibleMoreGames.map((g) => g.id), ['a', 'b']);
    expect(AppConfig.fromYamlString(_base).visibleMoreGames, isEmpty);
    final hidden = AppConfig.fromYamlString(
      '$_base'
      'more_games:\n  - id: z\n    package_name: com.x.z\n    name: Z\n'
      '    tagline: t\n    status: hidden\n',
    );
    expect(hidden.visibleMoreGames, isEmpty);
  });

  test('bundled config lists only hidden games', () async {
    final s = await buildFakeServices();
    expect(s.config.moreGames, isNotEmpty);
    expect(s.config.visibleMoreGames, isEmpty);
  });

  testWidgets('Home icon opens the screen; cards by status; no rewards', (
    tester,
  ) async {
    final links = FakeExternalLinkService();
    final s = await _services(links);
    await _pump(tester, s);
    await tester.tap(find.byKey(TestIds.homeMoreGames));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.moreGamesScreen), findsOneWidget);
    expect(find.byKey(TestIds.moreGamesCard('a')), findsOneWidget);
    expect(find.byKey(TestIds.moreGamesGet('a')), findsOneWidget);
    expect(find.byKey(TestIds.moreGamesCard('b')), findsOneWidget);
    expect(find.byKey(TestIds.moreGamesGet('b')), findsNothing);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.byKey(TestIds.moreGamesCard('c')), findsNothing);
    expect(find.byKey(TestIds.moreGamesCard('me')), findsNothing);
    expect(
      find.textContaining(RegExp('coin|reward', caseSensitive: false)),
      findsNothing,
    );

    // Get it: parent gate first, then the store page of that package.
    await tester.tap(find.byKey(TestIds.moreGamesGet('a')));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.gateDialog), findsOneWidget);
    expect(links.opened, isEmpty);
    await tester.enterText(
      find.byKey(TestIds.gateAnswer),
      '${s.parentGate.a * s.parentGate.b}',
    );
    await tester.tap(find.byKey(TestIds.gateSubmit));
    await tester.pumpAndSettle();
    expect(links.opened, ['com.x.a']);

    await tester.tap(find.byKey(TestIds.moreGamesBack));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
  });

  testWidgets('Cancelling the parent gate opens nothing', (tester) async {
    final links = FakeExternalLinkService();
    await _pump(tester, await _services(links));
    await tester.tap(find.byKey(TestIds.homeMoreGames));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.moreGamesGet('a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.gateCancel));
    await tester.pumpAndSettle();
    expect(links.opened, isEmpty);
  });

  testWidgets('Settings row opens the screen', (tester) async {
    await _pump(tester, await _services(FakeExternalLinkService()));
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(TestIds.settingsMoreGames), 200);
    await tester.tap(find.byKey(TestIds.settingsMoreGames));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.moreGamesScreen), findsOneWidget);
  });

  testWidgets('Nothing listed: no Home icon, no Settings row', (tester) async {
    await _pump(tester, await _services(FakeExternalLinkService(), more: ''));
    expect(find.byKey(TestIds.homeMoreGames), findsNothing);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.settingsMoreGames), findsNothing);
  });

  testWidgets('Home at 360x640: icon top right, no overlap, no overflow', (
    tester,
  ) async {
    await _pump(tester, await _services(FakeExternalLinkService()));
    final icon = tester.getRect(find.byKey(TestIds.homeMoreGames));
    expect(icon.size, const Size(48, 48));
    expect(icon.right, 360 - 4);
    for (final k in [
      TestIds.homePlay,
      TestIds.homeSettings,
      TestIds.homeCoins,
      TestIds.homeBestScore,
    ]) {
      expect(icon.overlaps(tester.getRect(find.byKey(k))), isFalse);
    }
    expect(tester.takeException(), isNull);
  });
}
