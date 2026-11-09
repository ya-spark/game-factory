import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

Map<String, dynamic> item(String id, int seq, {String? extra}) => {
  'id': id,
  'seq': seq,
  'difficulty': 1,
  'type': 'mcq',
  'explanation': 'e',
  'prompt': 'p',
  'options': ['a', 'b'],
  'correct': 0,
  'image': ?extra,
};

Map<String, dynamic> pack(
  String id,
  int n, {
  int version = 1,
  String? productId,
  int year = 3,
  String subject = 'maths',
  List<String> preview = const [],
  String? image,
}) => {
  'id': id,
  'version': version,
  'lang': 'en-AU',
  'subject': subject,
  'year': year,
  'topic': 'times_tables',
  'title': 'Pack $id',
  'product_id': ?productId,
  if (preview.isNotEmpty) 'preview': {'item_ids': preview},
  'items': [
    for (var i = 1; i <= n; i++)
      item(
        '$id.${i.toString().padLeft(3, '0')}',
        i,
        extra: i == 1 ? image : null,
      ),
  ],
};

/// A fake static server: serves `<app>/<path>`; can fail on chosen paths.
class FakeServer implements ContentFetcher {
  final Map<String, Uint8List> files = {};
  final Set<String> failing = {};
  final List<Uri> requests = [];

  @override
  Future<Uint8List> get(Uri url) async {
    requests.add(url);
    final name = url.path.split('/').skip(3).join('/'); // /v1/<app>/<path>
    if (failing.contains(name)) throw const HttpFailure();
    final f = files[name];
    if (f == null) throw const HttpFailure();
    return f;
  }
}

class HttpFailure implements Exception {
  const HttpFailure();
}

const app = 'learn_app';

/// Publishes packs on [server]: index, optional signature, pack files.
Future<void> publish(
  FakeServer server,
  List<Map<String, dynamic>> packs, {
  int version = 1,
  List<int>? seed,
  Map<String, Uint8List> assets = const {},
  bool sign = true,
  Map<String, Map<String, dynamic>> previews = const {},
}) async {
  final files = <String, Uint8List>{};
  final prev = <String, MapEntry<String, Uint8List>>{};
  for (final p in packs) {
    files['packs/${p['id']}/${p['version']}/full.json'] = b(jsonEncode(p));
    final pv = previews[p['id']];
    if (pv != null) {
      prev[p['id'] as String] = MapEntry(
        'packs/${p['id']}/${p['version']}/preview.json',
        b(jsonEncode(pv)),
      );
    }
  }
  final idx = buildIndex(
    app: app,
    version: version,
    packFiles: files,
    readAsset: (a) => assets[a],
    previewFiles: prev,
  );
  final bytes = encodeIndex(idx);
  server.files
    ..['index.json'] = bytes
    ..addAll(files)
    ..addAll(assets)
    ..addAll({for (final e in prev.values) e.key: e.value});
  if (seed != null && sign) {
    server.files['index.sig'] = b(await signIndex(bytes, seed));
  }
}

ServerContentSource source(
  FakeServer server,
  ContentStore store, {
  SigningConfig signing = const SigningConfig(
    publicKey: 'PLACEHOLDER_X',
    keyId: 'PLACEHOLDER_K',
  ),
}) => ServerContentSource(
  baseUrl: 'https://content.example.com/v1/',
  appId: app,
  fetcher: server,
  store: store,
  signing: signing,
);

