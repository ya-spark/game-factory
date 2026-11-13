import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_game_template/core/config/app_config.dart';
import 'package:flutter_game_template/core/config/products.dart';
import 'package:flutter_game_template/core/content/connectivity_probe.dart';
import 'package:flutter_game_template/core/content/learning_service.dart';
import 'package:flutter_game_template/core/profile/child_profile.dart';
import 'package:flutter_game_template/core/profile/profile_store.dart';
import 'package:flutter_game_template/core/purchase/purchase_service.dart';
import 'package:flutter_game_template/core/save/save_data.dart';
import 'package:flutter_game_template/core/save/save_service.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = ProductCatalog([
  ProductDef(
    id: 'unlock_full',
    type: ProductType.nonConsumable,
    title: 'Full Unlock',
    description: '',
    grants: 'unlock_full',
  ),
  ProductDef(
    id: 'coins_500',
    type: ProductType.consumable,
    title: 'Coins',
    description: '',
    coins: 500,
  ),
]);

Map<String, dynamic> _pack(String id, int n, {int year = 3}) => {
  'id': id,
  'version': 1,
  'lang': 'en-AU',
  'subject': 'maths',
  'year': year,
  'topic': 'times_tables',
  'title': id,
  'items': [
    for (var i = 1; i <= n; i++)
      {
        'id': '$id.${i.toString().padLeft(3, '0')}',
        'seq': i,
        'difficulty': 1,
        'type': 'mcq',
        'explanation': 'e',
      },
  ],
};

