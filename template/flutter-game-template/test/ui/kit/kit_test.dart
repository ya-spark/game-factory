import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_game_template/ui/kit/ds_bars.dart';
import 'package:flutter_game_template/ui/kit/ds_buttons.dart';
import 'package:flutter_game_template/ui/kit/ds_cards.dart';
import 'package:flutter_game_template/ui/kit/ds_chips.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_game_template/ui/theme/design_loader.dart';
import 'package:flutter_game_template/ui/theme/design_scope.dart';
import 'package:flutter_game_template/ui/theme/design_tokens.dart';
import 'package:flutter_game_template/ui/theme_gallery_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves `assets/design/...` from the repo's `design/` folder (or from `assets/design/` in a
/// generated game), so SVGs load in tests.
class FileDesignBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final candidates = [
      key,
      if (key.startsWith('assets/design/'))
        key.replaceFirst('assets/design/', 'design/'),
    ];
    for (final c in candidates) {
      final f = File(c);
      if (f.existsSync()) {
        final b = f.readAsBytesSync();
        return ByteData.view(b.buffer);
      }
    }
    throw FlutterError('Unable to load asset: $key');
  }
}

final designRoot = Directory('design').existsSync()
    ? 'design'
    : 'assets/design';

final appIds = [
  for (final d in Directory(designRoot).listSync())
    if (File('${d.path}/tokens.json').existsSync())
      d.uri.pathSegments[d.uri.pathSegments.length - 2],
]..sort();

DesignBundle loadDesign(String id) => DesignBundle(
  shared: SharedTokens.fromJson(
    File('$designRoot/tokens.json').readAsStringSync(),
  ),
  app: AppTokens.fromJson(
    File('$designRoot/$id/tokens.json').readAsStringSync(),
  ),
);

Future<void> pumpIn(
  WidgetTester tester,
  DesignBundle design,
  Widget child, {
  DesignMode? mode,
  InterfaceLevel? level,
  double textScale = 1.0,
  DesignPrefs prefs = const DesignPrefs(),
}) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: FileDesignBundle(),
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 1000),
            textScaler: TextScaler.linear(textScale),
          ),
          child: DesignScope(
            design: design,
            mode: mode ?? design.app.modes.keys.first,
            level: level,
            prefs: prefs,
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Widget kitSample() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    DsButton(id: 'p', label: 'Primary', onPressed: () {}),
    DsButton(
      id: 's',
      label: 'Secondary',
      kind: DsButtonKind.secondary,
      onPressed: () {},
    ),
    DsButton(
      id: 'g',
      label: 'Ghost',
      kind: DsButtonKind.ghost,
      onPressed: () {},
    ),
    const DsButton(id: 'd', label: 'Disabled', onPressed: null),
    const Wrap(
      children: [
        DsCoinChip(coins: 12),
        DsStatChip(id: 's', icon: 'star', value: '3', semanticLabel: '3 stars'),
        DsMasteryChip(id: 'm', mastery: Mastery.mastered),
      ],
    ),
    const DsProgressBar(id: 'a', value: 0.5),
    const DsProgressBar(id: 'b', value: 0.5, thin: true),
    DsTopBar(
      title: 'A long title for the top bar of a screen',
      modeToggle: const DsLabelChip(label: 'Toggle'),
      coins: 1234,
    ),
    DsSuggestedCard(
      id: 'x',
      eyebrow: 'Try next',
      title: 'Number sprint',
      actionLabel: 'Start',
      onTap: () {},
    ),
    DsTopicCard(
      id: 't',
      title: 'Fractions',
      subject: 'Maths',
      passed: 3,
      total: 10,
      mastery: Mastery.learning,
      toRevise: 2,
      accuracyPercent: 74,
      showAccuracy: true,
      onTap: () {},
    ),
    DsPackCard(id: 'p', title: 'Spelling pack', onTap: () {}),
    DsBottomBar(
      selected: 1,
      onSelect: (_) {},
      tabs: const [
        DsTab(id: 'a', label: 'Play', icon: 'gamepad'),
        DsTab(id: 'b', label: 'Challenges', icon: 'star'),
        DsTab(id: 'c', label: 'Shop', icon: 'bag'),
      ],
    ),
  ],
);