void main() {
  final seed = parseSigningKey(
    File('test/fixtures/test_only_signing_key.txt').readAsStringSync(),
  );
  late String pub;
  setUpAll(() async => pub = await publicKeyOf(seed));

  group('static server source', () {
    test('only https is accepted', () {
      expect(
        () => ServerContentSource(
          baseUrl: 'http://content.example.com/v1/',
          appId: app,
          fetcher: FakeServer(),
          store: MemoryContentStore(),
          signing: const SigningConfig(publicKey: 'PLACEHOLDER', keyId: 'P'),
        ),
        throwsArgumentError,
      );
    });

    test('hash mismatch is rejected and nothing is cached', () async {
      final server = FakeServer();
      await publish(server, [pack('p1', 3)]);
      final store = MemoryContentStore();
      final src = source(server, store);
      expect((await src.checkForUpdates()).status, UpdateStatus.updated);
      server.files['packs/p1/1/full.json'] = b('{"tampered":true}');
      final entry = (await src.listPacks()).single;
      final r = await src.download(
        entry,
        PackPart.full,
        connection: ConnectionKind.wifi,
      );
      expect(r.status, DownloadStatus.failed);
      expect(r.code, 'hash_mismatch');
      expect(store.files.keys.where((k) => k.startsWith('packs/')), isEmpty);
      expect(await src.loadPack('p1'), isNull);
    });

    test('a partial download leaves no cache', () async {
      final server = FakeServer();
      await publish(
        server,
        [pack('p1', 3, image: 'assets/content/a.png')],
        assets: {'assets/content/a.png': b('png-bytes')},
      );
      final store = MemoryContentStore();
      final src = source(server, store);
      await src.checkForUpdates();
      server.failing.add('assets/content/a.png');
      final entry = (await src.listPacks()).single;
      final r = await src.download(
        entry,
        PackPart.full,
        connection: ConnectionKind.wifi,
      );
      expect(r.ok, isFalse);
      expect(await src.isCached(entry, PackPart.full), isFalse);
      expect(store.files.keys.where((k) => k.startsWith('packs/')), isEmpty);
      // a retry that works stores everything
      server.failing.clear();
      expect(
        (await src.download(
          entry,
          PackPart.full,
          connection: ConnectionKind.wifi,
        )).ok,
        isTrue,
      );
      expect(await src.isCached(entry, PackPart.full), isTrue);
      expect((await src.loadPack('p1'))!.items, hasLength(3));
    });

    test('no network: check fails quietly and the cache still works', () async {
      final server = FakeServer();
      await publish(server, [pack('p1', 3)]);
      final store = MemoryContentStore();
      final src = source(server, store);
      await src.checkForUpdates();
      final entry = (await src.listPacks()).single;
      await src.download(entry, PackPart.full, connection: ConnectionKind.wifi);
      server.failing.addAll(['index.json']);
      expect((await src.checkForUpdates()).status, UpdateStatus.failed);
      expect((await src.loadPack('p1'))!.id, 'p1');
    });

    test('unsigned index is accepted while no key is set', () async {
      final server = FakeServer();
      await publish(server, [pack('p1', 3)]);
      final src = source(server, MemoryContentStore());
      expect((await src.checkForUpdates()).status, UpdateStatus.updated);
      expect(await src.listPacks(), hasLength(1));
    });

    test('with a key: unsigned and wrongly signed are rejected', () async {
      final server = FakeServer();
      final signing = SigningConfig(publicKey: pub, keyId: 'k1');
      await publish(server, [pack('p1', 3)], sign: false);
      final store = MemoryContentStore();
      final src = source(server, store, signing: signing);
      server.failing.add('index.sig');
      var r = await src.checkForUpdates();
      expect(r.status, UpdateStatus.failed); // no signature file at all
      server.failing.clear();
      server.files['index.sig'] = b(base64.encode(List.filled(64, 1)));
      r = await src.checkForUpdates();
      expect(r.status, UpdateStatus.rejected);
      expect(r.code, 'bad_signature');
      expect(await src.listPacks(), isEmpty);
      // another key's signature is wrong too
      final other = await signIndex(
        server.files['index.json']!,
        List.filled(32, 7),
      );
      server.files['index.sig'] = b(other);
      expect((await src.checkForUpdates()).code, 'bad_signature');
    });

    test('with a key: a valid signature is accepted', () async {
      final server = FakeServer();
      await publish(server, [pack('p1', 3)], seed: seed);
      final src = source(
        server,
        MemoryContentStore(),
        signing: SigningConfig(publicKey: pub, keyId: 'k1'),
      );
      expect((await src.checkForUpdates()).status, UpdateStatus.updated);
      expect(await src.listPacks(), hasLength(1));
    });

    test(
      'no downgrade: after a signed index, unsigned is never accepted',
      () async {
        final server = FakeServer();
        await publish(server, [pack('p1', 3)], seed: seed, version: 1);
        final store = MemoryContentStore();
        final signed = source(
          server,
          store,
          signing: SigningConfig(publicKey: pub, keyId: 'k1'),
        );
        await signed.checkForUpdates();
        // The server now serves an unsigned, newer index; even an app with no key set refuses it.
        await publish(server, [pack('p1', 3), pack('p2', 3)], version: 2);
        server.files.remove('index.sig');
        final noKey = source(server, store);
        final r = await noKey.checkForUpdates();
        // No signature file to fetch: the update fails and nothing changes.
        expect(r.status, isNot(UpdateStatus.updated));
        expect((await signed.listPacks()), hasLength(1));
        // A signature file that is empty is also not good enough.
        server.files['index.sig'] = b('');
        expect(
          (await noKey.checkForUpdates()).status,
          isNot(UpdateStatus.updated),
        );
        expect((await signed.listPacks()), hasLength(1));
      },
    );

    test('no rollback: an older index is ignored', () async {
      final server = FakeServer();
      final signing = SigningConfig(publicKey: pub, keyId: 'k1');
      final store = MemoryContentStore();
      final src = source(server, store, signing: signing);
      await publish(
        server,
        [pack('p1', 3), pack('p2', 3)],
        seed: seed,
        version: 5,
      );
      await src.checkForUpdates();
      await publish(server, [pack('p1', 3)], seed: seed, version: 4);
      expect(
        (await src.checkForUpdates()).status,
        UpdateStatus.rollbackIgnored,
      );
      expect(await src.listPacks(), hasLength(2));
      // same version: nothing to do
      await publish(
        server,
        [pack('p1', 3), pack('p2', 3)],
        seed: seed,
        version: 5,
      );
      expect((await src.checkForUpdates()).status, UpdateStatus.upToDate);
    });

    test('an index of another app is rejected', () async {
      final server = FakeServer();
      await publish(server, [pack('p1', 3)]);
      final src = ServerContentSource(
        baseUrl: 'https://content.example.com/v1/',
        appId: 'other',
        fetcher: server,
        store: MemoryContentStore(),
        signing: const SigningConfig(publicKey: 'PLACEHOLDER', keyId: 'P'),
      );
      server.files['index.json'] =
          server.files['index.json']!; // served under other/
      expect((await src.checkForUpdates()).status, isNot(UpdateStatus.updated));
    });

    test('requests carry nothing but the path (one host, https)', () async {
      final server = FakeServer();
      await publish(server, [pack('p1', 3)]);
      final src = source(server, MemoryContentStore());
      await src.checkForUpdates();
      for (final u in server.requests) {
        expect(u.scheme, 'https');
        expect(u.host, 'content.example.com');
        expect(u.hasQuery, isFalse);
        expect(u.userInfo, isEmpty);
      }
    });
  });

  group('downloads and purchases', () {
    Future<
      ({
        FakeServer server,
        MemoryContentStore store,
        ContentRepository repo,
        Set<String> owned,
      })
    >
    setUp({int bigAssetBytes = 0}) async {
      final server = FakeServer();
      final assets = <String, Uint8List>{};
      String? image;
      if (bigAssetBytes > 0) {
        image = 'assets/content/big.bin';
        assets[image] = Uint8List(bigAssetBytes);
      }
      final extra = pack(
        'x1',
        6,
        productId: 'pack_x1',
        preview: ['x1.001', 'x1.002'],
        image: image,
      );
      final previewPack = {
        ...extra,
        'items': [for (final i in (extra['items'] as List).take(2)) i],
      };
      await publish(
        server,
        [extra],
        assets: assets,
        previews: {'x1': previewPack},
      );
      final store = MemoryContentStore();
      final owned = <String>{};
      final repo = ContentRepository(
        builtIn: BuiltInContentSource((_) async => null, appId: app),
        server: source(server, store),
        store: store,
        isOwned: owned.contains,
      );
      return (server: server, store: store, repo: repo, owned: owned);
    }

    test('preview downloads with no purchase, on mobile data too', () async {
      final t = await setUp();
      await t.repo.checkOnLaunch(
        DateTime(2026, 1, 1),
        connection: ConnectionKind.mobile,
      );
      final c = (await t.repo.catalog()).single;
      final r = await t.repo.download(
        c,
        PackPart.preview,
        connection: ConnectionKind.mobile,
        settings: const DownloadSettings(wifiOnly: true),
      );
      expect(r.ok, isTrue);
      final play = await t.repo.loadForPlay((await t.repo.catalog()).single);
      expect(play!.previewOnly, isTrue);
      expect(play.pack.items, hasLength(2));
    });

    test('the full pack needs a confirmed purchase', () async {
      final t = await setUp();
      await t.repo.checkOnLaunch(
        DateTime(2026, 1, 1),
        connection: ConnectionKind.wifi,
      );
      final c = (await t.repo.catalog()).single;
      var r = await t.repo.download(
        c,
        PackPart.full,
        connection: ConnectionKind.wifi,
      );
      expect(r.status, DownloadStatus.notPurchased);
      expect(t.store.files.keys.where((k) => k.endsWith('full.json')), isEmpty);
      t.owned.add('pack_x1');
      r = await t.repo.download(
        c,
        PackPart.full,
        connection: ConnectionKind.wifi,
      );
      expect(r.ok, isTrue);
      final play = await t.repo.loadForPlay((await t.repo.catalog()).single);
      expect(play!.previewOnly, isFalse);
      expect(play.pack.items, hasLength(6));
    });

    test(
      'without the purchase a downloaded full pack is still preview only',
      () async {
        final t = await setUp();
        await t.repo.checkOnLaunch(
          DateTime(2026, 1, 1),
          connection: ConnectionKind.wifi,
        );
        t.owned.add('pack_x1');
        final c = (await t.repo.catalog()).single;
        await t.repo.download(
          c,
          PackPart.full,
          connection: ConnectionKind.wifi,
        );
        await t.repo.download(
          c,
          PackPart.preview,
          connection: ConnectionKind.wifi,
        );
        t.owned.clear(); // e.g. purchase refunded
        final play = await t.repo.loadForPlay((await t.repo.catalog()).single);
        expect(play!.previewOnly, isTrue);
      },
    );

    test(
      'above the size limit on mobile data the parent is asked first',
      () async {
        final t = await setUp(bigAssetBytes: 21 * 1024 * 1024);
        t.owned.add('pack_x1');
        await t.repo.checkOnLaunch(
          DateTime(2026, 1, 1),
          connection: ConnectionKind.wifi,
        );
        final c = (await t.repo.catalog()).single;
        var r = await t.repo.download(
          c,
          PackPart.full,
          connection: ConnectionKind.mobile,
        );
        expect(r.status, DownloadStatus.needsParentApproval);
        expect(
          t.store.files.keys.where((k) => k.contains('full.json')),
          isEmpty,
        );
        r = await t.repo.download(
          c,
          PackPart.full,
          connection: ConnectionKind.mobile,
          parentApproved: true,
        );
        expect(r.ok, isTrue);
      },
    );

    test(
      'a small pack on mobile data downloads without asking, unless Wi-Fi only',
      () async {
        final t = await setUp();
        t.owned.add('pack_x1');
        await t.repo.checkOnLaunch(
          DateTime(2026, 1, 1),
          connection: ConnectionKind.wifi,
        );
        final c = (await t.repo.catalog()).single;
        var r = await t.repo.download(
          c,
          PackPart.full,
          connection: ConnectionKind.mobile,
          settings: const DownloadSettings(wifiOnly: true),
        );
        expect(r.status, DownloadStatus.blockedWifiOnly);
        r = await t.repo.download(
          c,
          PackPart.full,
          connection: ConnectionKind.mobile,
        );
        expect(r.ok, isTrue);
      },
    );

    test('offline: no download, no crash', () async {
      final t = await setUp();
      await t.repo.checkOnLaunch(
        DateTime(2026, 1, 1),
        connection: ConnectionKind.wifi,
      );
      final c = (await t.repo.catalog()).single;
      final r = await t.repo.download(
        c,
        PackPart.preview,
        connection: ConnectionKind.offline,
      );
      expect(r.status, DownloadStatus.offline);
    });

    test('update check runs at most once a day', () async {
      final t = await setUp();
      final day = DateTime(2026, 1, 1, 8);
      expect(
        (await t.repo.checkOnLaunch(
          day,
          connection: ConnectionKind.wifi,
        )).status,
        UpdateStatus.updated,
      );
      final before = t.server.requests.length;
      await t.repo.checkOnLaunch(
        day.add(const Duration(hours: 5)),
        connection: ConnectionKind.wifi,
      );
      expect(t.server.requests.length, before);
      await t.repo.checkOnLaunch(
        day.add(const Duration(hours: 25)),
        connection: ConnectionKind.wifi,
      );
      expect(t.server.requests.length, greaterThan(before));
    });
  });

  group('built-in content and newest version', () {
    Future<BuiltInContentSource> builtIn(
      List<Map<String, dynamic>> packs,
    ) async {
      final files = {
        for (final p in packs) 'packs/${p['id']}.json': b(jsonEncode(p)),
      };
      final idx = encodeIndex(
        buildIndex(
          app: app,
          version: 1,
          packFiles: files,
          readAsset: (_) => null,
        ),
      );
      return BuiltInContentSource((path) async {
        if (path == 'assets/content/index.json') return idx;
        return files[path.replaceFirst('assets/content/', '')];
      }, appId: app);
    }

    test('works offline and a corrupt built-in file is refused', () async {
      final bi = await builtIn([pack('p1', 3)]);
      final repo = ContentRepository(builtIn: bi, isOwned: (_) => false);
      expect((await repo.catalog()).single.builtIn, isTrue);
      expect((await repo.loadAllForPlay()).single.pack.items, hasLength(3));
      final bad = BuiltInContentSource(
        (path) async => path.endsWith('index.json')
            ? encodeIndex(
                buildIndex(
                  app: app,
                  version: 1,
                  packFiles: {'packs/p1.json': b(jsonEncode(pack('p1', 3)))},
                  readAsset: (_) => null,
                ),
              )
            : b('{}'),
        appId: app,
      );
      expect(() => bad.loadPack('p1'), throwsA(isA<ContentException>()));
    });

    test('a newer verified download wins over the built-in version; an older one does not', () async {
      final bi = await builtIn([pack('p1', 3)]);
      final server = FakeServer();
      await publish(server, [pack('p1', 5, version: 2)]);
      final store = MemoryContentStore();
      final repo = ContentRepository(
        builtIn: bi,
        server: source(server, store),
        store: store,
        isOwned: (_) => false,
      );
      // built-in updates download by themselves after a check
      await repo.checkOnLaunch(
        DateTime(2026, 1, 1),
        connection: ConnectionKind.wifi,
      );
      expect((await repo.loadAllForPlay()).single.pack.items, hasLength(5));

      // built-in version now newer than the cached one (app update): the built-in copy wins
      final bi2 = await builtIn([pack('p1', 7, version: 3)]);
      final repo2 = ContentRepository(
        builtIn: bi2,
        server: source(server, store),
        store: store,
        isOwned: (_) => false,
      );
      expect((await repo2.loadAllForPlay()).single.pack.items, hasLength(7));
    });
  });

  group('daily release', () {
    final packs = [LoadedPack(ContentPack(pack('m', 30)))];
    const cfg = ReleaseConfig();
    ReleaseState step(ReleaseState? s, Set<String> passed, int day) =>
        ReleaseEngine.advance(
          s,
          ReleaseEngine.ordered(packs, 'maths', 3),
          passed,
          day,
          cfg,
        );

    Set<String> ids(int n) => {
      for (var i = 1; i <= n; i++) 'm.${i.toString().padLeft(3, '0')}',
    };

    test('10 items open at the start, in seq order', () {
      final s = step(null, {}, 100);
      expect(s.openIds, ids(10));
    });

    test('2 more open each day only when every open item is passed', () {
      var s = step(null, {}, 100);
      expect(step(s, {}, 101).openIds, ids(10)); // nothing passed
      expect(step(s, ids(9), 101).openIds, ids(10)); // one missing
      s = step(s, ids(10), 101);
      expect(s.openIds, ids(12));
      expect(step(s, ids(10), 101).openIds, ids(12)); // same day: nothing more
    });

    test(
      'items open once passing happens later (still max 2, no catch up)',
      () {
        var s = step(null, {}, 100);
        s = step(s, {}, 101); // not passed
        s = step(s, {}, 105);
        expect(s.openIds, ids(10));
        s = step(s, ids(10), 106);
        expect(s.openIds, ids(12)); // not 2 per missed day
      },
    );

    test('a date that goes back changes nothing', () {
      final s = step(step(null, {}, 100), ids(10), 101);
      expect(step(s, ids(12), 90), same(s));
    });

    test('a changed device date opens items sooner (accepted limit)', () {
      var s = step(null, {}, 100);
      s = step(s, ids(10), 200);
      expect(s.openIds, ids(12));
    });

    test('a year change starts a new release and keeps the old items open', () {
      final both = [
        LoadedPack(ContentPack(pack('m3', 15))),
        LoadedPack(ContentPack(pack('m4', 15, year: 4))),
      ];
      var p = const ChildProgress();
      p = ReleaseEngine.refresh(p, both, 3, 100, cfg);
      p = ReleaseEngine.refresh(p, both, 4, 100, cfg);
      expect(p.release[releaseKey('maths', 3)]!.openIds, hasLength(10));
      expect(p.release[releaseKey('maths', 4)]!.openIds, hasLength(10));
      final open = OpenItems.compute(both, p, fullUnlock: false);
      expect(open, hasLength(20));
    });

    test('items that are not open are not offered', () {
      final p = ReleaseEngine.refresh(
        const ChildProgress(),
        packs,
        3,
        100,
        cfg,
      );
      expect(OpenItems.compute(packs, p, fullUnlock: false), hasLength(10));
      expect(
        OpenItems.compute(packs, const ChildProgress(), fullUnlock: false),
        isEmpty,
      );
    });

    test('Full Unlock opens all built-in content', () {
      expect(
        OpenItems.compute(packs, const ChildProgress(), fullUnlock: true),
        hasLength(30),
      );
    });

    test('extra packs: preview items only until the full part is loaded', () {
      final extra = ContentPack(
        pack('x', 5, productId: 'pack_x', preview: ['x.001', 'x.003']),
      );
      final prev = OpenItems.compute(
        [LoadedPack(extra, previewOnly: true)],
        const ChildProgress(),
        fullUnlock: false,
      );
      expect(prev.map((p) => p.id), ['x.001', 'x.003']);
      final full = OpenItems.compute(
        [LoadedPack(extra)],
        const ChildProgress(),
        fullUnlock: false,
      );
      expect(full, hasLength(5));
      // Full Unlock does not open extra packs
      final locked = OpenItems.compute(
        [LoadedPack(extra, previewOnly: true)],
        const ChildProgress(),
        fullUnlock: true,
      );
      expect(locked, hasLength(2));
    });
  });

  group('progress', () {
    test('records attempts, passes and topic results; mistakes list', () {
      final pk = ContentPack(pack('m', 3));
      final items = [
        for (final it in pk.items)
          PoolItem(
            item: it,
            packId: 'm',
            subject: 'maths',
            year: 3,
            topic: 'times_tables',
          ),
      ];
      var p = const ChildProgress();
      p = p.record(items[0], correct: false);
      p = p.record(items[1], correct: true);
      expect(p.mistakeIds, ['m.001']);
      p = p.record(items[0], correct: true);
      p = p.record(items[0], correct: true);
      final t = p.topics[topicKey('maths', 3, 'times_tables')]!;
      expect((t.attempted, t.passed), (2, 2));
      expect(p.items['m.001']!.attempts, 3);
      expect(p.passedIds, {'m.001', 'm.002'});
      expect(p.mistakeIds, isEmpty);
      final back = ChildProgress.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>,
      );
      expect(back.toJson(), p.toJson());
    });
  });

  group('selector', () {
    final pk = ContentPack(pack('m', 20));
    final open = [
      for (final it in pk.items)
        PoolItem(
          item: it,
          packId: 'm',
          subject: 'maths',
          year: 3,
          topic: 'times_tables',
        ),
    ];
    List<String> pick(int seed, {List<String> recent = const []}) =>
        ItemSelector.select(
          open: open,
          subject: 'maths',
          year: 3,
          count: 5,
          random: Random(seed),
          recent: recent,
        ).map((p) => p.id).toList();

    test('same seed, same result; different seed, different result', () {
      expect(pick(1), pick(1));
      expect(pick(1), isNot(pick(2)));
      expect(pick(1).toSet(), hasLength(5));
    });

    test('recently seen items are avoided, then reused oldest first', () {
      final recent = [for (final p in open.take(18)) p.id];
      final r = pick(3, recent: recent);
      expect(r.take(2).toSet(), {'m.019', 'm.020'});
      expect(r.skip(2), ['m.001', 'm.002', 'm.003']); // least recent first
    });

    test('draws only from open items and honours filters', () {
      final few = open.take(3).toList();
      final r = ItemSelector.select(
        open: few,
        subject: 'maths',
        year: 3,
        count: 10,
        random: Random(1),
      );
      expect(r, hasLength(3));
      expect(
        ItemSelector.select(
          open: few,
          subject: 'english',
          year: 3,
          count: 3,
          random: Random(1),
        ),
        isEmpty,
      );
      expect(
        ItemSelector.hasMinimumPool(
          open: few,
          subject: 'maths',
          year: 3,
          needed: 4,
        ),
        isFalse,
      );
      expect(
        ItemSelector.hasMinimumPool(
          open: few,
          subject: 'maths',
          year: 3,
          needed: 3,
        ),
        isTrue,
      );
    });
  });
}