void main() {
  late DateTime now;
  late MemorySaveService saves;
  late ProfileStore store;

  setUp(() async {
    now = DateTime(2026, 3, 1, 10);
    saves = MemorySaveService();
    store = ProfileStore(
      saves: saves,
      retention: const RetentionConfig(),
      clock: () => now,
    );
    await store.init();
  });

  LearningService learning({int perDay = 2}) {
    final bytes = encodeIndex(
      buildIndex(
        app: 'a',
        version: 1,
        packFiles: {
          'packs/m3.json': Uint8List.fromList(
            utf8.encode(jsonEncode(_pack('m3', 30))),
          ),
        },
        readAsset: (_) => null,
      ),
    );
    final files = {
      'packs/m3.json': Uint8List.fromList(
        utf8.encode(jsonEncode(_pack('m3', 30))),
      ),
    };
    return LearningService(
      config: ContentConfig(
        dailyRelease: ReleaseConfig(perDayPerSubject: perDay),
      ),
      profile: store,
      purchases: FakePurchaseService(_catalog),
      connectivity: FakeConnectivityProbe(),
      clock: () => now,
      repository: ContentRepository(
        builtIn: BuiltInContentSource((path) async {
          if (path == 'assets/content/index.json') return bytes;
          return files[path.replaceFirst('assets/content/', '')];
        }, appId: 'a'),
        isOwned: store.ownsPack,
      ),
    );
  }

  test('add up to four children; nickname is trimmed and limited', () async {
    for (var i = 1; i <= 4; i++) {
      expect(await store.addChild('Kid $i  '), isNotNull);
    }
    expect(store.canAddChild, isFalse);
    expect(await store.addChild('Fifth'), isNull);
    expect(await store.addChild('   '), isNull);
    expect(store.children.map((c) => c.nickname), [
      'Kid 1',
      'Kid 2',
      'Kid 3',
      'Kid 4',
    ]);
    await store.deleteChild('p2');
    final c = await store.addChild('A very long nickname indeed');
    expect(c!.nickname.length, maxNicknameLength);
    expect(c.id, isNot('p1')); // ids are never reused while others exist
  });

  test('picker state: nobody is active until a child is chosen', () async {
    final c = (await store.addChild('Mia', year: 3))!;
    expect(store.activeChild, isNull);
    store.selectChild(c.id);
    expect(store.activeChild!.nickname, 'Mia');
    store.leaveChild();
    expect(store.activeChild, isNull);
  });

  test(
    'two profiles keep separate progress and share one coin balance',
    () async {
      final a = (await store.addChild('Ann', year: 3))!;
      final b = (await store.addChild('Ben', year: 3))!;
      final l = learning();
      await l.refreshRelease(a.id);
      await l.refreshRelease(b.id);
      final items = await l.openItems(a.id);
      expect(items, hasLength(10));
      await l.recordAnswer(a.id, items.first, correct: true);
      expect(store.children[0].progress.passedIds, {items.first.id});
      expect(store.children[1].progress.passedIds, isEmpty);
      await store.addCoins(30);
      store.selectChild(a.id);
      expect(store.data.coins, 30);
      store.selectChild(b.id);
      expect(store.data.coins, 30);
      expect(await store.spendCoins(10), isTrue);
      store.selectChild(a.id);
      expect(store.data.coins, 20);
    },
  );

  test(
    'release follows the day and the passed rule through the service',
    () async {
      final a = (await store.addChild('Ann', year: 3))!;
      final l = learning();
      await l.refreshRelease(a.id);
      for (final it in await l.openItems(a.id)) {
        await l.recordAnswer(a.id, it, correct: true);
      }
      now = now.add(const Duration(days: 1));
      await l.refreshRelease(a.id);
      expect(await l.openItems(a.id), hasLength(12));
      // not passed: the next day opens nothing
      now = now.add(const Duration(days: 1));
      await l.refreshRelease(a.id);
      expect(await l.openItems(a.id), hasLength(12));
    },
  );

  test(
    'year change starts a new release; parent can change year and lock',
    () async {
      final a = (await store.addChild('Ann', year: 3))!;
      final l = learning();
      await l.refreshRelease(a.id);
      await store.setChildYear(a.id, 4);
      await store.setChildLockedMode(a.id, LearnMode.study);
      expect(store.children.single.year, 4);
      expect(store.children.single.lockedMode, LearnMode.study);
      await l.refreshRelease(a.id); // no year-4 content: year 3 items stay open
      expect(await l.openItems(a.id), hasLength(10));
      await store.setChildLockedMode(a.id, null);
      expect(store.children.single.lockedMode, isNull);
    },
  );

  test('deleting a profile removes only that child', () async {
    final a = (await store.addChild('Ann', year: 3))!;
    final b = (await store.addChild('Ben', year: 3))!;
    await store.addCoins(50);
    store.selectChild(a.id);
    await store.deleteChild(a.id);
    expect(store.activeChild, isNull);
    expect(store.children.map((c) => c.id), [b.id]);
    expect(store.data.coins, 50);
    // and it is saved
    expect(saves.data.profiles.map((c) => c.id), [b.id]);
  });

  test('migration: an old single-player save becomes the first profile', () {
    final old = {
      'version': 2,
      'coins': 77,
      'bestScore': 900,
      'adsRemoved': true,
    };
    final d = SaveData.fromJson(SaveMigrator.migrate(old));
    expect(d.coins, 77);
    expect(d.bestScore, 900);
    expect(d.adsRemoved, isTrue);
    expect(d.profiles, hasLength(1));
    expect(d.profiles.single.year, isNull);
    expect(d.fullUnlock, isFalse);
    expect(SaveData.currentVersion, 5);
    // v0 saves migrate all the way
    expect(
      SaveData.fromJson(SaveMigrator.migrate({'highScore': 5})).profiles,
      hasLength(1),
    );
    // round trip
    final back = SaveData.fromJson(
      SaveMigrator.migrate(
        jsonDecode(jsonEncode(d.toJson())) as Map<String, Object?>,
      ),
    );
    expect(back.profiles.single.nickname, d.profiles.single.nickname);
  });

  test('Full Unlock opens every built-in item for every child', () async {
    final a = (await store.addChild('Ann', year: 3))!;
    final l = learning();
    await l.refreshRelease(a.id);
    expect(await l.openItems(a.id), hasLength(10));
    await store.deliverPurchase(
      const PurchaseUpdate(
        'unlock_full',
        PurchaseStatus.purchased,
        purchaseId: 'o1',
      ),
      _catalog,
    );
    expect(store.data.fullUnlock, isTrue);
    expect(await l.openItems(a.id), hasLength(30));
    // restore is idempotent
    await store.deliverPurchase(
      const PurchaseUpdate('unlock_full', PurchaseStatus.restored),
      _catalog,
    );
    expect(store.data.fullUnlock, isTrue);
  });

  test(
    'an extra pack purchase is stored once and shared by the device',
    () async {
      expect(store.ownsPack('pack_x1'), isFalse);
      await store.deliverPurchase(
        const PurchaseUpdate(
          'pack_x1',
          PurchaseStatus.purchased,
          purchaseId: 'o2',
        ),
        _catalog,
      );
      await store.deliverPurchase(
        const PurchaseUpdate('pack_x1', PurchaseStatus.restored),
        _catalog,
      );
      expect(store.data.ownedPacks, {'pack_x1'});
      expect(store.ownsPack('pack_x1'), isTrue);
      await store.deliverPurchase(
        const PurchaseUpdate('pack_x1', PurchaseStatus.canceled),
        _catalog,
      );
      expect(store.ownsPack('pack_x1'), isTrue);
    },
  );

  test('config: content defaults and the signing-off flag', () {
    const c = ContentConfig();
    expect(c.signingOff, isTrue);
    expect(c.baseUrl, startsWith('https://'));
    expect(c.dailyRelease.initialPerSubject, 10);
    expect(c.dailyRelease.perDayPerSubject, 2);
    expect(
      c.downloadSettings(wifiOnly: false).mobileConfirmBytes,
      20 * 1024 * 1024,
    );
  });
}
