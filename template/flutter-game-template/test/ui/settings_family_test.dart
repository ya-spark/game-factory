import 'package:flutter/material.dart';
import 'package:flutter_game_template/app.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/links/external_link_service.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

/// A learning game with one player, on the Settings screen. [privacyUrl] is set on the config.
Future<Services> _openSettings(
  WidgetTester tester, {
  DateTime Function()? clock,
  String privacyUrl = '',
}) async {
  tester.view.physicalSize = const Size(600, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final base = await buildFakeServices(contentEnabled: true, clock: clock);
  final c = base.config;
  final s = Services(
    config: AppConfig(
      appId: c.appId,
      displayName: c.displayName,
      packageName: c.packageName,
      themeSeedColor: c.themeSeedColor,
      themeDark: c.themeDark,
      platforms: c.platforms,
      admobDebug: c.admobDebug,
      admobRelease: c.admobRelease,
      adPacing: c.adPacing,
      retention: c.retention,
      playGames: c.playGames,
      content: c.content,
      audience: c.audience,
      privacyUrl: privacyUrl,
    ),
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
    links: FakeExternalLinkService(),
    parentGate: base.parentGate,
  );
  final kid = (await s.profile.addChild('Mia', year: 3))!;
  s.profile.selectChild(kid.id);
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
  await tester.tap(find.byKey(TestIds.homeSettings));
  await tester.pumpAndSettle();
  return s;
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _answerGate(WidgetTester tester, Services s) async {
  await tester.enterText(
    find.byKey(TestIds.gateAnswer),
    '${s.parentGate.a * s.parentGate.b}',
  );
  await tester.tap(find.byKey(TestIds.gateSubmit));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('text size, reduce motion and reminder time are saved', (
    tester,
  ) async {
    final s = await _openSettings(tester);
    await _scrollTo(tester, TestIds.settingsTextSize('large'));
    await tester.tap(find.byKey(TestIds.settingsTextSize('large')));
    await tester.pumpAndSettle();
    expect(s.profile.data.textSize, TextSizeChoice.large.name);

    await _scrollTo(tester, TestIds.settingsReduceMotion);
    await tester.tap(find.byKey(TestIds.settingsReduceMotion));
    await tester.pumpAndSettle();
    expect(s.profile.data.reduceMotion, isTrue);

    // The reminder time shows only once reminders are on (the fake grants no permission, so
    // switch it on in the store directly).
    expect(find.byKey(TestIds.settingsReminderTime), findsNothing);
    await s.profile.setReminders(true);
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.settingsReminderTime), findsOneWidget);
    expect(find.text('19:00'), findsWidgets);
  });

  testWidgets('the chosen text size scales the text across the app', (
    tester,
  ) async {
    final s = await _openSettings(tester);
    double scaleNow() =>
        MediaQuery.of(tester.element(find.byKey(TestIds.settingsVersion)))
            .textScaler
            .scale(10);
    await _scrollTo(tester, TestIds.settingsVersion);
    final before = scaleNow();
    await s.profile.setTextSize(TextSizeChoice.large);
    await tester.pumpAndSettle();
    expect(scaleNow(), closeTo(before * TextSizeChoice.large.scale, 0.001));
    await s.profile.setReduceMotion(true);
    await tester.pumpAndSettle();
    expect(
      MediaQuery.disableAnimationsOf(
        tester.element(find.byKey(TestIds.settingsVersion)),
      ),
      isTrue,
    );
  });

  testWidgets('shows the app version and opens the privacy policy', (
    tester,
  ) async {
    final s = await _openSettings(
      tester,
      privacyUrl: 'https://example.org/privacy',
    );
    await _scrollTo(tester, TestIds.settingsPrivacyPolicy);
    await tester.tap(find.byKey(TestIds.settingsPrivacyPolicy));
    await tester.pumpAndSettle();
    expect((s.links as FakeExternalLinkService).openedUrls, [
      'https://example.org/privacy',
    ]);
    await _scrollTo(tester, TestIds.settingsVersion);
    expect(find.textContaining('Version 1.2.3'), findsOneWidget);
  });

  testWidgets('no privacy link when the config has no policy address', (
    tester,
  ) async {
    await _openSettings(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.settingsPrivacyPolicy), findsNothing);
  });

  testWidgets('switch player goes back to the picker', (tester) async {
    final s = await _openSettings(tester);
    await _scrollTo(tester, TestIds.settingsSwitchPlayer);
    await tester.tap(find.byKey(TestIds.settingsSwitchPlayer));
    await tester.pumpAndSettle();
    expect(s.profile.activeChild, isNull);
    expect(
      find.byKey(TestIds.pickerChild(s.profile.children.first.id)),
      findsOneWidget,
    );
  });

  testWidgets(
    'grown-ups area (child apps) is behind the adult check and resets '
    'one player only',
    (tester) async {
      var now = DateTime(2026, 11, 12, 16);
      final s = await _openSettings(tester, clock: () => now);
      if (s.config.audience != Audience.child) {
        // Teen and adult apps: a plain Progress page, no adult check, no reset.
        await _scrollTo(tester, TestIds.settingsProgress);
        expect(find.byKey(TestIds.settingsGrownUps), findsNothing);
        await tester.tap(find.byKey(TestIds.settingsProgress));
        await tester.pumpAndSettle();
        expect(find.byKey(TestIds.progressScreen), findsOneWidget);
        expect(find.byKey(TestIds.reportPlayTime), findsOneWidget);
        expect(find.byKey(TestIds.parentReset), findsNothing);
        return;
      }
      final kid = s.profile.activeChild!;
      await s.profile.setChildProgress(
        kid.id,
        const ChildProgress(
          topics: {
            'maths/3/times_tables': TopicResult(
              attempted: 4,
              passed: 3,
              answers: 8,
              correct: 6,
            ),
          },
        ),
      );
      now = now.add(const Duration(minutes: 12));
      await s.profile.pausePlay(); // 12 minutes since the player was selected
      await tester.pumpAndSettle();

      await _scrollTo(tester, TestIds.settingsGrownUps);
      await tester.tap(find.byKey(TestIds.settingsGrownUps));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.gateDialog), findsOneWidget);
      await _answerGate(tester, s);
      expect(find.byKey(TestIds.parentArea), findsOneWidget);
      expect(find.textContaining('12 minutes'), findsOneWidget);
      expect(find.text('1 topic'), findsOneWidget);
      expect(find.textContaining('Times tables: 75% right'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(TestIds.parentReset),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(TestIds.parentReset));
      await tester.pumpAndSettle();
      // Keep: nothing changes.
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(s.profile.children.single.progress.topics, isNotEmpty);
      await tester.tap(find.byKey(TestIds.parentReset));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TestIds.parentResetConfirm));
      await tester.pumpAndSettle();
      expect(s.profile.children.single.progress.topics, isEmpty);
      expect(s.profile.children.single.playTime.secondsByDay, isEmpty);
      expect(s.profile.children.single.nickname, 'Mia');
      expect(find.text('None yet.'), findsOneWidget);
    },
  );

  testWidgets('a wrong adult check keeps the grown-ups area closed', (
    tester,
  ) async {
    final s = await _openSettings(tester);
    if (s.config.audience != Audience.child) return;
    await _scrollTo(tester, TestIds.settingsGrownUps);
    await tester.tap(find.byKey(TestIds.settingsGrownUps));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(TestIds.gateAnswer), '1');
    await tester.tap(find.byKey(TestIds.gateSubmit));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.parentArea), findsNothing);
  });

  testWidgets('the grown-ups area offers Remove Ads and restore', (
    tester,
  ) async {
    final s = await _openSettings(tester);
    if (s.config.audience != Audience.child) return;
    await _scrollTo(tester, TestIds.settingsGrownUps);
    await tester.tap(find.byKey(TestIds.settingsGrownUps));
    await tester.pumpAndSettle();
    await _answerGate(tester, s);
    await tester.scrollUntilVisible(
      find.byKey(TestIds.parentRemoveAds),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(TestIds.parentRemoveAds), findsOneWidget);
    expect(find.byKey(TestIds.parentRestore), findsOneWidget);
  });
}
