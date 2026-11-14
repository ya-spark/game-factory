import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/audio/audio_service.dart';
import 'package:flutter_game_template/core/profile/child_profile.dart';
import 'package:flutter_game_template/core/services.dart';
import 'package:flutter_game_template/ui/settings_screen.dart';
import 'package:flutter_game_template/ui/tabs/shop_tab.dart';
import 'package:flutter_game_template/ui/tabs/tab_data.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_game_template/ui/theme/app_theme.dart';
import 'package:flutter_game_template/ui/theme/design_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import 'kit/kit_test.dart' show FileDesignBundle, appIds, loadDesign;

Future<(Services, FakeAudioService, ChildProfile)> _pumpShop(
  WidgetTester tester, {
  required bool extras,
  int coins = 300,
}) async {
  tester.view.physicalSize = const Size(500, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final audio = FakeAudioService();
  final s = await buildFakeServices(
    contentEnabled: true,
    shopExtras: extras,
    audio: audio,
  );
  await s.profile.addCoins(coins);
  final kid = (await s.profile.addChild('Mia', year: 3))!;
  s.profile.selectChild(kid.id);
  final design = loadDesign(appIds.first);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: FileDesignBundle(),
      child: ServicesScope(
        services: s,
        child: MaterialApp(
          theme: buildDesignTheme(
            app: design.app,
            shared: design.shared,
            mode: design.app.modes.keys.first,
            level: design.app.levelForYear(3),
          ),
          builder: (context, child) => DesignScope(
            design: design,
            mode: design.app.modes.keys.first,
            level: design.app.levelForYear(3),
            child: child!,
          ),
          home: Scaffold(
            body: ListenableBuilder(
              listenable: s.profile,
              builder: (_, _) => ShopTab(
                child: s.profile.activeChild!,
                loaders: TabLoaders(
                  openItems: (_) async => const [],
                  packs: () async => const [],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (s, audio, kid);
}

void main() {
  group('catalogue and fallback (pure Dart)', () {
    test('extra themes cost 60, sound packs 80, sound ids are tracks', () {
      for (final id in extraThemeIds) {
        expect(shopItems.firstWhere((i) => i.id == id).price, 60);
      }
      final sounds = shopItems.where((i) => i.kind == ShopKind.sound);
      expect(sounds.map((i) => i.id).toSet(), soundPackIds);
      for (final i in sounds) {
        expect(i.price, 80);
        expect(ambienceTracks.any((t) => t.$1 == i.id), isTrue);
      }
    });

    test('flags decide what the shop offers', () {
      final off = shopItemsFor(extraThemes: false, soundPacks: false);
      expect(off.any((i) => i.kind == ShopKind.sound), isFalse);
      expect(off.any((i) => extraThemeIds.contains(i.id)), isFalse);
      final on = shopItemsFor(extraThemes: true, soundPacks: true);
      expect(on.length, shopItems.length);
    });

    test('a pack that is not owned falls back to the default', () {
      expect(
        resolveAmbience('rain', owned: {}, packsEnabled: true),
        defaultAmbienceId,
      );
      expect(
        resolveAmbience('rain', owned: {'rain'}, packsEnabled: true),
        'rain',
      );
      expect(
        resolveAmbience('rain', owned: {'rain'}, packsEnabled: false),
        defaultAmbienceId,
      );
      expect(resolveAmbience('night', owned: {}, packsEnabled: false), 'night');
      expect(resolveAmbience('off', owned: {}, packsEnabled: true), 'off');
    });
  });

  testWidgets('flags off: no extra themes, no Sounds section', (tester) async {
    await _pumpShop(tester, extras: false);
    expect(find.byKey(TestIds.shopTheme('sunset')), findsOneWidget);
    expect(find.byKey(TestIds.shopTheme('midnight')), findsNothing);
    expect(find.byKey(TestIds.shopSound('rain')), findsNothing);
    expect(find.text('Sounds'), findsNothing);
    expect(
      find.byKey(TestIds.dsButton('shop.theme.preview.sunset')),
      findsNothing,
    );
  });

  testWidgets('flags on: eight themes and the Sounds section', (tester) async {
    await _pumpShop(tester, extras: true);
    for (final id in [
      'default',
      'sunset',
      'forest',
      'ocean',
      ...extraThemeIds,
    ]) {
      expect(find.byKey(TestIds.shopTheme(id)), findsOneWidget, reason: id);
    }
    expect(find.text('Sounds'), findsOneWidget);
    for (final id in soundPackIds) {
      expect(find.byKey(TestIds.shopSound(id)), findsOneWidget, reason: id);
    }
  });

  testWidgets('buying a sound pack takes 80 coins and uses it', (tester) async {
    final (s, _, _) = await _pumpShop(tester, extras: true);
    await tester.tap(find.byKey(TestIds.dsButton('shop.use.rain')));
    await tester.pumpAndSettle();
    expect(s.profile.data.coins, 220);
    expect(s.profile.data.ownedItems, contains('rain'));
    expect(s.profile.data.ambience, 'rain');
  });

  testWidgets('a sound pack cannot be bought without coins', (tester) async {
    final (s, _, _) = await _pumpShop(tester, extras: true, coins: 70);
    await tester.tap(find.byKey(TestIds.dsButton('shop.use.rain')));
    await tester.pumpAndSettle();
    expect(s.profile.data.ownedItems, isNot(contains('rain')));
    expect(s.profile.data.coins, 70);
  });

  testWidgets('Listen plays a sample through the audio service', (
    tester,
  ) async {
    final (s, audio, _) = await _pumpShop(tester, extras: true);
    await tester.tap(find.byKey(TestIds.dsButton('shop.sound.preview.waves')));
    await tester.pumpAndSettle();
    expect(audio.previews, ['waves']);
    expect(audio.previewing, 'waves');
    expect(s.profile.data.ownedItems, isEmpty); // listening costs nothing
  });

  testWidgets('theme sheet shows swatches and a sample, then Buy', (
    tester,
  ) async {
    final (s, _, kid) = await _pumpShop(tester, extras: true);
    await tester.tap(
      find.byKey(TestIds.dsButton('shop.theme.preview.midnight')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.themeSheet), findsOneWidget);
    expect(find.byKey(TestIds.themeSwatch('primary')), findsOneWidget);
    expect(find.byKey(TestIds.themeSheetSampleCard), findsOneWidget);
    expect(find.byKey(TestIds.themeSheetSampleButton), findsOneWidget);
    expect(s.profile.data.ownedItems, isEmpty);
    await tester.tap(find.byKey(TestIds.dsButton('shop.themeSheet.action')));
    await tester.pumpAndSettle();
    expect(s.profile.data.ownedItems, contains('midnight'));
    expect(s.profile.data.coins, 240);
    expect(s.profile.activeChild!.colorTheme, 'midnight');
    expect(find.byKey(TestIds.themeSheet), findsNothing);
    expect(kid.id, s.profile.activeChild!.id);
  });

  testWidgets(
    'Settings: locked packs show a lock; unowned saved pack falls back',
    (tester) async {
      tester.view.physicalSize = const Size(500, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await buildFakeServices(shopExtras: true);
      await s.profile.setAmbience('rain'); // saved, but never bought
      await tester.pumpWidget(
        ServicesScope(
          services: s,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.settingsAmbienceLocked), findsOneWidget);
      final dd = tester.widget<DropdownButton<String>>(
        find.byKey(TestIds.settingsAmbience),
      );
      expect(dd.value, defaultAmbienceId);
      await tester.tap(find.byKey(TestIds.settingsAmbience));
      await tester.pumpAndSettle();
      expect(find.text('Rain (locked)'), findsWidgets);
      expect(find.text('Waves (locked)'), findsWidgets);
    },
  );

  test('FakeAudioService preview respects the Sound switch', () async {
    final a = FakeAudioService()..sound = false;
    await a.previewAmbience('rain');
    expect(a.previews, isEmpty);
    a.sound = true;
    await a.previewAmbience('rain');
    expect(a.previewing, 'rain');
    await a.stopPreview();
    expect(a.previewing, isNull);
  });
}