void main() {
  group('every shared widget builds in every theme', () {
    for (final id in appIds) {
      final design = loadDesign(id);
      for (final mode in design.app.modes.keys) {
        testWidgets('$id ${mode.key}', (tester) async {
          await pumpIn(tester, design, kitSample(), mode: mode);
          expect(tester.takeException(), isNull);
          expect(find.byKey(TestIds.dsButton('p')), findsOneWidget);
          expect(find.byKey(TestIds.dsTopicCard('t')), findsOneWidget);
          expect(find.byKey(TestIds.dsBottomBar('main')), findsOneWidget);
        });
      }
    }
  });

  group('no layout overflow at 150 percent text', () {
    for (final id in appIds) {
      final design = loadDesign(id);
      final levels = design.app.levels.isEmpty
          ? <InterfaceLevel?>[null]
          : <InterfaceLevel?>[...design.app.levels.keys];
      for (final mode in design.app.modes.keys) {
        for (final level in levels) {
          testWidgets('$id ${mode.key} ${level?.name ?? ""} kit', (
            tester,
          ) async {
            await pumpIn(
              tester,
              design,
              kitSample(),
              mode: mode,
              level: level,
              textScale: 1.5,
            );
            expect(tester.takeException(), isNull);
          });
        }
        testWidgets('$id ${mode.key} gallery', (tester) async {
          tester.view.physicalSize = const Size(400, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            DefaultAssetBundle(
              bundle: FileDesignBundle(),
              child: MaterialApp(
                home: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(400, 1000),
                    textScaler: TextScaler.linear(1.5),
                  ),
                  child: ThemeGalleryScreen(design: design),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.byKey(TestIds.themeGallery), findsOneWidget);
          await tester.tap(find.byKey(TestIds.galleryMode(mode.key)));
          await tester.pump();
          // Scroll through the whole gallery so every section is laid out.
          for (var i = 0; i < 12; i++) {
            await tester.drag(find.byType(ListView), const Offset(0, -600));
            await tester.pump();
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('behaviour', () {
    final design = loadDesign(appIds.first);

    testWidgets('button taps and disabled does not', (tester) async {
      var taps = 0;
      await pumpIn(
        tester,
        design,
        Column(
          children: [
            DsButton(id: 'on', label: 'On', onPressed: () => taps++),
            const DsButton(id: 'off', label: 'Off', onPressed: null),
          ],
        ),
      );
      await tester.tap(find.byKey(TestIds.dsButton('on')));
      await tester.tap(find.byKey(TestIds.dsButton('off')));
      expect(taps, 1);
    });

    testWidgets('touch targets are at least the token minimum', (tester) async {
      await pumpIn(tester, design, kitSample());
      final min = design.shared.size['min_touch']!;
      for (final k in [
        TestIds.dsButton('p'),
        TestIds.dsButton('g'),
        TestIds.dsButton('d'),
        TestIds.dsTab('main', 'a'),
        TestIds.dsTab('main', 'c'),
      ]) {
        final size = tester.getSize(find.byKey(k));
        expect(size.height, greaterThanOrEqualTo(min), reason: '$k height');
        expect(size.width, greaterThanOrEqualTo(min), reason: '$k width');
      }
    });

    testWidgets('younger level raises the touch size', (tester) async {
      final d = loadDesign('craft_lowteen');
      await pumpIn(
        tester,
        d,
        kitSample(),
        level: InterfaceLevel.younger,
        mode: DesignMode.game,
      );
      final h = tester.getSize(find.byKey(TestIds.dsButton('p'))).height;
      expect(h, greaterThanOrEqualTo(56));
    });

    testWidgets('screen-reader labels on every shared control', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIn(tester, design, kitSample());
      expect(find.bySemanticsLabel('Primary'), findsOneWidget);
      expect(find.bySemanticsLabel('Disabled'), findsOneWidget);
      expect(find.bySemanticsLabel('12 coins'), findsOneWidget);
      expect(find.bySemanticsLabel('3 stars'), findsOneWidget);
      expect(find.bySemanticsLabel('Challenges'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('3 of 10 passed')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Spelling pack.*locked')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Progress'), findsWidgets);
      handle.dispose();
    });

    testWidgets('topic card shows accuracy only when the flag is set', (
      tester,
    ) async {
      Widget card(bool flag) => DsTopicCard(
        id: 't',
        title: 'Fractions',
        subject: 'Maths',
        passed: 3,
        total: 10,
        mastery: Mastery.learning,
        accuracyPercent: 74,
        showAccuracy: flag,
        onTap: () {},
      );
      await pumpIn(tester, design, card(false));
      expect(find.textContaining('74%'), findsNothing);
      await pumpIn(tester, design, card(true));
      expect(find.textContaining('74%'), findsOneWidget);
    });

    testWidgets('pack card and topic card never show a price', (tester) async {
      await pumpIn(
        tester,
        design,
        Column(
          children: [
            DsPackCard(id: 'p', title: 'Pack', onTap: () {}),
            DsTopicCard(
              id: 't',
              title: 'T',
              subject: 'S',
              passed: 0,
              total: 1,
              mastery: Mastery.learning,
              onTap: () {},
            ),
          ],
        ),
      );
      expect(find.textContaining(RegExp(r'\$|coins|price')), findsNothing);
      expect(find.text('Preview free'), findsOneWidget);
      expect(find.text('Full pack'), findsOneWidget);
    });

    testWidgets('game tile: locked shows the coin price', (tester) async {
      await pumpIn(
        tester,
        design,
        SizedBox(
          width: 200,
          child: DsGameTile(
            id: 'x',
            title: 'Word hunt',
            art: const SizedBox.shrink(),
            lockedPrice: 200,
            onTap: () {},
          ),
        ),
      );
      expect(find.byKey(TestIds.dsCoinChip('price.x')), findsOneWidget);
    });

    testWidgets('reduce motion: bottom bar pill does not animate', (
      tester,
    ) async {
      await pumpIn(
        tester,
        design,
        DsBottomBar(
          selected: 0,
          onSelect: (_) {},
          tabs: const [
            DsTab(id: 'a', label: 'A', icon: 'gamepad'),
            DsTab(id: 'b', label: 'B', icon: 'star'),
            DsTab(id: 'c', label: 'C', icon: 'bag'),
          ],
        ),
        prefs: const DesignPrefs(reduceMotion: true),
      );
      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(TestIds.dsTab('main', 'a')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(container.duration, Duration.zero);
    });

    testWidgets('large text option multiplies the text size', (tester) async {
      Future<double> height(bool large) async {
        await pumpIn(
          tester,
          design,
          const Text('Hello', key: Key('probe')),
          prefs: DesignPrefs(largeText: large),
        );
        return tester.getSize(find.byKey(const Key('probe'))).height;
      }

      final normal = await height(false);
      final large = await height(true);
      expect(large, greaterThan(normal * 1.2));
    });

    testWidgets('dialog returns the chosen action', (tester) async {
      bool? result;
      await pumpIn(
        tester,
        design,
        Builder(
          builder: (context) => DsButton(
            id: 'open',
            label: 'Open',
            onPressed: () async => result = await showDsDialog(
              context,
              id: 'd',
              title: 'T',
              body: 'B',
              primaryLabel: 'Yes',
              secondaryLabel: 'No',
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(TestIds.dsButton('open')));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.dsDialog('d')), findsOneWidget);
      await tester.tap(find.byKey(TestIds.dsButton('d.primary')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });
}
