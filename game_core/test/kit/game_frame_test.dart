import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

/// A host that offers every ad format and a phone banner.
class AdsHost extends GameHost {
  const AdsHost({this.units = true});
  final bool units;
  @override
  GameReadAloud? readAloud(BuildContext context) => null;
  @override
  bool autoRead(BuildContext context) => false;
  @override
  bool reduceMotion(BuildContext context) => false;
  @override
  Widget banner(BuildContext context, GameBannerSlot slot) =>
      SizedBox(key: Key('banner.${slot.name}'), height: 50, width: 320);
  @override
  GameAdUnit? adUnit(BuildContext context, GameAdFormat format) => units
      ? GameAdUnit(
          widget: ColoredBox(key: Key('ad.${format.name}'), color: Colors.grey),
          size: format.size,
        )
      : null;
}

Future<void> pump(
  WidgetTester tester,
  Size size, {
  GameHost host = const AdsHost(),
  bool showAds = true,
  GameBannerSlot slot = GameBannerSlot.menu,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: GameHostScope(
        host: host,
        child: Scaffold(
          body: GameFrame(
            showAds: showAds,
            phoneBanner: slot,
            child: const ColoredBox(key: Key('game'), color: Colors.blue),
          ),
        ),
      ),
    ),
  );
}

Rect rect(WidgetTester t, Key k) => t.getRect(find.byKey(k));

void main() {
  group('window classes', () {
    test('breakpoints are 600 and 1024', () {
      expect(WindowClass.of(599), WindowClass.compact);
      expect(WindowClass.of(600), WindowClass.medium);
      expect(WindowClass.of(1023), WindowClass.medium);
      expect(WindowClass.of(1024), WindowClass.expanded);
    });
  });

  group('desktop, 1280 wide', () {
    testWidgets(
      'the stage and the rail are centered together, the stage at most 780',
      (tester) async {
        await pump(tester, const Size(1280, 800));
        final stage = rect(tester, FrameIds.stage);
        final rail = rect(tester, FrameIds.rail);
        expect(stage.width, 780);
        expect(rail.width, 300);
        expect(rail.left, greaterThan(stage.right));
        expect(rail.left - stage.right, 24);
        // the pair is centered in the window
        expect((stage.left + rail.right) / 2, closeTo(640, 0.5));
        expect(find.byKey(const Key('ad.halfPage')), findsOneWidget);
        expect(rect(tester, const Key('ad.halfPage')).height, 600);
      },
    );

    testWidgets('no ad unit: the stage alone is centered', (tester) async {
      await pump(
        tester,
        const Size(1280, 800),
        host: const AdsHost(units: false),
      );
      final stage = rect(tester, FrameIds.stage);
      expect(find.byKey(FrameIds.rail), findsNothing);
      expect(stage.width, 780);
      expect(stage.center.dx, closeTo(640, 0.5));
    });

    testWidgets('while playing no ad is shown and none is reserved', (
      tester,
    ) async {
      await pump(tester, const Size(1280, 800), showAds: false);
      expect(find.byKey(FrameIds.rail), findsNothing);
      expect(rect(tester, FrameIds.stage).center.dx, closeTo(640, 0.5));
    });

    testWidgets('a narrow desktop takes the skyscraper', (tester) async {
      await pump(tester, const Size(1040, 800));
      expect(find.byKey(const Key('ad.skyscraper')), findsOneWidget);
      expect(find.byKey(const Key('ad.halfPage')), findsNothing);
      expect(rect(tester, FrameIds.rail).width, 160);
    });

    testWidgets(
      'a short window leaves the rail out instead of squashing the ad',
      (tester) async {
        await pump(tester, const Size(1280, 500));
        expect(find.byKey(FrameIds.rail), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the stage takes the full height', (tester) async {
      await pump(tester, const Size(1280, 800));
      expect(rect(tester, FrameIds.stage).height, 800 - 24);
    });
  });

  group('tablet, 800 wide', () {
    testWidgets('a 728 x 90 strip on top, the stage centered below it', (
      tester,
    ) async {
      await pump(tester, const Size(800, 900));
      final strip = rect(tester, FrameIds.strip);
      final stage = rect(tester, FrameIds.stage);
      expect(strip.size, const Size(728, 90));
      expect(strip.bottom, lessThanOrEqualTo(stage.top));
      expect(stage.center.dx, closeTo(400, 0.5));
      expect(stage.width, lessThanOrEqualTo(780));
    });

    testWidgets('no strip while playing; the stage still centered', (
      tester,
    ) async {
      await pump(tester, const Size(800, 900), showAds: false);
      expect(find.byKey(FrameIds.strip), findsNothing);
      expect(rect(tester, FrameIds.stage).center.dx, closeTo(400, 0.5));
    });

    testWidgets('a window just over 600 keeps the stage inside it', (
      tester,
    ) async {
      await pump(tester, const Size(620, 900));
      final stage = rect(tester, FrameIds.stage);
      expect(stage.left, greaterThanOrEqualTo(0));
      expect(stage.right, lessThanOrEqualTo(620));
      expect(tester.takeException(), isNull);
    });
  });

  group('phone, 390 wide', () {
    testWidgets('the stage fills the width; the menu banner sits below it', (
      tester,
    ) async {
      await pump(tester, const Size(390, 800));
      expect(rect(tester, FrameIds.stage).width, 390 - 24);
      expect(find.byKey(const Key('banner.menu')), findsOneWidget);
      expect(find.byKey(FrameIds.rail), findsNothing);
      expect(find.byKey(FrameIds.strip), findsNothing);
    });

    testWidgets('the results screen asks for the postGame banner', (
      tester,
    ) async {
      await pump(tester, const Size(390, 800), slot: GameBannerSlot.postGame);
      expect(find.byKey(const Key('banner.postGame')), findsOneWidget);
    });

    testWidgets('no banner while playing', (tester) async {
      await pump(tester, const Size(390, 800), showAds: false);
      expect(find.byKey(const Key('banner.menu')), findsNothing);
      expect(rect(tester, FrameIds.stage).height, 800 - 24);
    });
  });

  testWidgets(
    'the default host (none) shows no ad anywhere and does not break',
    (tester) async {
      for (final size in const [
        Size(390, 800),
        Size(800, 900),
        Size(1280, 800),
      ]) {
        await pump(tester, size, host: const NoGameHost());
        expect(find.byKey(FrameIds.rail), findsNothing);
        expect(find.byKey(FrameIds.strip), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
