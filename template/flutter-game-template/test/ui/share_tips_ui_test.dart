import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_game_template/app.dart';
import 'package:flutter_game_template/core/audio/audio_service.dart';
import 'package:flutter_game_template/core/profile/profile_store.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/core/share/share_service.dart';
import 'package:flutter_game_template/ui/game_screen.dart';
import 'package:flutter_game_template/ui/share_card.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import '../helpers/puzzle_bot.dart';

Future<void> pumpApp(WidgetTester tester, Services s) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400)); // tip dialog route
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('share card renders to a non-empty PNG', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: const ShareCard(
            data: ShareCardData(
              gameName: 'Test Game',
              headline: 'Score',
              big: '42',
              best: 99,
            ),
          ),
        ),
      ),
    );
    final bytes = await tester.runAsync(
      () => boundaryToPng(
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary,
      ),
    );
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('settings.shareApp is hidden without a share link', (
    tester,
  ) async {
    final s = await buildFakeServices(); // fake share has no link
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await settle(tester);
    expect(
      find.byKey(TestIds.settingsShareApp, skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(TestIds.settingsTips, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('settings.shareApp shares the link when there is one', (
    tester,
  ) async {
    final share = FakeShareService(link: 'https://example.com/test');
    final s = await buildFakeServices(share: share);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await settle(tester);
    final item = find.byKey(TestIds.settingsShareApp, skipOffstage: false);
    await tester.scrollUntilVisible(item, 100);
    await tester.tap(item);
    await tester.pump();
    expect(share.sent.single.text, endsWith('\nhttps://example.com/test'));
  });

  testWidgets('an unlocked achievement can be shared; a locked one cannot', (
    tester,
  ) async {
    final share = FakeShareService(link: 'https://example.com/test');
    final s = await buildFakeServices(share: share);
    await s.profile.recordGameFinished(
      const GameSummary(
        score: 500,
        linesCleared: 20,
        piecesPlaced: 60,
        maxCombo: 5,
      ),
    );
    final unlocked = s.profile.data.unlockedAchievements;
    expect(unlocked, isNotEmpty);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeChallenges));
    await settle(tester);
    final id = unlocked.first;
    final btn = find.byKey(TestIds.achievementShare(id), skipOffstage: false);
    await tester.scrollUntilVisible(btn, 100);
    await tester.tap(btn);
    await tester.runAsync(() async {
      for (var i = 0; i < 20 && share.sent.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(share.sent, hasLength(1));
    expect(share.sent.single.text, startsWith('I unlocked "'));
    expect(share.sent.single.text, endsWith('\nhttps://example.com/test'));
  });

  testWidgets('settings: volume, background sound, voice and hand persist', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await settle(tester);
    for (final k in [
      TestIds.settingsSound,
      TestIds.settingsVolume,
      TestIds.settingsAmbience,
      TestIds.settingsVoice,
      TestIds.settingsHand,
    ]) {
      expect(find.byKey(k, skipOffstage: false), findsOneWidget, reason: '$k');
    }
    await tester.tap(find.byKey(TestIds.settingsVoice));
    await tester.pump();
    expect(s.profile.data.voiceOn, isFalse);
    await tester.tap(find.text('Left'));
    await tester.pump();
    expect(s.profile.data.leftHanded, isTrue);
    await s.profile.setMasterVolume(0.5);
    await s.profile.setAmbience('night');
    expect(s.profile.data.masterVolume, 0.5);
    expect(s.profile.data.ambience, 'night');
  });

  testWidgets('game screen applies sound settings and runs the ambience', (
    tester,
  ) async {
    final audio = FakeAudioService();
    final s = await buildFakeServices(audio: audio);
    await s.profile.setMasterVolume(0.3);
    await s.profile.setAmbience('heartbeat');
    await s.profile.setVoice(false);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ServicesScope(
        services: s,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await PuzzleBot(tester).waitForGame();
    expect(audio.volume, 0.3);
    expect(audio.ambience, 'heartbeat');
    expect(audio.voiceOn, isFalse);
    expect(audio.ambiencePlaying, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(audio.ambiencePlaying, isFalse);
  });

  testWidgets('left-handed mirrors the game screen back button', (
    tester,
  ) async {
    final s = await buildFakeServices();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<double> backX() async {
      await tester.pumpWidget(
        ServicesScope(
          services: s,
          child: MaterialApp(key: UniqueKey(), home: const GameScreen()),
        ),
      );
      await PuzzleBot(tester).waitForGame();
      return tester.getCenter(find.byKey(TestIds.gameBack)).dx;
    }

    final right = await backX();
    expect(right, lessThan(200));
    await s.profile.setLeftHanded(true);
    final left = await backX();
    expect(left, greaterThan(200));
  });

  testWidgets('home tip dialog shows once per day', (tester) async {
    var now = DateTime.utc(2026, 11, 5, 10);
    final s = await buildFakeServices(clock: () => now, tips: true);
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.tipClose));
    await settle(tester);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.tipsEnabled, isTrue);
    // Not again the same day.
    await s.profile.onAppOpened();
    await settle(tester);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    // Next day: back on a new home page / resume.
    now = DateTime.utc(2026, 11, 6, 10);
    await s.profile.onAppOpened();
    expect(s.profile.homeTipPending, isTrue);
    await tester.pumpWidget(const SizedBox()); // a fresh home page
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
  });

  testWidgets('home tip dialog never shows when tips are off', (tester) async {
    final s = await buildFakeServices(); // tips off
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsNothing);
  });

  testWidgets('no tip in play', (tester) async {
    final s = await buildFakeServices(tips: true);
    await s.profile.closeHomeTip(); // today's home tip already shown
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ServicesScope(
        services: s,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await PuzzleBot(tester).waitForGame();
    expect(find.byKey(TestIds.tipHome), findsNothing);
  });

  testWidgets('ticking the checkbox turns tips off; the settings switch '
      'brings them back', (tester) async {
    final s = await buildFakeServices(tips: true);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.tipDontShow));
    await tester.pump();
    await tester.tap(find.byKey(TestIds.tipClose));
    await settle(tester);
    expect(s.profile.tipsEnabled, isFalse);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.homeTipPending, isFalse);

    await tester.tap(find.byKey(TestIds.homeSettings));
    await settle(tester);
    final sw = find.byKey(TestIds.settingsTips);
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pump();
    expect(s.profile.tipsEnabled, isTrue);
  });
}
