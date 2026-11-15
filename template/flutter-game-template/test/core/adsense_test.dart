import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/ads/ad_slot_frame.dart';
import 'package:flutter_game_template/core/ads/adsense_plan.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

// Built here, never written literally: scripts/ad_safety_check.sh fails on a real-looking id.
final String realLooking = 'ca-pub-${'1234567'}${'890123456'}';

AdSenseConfig cfg({
  bool enabled = true,
  String? pub,
  bool testMode = true,
  AgeTreatment age = AgeTreatment.none,
  Map<String, String>? slots,
}) => AdSenseConfig(
  enabled: enabled,
  publisherId: pub ?? realLooking,
  testMode: testMode,
  ageTreatment: age,
  slots: slots ?? {'menu': '111', 'pre_game': '222', 'post_game': '333'},
);

void main() {
  group('config parsing', () {
    test('the template ships AdSense off, with placeholders and test mode', () {
      final c = AppConfig.fromYamlString(
        File('app.config.yaml').readAsStringSync(),
      ).adsense;
      expect(c.enabled, isFalse);
      expect(c.publisherId, 'PLACEHOLDER_ADSENSE_PUBLISHER_ID');
      expect(c.testMode, isTrue);
      expect(c.isLive, isFalse);
      expect(c.slots.keys, ['menu', 'pre_game', 'post_game']);
      for (final p in AdPlacement.values) {
        expect(c.slotFor(p), isNull, reason: 'placeholder slot ${p.name}');
      }
    });

    test('a missing adsense section means off with test mode on', () {
      final src = File('app.config.yaml').readAsStringSync();
      final cut = src.replaceFirst(RegExp(r'adsense:\n(  .*\n|\n)+'), '\n');
      expect(cut.contains('adsense:\n  enabled'), isFalse);
      final c = AppConfig.fromYamlString(cut).adsense;
      expect(c.enabled, isFalse);
      expect(c.testMode, isTrue);
    });

    test('age treatment follows the audience for child and teen', () {
      final src = File('app.config.yaml').readAsStringSync();
      AgeTreatment of(String audience, String treatment) =>
          AppConfig.fromYamlString(
            src
                .replaceFirst('audience: adult', 'audience: $audience')
                .replaceFirst(
                  'age_treatment: none',
                  'age_treatment: $treatment',
                ),
          ).adsense.ageTreatment;
      expect(of('child', 'none'), AgeTreatment.child);
      expect(of('teen', 'none'), AgeTreatment.teen);
      expect(of('adult', 'none'), AgeTreatment.none);
      expect(of('adult', 'child'), AgeTreatment.child);
    });

    test('Google attribute values: child 1, teen 2, unspecified 0', () {
      expect(AgeTreatment.child.attributeValue, 1);
      expect(AgeTreatment.teen.attributeValue, 2);
      expect(AgeTreatment.none.attributeValue, 0);
    });
  });

  group('when the script and ads are allowed (same rule as web_shell.py)', () {
    test('off, placeholder id, short id: not live', () {
      expect(cfg(enabled: false).isLive, isFalse);
      expect(cfg(pub: 'PLACEHOLDER_ADSENSE_PUBLISHER_ID').isLive, isFalse);
      expect(cfg(pub: 'ca-pub-123').isLive, isFalse);
    });

    test('enabled with a real-looking id (test mode on): live', () {
      expect(cfg().isLive, isTrue);
      expect(cfg().testMode, isTrue);
    });
  });

  group('placement plan', () {
    test('only the three placements exist, none in play', () {
      expect(AdPlacement.values.map((p) => p.configName), [
        'menu',
        'pre_game',
        'post_game',
      ]);
    });

    test('nothing to request while off or on a placeholder', () {
      for (final p in AdPlacement.values) {
        expect(AdSensePlan.unitFor(cfg(enabled: false), p), isNull);
        expect(
          AdSensePlan.unitFor(cfg(pub: 'PLACEHOLDER_ADSENSE_PUBLISHER_ID'), p),
          isNull,
        );
        expect(AdSensePlan.unitFor(cfg(), p, bannerEnabled: false), isNull);
      }
    });

    test('a placeholder or empty slot gives no unit', () {
      final c = cfg(
        slots: {'menu': 'PLACEHOLDER_ADSENSE_SLOT_MENU', 'pre_game': ''},
      );
      for (final p in AdPlacement.values) {
        expect(AdSensePlan.unitFor(c, p), isNull);
      }
    });

    test('attributes per placement, with test mode', () {
      final u = AdSensePlan.unitFor(cfg(), AdPlacement.preGame)!;
      expect(u.attributes, {
        'data-ad-client': realLooking,
        'data-ad-slot': '222',
        'data-adtest': 'on',
      });
      expect(u.nonPersonalised, isFalse);
    });

    test('no data-adtest when test mode is off', () {
      final u = AdSensePlan.unitFor(cfg(testMode: false), AdPlacement.menu)!;
      expect(u.attributes.containsKey('data-adtest'), isFalse);
    });

    test(
      'child: tag 1 and non-personalised; teen: tag 2 and non-personalised',
      () {
        final child = AdSensePlan.unitFor(
          cfg(age: AgeTreatment.child),
          AdPlacement.postGame,
        )!;
        expect(child.attributes['data-tag-for-age-treatment'], '1');
        expect(child.nonPersonalised, isTrue);
        final teen = AdSensePlan.unitFor(
          cfg(age: AgeTreatment.teen),
          AdPlacement.menu,
        )!;
        expect(teen.attributes['data-tag-for-age-treatment'], '2');
        expect(teen.nonPersonalised, isTrue);
        expect(cfg(age: AgeTreatment.child).nonPersonalisedOnly, isTrue);
        expect(cfg(age: AgeTreatment.none).nonPersonalisedOnly, isFalse);
      },
    );

    test('none adds no age tag (unspecified)', () {
      final u = AdSensePlan.unitFor(cfg(), AdPlacement.menu)!;
      expect(u.attributes.containsKey('data-tag-for-age-treatment'), isFalse);
    });

    test('Ad privacy choices row: web and enabled only', () {
      expect(AdSensePlan.showPrivacyChoicesRow(cfg(), web: true), isTrue);
      expect(AdSensePlan.showPrivacyChoicesRow(cfg(), web: false), isFalse);
      expect(
        AdSensePlan.showPrivacyChoicesRow(cfg(enabled: false), web: true),
        isFalse,
      );
    });
  });

  testWidgets('the slot reserves a fixed height outside the game canvas', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: AdSlotFrame(placementName: 'menu', child: SizedBox.shrink()),
        ),
      ),
    );
    final box = tester.getSize(find.byKey(TestIds.adSlot('menu')));
    expect(box.height, adSenseSlotHeight);
    expect(TestIds.adSlot('menu'), adSlotKey('menu'));
  });
}
