import 'package:flutter/material.dart';
import 'package:flutter_game_template/app.dart';
import 'package:flutter_game_template/core/profile/child_profile.dart';
import 'package:flutter_game_template/ui/theme/color_themes.dart';
import 'package:flutter_game_template/ui/theme/design_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_services.dart';
import '../kit/kit_test.dart' show FileDesignBundle, appIds, loadDesign;

void main() {
  group('every colour theme keeps text and buttons readable', () {
    for (final s in colorThemeSpecs) {
      test(s.id, () {
        final p = themePalette(s);
        for (final (fg, bg) in contrastPairs) {
          if (!p.containsKey(fg) || !p.containsKey(bg)) continue;
          expect(
            contrastRatio(p[fg]!, p[bg]!),
            greaterThanOrEqualTo(4.5),
            reason: '${s.id}: $fg on $bg',
          );
        }
      });
    }
  });

  test('every theme in the shop has a palette except Classic', () {
    for (final i in shopItems.where((i) => i.kind == ShopKind.theme)) {
      expect(colorThemeSpec(i.id) != null, i.id != 'default', reason: i.id);
    }
    expect(colorThemeOverrides('default'), isNull);
    expect(colorThemeOverrides('nope'), isNull);
  });

  test('themes cost 60 coins', () {
    for (final i in shopItems.where(
      (i) => i.kind == ShopKind.theme && i.id != 'default',
    )) {
      expect(i.price, 60, reason: i.id);
    }
  });

  testWidgets('the equipped theme changes the app colour scheme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final id = appIds.first;
    final s = await buildFakeServices(contentEnabled: true);
    final kid = (await s.profile.addChild('Mia', year: 3))!;
    s.profile.selectChild(kid.id);
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: FileDesignBundle(),
        child: GameApp(services: s, design: loadDesign(id)),
      ),
    );
    await tester.pump();
    Color primary() =>
        Theme.of(tester.element(find.byType(Scaffold).first))
            .colorScheme
            .primary;
    final before = primary();
    await s.profile.addCoins(100);
    final sunset = shopItems.firstWhere((i) => i.id == 'sunset');
    expect(await s.profile.buyItem(sunset), isTrue);
    expect(await s.profile.equipItem(kid.id, sunset), isTrue);
    await tester.pump();
    await tester.pump();
    expect(primary(), isNot(before));
    expect(
      primary().toARGB32(),
      themePalette(colorThemeSpec('sunset')!)['primary'],
    );
  });
}
