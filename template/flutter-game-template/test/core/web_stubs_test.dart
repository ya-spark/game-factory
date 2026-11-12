import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_game_template/core/ads/ad_service.dart';
import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/config/products.dart';
import 'package:flutter_game_template/core/purchase/purchase_service.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web ad stub shows no ad and never grants a reward', () async {
    final ads = NoAdService();
    await ads.initialize();
    expect(ads.adsEnabled, isFalse);
    expect(ads.isRewardedReady, isFalse);
    expect(await ads.showRewarded(RewardedPlacement.revive), isFalse);
    expect(ads.buildBanner(AdPlacement.menu), isA<SizedBox>());
  });

  test('web purchase stub is unavailable, says so and buys nothing', () async {
    final p = UnavailablePurchaseService();
    expect(p.available, isFalse);
    expect(p.products, isEmpty);
    expect(p.priceOf('remove_ads_all'), isNull);
    expect(p.unavailableMessage, webPurchasesMessage);
    expect(webPurchasesMessage, contains('not available in this web version'));
    final seen = <PurchaseUpdate>[];
    final sub = p.updates.listen(seen.add);
    await p.buy('remove_ads_all');
    await p.restore();
    await sub.cancel();
    expect(seen, isEmpty);
  });

  test('device purchase services have no unavailable message', () {
    expect(FakePurchaseService(_catalog).unavailableMessage, isNull);
  });

  test('web content cache keeps files for the session', () async {
    final s = MemoryContentStore();
    expect(await s.read('a'), isNull);
    await s.writeAll({
      'a': Uint8List.fromList([1, 2]),
    });
    expect(await s.read('a'), [1, 2]);
  });
}

final _catalog = ProductCatalog.fromYamlString('products: []');
